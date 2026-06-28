#!/usr/bin/env python3
"""Validate dot-opencode JSON(C) config files.

A hand-edit that makes opencode.jsonc invalid JSON otherwise surfaces only as a
cryptic "Unexpected server error" at OpenCode startup (config.providers et al.
all fail at once). This catches it with the exact line.

Validates opencode.jsonc / opencode.json / tui.json if present. Comment- and
trailing-comma-tolerant (JSONC), and string-aware so `://` inside URLs is safe.
Exit 0 if all valid, 1 otherwise.
"""
import json
import os
import re
import sys

# Force UTF-8 output so the ✓/✗ glyphs don't crash on a legacy Windows console
# (cp1252), which would otherwise make update.ps1 fail mid-run. No-op elsewhere.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):  # pre-3.7, or a non-reconfigurable stream
        pass


def strip_jsonc(src):
    """Remove // and /* */ comments while preserving line numbers and string
    contents (so `https://…` is never mistaken for a comment)."""
    out = []
    i, n = 0, len(src)
    in_str = esc = False
    while i < n:
        c = src[i]
        d = src[i + 1] if i + 1 < n else ""
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "/" and d == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and d == "*":
            i += 2
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                if src[i] == "\n":
                    out.append("\n")
                i += 1
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def validate(path):
    name = os.path.basename(path)
    src = open(path, encoding="utf-8").read()
    cleaned = re.sub(r",(\s*[}\]])", r"\1", strip_jsonc(src))
    try:
        json.loads(cleaned)
        print(f"  ✓ {name}: valid")
        return True
    except json.JSONDecodeError as e:
        print(
            f"  ✗ {name}: invalid JSON — {e.msg} at line {e.lineno}, col {e.colno}",
            file=sys.stderr,
        )
        orig = src.splitlines()
        for k in range(max(1, e.lineno - 1), min(len(orig), e.lineno + 1) + 1):
            mark = ">>" if k == e.lineno else "  "
            print(f"    {mark} {k:>3}: {orig[k - 1]}", file=sys.stderr)
        return False


def main():
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    targets = [
        f
        for f in ("opencode.jsonc", "opencode.json", "tui.json")
        if os.path.exists(os.path.join(repo, f))
    ]
    if not targets:
        print("validate: no config files found", file=sys.stderr)
        return 1
    ok = all(validate(os.path.join(repo, f)) for f in targets)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
