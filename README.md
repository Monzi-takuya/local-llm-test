# local-llm-test

WSL2 からローカル LLM の推論を検証し、**トークン化 → GGUF → GPU 推論 → OpenAI 互換 API** の仕組みを段階的に理解するための実験リポジトリ。推論の弧（フェーズ 0–12）を閉じたあと、**事後学習の弧**（13–17: 軽量モデルに LoRA SFT）に入る。

一気に全部やらない。進行の正本は [`PROGRESS.md`](PROGRESS.md)。計画の 0–5、7、10–12 は完了、6 はキャンセル。日常モデルは Qwen3.5-9B Q4。追加実験は新しいフェーズを切ってから。

## いまやること

**フェーズ 13**（[`phases/13-name-split-probe.md`](phases/13-name-split-probe.md)）: 姓名分割「山田太郎 → `{"sei":"山田","mei":"太郎"}`」を題材に、学習なしで 9b / 9b-base / 2b / 2b-base の出力を固定 20 件で取る。続いて 14（学習環境）→ 15（Qwen3.5-2B に LoRA SFT）→ 16（merge → GGUF → `serve.sh 2b-sft`）→ 17（2B-Base に同じ SFT、任意）。精度で辞書に勝つことは目的にせず、型・過学習・忘却と、損失マスク・LoRA の当て先を **自分の目で見る**。

先に読む教材: [`notes/learn-llm-basics.html`](notes/learn-llm-basics.html)（これまで動かしてきたものの中身。13 の前）、[`notes/learn-sft-lora.html`](notes/learn-sft-lora.html)（SFT と LoRA。14 の前）。

推論の口はそのまま: ブラウザは [`scripts/serve.sh`](scripts/serve.sh)（`9b` / `9b-base` / `27b`）。東京 L4 の 27B は [`results/11-gcp-l4.md`](results/11-gcp-l4.md) / IAP UI は [`results/12-gcp-webui.md`](results/12-gcp-webui.md): Gen **14.5–14.6 tok/s**。VM は stop 済み、ディスクは残している。再起動は [`scripts/gcp/start.sh`](scripts/gcp/start.sh) と [`scripts/gcp/tunnel.sh`](scripts/gcp/tunnel.sh)。学習は手元 8GB が本命で、L4 は詰まって人が許可したときだけ。

## ディレクトリ

| パス | 役割 |
| --- | --- |
| [`PROGRESS.md`](PROGRESS.md) | 進行管理の正本 |
| [`docs/environment.md`](docs/environment.md) | 実測スペックと制約 |
| [`phases/`](phases/) | フェーズごとの手順・合格条件 |
| [`notes/`](notes/) | 学習ノート。[`notes/pipeline.md`](notes/pipeline.md)、GPU 用語 [`notes/learn-gpu-stack.html`](notes/learn-gpu-stack.html)、量子化 [`notes/learn-quantization.html`](notes/learn-quantization.html)、LLM の中身 [`notes/learn-llm-basics.html`](notes/learn-llm-basics.html)、SFT と LoRA [`notes/learn-sft-lora.html`](notes/learn-sft-lora.html) |
| [`scripts/`](scripts/) | 検証スクリプト。tokenizer、[`scripts/chat_client.py`](scripts/chat_client.py)、[`scripts/bench.sh`](scripts/bench.sh)、Web UI 起動 [`scripts/serve.sh`](scripts/serve.sh)、Base 生続き [`scripts/raw_complete.py`](scripts/raw_complete.py)。GCP VM は [`scripts/gcp/`](scripts/gcp/)。学習は `scripts/train/`（フェーズ 15 で作る） |
| [`data/`](data/) | 手書きの学習・評価データ（架空名の JSONL。フェーズ 13 で作る）。git に入れる |
| [`results/`](results/) | 計測メモ・ログ |
| [`sample.wslconfig`](sample.wslconfig) | WSL 設定のリポジトリ側正本（適用先は `%UserProfile%\.wslconfig`） |

モデル本体は git に入れない。置き場所は WSL の ext4（推奨: `~/models`。学習用の safetensors は `~/models/hf/`、LoRA adapter は `~/models/lora/`）。

## このマシンでの前提

- RTX 5060 **8 GB**（Blackwell）
- WSL RAM **24 GB**（`sample.wslconfig` / mirrored 適用済み。実測 Mem 約 23Gi）
- Python は **3.12**（システムの 3.14 は使わない）。推論用 `.venv` と学習用 `.venv-train`（PyTorch cu128 系。フェーズ 14）は分ける
- Cursor Agent のサンドボックスでは GPU が使えない。推論は通常ターミナルで行う

詳細は [`docs/environment.md`](docs/environment.md)。
