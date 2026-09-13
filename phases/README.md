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

実行ルールは [`../PROGRESS.md`](../PROGRESS.md)。スペックは [`../docs/environment.md`](../docs/environment.md)。
