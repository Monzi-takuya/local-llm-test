# フェーズ 6: Cursor からの実行 — キャンセル（2026-09-13）

## なぜキャンセルか

フェーズ 6 の本筋は「Cursor Chat にモデルを繋ぐ」ではなく、**Cursor に開いた WSL ターミナルからローカルランタイムを叩く**ことだった。

それはフェーズ 2–5 で終わっている。Ollama、`llama-cli`、`llama-server` + `scripts/chat_client.py`、`scripts/bench.sh` は、いずれもこのリポジトリの通常ターミナル（Agent サンドボックスではない）から実行し、日本語の生成まで確認済み。ユーザ判断で追加の手順は不要。

## やらなかったこと

- Cursor Chat / Agent への Override OpenAI Base URL
- ngrok / Cloudflare Tunnel などの公開 HTTPS
- Continue 等のエディタ直結クライアント
- このフェーズ専用の再計測

フェーズ 4 で Windows `curl.exe` → `127.0.0.1:8080` は届いた。それは同じ PC 内の mirrored であり、Cursor クラウドから localhost が見えることではない。Chat をローカル LLM にする実験は、必要になったら新しいフェーズを切る。

## 残しておく期待値（実施しないが事実）

- Cursor Chat / Agent のプロンプト組み立てはクラウド側。`http://127.0.0.1:8080` や `:11434` には Cursor サーバから届かない
- Agent サンドボックスは GPU をブロックする。推論と `nvidia-smi` は通常ターミナル
- Tab 補完はクラウド専用
