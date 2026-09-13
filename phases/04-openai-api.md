# フェーズ 4: OpenAI 互換サーバ

ローカル LLM を「対話アプリの部品」にする。ここで初めて、エディタやクライアントが何を POST しているかが分かる。

- 依存: フェーズ 2 または 3 で、動くモデルが 1 つあること
- GPU: サーバ起動中は占有する
- 所要の目安: サーバ起動と curl / 短い Python

## なぜ今これか

フェーズ 2 で分かったこと: Ollama は `127.0.0.1:11434` に常駐し、独自の `POST /api/generate` で日本語が出る。

フェーズ 3 で分かったこと: 同じ 7B Q4 を `llama-cli` で `-ngl 99` すると約 80 tok/s。ただし **起動のたびに GGUF を載せ、1 回生成して終了**する。`-n` で出力も切れる。

このフェーズで確定すること: モデルを載せたまま待つ HTTP（`llama-server`）と、OpenAI と同じ `POST /v1/chat/completions`。クライアントは `messages` を JSON で渡すだけで、chat template と tokenize はサーバ側。`stream: true` の SSE がフェーズ 1 の「1 トークンずつ」に対応する。

やらなかったこと（このフェーズでは）: Cursor からの接続（フェーズ 6）、本格ベンチ（フェーズ 5）、`0.0.0.0` やトンネルでの公開、CUDA Toolkit。VRAM 8GB では llama-server と Ollama に 7B を同時載せしない。

## 学習で押さえること

```text
Client → POST /v1/chat/completions
      → chat template + tokenize
      → 1 トークンずつ推論
      → 非ストリーム: 一括 JSON / ストリーム: SSE delta
```

- **OpenAI 互換**: クラウドの OpenAI に繋ぐことではない。リクエストの形（パス、`messages`、`stream`）が同じ、という意味
- **SSE**（Server-Sent Events）: 1 本の HTTP 応答を切らずに `data:` 行を流す。各行の `delta.content` が 1 トークン相当（BPE なので 1 文字とは限らない）
- `model` はサーバが知っている名前（Ollama のタグ、llama-server の `--alias`）
- `base_url` は `http://127.0.0.1:<port>/v1` の形が多い
- `mirrored` なら **同じ PC の Windows ブラウザ / curl.exe** からも `localhost` で届くことがある
- それは Cursor クラウドからは見えない（フェーズ 6）

## 手順

主は **llama-server**（フェーズ 3 の続き。`-ngl` / `-c` が見える）。Ollama の `/v1` は、同じ JSON が別サーバでも通ることの任意確認。8GB では同時に 7B を載せない。

すべて Cursor サンドボックス外。

### 4-1. サーバを立てる

なぜ: `llama-cli` との差は「常駐」。ログに `model loaded` と `listening` が出て、`nvidia-smi` の VRAM がモデルサイズのまま残れば、次の POST でロードし直さない。

```bash
BIN="$HOME/opt/llama.cpp/llama-b10938"
export LD_LIBRARY_PATH="$BIN:/usr/local/lib/ollama/cuda_v13:/usr/lib/wsl/lib"
"$BIN/llama-server" \
  -m "$HOME/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf" \
  -ngl 99 -c 2048 \
  --host 127.0.0.1 \
  --port 8080 \
  --alias qwen2.5-7b-instruct
```

見る場所:

```text
srv  llama-server: model loaded
srv  llama-server: listening on http://127.0.0.1:8080
```

待ち状態の VRAM はフェーズ 3 の `-c 2048` と同じオーダー（実測 4544 MiB）。Util は 0% でよい（生成していない）。

Ollama を主にする場合（任意）: 既定 `http://127.0.0.1:11434/v1`。モデル名は `ollama list` のタグそのもの。

ポートとモデル名を [`../results/04-api.md`](../results/04-api.md) に書く。

### 4-2. curl 非ストリーム

なぜ: アプリが最初に見るのは、一括 JSON の `choices[0].message.content`。ここが空なら chat template / モデル名を疑う。

```bash
curl -sS http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen2.5-7b-instruct",
    "messages": [{"role": "user", "content": "1+1は？短く答えて。"}],
    "max_tokens": 64
  }' | jq .
```

見る場所: `choices[0].message.content` があること。`usage.prompt_tokens` は生の文字数ではなく、サーバが template 後に切ったトークン数。

### 4-3. curl ストリーム

なぜ: フェーズ 1 の「1 トークンずつ sample → detokenize」が、HTTP 上では SSE の `data:` 行になる。一括 JSON だけだと、その対応が見えない。

```bash
curl -N -sS http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen2.5-7b-instruct",
    "messages": [{"role": "user", "content": "WSLからローカルLLMを動かしたい理由を一文で。"}],
    "max_tokens": 64,
    "stream": true
  }'
```

見る場所: `data:` が順に増え、最後が `data: [DONE]`。`delta.content` は BPE の切れ目（「ーカ」のように 2 文字以上の行もある）。

### 4-4. Python クライアント

なぜ: curl は形の確認。実際のクライアントは SDK 経由が多い。システムの 3.14 ではなく `.venv`（3.12）で、`base_url` だけ差し替えてローカルを叩く。

`.venv` で `openai` パッケージを入れ、`scripts/chat_client.py` を使う。

```bash
uv pip install openai   # 未導入なら。判断はフェーズ開始時に確認済み

.venv/bin/python scripts/chat_client.py \
  --base-url http://127.0.0.1:8080/v1 \
  --model qwen2.5-7b-instruct \
  --prompt '1+1は？短く答えて。'

.venv/bin/python scripts/chat_client.py \
  --base-url http://127.0.0.1:8080/v1 \
  --model qwen2.5-7b-instruct \
  --stream
```

要件:

- `base_url` と `model` を引数または環境変数で変える
- API キーはダミーでよい（ローカルサーバは検証しないことが多い）
- ストリーム表示できる
- システムの 3.14 では実行しない

### 4-5. mirrored の確認（任意だが推奨）

なぜ: フェーズ 6 で「Cursor クラウドから届かない」と比較するとき、**同じ PC 内の Windows からは届く**証拠が要る。

```bash
/mnt/c/Windows/System32/curl.exe -sS http://127.0.0.1:8080/v1/models
```

届いた / 届かないを [`../results/04-api.md`](../results/04-api.md) に書く。サーバが `127.0.0.1` のみでも、`mirrored` なら Windows の localhost と共有されうる。

## 合格条件

- [x] `/v1/chat/completions` が非ストリームで JSON を返す
- [x] ストリーム（SSE）でトークンが順に見える
- [x] `scripts/chat_client.py` が同じサーバを叩ける
- [x] ポート・モデル名・起動コマンドを `results/04-api.md` に書いた
- [x] [`../PROGRESS.md`](../PROGRESS.md) を更新した

実施メモ（2026-09-13）:

- 主: `llama-server` b10938、`127.0.0.1:8080`、`--alias qwen2.5-7b-instruct`、VRAM 4544 MiB
- 非ストリーム `content` は `2`。SSE の decode 約 79 tok/s。Windows `curl.exe` から localhost 到達
- 任意: Ollama `11434/v1` も同じ JSON（モデル名は `qwen2.5:7b-instruct`）。同時載せはしていない
- 詳細: [`../results/04-api.md`](../results/04-api.md)

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| connection refused | サーバ未起動、ポート、Ollama が別ユーザ空間 |
| 404 / model not found | タグの完全一致（alias と Ollama タグは別） |
| Windows から届かない | サーバが `127.0.0.1` のみ bind。`mirrored` でも bind 先を確認 |
| 応答が空 | chat template、Instruct モデルか |

## 成果物

- `scripts/chat_client.py`
- `results/04-api.md`

## 次

完了したら止める。次は [`05-benchmark.md`](05-benchmark.md)。計測を急がないなら 6 のターミナル確認だけ先でもよいが、計画上の順は 5。
