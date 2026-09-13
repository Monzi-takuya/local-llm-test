# local-llm-test

WSL2 からローカル LLM の推論を検証し、**トークン化 → GGUF → GPU 推論 → OpenAI 互換 API** の仕組みを段階的に理解するための実験リポジトリ。

一気に全部やらない。進行の正本は [`PROGRESS.md`](PROGRESS.md)。今やる作業はそこの「現在地」だけ。

## いまやること

1. [`PROGRESS.md`](PROGRESS.md) の現在地を見る
2. 対応する [`phases/`](phases/) の MD を開く
3. そのフェーズの合格条件まで実施する
4. 記録を [`results/`](results/) かフェーズ MD の記録欄に残し、`PROGRESS.md` を更新する
5. 次のフェーズには入らない

## ディレクトリ

| パス | 役割 |
| --- | --- |
| [`PROGRESS.md`](PROGRESS.md) | 進行管理の正本 |
| [`docs/environment.md`](docs/environment.md) | 実測スペックと制約 |
| [`phases/`](phases/) | フェーズごとの手順・合格条件 |
| [`notes/`](notes/) | 学習ノート。フェーズ 1 の [`notes/pipeline.md`](notes/pipeline.md)、フェーズ 3 用語の図解 [`notes/learn-gpu-stack.html`](notes/learn-gpu-stack.html) |
| [`scripts/`](scripts/) | 検証スクリプト。フェーズ 1 の tokenizer、フェーズ 4 の [`scripts/chat_client.py`](scripts/chat_client.py) |
| [`results/`](results/) | 計測メモ・ログ |
| [`sample.wslconfig`](sample.wslconfig) | WSL 設定のリポジトリ側正本（適用先は `%UserProfile%\.wslconfig`） |

モデル本体は git に入れない。置き場所は WSL の ext4（推奨: `~/models`）。

## このマシンでの前提

- RTX 5060 **8 GB**（Blackwell）
- WSL RAM **16 GB**（`sample.wslconfig` / mirrored 適用済み）
- 学習用 Python は **3.12**（システムの 3.14 は使わない）
- Cursor Agent のサンドボックスでは GPU が使えない。推論は通常ターミナルで行う

詳細は [`docs/environment.md`](docs/environment.md)。
