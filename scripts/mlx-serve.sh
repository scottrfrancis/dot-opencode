#!/usr/bin/env bash
# mlx-serve.sh — on-demand local MLX server for OpenCode (Apple Silicon only).
#
# Serves an MLX LLM through an OpenAI-compatible endpoint that the `mlx` provider
# in opencode.jsonc points at (http://127.0.0.1:8080/v1). Treat this as a private,
# offline BACKUP to the remote box (dev-ai / 192.168.4.237) — launch it when you
# want it, Ctrl-C when you're done. Every memory knob is overridable by env var.
#
# Defaults are sized for the LOCKED-DOWN M4 Pro / 24 GB MacBook (the only Apple
# Silicon target in this fleet — the Razer is AMD/RTX and cannot run MLX). On a
# 24 GB box, Metal caps at ~75% of unified memory (~18 GB) and the binding
# constraint is KV-cache headroom, not weight size: an 8 B 8-bit dense model
# (~9 GB resident) leaves room for the prompt cache; a 30 B MoE keeps the full
# 30 B resident and starves it. See guides/mac-mlx-opencode.md for the full budget.
#
# Prereqs:  pip install mlx-lm        (already installed on the target Mac)
# Usage:
#   ./mlx-serve.sh                              # 24 GB defaults: Qwen3-8B-8bit
#   MLX_MODEL=lmstudio-community/Qwen3-14B-MLX-4bit ./mlx-serve.sh   # tighter, more capable
#   MLX_HOST=0.0.0.0 ./mlx-serve.sh             # share over Tailscale/LAN
set -euo pipefail

MODEL="${MLX_MODEL:-lmstudio-community/Qwen3-8B-MLX-8bit}"
HOST="${MLX_HOST:-127.0.0.1}"                  # 0.0.0.0 to share over Tailscale/LAN
PORT="${MLX_PORT:-8080}"
CACHE_BYTES="${MLX_CACHE_BYTES:-3221225472}"   # 3 GiB hard KV-cache ceiling (the OOM guard)
CACHE_SLOTS="${MLX_CACHE_SLOTS:-2}"            # max distinct cached prompts held at once
MAX_TOKENS="${MLX_MAX_TOKENS:-4096}"
THINK="${MLX_THINK:-true}"                     # true keeps Qwen3 /think · /no_think switches alive

if ! command -v mlx_lm.server >/dev/null 2>&1; then
  echo "error: mlx_lm.server not found. Install with: pip install mlx-lm" >&2
  exit 1
fi

echo "▶ $MODEL on $HOST:$PORT  (KV ≤ $((CACHE_BYTES / 1024 / 1024 / 1024)) GiB, think=$THINK)"
echo "  point OpenCode's mlx provider at http://${HOST/0.0.0.0/127.0.0.1}:$PORT/v1 — /models → MLX (local)"

# caffeinate -i: stay awake only while serving (no global sleep change);
# exec so Ctrl-C stops the server cleanly.
exec caffeinate -i mlx_lm.server \
  --model "$MODEL" \
  --host "$HOST" --port "$PORT" \
  --temp 0.0 \
  --max-tokens "$MAX_TOKENS" \
  --prompt-cache-bytes "$CACHE_BYTES" \
  --prompt-cache-size "$CACHE_SLOTS" \
  --chat-template-args "{\"enable_thinking\":$THINK}"
