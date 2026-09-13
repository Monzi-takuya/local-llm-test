#!/usr/bin/env bash
# Phase 5: one llama-cli run with fixed sampling and VRAM watch.
#
# Why: llama.cpp prints Prompt / Generation token/s. Ollama hides -ngl.
# Read this file before running. Paths are for this WSL machine.
#
# Usage:
#   scripts/bench.sh <tag> <gguf> <ngl> <ctx> <prompt_file>
#
# Example:
#   scripts/bench.sh 7b-q4-ngl99-c2048-ja \
#     ~/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf 99 2048 \
#     results/05-prompt-ja.txt
#
# Writes:
#   $BENCH_OUTDIR/<tag>.txt       llama-cli stdout+stderr + meta (default results/05-raw)
#   $BENCH_OUTDIR/<tag>.vram.csv  nvidia-smi samples during the run
#
# Optional env:
#   LLAMA_BIN       llama.cpp dir (default ~/opt/llama.cpp/llama-b10938)
#   BENCH_OUTDIR    log directory
#   LLAMA_EXTRA     extra llama-cli args, e.g. '--reasoning off'
#
# Not done here: OpenAI API, Ollama, Windows native, Q8.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${LLAMA_BIN:-$HOME/opt/llama.cpp/llama-b10938}"
export LD_LIBRARY_PATH="$BIN:/usr/local/lib/ollama/cuda_v13:/usr/lib/wsl/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

usage() {
  echo "usage: $0 <tag> <gguf> <ngl> <ctx> <prompt_file>" >&2
  exit 2
}

[[ $# -eq 5 ]] || usage

TAG=$1
GGUF=$2
NGL=$3
CTX=$4
PROMPT_FILE=$5

if [[ ! -x "$BIN/llama-cli" ]]; then
  echo "missing llama-cli at $BIN/llama-cli" >&2
  exit 1
fi
if [[ ! -f "$GGUF" ]]; then
  echo "missing gguf: $GGUF" >&2
  exit 1
fi
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "missing prompt: $PROMPT_FILE" >&2
  exit 1
fi

OUTDIR="${BENCH_OUTDIR:-$ROOT/results/05-raw}"
mkdir -p "$OUTDIR"
LOG="$OUTDIR/${TAG}.txt"
WATCH="$OUTDIR/${TAG}.vram.csv"
PROMPT="$(cat "$PROMPT_FILE")"

: > "$WATCH"
(
  while true; do
    nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader,nounits >> "$WATCH" || true
    sleep 0.25
  done
) &
WATCH_PID=$!
cleanup() { kill "$WATCH_PID" 2>/dev/null || true; }
trap cleanup EXIT

{
  echo "=== meta ==="
  echo "date: $(date -Iseconds)"
  echo "tag: $TAG"
  echo "bin: $BIN/llama-cli"
  echo "gguf: $GGUF"
  echo "ngl: $NGL"
  echo "ctx: $CTX"
  echo "n_predict: 128"
  echo "temp: 0"
  echo "top_k: 0"
  echo "top_p: 1.0"
  echo "seed: 0"
  echo "prompt_file: $PROMPT_FILE"
  echo "llama_extra: ${LLAMA_EXTRA:-}"
  echo "ram_before: $(free -h | awk '/Mem:/ {print $3 " used / " $2}')"
  echo
  echo "=== llama-cli ==="
  "$BIN/llama-cli" \
    -m "$GGUF" \
    -ngl "$NGL" \
    -c "$CTX" \
    -n 128 \
    --temp 0 \
    --top-k 0 \
    --top-p 1.0 \
    -s 0 \
    -st \
    --no-display-prompt \
    ${LLAMA_EXTRA:-} \
    -p "$PROMPT"
  echo
  echo "=== ram_after ==="
  free -h | awk '/Mem:/ {print $3 " used / " $2}'
} >"$LOG" 2>&1

cleanup
trap - EXIT
wait "$WATCH_PID" 2>/dev/null || true

if [[ -s "$WATCH" ]]; then
  python3 - "$WATCH" "$LOG" <<'PY'
import sys
path, log = sys.argv[1], sys.argv[2]
mem, util = [], []
with open(path, encoding="utf-8") as f:
    for line in f:
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 2:
            continue
        try:
            mem.append(float(parts[0]))
            util.append(float(parts[1]))
        except ValueError:
            continue
summary = []
if mem:
    summary.append(f"vram_max_mib {max(mem):.0f}")
    summary.append(f"util_max_pct {max(util):.0f}")
    summary.append(f"vram_samples {len(mem)}")
else:
    summary.append("vram_max_mib NA")
with open(log, "a", encoding="utf-8") as f:
    f.write("\n=== watch ===\n")
    f.write("\n".join(summary) + "\n")
print("\n".join(summary))
PY
fi

echo "wrote $LOG"
