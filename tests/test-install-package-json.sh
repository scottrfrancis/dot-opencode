#!/usr/bin/env bash
# tests/test-install-package-json.sh: install.sh must COPY package.json, not link it.
# OpenCode rewrites package.json on start to pin its own plugin SDK version; a
# symlink would push that rewrite into the shared checkout and dirty it.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export OPENCODE_CONFIG_DIR="$TMP/opencode"
PATH="$TMP/nobin:$PATH" bash "$REPO/install.sh" >/dev/null   # nobin: no bun/npm, skip the SDK install
fail=0
if [ -L "$OPENCODE_CONFIG_DIR/package.json" ]; then echo "FAIL: package.json is a symlink"; fail=1; fi
[ -f "$OPENCODE_CONFIG_DIR/package.json" ] || { echo "FAIL: package.json missing"; fail=1; }
cmp -s "$REPO/package.json" "$OPENCODE_CONFIG_DIR/package.json" || { echo "FAIL: package.json content differs"; fail=1; }
[ -L "$OPENCODE_CONFIG_DIR/opencode.jsonc" ] || { echo "FAIL: opencode.jsonc should still be a symlink"; fail=1; }
[ "$fail" = 0 ] && echo "PASS: package.json copied, other items linked"
exit "$fail"
