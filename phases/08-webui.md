# フェーズ 8: 付属 Web UI で 9B / 27B

フェーズ 4 の `llama-server` とフェーズ 7 の採用フラグを、ブラウザから試す。新しいチャットアプリは作らない。

- 依存: フェーズ 7 の GGUF が `~/models` にあること
- GPU: 必須。サンドボックス外
- 同時起動しない（8GB VRAM）

## なぜ今これか

フェーズ 7 で日常は 9B、上限は 27B と分かった。curl / `chat_client.py` では会話の体感が取りにくい。`llama-server` の付属 Web UI が同じ 8080 に付くので、それを起動するだけにする。

このフェーズで確定すること: 9B と 27B を **入れ替えて** ブラウザ 1 往復できる。reasoning on/off も起動時に指定できる。Base（研究）は [`09-base-output.md`](09-base-output.md)。

やらなかったこと: 自前 SPA、0.0.0.0、API キー、Cursor Chat、9B と 27B の同時載せ。

## 手順

すべて Cursor サンドボックス外。Ollama にモデルを載せない。既に 8080 が生きていたら先に Ctrl+C。

**reasoning**: 答えの前に推論トークンを出すか。省略時 `off`（フェーズ 7 と同じ）。`on` はトークンが増える。27B は off でも約 3.7 tok/s。

```bash
# 日常（think off）
scripts/serve.sh 9b

# 同じ 9B で thinking を見る
scripts/serve.sh 9b on

# 上限（遅い）
scripts/serve.sh 27b
scripts/serve.sh 27b on

# 研究（Base）。日常には使わない。手順はフェーズ 9
scripts/serve.sh 9b-base
```

見る場所:

- ログ: `listening on http://127.0.0.1:8080`
- ブラウザ: 同じ URL（Windows も mirrored なら可）
- `nvidia-smi`: 9B 約 5400 MiB、27B 約 7714 MiB
- 起動直後の `reasoning:` 行が on/off と一致

止め方: 起動したターミナルで Ctrl+C。別プロファイルに切り替えるときは必ず止めてから。

## 合格条件

- [ ] `scripts/serve.sh 9b` で UI が開き、日本語 1 往復できた
- [ ] 止めてから `scripts/serve.sh 27b` でも 1 往復できた（遅くてよい）
- [ ] `9b on` または `27b on` を 1 回試し、off との差（前置きの長さ）を見た
- [ ] 同時に 2 本立てないことを確認した（2 本目は port in use）

記録するなら [`../results/08-webui.md`](../results/08-webui.md) にコマンドと可否だけ。必須ではない。

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| port in use | 前の llama-server が残っている |
| 数 tok/s の 9B | GDN CPU 落ち。フェーズ 7 と同じ LD_LIBRARY_PATH |
| 27B が 1 tok/s 台 | `-t` が default の 20。スクリプトが 12 になっているか |
| Cursor Chat から届かない | 想定どおり。ブラウザか WSL ターミナル |

## 成果物

- [`../scripts/serve.sh`](../scripts/serve.sh)
