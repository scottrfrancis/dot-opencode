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

## Models (offline-first)

Configured in `opencode.jsonc`:

| Provider id | Where | Default? |
| ----------- | ----- | -------- |
| `dev-ai` | RTX 4500 Blackwell (32GB) box at `dev-ai.local:11434` (OpenAI-compatible) | **yes** (`dev-ai/qwen3.6:35b-a3b`) |
| `local` | Razer LM Studio at `localhost:1234` | fallback for disconnected use |

The working pair is **`qwen3.6-35b-a3b`** (deep, the remote default — fits fully in the 32GB VRAM so
it's fast there) and **`qwen3-coder-30b`** (fast, for quick edits). Switch at runtime with `/models`,
or set `"model"` in `opencode.jsonc` to `"local/qwen/qwen3-coder-30b"` for fully offline. An Ollama
provider stub is included (commented).

> Note: model ids must match exactly what each server's `/v1/models` reports — LM Studio
> namespaces with a publisher prefix (`qwen/qwen3-coder-30b`); the remote Ollama box uses tag
> form (`qwen3-coder:30b-a3b-q4_K_M`). On the local 8GB-VRAM box, load **one model at a time**
> (LM Studio → Max loaded models = 1); the 35B reasons heavily (~60-140s/answer) so it's the
> deep-dive option, not the interactive default. `dev-ai/gemma4:12b` is the small/fast model.

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
├── guides/               # transition docs (opencode-from-claude.md)
├── scripts/              # account-context.sh (kept for reference; see parity notes)
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

`/lets-go`, `/handoff`, `/pickup`, `/session-logger`, `/mine-sessions`, `/autocommit`,
`/arch-review`, `/extract-adr`, `/doc-review`, `/editorial-review`, `/security-audit`,
`/review-pr`, `/babysit-pr`, `/build-pdf`. See `AGENTS.md` for the table, or the individual
files in `commands/`.

> Hardware-specific helpers (`session-cleanup`, `validate-hw-env`) and Claude-only utilities
> (`export-prompts`, `pr-tokens`, `commit-manual`, `checkpoint-progress`) were not ported.
> Add them under `commands/` if needed.

## Keeping in sync with dot-claude

The two repos share `guidelines/` and the command bodies. When you change a guideline in one,
copy it to the other (or symlink `guidelines/` across both). `/lets-go` runs an opportunistic
drift check against both `dot-opencode` and `dot-claude`.

## See also

- `guides/opencode-from-claude.md` — transition guide for Claude Code users.
- [OpenCode docs](https://opencode.ai/docs/) — config, commands, agents, plugins, permissions.
