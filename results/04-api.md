# フェーズ 4: OpenAI 互換 API（2026-09-13）

フェーズ 3 の `llama-cli` は、起動のたびに GGUF を載せて 1 回生成して終了していた。アプリが叩く口はそれではなく、**載ったまま待つ HTTP** と、業界で共通の JSON（`POST /v1/chat/completions`）である。同じ 7B Q4 を `llama-server` で常駐させ、curl と Python が何を POST しているかを確定した。

やらなかったこと: Cursor Chat / Agent からの接続（フェーズ 6）、本格ベンチ（フェーズ 5）、`0.0.0.0` 公開、API キー認証、HTTPS / Cloudflare Tunnel。VRAM 8GB では `llama-server` と Ollama に 7B を同時載せしない。

## なぜ今これか

フェーズ 2 で分かったこと: Ollama は `127.0.0.1:11434` の常駐サーバで、独自の `POST /api/generate` が動く。

フェーズ 3 で分かったこと: 同じ GGUF を `llama-cli` で `-ngl 99` すると Generation 約 80 tok/s。ただし毎回ロードし、`-n` で切れる。

このフェーズで確定すること:

1. モデルを載せたまま待つプロセス（`llama-server`）がある
2. クライアントは OpenAI と同じ JSON を POST すればよい（`messages` → サーバ側が chat template + tokenize）
3. `stream: true` の SSE が、フェーズ 1 の「1 トークンずつ」に対応する
4. `mirrored` なら **同じ PC の Windows** から `localhost` で届く。Cursor クラウドからは見えない（フェーズ 6）

## 主サーバ: llama-server（8080）

フェーズ 3 と同じバイナリ置き場。`LD_LIBRARY_PATH` も同じ（Ollama 同梱 CUDA so）。新規パッケージは入れていない。

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

見る場所: 次の 2 行。

```text
srv  llama-server: model loaded
srv  llama-server: listening on http://127.0.0.1:8080
```

| 項目 | 値 |
| --- | --- |
| バイナリ | `/home/kuos1/opt/llama.cpp/llama-b10938/llama-server`（b10938） |
| bind | `127.0.0.1:8080`（ヘルプ既定。LAN 公開ではない） |
| モデル名（API） | `--alias` の `qwen2.5-7b-instruct` |
| ロード後 VRAM（アイドル） | **4544 MiB**（フェーズ 3 の `-c 2048` と一致） |
| GPU-Util（待ち） | 0%（重みは載っているが生成していない） |

`--alias` を付けないと、クライアントの `model` がファイル名依存になる。Ollama のタグ `qwen2.5:7b-instruct` とは別名前（コロン無し）。

警告（ログ）: CORS `*` かつ API キー無し。この検証は `127.0.0.1` のみなので、LAN 公開はしていない。

終了後はプロセスを止めれば VRAM は 0 に戻る（`llama-cli` と同じ。常駐し続けるのは起動しているあいだだけ）。

## 4-2. curl 非ストリーム

```bash
curl -sS http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen2.5-7b-instruct",
    "messages": [{"role": "user", "content": "1+1は？短く答えて。"}],
    "max_tokens": 64
  }' | jq .
```

見る場所:

- `object`: `chat.completion`
- `choices[0].message.content`: **`2`**
- `usage.prompt_tokens`: **39**（生の文字数ではない。サーバが chat template を付けて tokenize した結果）
- `usage.completion_tokens`: **2**
- フェーズ 1 の token ID 列は渡していない。渡したのは `messages` の文字列

`GET http://127.0.0.1:8080/v1/models` の `data[0].id` が `qwen2.5-7b-instruct`。`n_ctx` 2048、`n_params` 7615616512、`ftype` Q4_K Medium。

## 4-3. curl ストリーム（SSE）

SSE は、1 本の HTTP 応答を切らずに、`data:` 行を順に流す形式である。フェーズ 1 の「1 ステップで 1 トークン」が、ここで画面に見える。

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

見る場所: 各行が `data: {..., "delta":{"content":"..."}}`。最後が `data: [DONE]`。

実測の断片（日本語は BPE の切れ目なので、1 行が 1 文字とは限らない）:

```text
data: {"choices":[{"delta":{"content":"ロ"}}], ...}
data: {"choices":[{"delta":{"content":"ーカ"}}], ...}
data: {"choices":[{"delta":{"content":"ル"}}], ...}
...
data: [DONE]
```

最後の chunk の timings: `predicted_n` 40、`predicted_per_second` **79.3**（フェーズ 3 の Generation 80 tok/s と同オーダー）。判定は decode 速度。短い「1+1」の 2 トークンでは tok/s がブレる。

## 4-4. Python クライアント

システムの 3.14 は使っていない。`.venv` の 3.12.14 に `openai` **3.13.0** を入れた（`uv pip install openai`）。クラウドの OpenAI には繋がない。`api_key` はダミー `local-unused`（llama-server は未設定なら検証しない）。

```bash
.venv/bin/python scripts/chat_client.py \
  --base-url http://127.0.0.1:8080/v1 \
  --model qwen2.5-7b-instruct \
  --prompt '1+1は？短く答えて。'

.venv/bin/python scripts/chat_client.py \
  --base-url http://127.0.0.1:8080/v1 \
  --model qwen2.5-7b-instruct \
  --prompt 'WSLからローカルLLMを動かしたい理由を一文で。' \
  --stream
```

| | 実測 |
| --- | --- |
| python | 3.12.14 |
| 非ストリーム | `content` が `2`、`usage prompt=39 completion=2` |
| ストリーム | トークンが順に標準出力へ（SDK が SSE を隠して `delta.content` を繋ぐ） |

`base_url` / `model` は引数または環境変数 `OPENAI_BASE_URL` / `OPENAI_MODEL`。

## 4-5. mirrored（Windows → localhost）

`.wslconfig` は `networkingMode=mirrored`。サーバは `127.0.0.1` のみ。Windows 側の `curl.exe` で同じループバックを叩いた。

```bash
/mnt/c/Windows/System32/curl.exe -sS http://127.0.0.1:8080/v1/models

/mnt/c/Windows/System32/curl.exe -sS http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"qwen2.5-7b-instruct\",\"messages\":[{\"role\":\"user\",\"content\":\"1+1は？短く答えて。\"}],\"max_tokens\":16}"
```

結果: **届いた**。`/v1/models` が JSON、chat の `content` は `2`。

これは「同じ PC 内の Windows プロセス → WSL の 127.0.0.1」の証拠。Cursor のクラウドからは、この `localhost` は見えない（フェーズ 6）。

## 任意確認: Ollama の `/v1`（11434）

同じ JSON 形が、別サーバでも通ることを見る。`llama-server` を止めたあと（VRAM を空けてから）実行。同時載せはしていない。

```bash
curl -sS http://127.0.0.1:11434/v1/models | jq .

curl -sS http://127.0.0.1:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen2.5:7b-instruct",
    "messages": [{"role": "user", "content": "1+1は？短く答えて。"}],
    "max_tokens": 64
  }' | jq '{id, object, model, choices, usage}'

.venv/bin/python scripts/chat_client.py \
  --base-url http://127.0.0.1:11434/v1 \
  --model 'qwen2.5:7b-instruct' \
  --prompt '1+1は？短く答えて。' \
  --stream
```

| | llama-server | Ollama |
| --- | --- | --- |
| base_url | `http://127.0.0.1:8080/v1` | `http://127.0.0.1:11434/v1` |
| model | `qwen2.5-7b-instruct` | `qwen2.5:7b-instruct`（`ollama list` のタグ） |
| `choices[0].message.content` | `2` | `2` |
| `usage.prompt_tokens` | 39 | 39 |

クライアントはホストとモデル名を差し替えるだけ。中の tokenizer / chat template は各サーバが GGUF または Ollama blob から読む。フェーズ 1 の ID 列はどちらにも渡していない。

確認後: `ollama stop qwen2.5:7b-instruct`。VRAM 0 MiB。

## 合格

- [x] `/v1/chat/completions` が非ストリームで JSON（`choices[0].message.content`）
- [x] ストリーム（SSE）で `data:` が順に増える
- [x] `scripts/chat_client.py` が同じサーバを叩ける（3.12、ストリーム可）
- [x] ポート・モデル名・起動コマンドをこのファイルに書いた
- [x] Windows `localhost` から届くことを記録した
