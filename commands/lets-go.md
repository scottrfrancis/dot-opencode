---
description: set initial context for a working session
---

as $ARGUMENTS

Run these checks in order, then give the Ready Output. Keep intermediate output terse.

## 1. Plugin health check

```bash
test -f ~/.config/opencode/plugins/safety.js && echo "OK: safety.js" || echo "MISSING: safety.js"
grep -q '"@opencode-ai/plugin"' ~/.config/opencode/package.json 2>/dev/null && echo "OK: plugin dep" || echo "NOTE: dep not pinned (plugin still loads)"
```

If missing: warn prominently, tell the user to run `~/.config/opencode/update.sh` (or re-run
`install.sh`), then continue anyway — this is advisory.

## 2. Handoff context

The `safety` plugin auto-injects the newest handoff on session start. Verify, and check for
cross-tool handoffs: take the newest `handoff-*.md` from `session-logs/`, `.claude/session-logs/`,
or `.factory/logs/`. If <7 days old, read it as context; note its `tool:` frontmatter if present
("Continuing from a Cursor session"). Report "Loaded handoff from [file] ([tool])" or "No recent handoff".

## 3. dot-opencode sync

The global config at `~/.config/opencode` is symlinked from the `dot-opencode` repo, so updates
are a `git pull` away. Resolve the repo and check drift:

```bash
OC=$(cd "$(dirname "$(readlink -f ~/.config/opencode/opencode.jsonc 2>/dev/null || echo ~/workspace/dot-opencode/opencode.jsonc)")" && pwd)
git -C "$OC" fetch origin -q
echo "behind=$(git -C "$OC" rev-list --count HEAD..origin/main 2>/dev/null) ahead=$(git -C "$OC" rev-list --count origin/main..HEAD 2>/dev/null)"
git -C "$OC" status --porcelain
```

- **Behind** → "⚠ dot-opencode is N behind — run `./update.sh` to refresh config/commands."
- **Ahead** → "N unpushed commits — consider pushing to back up your config."
- **Dirty** → "uncommitted changes in dot-opencode."

Skip silently if there is no remote or the fetch fails. **Opportunistic:** if other dot-repos
are present on this machine (`$HOME/.claude`, `$HOME/.factory`→symlink, `dot-cursor`/`dot-copilot`),
run the same fetch/rev-list/status and report drift the same way. Skip any not installed.

## 4. Project repo sync

```bash
git fetch origin -q
git status -sb
```

Determine branch and upstream. If no upstream: "branch {name} — local only". Else report:
in sync / N behind (recommend `git pull`) / N ahead (unpushed) / diverged (pull + rebase).
If dirty **and** behind: "stash first, then pull". If on the default branch (main/master) with
uncommitted changes: suggest a feature branch.

## 5. Project context

Review what's present: README, ARCHITECTURE.md, CONTRIBUTING.md, `docs/`, `plans/`, TODO, and
recent commits/session logs. Fold in $ARGUMENTS (role + task).

## Ready Output

Confirm with "i am ready to opencode" and a short plan. Brief, bulleted:

- **Status** — git branch + sync state (e.g. "main: 2 behind origin, clean — pull recommended")
- **Session context** — role, recent work
- **Project context** — from docs + recent logs
- **Next steps** — from TODOs, open issues, uncommitted changes
