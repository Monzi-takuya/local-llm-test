# 進行管理

このファイルが進行の正本。フェーズ MD を実施したら、ここを更新してから止める。

正本プラン: Cursor 側の `wsl_local_llm` 計画。リポジトリ内の詳細手順は [`phases/`](phases/)。

## 現在地

- **フェーズ**: 10（monzi-sandbox で 27B / L4 の可否）
- **状態**: 完了（`GPUS_ALL_REGIONS=1`。GPU VM 未作成）
- **次に開くファイル**: 実測 [`results/10-gcp-27b.md`](results/10-gcp-27b.md)。次は別リポジトリで create/stop/delete。Base 研究は [`phases/09-base-output.md`](phases/09-base-output.md)

状態の意味: `未着手` / `実施中` / `ブロック` / `完了` / `キャンセル`

## フェーズ一覧

| ID | 名前 | 状態 | 詳細 |
| --- | --- | --- | --- |
| 骨格 | リポジトリと進行管理 | 完了 | このディレクトリ構成と MD |
| 0 | WSL 土台 | 完了 | [`phases/00-wsl-env.md`](phases/00-wsl-env.md) |
| 1 | トークン化とパイプライン | 完了 | [`phases/01-pipeline-tokenize.md`](phases/01-pipeline-tokenize.md) |
| 2 | Ollama で GPU 確認 | 完了 | [`phases/02-ollama-gpu.md`](phases/02-ollama-gpu.md) |
| 3 | llama.cpp で中身を見る | 完了 | [`phases/03-llamacpp.md`](phases/03-llamacpp.md) |
| 4 | OpenAI 互換 API | 完了 | [`phases/04-openai-api.md`](phases/04-openai-api.md) |
| 5 | 計測と比較 | 完了 | [`phases/05-benchmark.md`](phases/05-benchmark.md) |
| 6 | Cursor からの実行 | キャンセル | [`phases/06-cursor.md`](phases/06-cursor.md) |
| 7 | 快適全載せと部分 GPU | 完了 | [`phases/07-best-local-2026-09.md`](phases/07-best-local-2026-09.md) |
| 8 | 付属 Web UI | 未着手 | [`phases/08-webui.md`](phases/08-webui.md) |
| 9 | 9B-Base の出力（研究） | 実施中 | [`phases/09-base-output.md`](phases/09-base-output.md) |
| 10 | monzi-sandbox で 27B 全載せの可否 | 完了 | [`phases/10-gcp-27b.md`](phases/10-gcp-27b.md) |

依存: 0 → 1 は GPU 不要で並列に見えるが、Python 3.12 は 0 で用意する。2 は 0 の後。3 は 2 の後が安全。4 は 2 か 3 の後。5 は 3（または 2）の後。6 は 4 の後。

## 進め方

1. 上の「現在地」を `実施中` に変える
2. そのフェーズ MD の手順だけやる
3. 合格条件をすべて満たしたら状態を `完了` にする
4. 「現在地」を次フェーズの `未着手` のまま更新し、チャットを止めて確認を待つ
5. 失敗したら状態を `ブロック` にし、現象と次の仮説を記録する

コミット / プッシュ前は `.cursor/rules/push-secrets-check.mdc` に従い、ステージ差分に秘密情報がないか確認する。`results/00-env.txt` 程度は private リポジトリでは可。

資料の粒度は `.cursor/rules/audience-and-notes.mdc`（クラウド/Web は既知、LLM 用語は定義する）。作業の手順・報告は `.cursor/rules/explain-work.mdc`（なぜやるかと実コマンドを厚く。冗長でよい）。`notes/` の HTML コメントは本文に折り込んで消す。

Agent で推論や `nvidia-smi` を回すときは、サンドボックス外のターミナルを使う。

## ログ

| 日付 | フェーズ | 内容 |
| --- | --- | --- |
| 2026-09-13 | 骨格 | README / PROGRESS / phases / docs / .gitignore を作成。インストールと推論は未実施 |
| 2026-09-13 | 0 | nvidia-smi で RTX 5060 8GB を確認。RAM 16GB。当初 `.wslconfig` なし。cmake/jq は sudo 不可のため ~/.local。uv で Python 3.12.14 の .venv と ~/models を作成 |
| 2026-09-13 | 0 追記 | 正しい `%UserProfile%\.wslconfig` を `sample.wslconfig` 相当で作り直し再起動。mirrored 適用を確認（`192.168.40.85`）。GPU・16GB・.venv は維持 |
| 2026-09-13 | 1 | Qwen2.5-7B-Instruct の tokenizer のみ。日本語 14→43 / 英語 13→42 トークン。`notes/pipeline.md` と `scripts/tokenize_demo.py`。GPU・GGUF なし |
| 2026-09-13 | 2 | Ollama 0.34.0（install.sh + zstd）。`gemma3:4b` と `qwen2.5:7b-instruct` が 100% GPU。7B は VRAM 4658 MiB / 8GB。decode 約 40 / 68 tok/s。`results/02-ollama.md` |
| 2026-09-13 | ルール | `.cursor/rules/explain-work.mdc`（なぜやるかと実コマンドを厚く）。フェーズ 3 手順も同じ粒度に更新 |
| 2026-09-13 | 3 | llama-cli b10938 + Ollama の CUDA so。Linux CUDA 公式バイナリなし。7B `-ngl 99` 80 tok/s vs `-ngl 0` 6.4。`-c` 2048→8192 で VRAM 4544→4886 MiB。`results/03-llamacpp.md` |
| 2026-09-13 | 学習 | GPU 用語の図解 HTML: [`notes/learn-gpu-stack.html`](notes/learn-gpu-stack.html) |
| 2026-09-13 | 4 | llama-server `127.0.0.1:8080`。`/v1/chat/completions` 非ストリーム + SSE。Windows localhost 到達。`scripts/chat_client.py`（openai 3.13 / 3.12）。Ollama `/v1` は任意確認。`results/04-api.md` |
| 2026-09-13 | 5 | 固定 2 プロンプト・temp 0・n 128。4B vs 7B、Q4 vs Q5（5204 MiB、ja 崩れ）、GPU 78 vs CPU 6 tok/s、c 2048 vs 8192 は VRAM +342。`results/05-bench.md` / [`notes/learn-quantization.html`](notes/learn-quantization.html) |
| 2026-09-13 | 6 | キャンセル。本筋は Cursor の WSL ターミナルからの実行で、フェーズ 2–5 で確認済み。Chat BYOK / トンネルは未実施。`results/06-cursor.md` |
| 2026-09-13 | 7 | WSL 24GB 確認。Qwen3.5-9B Q4 は c 8192 で VRAM 5400 / 66 tok/s（日常）。Qwen3.8-27B は ngl 30・`-t 12` で 7714 MiB / 3.7 tok/s。default 20 スレッドは CPU 満杯でも遅い。35B 取得は中止。`results/07-best-local.md` |
| 2026-09-13 | 8 | `scripts/serve.sh 9b|27b [on|off]`。付属 Web UI。同時起動しない。手順 [`phases/08-webui.md`](phases/08-webui.md) |
| 2026-09-13 | 9 | 研究用 `9b-base`。GGUF は mradermacher の Q4_K_M。Unsloth Base GGUF は無し。手順 [`phases/09-base-output.md`](phases/09-base-output.md) |
| 2026-09-13 | 10 | `gcloud` は `monzi-sandbox` で動作。東京 L4 / `g2-standard-8` はある。地域 `NVIDIA_L4_GPUS=1` だが `GPUS_ALL_REGIONS=0`。GPU insert は無料枠で 400。VM 未作成。誤って立った e2-micro は削除。記録 [`results/10-gcp-27b.md`](results/10-gcp-27b.md) |
| 2026-09-14 | 10 | 有料化後の読み取り再実測。`billingEnabled` は true のまま。東京 L4=1、**`GPUS_ALL_REGIONS=0` は変わらず**。insert なし。VM なし。 [`results/10-gcp-27b.md`](results/10-gcp-27b.md) |
| 2026-09-14 | 10 | 人が `GPUs (all regions)` を 1 申請、約 1 分で承認。JSON で **`GPUS_ALL_REGIONS` limit 1** / usage 0。東京 L4=1。VM なし。 [`results/10-gcp-27b.md`](results/10-gcp-27b.md) |
