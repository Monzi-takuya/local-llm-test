# フェーズ詳細

各ファイルが「そのフェーズで何を・どの順で・どこまでやれば次に進んでよいか」の手順書。

| ファイル | 目的 | GPU | 主な成果物 |
| --- | --- | --- | --- |
| [00-wsl-env.md](00-wsl-env.md) | 動かない原因を先に潰す | 確認のみ | Python 3.12、パッケージ、WSL メモ |
| [01-pipeline-tokenize.md](01-pipeline-tokenize.md) | 推論ループの言葉をコードで固定する | 不要 | `notes/pipeline.md`, `scripts/tokenize_demo.py` |
| [02-ollama-gpu.md](02-ollama-gpu.md) | WSL から RTX 5060 でトークンが出ることを確定する | 必須 | 4B / 7B 起動記録 |
| [03-llamacpp.md](03-llamacpp.md) | ngl・コンテキスト・timings を可視化する | 必須 | llama.cpp 実行メモ |
| [04-openai-api.md](04-openai-api.md) | アプリから叩ける HTTP にする | 必須 | `scripts/chat_client.py` |
| [05-benchmark.md](05-benchmark.md) | サイズ・量子化・コンテキストを比較する | 必須 | `results/` の計測メモ |
| [06-cursor.md](06-cursor.md) | Cursor からの実行範囲（本筋は WSL ターミナル。2026-09-13 キャンセル） | ターミナル | [`../results/06-cursor.md`](../results/06-cursor.md) |
| [07-best-local-2026-09.md](07-best-local-2026-09.md) | 2026-09 の日常 9B 全載せと 27B 部分 GPU | 必須 | [`../results/07-best-local.md`](../results/07-best-local.md) |
| [08-webui.md](08-webui.md) | llama-server 付属 UI で 9B / 27B | 必須 | [`../scripts/serve.sh`](../scripts/serve.sh) |
| [09-base-output.md](09-base-output.md) | 同じ口で 9B-Base の出力を見る（研究） | 必須 | `serve.sh 9b-base` |
| [10-gcp-27b.md](10-gcp-27b.md) | monzi-sandbox で 27B を L4 全載せできるか | 不要（gcloud） | [`../results/10-gcp-27b.md`](../results/10-gcp-27b.md) |
| [11-gcp-l4-iap.md](11-gcp-l4-iap.md) | 東京 L4 に 27B 全載せ（IAP・外部 IP なし） | 不要（クラウド L4） | `scripts/gcp/`、[`../results/11-gcp-l4.md`](../results/11-gcp-l4.md) |
| [12-gcp-webui-iap.md](12-gcp-webui-iap.md) | IAP `-L` で llama-server（L4 27B） | 不要（クラウド L4） | `scripts/gcp/start.sh` / `tunnel.sh`、[`../results/12-gcp-webui.md`](../results/12-gcp-webui.md) |
| [13-name-split-probe.md](13-name-split-probe.md) | 姓名分割を 4 重み（9b / 9b-base / 2b / 2b-base）でプロンプトだけ試し、学習前の基準表を作る | 必須（推論） | `data/name-split/`、`scripts/name_split_probe.py`、`results/13-name-split.md` |
| [14-train-env.md](14-train-env.md) | Blackwell で torch を動かし、2B を bf16 で 1 forward、LoRA の当て先を名前で決める | 必須（forward 1 回） | `.venv-train`、`results/14-train-env.md` |
| [15-lora-sft-2b.md](15-lora-sft-2b.md) | 約 100 件で 2B に LoRA SFT。completion-only の label を目で確認し、型・過学習・忘却を見る | 必須（学習） | `scripts/train/`、adapter、`results/15-sft.md` |
| [16-merge-gguf.md](16-merge-gguf.md) | merge → GGUF → Q4 → `serve.sh 2b-sft` で同じ 20 件 | 必須（推論） | `serve.sh 2b-sft`、`results/16-merge.md`、13 の表の完成 |
| [17-base-sft.md](17-base-sft.md) | 2B-Base に同じ SFT。Instruct との差を同じ表で（任意） | 必須（学習） | `results/17-base-sft.md` |

13 以降は事後学習の弧。理論は [`../notes/learn-llm-basics.html`](../notes/learn-llm-basics.html)（13 の前）と [`../notes/learn-sft-lora.html`](../notes/learn-sft-lora.html)（14 の前）。

実行ルールは [`../PROGRESS.md`](../PROGRESS.md)。スペックは [`../docs/environment.md`](../docs/environment.md)。
