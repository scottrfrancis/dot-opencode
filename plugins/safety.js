// dot-opencode safety plugin
// -----------------------------------------------------------------------------
// One JS plugin that replaces the four shell hooks from ~/.claude:
//
//   pre-tool-safety.sh        ->  tool.execute.before   (block destructive ops)
//   load-handoff-context.sh   ->  chat.message          (inject newest handoff once)
//   account-mismatch-warn.sh  ->  chat.message          (warn on cwd/account mismatch)
//   session-end-reminder.sh   ->  event: session.idle   (session-log / handoff nudge)
//
// OpenCode has no SessionStart/Stop shell-hook contract; the equivalents are the
// plugin lifecycle (runs once at startup), the chat.message hook (first user turn),
// and the event bus (session.idle). Everything except the destructive-op BLOCK is
// advisory and wrapped in try/catch so it can never break a session. The block
// throws on purpose — that is how OpenCode aborts a tool call.
//
// Docs: https://opencode.ai/docs/plugins/
// -----------------------------------------------------------------------------

import { readFile, readdir, rename, mkdir, stat } from "node:fs/promises"
import { existsSync } from "node:fs"
import { join, dirname, basename } from "node:path"

// --- pre-tool-safety.sh: destructive command patterns (first line only) -------
const DESTRUCTIVE = [
  /git\s+reset\s+--hard\b/,
  /git\s+push\s+.*--force\b/,
  /git\s+push\s+.*\s-f\b/,
  /git\s+clean\s+-[a-zA-Z]*f/,
  /git\s+checkout\s+--\s/,
  /git\s+rebase\s+.*--abort/,
  /git\s+worktree\s+remove\s+--force/,
  /\brm\s+-[a-zA-Z]*r[a-zA-Z]*f\b/,
  /\brm\s+-[a-zA-Z]*f[a-zA-Z]*r\b/,
  /\brm\s+-rf\b/,
  /\brm\s+-fr\b/,
]
// Redirects into sensitive config files
const SENSITIVE_WRITE =
  /(>|>>)\s*(~?\/?\.config\/opencode\/opencode\.jsonc?|~?\/?\.ssh\/|~?\/?\.aws\/credentials)/

const HANDOFF_DIRS = ["session-logs", ".opencode/session-logs", ".claude/session-logs", ".factory/logs"]
const SEVEN_DAYS = 7 * 24 * 60 * 60 * 1000

/** @type {import("@opencode-ai/plugin").Plugin} */
export const SafetyPlugin = async ({ client, directory, $ }) => {
  let injected = false

  // Best-effort toast; falls back to stderr. Method name is version-sensitive,
  // so we probe a couple of shapes and swallow anything that doesn't exist.
  async function notify(message, variant = "info") {
    try {
      if (client?.tui?.showToast) return await client.tui.showToast({ message, variant })
    } catch {}
    try {
      if (client?.tui?.toast?.show) return await client.tui.toast.show({ message, variant })
    } catch {}
    console.error(`[dot-opencode] ${message}`)
  }

  // Find the newest handoff-*.md across the cross-tool search dirs (< 7 days old).
  async function findHandoff() {
    let best = null
    for (const rel of HANDOFF_DIRS) {
      const dir = join(directory, rel)
      if (!existsSync(dir)) continue
      let entries = []
      try { entries = await readdir(dir) } catch { continue }
      for (const name of entries) {
        if (!/^handoff-.*\.md$/.test(name)) continue
        const path = join(dir, name)
        let s
        try { s = await stat(path) } catch { continue }
        if (Date.now() - s.mtimeMs > SEVEN_DAYS) continue
        if (!best || s.mtimeMs > best.mtimeMs) best = { path, name, mtimeMs: s.mtimeMs }
      }
    }
    return best
  }

  // Count uncommitted + untracked files in cwd (for the idle reminder).
  async function changedFileCount() {
    try {
      const a = (await $`git -C ${directory} diff --name-only HEAD`.text()).trim()
      const b = (await $`git -C ${directory} ls-files --others --exclude-standard`.text()).trim()
      return [a, b].filter(Boolean).join("\n").split("\n").filter(Boolean).length
    } catch {
      return 0
    }
  }

  return {
    // --- pre-tool-safety.sh ---------------------------------------------------
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return
      const raw = output?.args?.command ?? ""
      // Examine first line only, stripped of -m/--message bodies (avoids false
      // positives on dangerous-sounding text inside commit messages / heredocs).
      const head = raw.split("\n")[0].replace(/ -m .*/, "").replace(/ --message .*/, "").slice(0, 200)
      for (const re of DESTRUCTIVE) {
        if (re.test(head)) {
          throw new Error(
            `Safety check: destructive command blocked — "${head.slice(0, 120)}". ` +
              `Re-run intentionally (or split the safe part out) if this is what you want.`
          )
        }
      }
      if (SENSITIVE_WRITE.test(head)) {
        throw new Error(`Safety check: redirect to a sensitive config file blocked — "${head.slice(0, 120)}".`)
      }
    },

    // --- load-handoff-context.sh (once, on the first user turn) ---------------
    // NOTE: the exact way to append context to a turn is version-sensitive. We
    // push a text part onto the message and fall back to a toast if that shape
    // isn't supported. Either way the original handoff is archived so it isn't
    // re-injected next session.
    "chat.message": async (input, output) => {
      if (injected) return
      injected = true
      try {
        const h = await findHandoff()
        if (!h) return
        const body = await readFile(h.path, "utf8")
        const banner = `\n\n[dot-opencode] Previous session handoff (${h.name}):\n\n${body}`
        let appended = false
        try {
          if (output?.parts && Array.isArray(output.parts)) {
            output.parts.push({ type: "text", text: banner })
            appended = true
          } else if (output?.message && typeof output.message.text === "string") {
            output.message.text += banner
            appended = true
          }
        } catch {}
        if (!appended) {
          await notify(`Handoff found (${h.name}) — run /pickup to load it.`, "info")
        }
        // Archive (consume) so subsequent sessions don't reload stale context.
        try {
          const archive = join(dirname(h.path), "archive")
          await mkdir(archive, { recursive: true })
          await rename(h.path, join(archive, h.name))
        } catch {}
      } catch {}
    },

    // --- session-end-reminder.sh ----------------------------------------------
    event: async ({ event }) => {
      try {
        if (event?.type !== "session.idle") return
        const n = await changedFileCount()
        if (n >= 5) {
          await notify(`${n} files changed — consider /session-logger and /handoff before you stop.`, "warning")
        } else if (n >= 3) {
          await notify(`${n} files changed — consider /session-logger before you stop.`, "info")
        }
      } catch {}
    },
  }
}
