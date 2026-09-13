# フェーズ 1: トークン化とパイプライン

推論エンジンの前に、生成ループの言葉をコードで固定する。**GPU は使わない。モデル重みのダウンロードは tokenizer 用の小さなファイルだけ。**

- 依存: フェーズ 0 の Python 3.12（`.venv`）
- GPU: 不要
- 所要の目安: tokenizer の取得と短いスクリプト

## 学習で押さえること

推論は次のループである。

1. プロンプトを **chat template** でモデル用の文字列にする
2. **tokenize** して token ID 列にする
3. 重み（後のフェーズでは GGUF）を使って順伝播し **logits** を得る
4. 温度・top-p などで **1 トークンをサンプリング**する
5. ID を文字列に戻し（detokenize）、終了トークンまで 3–5 を繰り返す

このフェーズでは 3 の行列演算は走らせない。1, 2, 5 と、量子化・KV キャッシュの説明まで。

```text
Prompt → chat template → token IDs → (後続フェーズ: GPU) → logits → sample → detokenize
```

## 手順

### 1-1. ノートの骨格

[`../notes/pipeline.md`](../notes/pipeline.md) を新規作成し、少なくとも次を自分の言葉で書く。

- BPE / サブワード: 「単語」ではなく token ID がモデルの入力単位
- 特殊トークン: BOS / EOS / PAD、チャットの role 区切り
- chat template: 同じユーザ文でもテンプレを忘れると品質が崩れる
- 温度と top-p: 次トークン分布からのサンプリング
- 量子化: FP16 と Q4 のサイズ差、なぜ 7B が 8 GB VRAM に載るか
- KV キャッシュ: コンテキストが長いと VRAM が増える理由
- GGUF: llama.cpp / Ollama が読む重みの入れ物、という位置づけ（バイナリ解剖はしない）

### 1-2. tokenizer デモ

`.venv` を有効化し、GPU 不要のライブラリだけ入れる。

```bash
source /home/kuos1/dev/local-llm-test/.venv/bin/activate
uv pip install transformers tokenizers huggingface_hub jinja2
```

`scripts/tokenize_demo.py` を作り、同じ日本語文で少なくとも次を表示する。

- 生トークン文字列と ID の対応
- トークン数（文字数との差）
- そのモデルの EOS など特殊トークン
- `apply_chat_template` 前後の文字列と ID 列の差

モデルは **tokenizer だけ**取れる Instruct 系にする。本文生成はしない。候補:

- フェーズ 2 の主戦力に合わせるなら Qwen2.5-7B-Instruct の tokenizer
- ダウンロードを小さくしたいなら同じ系列の小さい Instruct

ネットから tokenizer を取る。重み（safetensors）は落とさない。`huggingface_hub` の tokenizer ファイル（`tokenizer.json` 等）だけでよい。

### 1-3. 確認用の文

少なくとも次の 2 本を通し、ノートにトークン数を書く。

- 短い日本語: `WSLからローカルLLMを動かしたい。`
- 英語 1 文: `Summarize why quantization helps 8GB VRAM.`

## 合格条件

- [x] `notes/pipeline.md` があり、上の項目をカバーしている
- [x] `scripts/tokenize_demo.py` が `.venv` の 3.12 でエラーなく終わる
- [x] chat template あり / なしで ID 列が変わることを確認した
- [x] GPU も GGUF も使っていない
- [x] [`../PROGRESS.md`](../PROGRESS.md) を更新した

実施メモ（2026-09-13）:

- tokenizer: `Qwen/Qwen2.5-7B-Instruct`（重みは未取得。cache は tokenizer.json / vocab / merges / config のみ）
- `apply_chat_template` に jinja2 が必要だったので追加
- 日本語 raw 19 文字 / 14 トークン → template 後 43。英語 raw 42 文字 / 13 トークン → template 後 42
- ログ: [`../results/01-tokenize.txt`](../results/01-tokenize.txt)

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| transformers が 3.14 で入らない | `.venv` が 3.12 か |
| 巨大な weight をダウンロードし始める | モデル ID の取り方。tokenizer のみにする |
| 日本語が文字化け | ターミナルの UTF-8 |

## 成果物

- `notes/pipeline.md`
- `scripts/tokenize_demo.py`

## 次

完了したら止める。次は [`02-ollama-gpu.md`](02-ollama-gpu.md)。
