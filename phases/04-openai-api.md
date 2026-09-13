# フェーズ 4: OpenAI 互換サーバ

ローカル LLM を「対話アプリの部品」にする。ここで初めて、エディタやクライアントが何を POST しているかが分かる。

- 依存: フェーズ 2 または 3 で、動くモデルが 1 つあること
- GPU: サーバ起動中は占有する
- 所要の目安: サーバ起動と curl / 短い Python

## 学習で押さえること

```text
Client → POST /v1/chat/completions
      → chat template + tokenize
      → 1 トークンずつ推論
      → 非ストリーム: 一括 JSON / ストリーム: SSE delta
```

- `model` はサーバが知っている名前（Ollama のタグ、llama-server の別名）
- `base_url` は `http://127.0.0.1:<port>/v1` の形が多い
- `mirrored` なら **同じ PC の Windows ブラウザ**からも `localhost` で届くことがある
- それは Cursor クラウドからは見えない（フェーズ 6）

## 手順

サーバはどちらか一方を主、もう一方は任意の確認でよい。

### 4-1. サーバを立てる

Ollama（フェーズ 2 済みなら手軽）:

- 既定 `http://127.0.0.1:11434/v1`
- モデル名は `ollama list` のタグそのもの

llama-server（フェーズ 3 の続きとして推奨）:

```bash
llama-server -m ~/models/<model>.gguf -ngl 99 -c 2048 --port 8080
```

実際のフラグはバイナリのヘルプに合わせる。ポートとモデル名を [`../results/04-api.md`](../results/04-api.md) に書く。

### 4-2. curl 非ストリーム

```bash
curl -s http://127.0.0.1:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "REPLACE_ME",
    "messages": [{"role": "user", "content": "1+1は？"}],
    "max_tokens": 64
  }' | jq .
```

llama-server ならホストとポートを読み替える。`choices[0].message.content` があること。

### 4-3. curl ストリーム

`"stream": true` を付け、SSE の `data:` 行が順に増えることを見る。フェーズ 1 の「1 トークンずつ」と対応づける。

### 4-4. Python クライアント

`.venv`（3.12）で `openai` パッケージを入れ、`scripts/chat_client.py` を作る。

要件:

- `base_url` と `model` を引数または環境変数で変える
- API キーはダミーでよい（ローカルサーバは検証しないことが多い）
- ストリーム表示できる
- システムの 3.14 では実行しない

### 4-5. mirrored の確認（任意だが推奨）

Windows 側から `http://127.0.0.1:<port>` に届くか。届いた / 届かないを記録する。これはフェーズ 6 の「同じ PC 内 localhost」の証拠になる。

## 合格条件

- [ ] `/v1/chat/completions` が非ストリームで JSON を返す
- [ ] ストリーム（SSE）でトークンが順に見える
- [ ] `scripts/chat_client.py` が同じサーバを叩ける
- [ ] ポート・モデル名・起動コマンドを `results/04-api.md` に書いた
- [ ] [`../PROGRESS.md`](../PROGRESS.md) を更新した

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| connection refused | サーバ未起動、ポート、Ollama が別ユーザ空間 |
| 404 / model not found | タグの完全一致 |
| Windows から届かない | サーバが `127.0.0.1` のみ bind。`mirrored` でも bind 先を確認 |
| 応答が空 | chat template、Instruct モデルか |

## 成果物

- `scripts/chat_client.py`
- `results/04-api.md`

## 次

完了したら止める。次は [`05-benchmark.md`](05-benchmark.md)。計測を急がないなら 6 のターミナル確認だけ先でもよいが、計画上の順は 5。
