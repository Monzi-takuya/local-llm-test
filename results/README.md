# results

計測と環境ログの置き場。モデルや巨大ログは git に入れない（ルートの `.gitignore`）。

| ファイル | 書くフェーズ |
| --- | --- |
| `00-env.txt` | 0 |
| `01-tokenize.txt` | 1 |
| `02-ollama.md` | 2 |
| `03-llamacpp.md` | 3 |
| `04-api.md` | 4 |
| `05-prompts.md` / `05-bench.md` | 5 |
| `05-raw/` | 5（llama-cli 生ログ。VRAM csv は git 対象外） |
| `06-cursor.md` | 6（キャンセル記録） |
| `07-best-local.md` / `07-prompts.md` / `07-raw/` | 7 |
| `10-gcp-27b.md` | 10（monzi-sandbox の L4 可否。GPU VM なし） |
| `11-gcp-l4.md` / `11-raw/` | 11（東京 L4 全載せ。VRAM csv は git 対象外） |
