# AGENTS.md — Global OpenCode Guidelines

Global instructions loaded into **every** OpenCode session (the OpenCode analogue of
`~/.claude/CLAUDE.md`). Kept deliberately lean — this file is in context on every turn,
so it carries only behavioral rules and pointers. Reference detail (the full command and
guideline indexes, the Claude Code → OpenCode feature map) lives in `README.md`, which is
**not** loaded into context. Per-project `AGENTS.md` files extend this base.

> Ported from `dot-claude` (`~/.claude`). OpenCode also auto-reads `~/.claude/CLAUDE.md`
> as a fallback, but this file is the canonical OpenCode copy.

## Branch Policy

The user works across many repos with different policies and is forgetful about syncing at
session start. REMIND them to consider branching strategy when starting a session or a task
series — current branch and status, and whether to pull, push, create, or delete branches.
When asked to push, suggest a new branch if the current branch is the default (main/master).

## Session Safety (CRITICAL)

When working on hardware (NPU/GPU) development systems, **follow
`~/.config/opencode/guidelines/session-safety.md`**: run session cleanup, verify device
availability, and ensure exclusive access first. Concurrent sessions cause device contention
and context loss requiring a restart.

## Guidelines (on-demand)

On-demand reference standards in `~/.config/opencode/guidelines/`. Read the relevant one
**before** the matching task — they are NOT auto-loaded (kept out of context on purpose).
Filenames are self-describing; topics:

`shell-scripts` · `shell-escaping` · `conventional-commits` · `readme-documentation` ·
`markdown-formatting` · `session-safety` (CRITICAL) · `ai-patterns` · `project-setup` ·
`prose-style` · `prototype-hygiene` · `security-hardening` · `golang` · `testing` ·
`ci-local-parity` · `docx-conversion` · `karpathy-principles` · `2x2-status-report` ·
`C4-diagramming` · `pr-token-tracking`

See README for the annotated index.

## Commands

Global slash commands in `~/.config/opencode/commands/` — invoke with `/<name>`:

`/lets-go` · `/handoff` · `/pickup` · `/session-logger` · `/mine-sessions` · `/autocommit` ·
`/arch-review` · `/doc-review` · `/editorial-review` · `/security-audit` ·
`/review-pr` · `/babysit-pr` · `/build-pdf`

See README for per-command purpose and which are suited to local vs remote/cloud models.

## Plugin (the hooks equivalent)

`~/.config/opencode/plugins/safety.js` replaces Claude Code's shell hooks: it **blocks**
destructive bash (`rm -rf`, `git reset --hard`, force-push, sensitive-config redirects) at
`tool.execute.before`, injects the newest `handoff-*.md` once per session, and nudges
`/session-logger` / `/handoff` on idle. Permissions are enforced separately in
`opencode.jsonc` (`permission`); the plugin's block is defense in depth.

## Memory Convention

OpenCode has no built-in memory store. Keep the `dot-claude` convention: a project's durable,
non-obvious context lives in `<project>/.opencode/memory/MEMORY.md` (or `.claude/memory/` if
shared with Claude Code) — one line per fact, pointing at detail files. Don't record what the
repo already captures (code structure, git history).

## Cross-Tool Session Protocol

Session logs and handoffs go in `session-logs/` at the project root — a shared location read
by Claude Code, Cursor, Copilot, Droid, and OpenCode (legacy: `.opencode/session-logs/`,
`.claude/session-logs/`, `.factory/logs/`). Every file carries YAML frontmatter with a
`tool:` field; OpenCode writes `tool: opencode`. This enables cross-tool continuity.

## Global Behavioral Rules

- **Red-Green-Refactor TDD is REQUIRED for ALL code changes.** Write a failing test first
  (RED), then minimum code to pass (GREEN), then refactor with tests green. No production
  code without a failing test. No retroactive tests. See `guidelines/testing.md`.
- **Surface conflicts; don't average them.** When two patterns in the codebase contradict,
  pick one — usually the more recent or more tested — explain why, and flag the other for
  cleanup. Blending two patterns produces a third nobody intended.
- Create temporary test scripts and programs in `/tmp`, not in the project directory.
- When the user reports a PR has been merged, prompt them to update the local repo (pull,
  delete merged branch).
- When asked to push to a repo, suggest a new branch if the current branch is the default.
<\!-- central-ops-knowledge: begin -->
## Central Ops Knowledge (shared doctrine — all my AI tools)

I maintain ONE central, authoritative **ops-knowledge state** for my homelab/home: **dynamic**
(live, current, queryable by every human and AI on the LAN) and **archival** (durable,
portable, hand-off-able to anyone taking over anything). It lives in the **HomeAssistant repo**
(`/Volumes/workspace/HomeAssistant/` → `home-ops/` OKF bundle + `wiki/`), is surfaced
live by the **Librarian RAG + Hazel** (OpenWebUI on `mini.local`), and kept current by the
`tools/*-scan.sh` self-tracking probes. Full doctrine: `~/.claude/guidelines/central-ops-knowledge.md`.

Operating rules for every agent (Claude, OpenCode, Codex, Cursor, Droid, Copilot…):
1. **Consult before acting on infrastructure** — before stopping/changing a service, host, or
   config, check the knowledge base for "what is this and *why*." Stale assumptions cause outages.
2. **Write back** — when you learn or change something about the ops state, record or flag it so
   it stays current. Session-only knowledge is lost.
3. **OKF form** — plain markdown + YAML, **no secrets** (pointers only), conformant for any tool.
4. **Local-first / WAN-tolerant** — prefer local LLM/files/Kiwix; must work with the internet down.
5. **Respect boundaries** — household surfaces LAN-only; don't touch non-Scott tailnet hosts.
<\!-- central-ops-knowledge: end -->
