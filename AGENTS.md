# AGENTS.md — Global OpenCode Guidelines

Global instructions loaded into every OpenCode session (the OpenCode analogue of
`~/.claude/CLAUDE.md`). This is the `dot-opencode` base, installed to
`~/.config/opencode/`. Per-project `AGENTS.md` files extend this foundation with
domain-specific context. Keep this file as a stable base class — project files carry
the specifics.

> Ported from the `dot-claude` (`~/.claude`) setup. OpenCode also auto-reads
> `~/.claude/CLAUDE.md` as a fallback, so the two stay broadly in sync, but this file
> is the canonical OpenCode copy and is what you should edit for OpenCode behavior.

## Branch Policy and Strategy

The user works across multiple repositories with different policies. The user is
forgetful about syncing the local repo at the start of a session.

REMIND the user to consider the appropriate branching strategy when starting a session
or a series of tasks. Include:

- current branch and status
- suggestions to pull, push, create, or delete branches

When asked to push to a repo, suggest a new branch if the current branch is the default
(main/master).

## Session Safety (CRITICAL)

**ALWAYS follow `~/.config/opencode/guidelines/session-safety.md`** when working on
hardware development systems. Multiple agent sessions accessing NPU/GPU devices
simultaneously cause device contention, resource leakage, and complete context loss
requiring a system restart.

**Before every hardware session**: run session cleanup, verify device availability, and
ensure exclusive hardware access.

## Active Guidelines

On-demand reference standards. Read the relevant one before the matching task — they are
NOT auto-loaded into context (kept lean on purpose). Files live in
`~/.config/opencode/guidelines/`:

- **shell-scripts.md** — directory management, error handling, portability
- **conventional-commits.md** — standardized commit message format
- **readme-documentation.md** — README as central documentation hub
- **session-safety.md** — **CRITICAL** — prevent session hangs / context loss on hardware
- **ai-patterns.md** — LLM integration: caching, routing, guardrails, RAG
- **project-setup.md** — tiered checklist for bootstrapping new projects
- **prose-style.md** — anti-AI-smell rules for narrative writing
- **prototype-hygiene.md** — ship clean: config over code, stable docs, PRs over branches
- **security-hardening.md** — defense-in-depth patterns grounded in breach analysis
- **golang.md** — Go: JSON response safety, gosec patterns, G104 triage
- **testing.md** — test pyramid, mocking, CI integration
- **ci-local-parity.md** — run exact CI commands locally before pushing
- **docx-conversion.md** — python-docx over pandoc; palette, typography
- **karpathy-principles.md** — surface assumptions, match existing style, read before you write
- **2x2-status-report.md** — quad-chart weekly status format
- **shell-escaping.md** — shell quoting, TTY handling
- **C4-diagramming.md** — C4 Model PlantUML organization
- **markdown-formatting.md** — spacing and list formatting standards
- **pr-token-tracking.md** — PR token accounting

## Commands

Global slash commands live in `~/.config/opencode/commands/` (one markdown file per
command). Invoke with `/<name>`.

### Session Management

| Command | Purpose |
| ------- | ------- |
| `/lets-go [role with task]` | Initialize a session: plugin health check, git sync protocol, load project docs, surface handoffs |
| `/session-logger [topic]` | Structured session summary with effectiveness assessment; cross-links to previous log |
| `/handoff [topic notes]` | Forward-looking continuation prompt for the next session |
| `/pickup` | Resume from the most recent handoff; archive it so it isn't re-injected |
| `/mine-sessions [days:N] [save]` | Analyze session logs for patterns, metrics, process improvements |

### Git and Code Quality

| Command | Purpose |
| ------- | ------- |
| `/autocommit [-n] [-t type]` | Stage tracked changes, commit with a generated conventional message |
| `/arch-review` | Principal Architect review framework |
| `/extract-adr` | Convert logged decisions into ADRs |
| `/doc-review` | Audit documentation for accuracy, DRY, clarity; commit on a docs branch |
| `/editorial-review [style]` | Audit prose for AI tells; refine toward a voice/style |
| `/security-audit` | Breach-driven security audit for web apps |
| `/review-pr [PR or branch]` | Review a PR diff: bugs, security, missing tests, style |
| `/babysit-pr <PR>` | Monitor a PR for checks, reviews, merge readiness |
| `/build-pdf [report.yaml]` | Build a PDF from markdown sections |

## Plugin (the hooks equivalent)

OpenCode has no shell-hook contract like Claude Code's SessionStart/PreToolUse/Stop.
The single plugin `~/.config/opencode/plugins/safety.js` provides the equivalents:

- `tool.execute.before` — **blocks** destructive bash (`rm -rf`, `git reset --hard`,
  `git push --force`, force worktree removal, redirects into sensitive config). Throws to
  abort the tool call.
- `chat.message` — injects the most recent `handoff-*.md` once per session (≈ SessionStart
  auto-load) and archives it.
- `event: session.idle` — reminds about `/session-logger` (3+ files changed) and `/handoff`
  (5+ files changed).

Permissions are enforced separately in `opencode.jsonc` under `permission` (ask by default;
safe git/find/read auto-allowed; destructive denied). The plugin's block is defense in depth.

## Memory Convention

OpenCode has no built-in persistent memory store. Keep the `dot-claude` convention: a
project's durable, non-obvious context lives in `<project>/.opencode/memory/MEMORY.md`
(or `.claude/memory/MEMORY.md` if shared with Claude Code) — one line per fact, pointing at
detail files. Don't record what the repo already captures (code structure, git history).

## Cross-Tool Session Protocol

Session logs are written to `session-logs/` at the project root — a shared location read by
Claude Code, Cursor, Copilot, Droid, and OpenCode. Legacy locations (`.opencode/session-logs/`,
`.claude/session-logs/`, `.factory/logs/`) are searched as fallbacks.

All session logs and handoff files carry YAML frontmatter with a `tool:` field. OpenCode
sessions write `tool: opencode`. This enables cross-tool continuity — a handoff written in
Claude Code can be picked up in OpenCode, and vice versa.

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

## Notes on Parity

OpenCode does **not** support a Claude Code-style `statusLine` command. The account-context
banner (`scripts/account-context.sh`) is kept for reference and for the `/lets-go` git-sync
output, but it does not render in the OpenCode status bar. See `README.md` for the full
Claude Code → OpenCode feature map.
