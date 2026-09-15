# フェーズ 12: IAP `-L` で llama-server（L4 27B）

日付: 2026-09-15。project `monzi-sandbox`。VM `l4-27b`（東京 c）。外部 IP なし。

## なぜこの作業か

フェーズ 11 は `llama-cli` 1 本の timings（Gen **14.5 tok/s**）。対話の口は `llama-server` の付属 Web UI。VM に外部 IP が無いので、IAP SSH の `-L` で手元 `127.0.0.1:8080` に出す。8080 の fw と `0.0.0.0` は使わない。

## start

```bash
scripts/gcp/start.sh
# 2026-09-15T23:12:08+09:00 開始
# status: RUNNING、zone: asia-northeast1-c、内部 IP 10.146.0.3
```

直後の IAP SSH は `4003 failed to connect to backend`（sshd 未起動）。約 20 秒待って再試行。

```bash
scripts/gcp/ssh.sh --command='nvidia-smi'
# NVIDIA L4、23034 MiB、Driver 580.178.04、CUDA 13.0、used 0 MiB
```

GGUF `~/models/Qwen3.8-27B-UD-Q4_K_M.gguf`（16G）はディスクに残っていた。再取得していない。

## llama-server が無かった

`~/opt/llama.cpp/build/bin/llama-cli` はある。`llama-server` は無かった（フェーズ 11 は cli だけ使った）。`libllama-server-impl.so` は既にある。全 CUDA 再ビルドはしない。

```bash
cmake --build ~/opt/llama.cpp/build --target llama-server -j"$(nproc)"
# 約 4 秒。version: 0.4.1-dev (commit 41abbfd)
```

次回 start ではこのバイナリがディスクに残る。

## llama-server

bind は `127.0.0.1:8080`。フラグはベンチと同じ。

```bash
# VM 上。pgrep -f llama-server は SSH のコマンド行にマッチして誤判定するので使わない
nohup ~/opt/llama.cpp/build/bin/llama-server \
  -m ~/models/Qwen3.8-27B-UD-Q4_K_M.gguf \
  --alias qwen3.8-27b \
  --host 127.0.0.1 --port 8080 --webui \
  -ngl 99 -c 2048 --reasoning off \
  >~/logs/llama-server.log 2>&1 </dev/null &
```

ロード約 1.4 分。ログ `listening on http://127.0.0.1:8080`。VRAM **15764 MiB** / 23034（フェーズ 11 の cli は max 15320。server はスロット 4 のため少し多い）。

## トンネル

```bash
scripts/gcp/tunnel.sh
# 手元 8080 は空いていた
curl -sS http://127.0.0.1:8080/health
# {"status":"ok"}
```

`gcloud compute start-iap-tunnel 8080` は使っていない。fw の 8080 も開けていない。

curl で `GET /` は `415`（Accept）。ブラウザと `/health` / `/v1/chat/completions` / `/props` は通る。

## 1 往復

同じ ja プロンプトを API で:

```bash
curl -sS http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.8-27b","messages":[{"role":"user","content":"WSLからローカルLLMを動かしたい理由を一文で。"}],"temperature":0,"max_tokens":64}'
```

| 項目 | 値 |
| --- | --- |
| Prompt | 27 tok、**70.7 tok/s** |
| Generation | 37 tok、**14.46 tok/s** |
| 応答 | WindowsのGUI環境を維持したまま、Linuxネイティブのツールチェーンや高性能な推論ライブラリをシームレスに利用して開発効率を最大化するため。 |
| VRAM | 15770 MiB |

フェーズ 11 の cli（14.5 tok/s）と同じ帯。トンネル越しでも decode は落ちていない。

付属 UI（`http://127.0.0.1:8080`）: モデル表示 `qwen3.8 27B`。プリフィル「こんにちは！あなたについて教えてください」を Send。UI 表示 **14.63 t/s**（150 tokens / 10s）。そのあと人が同じトンネルで追加の対話を試した。

## stop

```bash
scripts/gcp/stop.sh
```

| 項目 | 値 |
| --- | --- |
| lastStartTimestamp | 2026-09-15T07:12:20-07:00（23:12 JST） |
| lastStopTimestamp | 2026-09-15T07:26:40-07:00（23:26 JST） |
| status | **TERMINATED** |
| RUNNING | 約 **14 分** |
| GPU 目安 | `$1.0962/h` × 0.24h ≈ **$0.26** |
| ディスク | 残した（GGUF + 今回足した `llama-server`） |

やらなかったこと: 8080 fw、`0.0.0.0`、Cloudflare、delete、ctx 拡大。
