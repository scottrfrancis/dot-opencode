# OpenCode for Claude Code users

A transition guide for moving between Claude Code and OpenCode with the same muscle memory.
Pairs with the feature map in the top-level `README.md`.

## Mental model

OpenCode is a terminal agent like Claude Code, but it is **provider-agnostic** — you point it
at any model (Anthropic, OpenAI, a local LM Studio/Ollama server, a remote GPU box) via the
`provider` block. This `dot-opencode` base is tuned for **offline use**: the default is a
remote box, with local LM Studio as the disconnected fallback. Switch anytime with `/models`.

The big structural differences from Claude Code:

| Concern | Claude Code | OpenCode |
| ------- | ----------- | -------- |
| Global rules | `~/.claude/CLAUDE.md` | `~/.config/opencode/AGENTS.md` (also reads `CLAUDE.md` as fallback) |
| Settings | one `settings.json` | `opencode.jsonc` (config) **+** `tui.json` (theme/keybinds) |
| Automation | shell hooks in `settings.json` | JS/TS **plugins** in `plugins/` |
| Tool gating | `allowed-tools` per command + `permissions` | global `permission` + per-agent `permission` |
| Status bar | `statusLine` command | fixed built-in (no custom command) |

## Setup

```bash
cd ~/workspace/dot-opencode
./install.sh        # or ./install.ps1 on native Windows; add --copy / -Copy if symlinks are blocked
```

Then start OpenCode (`opencode`) in any project. The global config and the `safety.js` plugin
load automatically.

## Session lifecycle (same shape as dot-claude)

```text
[plugin: chat.message]   ← auto: inject most recent handoff-*.md (then archive it)
   ↓
/lets-go                 ← sync git, plugin health check, load project docs
   ↓
  [work]                 ← plugin: tool.execute.before blocks destructive bash
   ↓
[plugin: session.idle]   ← auto: remind about /session-logger and /handoff
   ↓
/session-logger          ← capture outcomes, cross-link to previous log
/handoff                 ← or: generate a continuation prompt when context fills
```

`session-logs/` at the project root is the shared, cross-tool location — a handoff written in
Claude Code is picked up here, and vice versa, via the `tool:` frontmatter field.

## Commands

Identical invocation: `/<name>`. Arguments work the same — `$ARGUMENTS` (all args) and `$1`,
`$2` (positionals). Shell injection in a command body uses OpenCode's `` !`cmd` `` syntax
(stdout spliced into the prompt). The ported commands live in `commands/`.

## Writing a plugin (the hook replacement)

A plugin is a JS/TS module in `plugins/` exporting an async function that returns a hooks
object. The events that matter for porting Claude hooks:

```js
export const MyPlugin = async ({ client, directory, $ }) => ({
  "tool.execute.before": async (input, output) => {     // ≈ PreToolUse — throw to block
    if (input.tool === "bash" && /rm -rf/.test(output.args.command)) {
      throw new Error("blocked")
    }
  },
  "chat.message": async (input, output) => { /* ≈ SessionStart context injection */ },
  event: async ({ event }) => {                          // ≈ Stop / idle
    if (event.type === "session.idle") { /* remind */ }
  },
})
```

See `plugins/safety.js` for the real, defensive implementation. Throwing in
`tool.execute.before` aborts the tool call (that's how you block); every other hook is wrapped
in try/catch so it can never break a session.

## Gotchas

- **Directory names are plural**: `commands/`, `agents/`, `plugins/`, `themes/`.
- **Theme and keybinds are in `tui.json`**, not `opencode.jsonc`.
- **Local models need `"tools": true`** per model or the agent can't call tools.
- **No statusline** — don't expect the `[SS-Personal]`/`[BS-Enterprise]` banner in the bar.
- **Plugin SDK must be installed** in `~/.config/opencode` (`bun install`) or `safety.js`
  fails to import `@opencode-ai/plugin`. The installer does this for you.
- **Restart OpenCode** after changing plugins or providers — they load at startup.
