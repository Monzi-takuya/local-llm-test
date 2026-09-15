# local-llm-test

WSL2 からローカル LLM の推論を検証し、**トークン化 → GGUF → GPU 推論 → OpenAI 互換 API** の仕組みを段階的に理解するための実験リポジトリ。

一気に全部やらない。進行の正本は [`PROGRESS.md`](PROGRESS.md)。計画の 0–5 と 7 は完了、6 はキャンセル。日常モデルは Qwen3.5-9B Q4。追加実験は新しいフェーズを切ってから。

## いまやること

計画どおりのローカル検証は完了。ブラウザは [`scripts/serve.sh`](scripts/serve.sh)（`9b` / `27b`）。東京 L4 の 27B 全載せは [`results/11-gcp-l4.md`](results/11-gcp-l4.md): Gen **14.5 tok/s**。VM は stop 済み、ディスクは残している。

## ディレクトリ

| パス | 役割 |
| --- | --- |
| [`PROGRESS.md`](PROGRESS.md) | 進行管理の正本 |
| [`docs/environment.md`](docs/environment.md) | 実測スペックと制約 |
| [`phases/`](phases/) | フェーズごとの手順・合格条件 |
| [`notes/`](notes/) | 学習ノート。[`notes/pipeline.md`](notes/pipeline.md)、GPU 用語 [`notes/learn-gpu-stack.html`](notes/learn-gpu-stack.html)、量子化 [`notes/learn-quantization.html`](notes/learn-quantization.html) |
| [`scripts/`](scripts/) | 検証スクリプト。tokenizer、[`scripts/chat_client.py`](scripts/chat_client.py)、[`scripts/bench.sh`](scripts/bench.sh)、Web UI 起動 [`scripts/serve.sh`](scripts/serve.sh)、Base 生続き [`scripts/raw_complete.py`](scripts/raw_complete.py)。GCP VM は [`scripts/gcp/`](scripts/gcp/) |
| [`results/`](results/) | 計測メモ・ログ |
| [`sample.wslconfig`](sample.wslconfig) | WSL 設定のリポジトリ側正本（適用先は `%UserProfile%\.wslconfig`） |

モデル本体は git に入れない。置き場所は WSL の ext4（推奨: `~/models`）。

## このマシンでの前提

- RTX 5060 **8 GB**（Blackwell）
- WSL RAM **24 GB**（`sample.wslconfig` / mirrored 適用済み。実測 Mem 約 23Gi）
- 学習用 Python は **3.12**（システムの 3.14 は使わない）
- Cursor Agent のサンドボックスでは GPU が使えない。推論は通常ターミナルで行う

詳細は [`docs/environment.md`](docs/environment.md)。
