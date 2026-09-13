# 進行管理

このファイルが進行の正本。フェーズ MD を実施したら、ここを更新してから止める。

正本プラン: Cursor 側の `wsl_local_llm` 計画。リポジトリ内の詳細手順は [`phases/`](phases/)。

## 現在地

- **フェーズ**: 1（トークン化とパイプライン）
- **状態**: 未着手
- **次に開くファイル**: [`phases/01-pipeline-tokenize.md`](phases/01-pipeline-tokenize.md)

状態の意味: `未着手` / `実施中` / `ブロック` / `完了`

## フェーズ一覧

| ID | 名前 | 状態 | 詳細 |
| --- | --- | --- | --- |
| 骨格 | リポジトリと進行管理 | 完了 | このディレクトリ構成と MD |
| 0 | WSL 土台 | 完了 | [`phases/00-wsl-env.md`](phases/00-wsl-env.md) |
| 1 | トークン化とパイプライン | 未着手 | [`phases/01-pipeline-tokenize.md`](phases/01-pipeline-tokenize.md) |
| 2 | Ollama で GPU 確認 | 未着手 | [`phases/02-ollama-gpu.md`](phases/02-ollama-gpu.md) |
| 3 | llama.cpp で中身を見る | 未着手 | [`phases/03-llamacpp.md`](phases/03-llamacpp.md) |
| 4 | OpenAI 互換 API | 未着手 | [`phases/04-openai-api.md`](phases/04-openai-api.md) |
| 5 | 計測と比較 | 未着手 | [`phases/05-benchmark.md`](phases/05-benchmark.md) |
| 6 | Cursor からの実行 | 未着手 | [`phases/06-cursor.md`](phases/06-cursor.md) |

依存: 0 → 1 は GPU 不要で並列に見えるが、Python 3.12 は 0 で用意する。2 は 0 の後。3 は 2 の後が安全。4 は 2 か 3 の後。5 は 3（または 2）の後。6 は 4 の後。

## 進め方

1. 上の「現在地」を `実施中` に変える
2. そのフェーズ MD の手順だけやる
3. 合格条件をすべて満たしたら状態を `完了` にする
4. 「現在地」を次フェーズの `未着手` のまま更新し、チャットを止めて確認を待つ
5. 失敗したら状態を `ブロック` にし、現象と次の仮説を記録する

Agent で推論や `nvidia-smi` を回すときは、サンドボックス外のターミナルを使う。

## ログ

| 日付 | フェーズ | 内容 |
| --- | --- | --- |
| 2026-09-13 | 骨格 | README / PROGRESS / phases / docs / .gitignore を作成。インストールと推論は未実施 |
| 2026-09-13 | 0 | nvidia-smi で RTX 5060 8GB を確認。RAM 16GB。当初 `.wslconfig` なし。cmake/jq は sudo 不可のため ~/.local。uv で Python 3.12.14 の .venv と ~/models を作成 |
| 2026-09-13 | 0 追記 | 正しい `%UserProfile%\.wslconfig` を `sample.wslconfig` 相当で作り直し再起動。mirrored 適用を確認（`192.168.40.85`）。GPU・16GB・.venv は維持 |
