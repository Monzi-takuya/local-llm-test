#!/usr/bin/env bash
# 付属 Web UI（llama-server）を、フェーズ 7 で確定したフラグで起動する。
#
# Why: ブラウザから 9B（日常）と 27B（上限・低速）と 9B-Base（研究）を同じ口で試す。
# 新しいチャットアプリは作らない。llama-server の Web UI が同じポートに付く。
# 8GB VRAM では同時に 2 モデルを載せない。起動は 1 本だけ。
#
# Usage（サンドボックス外のターミナル）:
#   scripts/serve.sh 9b
#   scripts/serve.sh 9b on
#   scripts/serve.sh 9b-base
#   scripts/serve.sh 27b off
#
# 第2引数は reasoning（thinking）。モデルが答えの前に推論トークンを出すか。
# 省略時は off（フェーズ 7 の速度表と同じ）。on はトークンが増え、27B はさらに遅い。
# 9b-base でも同じフラグを渡せるが、Base は thinking 用に post-train していない。
#
# 見る場所:
#   ログの `listening on http://127.0.0.1:8080`
#   ブラウザ（Windows 可、mirrored）: http://127.0.0.1:8080
#   nvidia-smi の used。9B / 9B-Base は約 5400 MiB、27B は約 7714 MiB
#
# 止め方: このプロセスで Ctrl+C。VRAM は 0 に戻る。
#
# Optional env: LLAMA_BIN HOST PORT
# Not done: 0.0.0.0、API キー、HTTPS、Ollama 同時載せ、35B。

set -euo pipefail

BIN="${LLAMA_BIN:-$HOME/opt/llama.cpp/llama-b10938}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
MODELS="${MODELS_DIR:-$HOME/models}"

export LD_LIBRARY_PATH="$BIN:/usr/local/lib/ollama/cuda_v13:/usr/lib/wsl/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

usage() {
  echo "usage: $0 9b|9b-base|27b [on|off]" >&2
  echo "  9b      : Qwen3.5-9B Q4       日常（~66 tok/s, VRAM ~5400）" >&2
  echo "  9b-base : Qwen3.5-9B-Base Q4  研究。チャット相手ではない" >&2
  echo "  27b     : Qwen3.8-27B Q4      上限（~3.7 tok/s, VRAM ~7714）。-t 12" >&2
  echo "  on|off  : --reasoning。省略時 off" >&2
  exit 2
}

[[ $# -eq 1 || $# -eq 2 ]] || usage
PROFILE=$1
REASONING=${2:-off}

case "$REASONING" in
  on|off) ;;
  *)
    echo "reasoning must be on or off, got: $REASONING" >&2
    usage
    ;;
esac

case "$PROFILE" in
  9b)
    GGUF="$MODELS/Qwen3.5-9B-Q4_K_M.gguf"
    ALIAS=qwen3.5-9b
    EXTRA=( -ngl 99 -c 8192 --reasoning "$REASONING" )
    NOTE="日常。c 8192。"
    ;;
  9b-base)
    # mradermacher のファイル名はドット区切り。Unsloth の日常 9B とは別 quantizer。
    # GGUF に chat template が載っているので Web UI は 9b と同じ口。重みだけ Base。
    GGUF="$MODELS/Qwen3.5-9B-Base.Q4_K_M.gguf"
    ALIAS=qwen3.5-9b-base
    EXTRA=( -ngl 99 -c 8192 --reasoning "$REASONING" )
    NOTE="研究用 Base。指示追従も thinking も学習していない。日常には使わない。"
    ;;
  27b)
    GGUF="$MODELS/Qwen3.8-27B-UD-Q4_K_M.gguf"
    ALIAS=qwen3.8-27b
    # フェーズ 7: ngl 32+ は VRAM 7880 で decode が落ちる。-t 20 も遅い。
    EXTRA=( -ngl 30 -c 2048 -t 12 -tb 12 --reasoning "$REASONING" )
    NOTE="上限・低速。チャット日常には向かない。Ctrl+C で止めてから 9b に戻す。"
    ;;
  *)
    usage
    ;;
esac

if [[ ! -x "$BIN/llama-server" ]]; then
  echo "missing llama-server at $BIN/llama-server" >&2
  exit 1
fi
if [[ ! -f "$GGUF" ]]; then
  echo "missing gguf: $GGUF" >&2
  exit 1
fi

if command -v ss >/dev/null 2>&1; then
  if ss -ltn | grep -qE ":${PORT}\\b"; then
    echo "port $PORT is already in use. stop the other llama-server (Ctrl+C) first." >&2
    echo "8GB では 9b / 9b-base / 27b を同時に載せない。" >&2
    exit 1
  fi
fi

echo "profile:    $PROFILE"
echo "alias:      $ALIAS"
echo "reasoning:  $REASONING"
echo "gguf:       $GGUF"
echo "bind:       http://${HOST}:${PORT}"
echo "note:       $NOTE"
echo "ui:         enabled (llama-server default --webui)"
echo "open:       Windows ブラウザでも mirrored なら同じ URL"
echo "not:        Cursor Chat、LAN 公開、Ollama にモデルを載せたまま"
echo

exec "$BIN/llama-server" \
  -m "$GGUF" \
  --alias "$ALIAS" \
  --host "$HOST" \
  --port "$PORT" \
  --webui \
  "${EXTRA[@]}"
