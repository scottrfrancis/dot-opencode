#!/usr/bin/env bash
# update.sh — pull the latest dot-opencode and refresh the live install.
#
# With the default symlink install, `git pull` alone already makes most changes
# live (config dirs are symlinked, so new/changed commands and guidelines appear
# instantly). This wrapper adds what a bare pull misses: refusing to pull over
# local edits, re-linking any brand-new top-level item, and reinstalling the
# plugin SDK. Run it on each machine (MacBook, Razer) whenever you want updates.
#
# Usage:  ./update.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
cd "$REPO"

# Guard: never pull over uncommitted local edits (commit or stash first).
if ! git diff --quiet HEAD 2>/dev/null; then
  echo "✗ dot-opencode has uncommitted changes — commit or stash before updating:" >&2
  git status --short >&2
  exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
echo "▶ git pull --ff-only ($branch)"
if ! git pull --ff-only; then
  echo "✗ pull failed (diverged history?). Resolve manually, then re-run." >&2
  exit 1
fi

# Copy-mode installs need a re-copy; symlink installs are already live.
if [ -e "$TARGET/AGENTS.md" ] && [ ! -L "$TARGET/AGENTS.md" ]; then
  echo "▶ copy-mode install detected — re-copying into $TARGET"
  ./install.sh --copy
else
  echo "✓ symlink install — pulled changes are already live"
  # Idempotent re-link: catches any brand-new top-level item and reinstalls the
  # plugin SDK. Cheap; existing symlinks are replaced, not backed up.
  ./install.sh
fi

echo "✓ done — restart OpenCode to load updates."
