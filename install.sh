#!/usr/bin/env bash
# install.sh — link this dot-opencode repo into ~/.config/opencode.
#
# Symlinks each config item into the OpenCode global config dir, leaving the dir
# itself real so OpenCode can still write runtime state (auth.json, cache/, etc.).
# Anything real already in place is backed up to <name>.bak.<timestamp> first.
#
# Usage:
#   ./install.sh            # symlink (preferred)
#   ./install.sh --copy     # copy instead of symlink (no dev-mode/admin needed)
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
MODE="link"
[ "${1:-}" = "--copy" ] && MODE="copy"

ITEMS=(opencode.jsonc tui.json AGENTS.md package.json commands agents plugins guidelines guides scripts themes)
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$TARGET"
echo "dot-opencode → $TARGET  (mode: $MODE)"

for item in "${ITEMS[@]}"; do
  src="$REPO/$item"
  dst="$TARGET/$item"
  [ -e "$src" ] || continue

  # Back up a real (non-symlink) target so we never clobber existing config.
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak.$STAMP"
    echo "  backed up existing $item → $item.bak.$STAMP"
  elif [ -L "$dst" ]; then
    rm -f "$dst"
  fi

  if [ "$MODE" = "copy" ]; then
    cp -R "$src" "$dst"
    echo "  copied  $item"
  else
    ln -sfn "$src" "$dst"
    echo "  linked  $item"
  fi
done

# Restore the plugin SDK so safety.js can import @opencode-ai/plugin.
if command -v bun >/dev/null 2>&1; then
  ( cd "$TARGET" && bun install ) && echo "  bun install: ok"
elif command -v npm >/dev/null 2>&1; then
  ( cd "$TARGET" && npm install ) && echo "  npm install: ok"
else
  echo "  NOTE: neither bun nor npm found — run 'bun install' in $TARGET so the plugin resolves."
fi

echo "Done. Restart OpenCode to load the new config and plugin."
