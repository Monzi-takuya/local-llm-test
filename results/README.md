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
| `12-gcp-webui.md` | 12（IAP `-L` で llama-server。外部 IP なし） |
| `13-name-split.md` / `13-raw/` | 13（姓名分割の基準表。15 / 16 / 17 が列を足す。生応答 JSONL は `13-raw/` に残す） |
| `14-train-env.md` | 14（torch / sm_120、2B bf16 の VRAM、線形層一覧、target_modules 候補） |
| `15-sft.md` | 15（LoRA 設定、trainable params、loss、VRAM、見えたもの） |
| `16-merge.md` | 16（merge / GGUF / Q4 のサイズと所要、Q4 で差分が残ったか） |
| `17-base-sft.md` | 17（2B-Base の同設定 SFT。Instruct との差） |
