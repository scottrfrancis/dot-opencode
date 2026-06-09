# dot-opencode

Personal [OpenCode](https://opencode.ai) global configuration — the OpenCode counterpart
to [`dot-claude`](https://github.com/scottrfrancis/dot-claude) (`~/.claude`). Same commands,
guidelines, safety behavior, and session-lifecycle discipline, ported to OpenCode's
configuration model. Built for **offline / disconnected use** with local model servers
(LM Studio, Ollama) and a remote GPU box.

This repo lives in `~/workspace/dot-opencode` and installs into `~/.config/opencode/`
(OpenCode's global config dir) via symlinks. Runtime state (auth, cache, sessions) stays in
`~/.config/opencode` and is gitignored — only the config source is tracked here.

## Quick start

```bash
git clone <this-repo> ~/workspace/dot-opencode
cd ~/workspace/dot-opencode
./install.sh                # bash / git-bash / WSL  (use --copy if symlinks are blocked)
#   or, native Windows PowerShell:
# ./install.ps1             # use -Copy if Developer Mode / admin is unavailable
```

The installer symlinks each config item into `~/.config/opencode/`, backing up anything real
already there, then runs `bun install` (or `npm install`) so the safety plugin can resolve
`@opencode-ai/plugin`. Restart OpenCode afterward.

> The installer never touches your existing live config destructively — real files are moved
> to `<name>.bak.<timestamp>` before a symlink is placed.

## Models (offline-capable, capability-first)

Configured in `opencode.jsonc`:

| Provider id | Where | Role |
| ----------- | ----- | ---- |
| `dev-ai` | Remote Ollama box at `dev-ai.local:11434` (`192.168.7.235`, OpenAI-compatible) | **default** (`dev-ai/gpt-oss:20b`) — on-network |
| `mlx` | On-device MLX server at `127.0.0.1:8080` (Apple Silicon only) | private/offline fallback for the M4 Pro Mac |
| `local` | Razer LM Studio at `localhost:1234` | fallback for the Razer |

Switch models at runtime with `/models`. On the Mac, start the on-device server with
`scripts/mlx-serve.sh`, then `/models → MLX (local)` (or set `"model"` to
`"mlx/default_model"` when fully off-network). A same-machine Ollama provider stub is
included (commented).

> The remote box stays the default on purpose — even the biggest model a 24 GB Mac can
> serve is a different league from the remote box. MLX is the private/offline option, not
> the everyday default. The provider uses the `dev-ai.local` hostname (DNS resolves it to
> `192.168.7.235`); fall back to the literal IP only if mDNS is flaky.

### On-device MLX on the Mac

The locked-down **M4 Pro / 24 GB MacBook** can run a fully on-device coding agent via
`mlx_lm.server` + the `mlx` provider. The launcher [`scripts/mlx-serve.sh`](scripts/mlx-serve.sh)
is sized for 24 GB (Qwen3-8B-8bit, 3 GiB KV ceiling) and every knob is env-overridable.
See **[`guides/mac-mlx-opencode.md`](guides/mac-mlx-opencode.md)** for the full setup,
the 24 GB memory budget, the thinking-mode toggle, and troubleshooting.

```bash
~/.config/opencode/scripts/mlx-serve.sh    # Apple Silicon only; needs `pip install mlx-lm`
```

### ⚠️ Set the context window ≥ 32K on every local backend

OpenCode's system prompt + tool definitions + `AGENTS.md` consume **~7–10K tokens before any
work** — and they *overflow small default context windows*, at which point tool-calling
silently breaks (the model chats but never edits, with no error). Configure each backend:

| Backend | Default | Fix |
| ------- | ------- | --- |
| Ollama (`dev-ai`) | 4K | `OLLAMA_CONTEXT_LENGTH=32768` on the rig (or `num_ctx 32768` in a Modelfile) |
| LM Studio (`local`, Razer) | 4K–8K | Set **Context Length = 32768** in the model load settings before serving |
| MLX (`mlx`, Mac) | model native (Qwen3 = 32K) | No flag needed, but the 3 GiB KV ceiling caps *warm* cache at ~20K tokens — keep sessions and commands lean (see the guide's budget section) |

## Repository layout

```text
dot-opencode/
├── opencode.jsonc        # model, providers, permission (≈ ~/.claude/settings.json)
├── tui.json              # theme + keybinds (OpenCode keeps these separate)
├── AGENTS.md             # global rules, loaded every session (≈ CLAUDE.md)
├── package.json          # pins @opencode-ai/plugin for the safety plugin
├── install.sh / .ps1     # symlink (or --copy) into ~/.config/opencode
├── commands/             # /slash commands (ported from ~/.claude/commands)
├── agents/               # subagents (e.g. code-reviewer)
├── plugins/
│   └── safety.js         # the 4 ~/.claude hooks consolidated into one plugin
├── guidelines/           # on-demand reference standards (verbatim from dot-claude)
├── guides/               # transition + setup docs (opencode-from-claude, mac-mlx-opencode)
├── scripts/              # account-context.sh, mlx-serve.sh (on-device MLX launcher)
└── themes/               # custom TUI themes (empty; drop *.json here)
```

## Claude Code → OpenCode feature map

| Claude Code (`~/.claude`) | OpenCode (`~/.config/opencode`) | Notes |
| ------------------------- | ------------------------------- | ----- |
| `CLAUDE.md` | `AGENTS.md` | Auto-loaded global rules. OpenCode also reads `~/.claude/CLAUDE.md` as a fallback. |
| `settings.json` → `permissions` | `opencode.jsonc` → `permission` | Allowlist posture preserved: ask by default, safe git/find allowed, destructive denied. |
| `settings.json` → `theme`, statusLine | `tui.json` → `theme`, `keybinds` | **No statusline equivalent** in OpenCode (see below). |
| `commands/*.md` | `commands/*.md` | Same markdown+frontmatter idea. `$ARGUMENTS`/`$1` identical. Legacy `allowed-tools`/`argument-hint` frontmatter dropped (OpenCode uses `agent`/`permission`). |
| Hooks: SessionStart / PreToolUse / Stop | `plugins/safety.js` | One JS plugin: `chat.message`, `tool.execute.before`, `event: session.idle`. |
| `hooks/pre-tool-safety.sh` | `tool.execute.before` | Blocks `rm -rf`, `git reset --hard`, force-push, sensitive-config redirects. |
| `hooks/load-handoff-context.sh` | `chat.message` (once/session) | Injects newest `handoff-*.md`, then archives it. |
| `hooks/session-end-reminder.sh` | `event: session.idle` | Nudges `/session-logger` (3+ files) and `/handoff` (5+). |
| `hooks/account-mismatch-warn.sh` | folded into `safety.js` / `scripts/account-context.sh` | Cost-management account check. |
| `guidelines/*.md` | `guidelines/*.md` | Copied verbatim; referenced on-demand from `AGENTS.md` (not auto-loaded). |
| `memory/MEMORY.md` | `.opencode/memory/MEMORY.md` (convention) | OpenCode has no native memory store; convention preserved. |
| Subagents / skills | `agents/*.md` | OpenCode primary/subagent model; `@mention` or Task tool to invoke. |
| MCP servers | `opencode.jsonc` → `mcp` | Same idea; none configured in the base. |

### What does NOT port cleanly

- **Statusline.** OpenCode has no `statusLine` command hook
  ([feature request #8619](https://github.com/anomalyco/opencode/issues/8619)). The
  `[SS-Personal]` / `[BS-Enterprise]` account banner can't render in the status bar.
  `scripts/account-context.sh` is kept so `/lets-go` can print the banner in its output, and
  the account-mismatch check lives in the plugin instead.
- **Handoff auto-injection** uses `chat.message` part-appending, which is version-sensitive.
  The plugin appends defensively and falls back to a toast prompting `/pickup`; either way it
  archives the handoff. If your OpenCode version exposes a different message API, adjust the
  `chat.message` hook in `plugins/safety.js`.
- **`allowed-tools` per command** has no OpenCode equivalent — tool access is governed
  globally (`permission`) or per-agent (`agents/*.md`), not per command.

## Commands

Global slash commands live in `commands/` (one markdown file per command). Invoke with
`/<name>`. The **Model** column is guidance for this offline-first fleet: reasoning-heavy
commands produce shallow/unreliable output on small local models (MLX 8B, LM-Studio-on-8GB)
and should run on the remote box or cloud Claude — see [Model suitability](#model-suitability).

### Session management

| Command | Purpose | Model |
| ------- | ------- | ----- |
| `/lets-go [role with task]` | Initialize a session: plugin health check, git sync, load project docs, surface handoffs | local-OK |
| `/handoff [topic notes]` | Forward-looking continuation prompt for the next session | local-OK |
| `/pickup` | Resume from the most recent handoff; archive it so it isn't re-injected | local-OK |
| `/session-logger [topic]` | Structured session summary with effectiveness assessment; cross-links to previous log | remote/cloud |
| `/mine-sessions [days:N] [save]` | Analyze session logs for patterns, metrics, process improvements | remote/cloud |

### Git and code quality

| Command | Purpose | Model |
| ------- | ------- | ----- |
| `/autocommit [-n] [-t type]` | Stage tracked changes, commit with a generated conventional message | local-OK |
| `/babysit-pr <PR>` | Monitor a PR for checks, reviews, merge readiness | local-OK |
| `/build-pdf [report.yaml]` | Build a PDF from markdown sections | local-OK |
| `/review-pr [PR or branch]` | Review a PR diff: bugs, security, missing tests, style | remote/cloud |
| `/arch-review` | Principal Architect review framework | remote/cloud |
| `/doc-review` | Audit documentation for accuracy, DRY, clarity; commit on a docs branch | remote/cloud |
| `/editorial-review [style]` | Audit prose for AI tells; refine toward a voice/style | remote/cloud |
| `/security-audit` | Breach-driven security audit for web apps | remote/cloud |

### Model suitability

This fleet runs small local models (MLX Qwen3-8B on the Mac, qwen3-coder-30b in LM Studio on
the Razer's 8 GB GPU) as the **private/offline coding loop**, with the remote `dev-ai` box and
cloud Claude for heavier work. Calibrate command use accordingly:

- **local-OK** — mechanical or orchestration commands: short bodies, concrete single-purpose
  steps, little intermediate reasoning. Reliable on local models.
- **remote/cloud** — multi-phase protocols that hinge on *quality of reasoning* (synthesis,
  audit, effectiveness assessment). On an 8–30 B local model these are slow (long thinking
  traces eat the KV cache budget) and produce confident-but-shallow output. See
  [`guides/mac-mlx-opencode.md`](guides/mac-mlx-opencode.md) for the context-budget math.

  These commands **pin `model:` in their frontmatter** to the remote box — code reviews
  (`review-pr`, `security-audit`) to `dev-ai/qwen3-coder:30b`, the rest to
  `dev-ai/gpt-oss:20b` — so they route to a capable model deterministically instead of
  silently running on whatever's selected. The pin is harness-enforced (it doesn't rely on a
  small model choosing correctly).

  > ⚠️ **Offline caveat:** because the pin targets `dev-ai`, these commands **fail when the
  > remote box is unreachable** (the error names the missing model). Offline, either remove
  > the `model:` line, override it, or run the task in Claude Code. Mechanical (local-OK)
  > commands carry no pin and run on whatever model is active.

> Not ported from `dot-claude`: hardware helpers (`session-cleanup`, `validate-hw-env`),
> Claude-only utilities (`export-prompts`, `pr-tokens`, `commit-manual`, `checkpoint-progress`),
> and `extract-adr` (convert logged decisions into ADRs). Add them under `commands/` if needed.

## Guidelines (annotated index)

On-demand reference standards in `guidelines/` — read the relevant one before the matching
task (not auto-loaded; `AGENTS.md` carries only the topic list). Copied verbatim from
`dot-claude`:

| File | Covers |
| ---- | ------ |
| `shell-scripts.md` | directory management, error handling, portability |
| `shell-escaping.md` | shell quoting, TTY handling |
| `conventional-commits.md` | standardized commit message format |
| `readme-documentation.md` | README as central documentation hub |
| `markdown-formatting.md` | spacing and list formatting standards |
| `session-safety.md` | **CRITICAL** — prevent session hangs / context loss on hardware |
| `ai-patterns.md` | LLM integration: caching, routing, guardrails, RAG |
| `project-setup.md` | tiered checklist for bootstrapping new projects |
| `prose-style.md` | anti-AI-smell rules for narrative writing |
| `prototype-hygiene.md` | ship clean: config over code, stable docs, PRs over branches |
| `security-hardening.md` | defense-in-depth patterns grounded in breach analysis |
| `golang.md` | Go: JSON response safety, gosec patterns, G104 triage |
| `testing.md` | test pyramid, mocking, CI integration |
| `ci-local-parity.md` | run exact CI commands locally before pushing |
| `docx-conversion.md` | python-docx over pandoc; palette, typography |
| `karpathy-principles.md` | surface assumptions, match existing style, read before you write |
| `2x2-status-report.md` | quad-chart weekly status format |
| `C4-diagramming.md` | C4 Model PlantUML organization |
| `pr-token-tracking.md` | PR token accounting |

## Keeping in sync with dot-claude

The two repos share `guidelines/` and the command bodies. When you change a guideline in one,
copy it to the other (or symlink `guidelines/` across both). `/lets-go` runs an opportunistic
drift check against both `dot-opencode` and `dot-claude`.

## See also

- `guides/opencode-from-claude.md` — transition guide for Claude Code users.
- `guides/mac-mlx-opencode.md` — on-device MLX + OpenCode setup for the Apple Silicon Mac.
- [OpenCode docs](https://opencode.ai/docs/) — config, commands, agents, plugins, permissions.
