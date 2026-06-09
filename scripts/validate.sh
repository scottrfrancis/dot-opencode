#!/usr/bin/env bash
# validate.sh — check the dot-opencode JSON(C) config parses before OpenCode
# loads it. Run this after any hand-edit to opencode.jsonc / tui.json; a syntax
# error otherwise shows up only as a cryptic "Unexpected server error" at startup.
#
# Usage:  ./scripts/validate.sh   (also run automatically by update.sh)
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1; then PY=python
else
  echo "  (validate.sh: python not found — skipping config check)" >&2
  exit 0
fi

exec "$PY" "$REPO/scripts/validate.py"
