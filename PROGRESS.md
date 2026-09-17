# 進行管理

このファイルが進行の正本。フェーズ MD を実施したら、ここを更新してから止める。

正本プラン: Cursor 側の `wsl_local_llm` 計画。リポジトリ内の詳細手順は [`phases/`](phases/)。

## 現在地

- **フェーズ**: 13（姓名分割の学習なしベースライン）
- **状態**: 未着手（推論の弧 0–12 は閉じた。ここから事後学習の弧 13 → 14 → 15 → 16 → 17）
- **次に開くファイル**: 教材 [`notes/learn-llm-basics.html`](notes/learn-llm-basics.html) を読んでから [`phases/13-name-split-probe.md`](phases/13-name-split-probe.md)。手法の教材は [`notes/learn-sft-lora.html`](notes/learn-sft-lora.html)（フェーズ 14 の前に 1–6）。式の分解は [`primer/README.md`](primer/README.md)（計画のみ、並行）
- **クラウド**: L4 VM は TERMINATED、ディスク残。学習は手元 8GB が本命。L4 は sm_120 / Ubuntu 26.04 で詰まって人が許可したときだけ

並行トラック: **primer**（[`primer/README.md`](primer/README.md)）。高校数学から行列積・勾配・文字単位の超小型 LM までを手で書く。GPU 不要。フェーズ 13–17 をブロックしない。いまは計画 MD のみ。

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
| 11 | 東京 L4 に 27B 全載せ（IAP） | 完了 | [`phases/11-gcp-l4-iap.md`](phases/11-gcp-l4-iap.md) |
| 12 | IAP トンネルで llama-server | 完了 | [`phases/12-gcp-webui-iap.md`](phases/12-gcp-webui-iap.md) |
| 13 | 姓名分割の学習なしベースライン（4 重み × 0/3-shot） | 未着手 | [`phases/13-name-split-probe.md`](phases/13-name-split-probe.md) |
| 14 | 学習環境と 1 forward（torch cu128 / sm_120 / target_modules） | 未着手 | [`phases/14-train-env.md`](phases/14-train-env.md) |
| 15 | Qwen3.5-2B に LoRA SFT（completion-only） | 未着手 | [`phases/15-lora-sft-2b.md`](phases/15-lora-sft-2b.md) |
| 16 | merge → GGUF → `serve.sh 2b-sft` | 未着手 | [`phases/16-merge-gguf.md`](phases/16-merge-gguf.md) |
| 17 | 2B-Base に同じ SFT（任意） | 未着手 | [`phases/17-base-sft.md`](phases/17-base-sft.md) |

依存: 0 → 1 は GPU 不要で並列に見えるが、Python 3.12 は 0 で用意する。2 は 0 の後。3 は 2 の後が安全。4 は 2 か 3 の後。5 は 3（または 2）の後。6 は 4 の後。

事後学習の弧: 13 → 14 → 15 → 16 → 17 の順。13 は 8（`serve.sh`）と 9（9B-Base）に依存し、9 の「Base は指示を守らない」の記録は 13 の表に吸収する（9 は実施中のまま残す）。14 は 13 が無くても環境作りは進められるが、順番は守る。17 は 16 の後で任意。教材は [`notes/learn-llm-basics.html`](notes/learn-llm-basics.html)（13 の前）と [`notes/learn-sft-lora.html`](notes/learn-sft-lora.html)（14 の前に 1–6、16 の後に 7–8 と 12 節の数字）。式の中身（行列積、softmax、勾配、attention の数値表）は並行して [`primer/README.md`](primer/README.md)。

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
| 2026-09-15 | 11 | 東京 c の `g2-standard-8`。IAP・NAT。27B Q4 `-ngl 99` は Prompt 83.9 / Gen **14.5 tok/s**、VRAM 15320 MiB。a/b は在庫切れ。約 72 分で stop。ディスク残。 [`results/11-gcp-l4.md`](results/11-gcp-l4.md) |
| 2026-09-15 | 12 | IAP `-L` で llama-server。UI **14.6 tok/s**、VRAM 15770 MiB。`llama-server` はターゲットだけ約 4 秒で足した。約 14 分で stop。 [`results/12-gcp-webui.md`](results/12-gcp-webui.md) |
| 2026-09-15 | 計画 | 事後学習の弧 13–17 を切った。学習対象は **Qwen3.5-2B**（Instruct。Base は 17）。手元 8GB、bf16 LoRA、completion-only。`docs/environment.md` の「ファインチューニングをやらない」を 2B LoRA に限って解禁。教材 `notes/learn-llm-basics.html` / `notes/learn-sft-lora.html` を追加。実行はまだ |
| 2026-09-16 | primer | 基礎サブプロジェクトの計画のみ。HTML/スクリプトは未作成。形式は既存ノートと同じ HTML（KaTeX・数値表）+ 標準ライブラリの `.py`。Jupyter は使わない。行ベクトル流儀、文字単位 bigram から。 [`primer/README.md`](primer/README.md) |
