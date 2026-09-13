# フェーズ 6: Cursor からの実行

「Cursor でローカル LLM を使う」の範囲を、動かす前に固定する。Chat にモデルを繋ぐことがゴールではない。

- 依存: フェーズ 4（ターミナルから HTTP クライアントが叩けること）。フェーズ 2/3 の CLI でも本筋の確認は可能
- GPU: ターミナル実行時のみ。Agent サンドボックスでは使えない
- 所要の目安: 確認が中心。トンネル実験は任意

## 先に固定する期待値

Cursor Chat / Agent は、プロンプト組み立てがクラウド側である。そのため:

- `http://localhost:11434` には **Cursor サーバから届かない**
- `networkingMode=mirrored` は **同じ PC 内**の Windows ↔ WSL には効くが、Cursor Chat は直らない
- 公開 HTTPS（ngrok / Cloudflare Tunnel）+ Override OpenAI Base URL は、通信が Cursor 経由のままで、プロンプトが外に出る
- Tab 補完はクラウド専用
- Agent サンドボックスは GPU をブロックする
- 8 GB VRAM の 7B は、ツール多用の Agent には力不足になりやすい

本筋は **Cursor の WSL ターミナルからローカルランタイムを叩く**こと。

## 手順

### 6-1. 本筋: WSL ターミナル

Cursor に開いているこのリポジトリのターミナル（サンドボックスではないもの）で、次のうち使えるものを 1 つ以上実行する。

- `ollama run <tag>` の短い対話
- `llama-cli` の短い生成
- `python scripts/chat_client.py`（フェーズ 4 のサーバが上がっていること）

成功したら、それが「Cursor からローカル LLM を実行した」の定義である。[`../results/06-cursor.md`](../results/06-cursor.md) にコマンドと可否を書く。

### 6-2. Agent サンドボックスの再確認

Agent 経由で `nvidia-smi` を一度試し、ブロックされることを記録してよい。推論を Agent にやらせない。

### 6-3. 同じ PC の localhost（mirrored）

Windows 側ブラウザまたは `curl.exe` で、フェーズ 4 のポートへ。届くなら「Windows プロセス → WSL サーバ」は生きている。Cursor Chat とは別経路だと明記する。

### 6-4. 任意: ローカル完結クライアント

Continue 等、**エディタから直接 localhost を叩く**ツールは、学習の延長として試してよい。入れる場合は名前・接続 URL・可否だけ記録する。必須ではない。

### 6-5. 任意: Cursor Chat の BYOK + トンネル

やるなら次を理解したうえで、短時間の実験に限る。

- ローカル API を公開 HTTPS にする
- Cursor の Override OpenAI Base URL に `/v1` 付きで渡す
- ダミー API キー
- モデル名はサーバ側タグと完全一致

やらなくてよい。やる場合は、プロンプトが Cursor サーバとトンネル先を通ることを `results/06-cursor.md` に明示する。実験後はトンネルを止める。

## 合格条件

必須:

- [ ] Cursor の WSL ターミナルから、ローカルモデルで 1 往復できた
- [ ] 「Chat = ローカル LLM」ではないことを `results/06-cursor.md` に書いた
- [ ] サンドボックスでは GPU 検証しない、と運用を書いた
- [ ] [`../PROGRESS.md`](../PROGRESS.md) を更新した

任意の実験をしたら、その結果も同ファイルへ。

実施メモ（2026-09-13）: **キャンセル**。理由と残した期待値は [`../results/06-cursor.md`](../results/06-cursor.md)。

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| Agent が nvidia-smi 失敗 | 想定どおり。ターミナルへ |
| Chat が localhost に繋がらない | 想定どおり。トンネルなしでは直らない |
| トンネルしても model not found | タグの文字、Base URL の `/v1` |
| 7B で Agent が使い物にならない | 想定どおり。この GPU では無理しない |

## 成果物

- `results/06-cursor.md`

## 次

計画上の最終フェーズ。2026-09-13 にキャンセル（本筋のターミナル実行は 2–5 で済み）。追加でやりたくなったことは、新しい `phases/` ファイルを切ってからにする。
