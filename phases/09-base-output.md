# フェーズ 9: Qwen3.5-9B-Base の出力（研究）

フェーズ 7 の日常は post-trained の `Qwen3.5-9B`。同じ 9B の **Base**（事前学習のみ）を同じ `llama-server` 口で出し、指示追従・thinking・拒否が重み側の学習か、テンプレだけの話かを見る。

- 依存: フェーズ 8 の `scripts/serve.sh`、フェーズ 7 の 9B Q4
- GPU: 必須。サンドボックス外。8GB では 9b と同時に載せない
- 日常の置き換えではない

## なぜ今これか

9B チャットは chat template に安全文が無くても拒否する。thinking の `<think>` も語彙にある。それが **post-training で付いた習慣**なら、Base では同じテンプレでも続きを書く／指示を無視するはず。テンプレだけの効果なら Base でもアシスタントになる。このフェーズは重みを入れ替えてその差を見る。

このフェーズで確定すること:

1. Base Q4 が `~/models` にあり、`scripts/serve.sh 9b-base` が 8080 で待つ
2. 同じ Web UI で、短い日本語 1 本を 9b と 9b-base で並べられる（同時起動はしない）
3. Base がチャット相手として壊れる／続く、のどちらが主かを記録する

やらなかったこと: Base の速度表、27B-Base、ファインチューン、Unsloth 再量子化、mmproj。

## 取得

日常 9B は Unsloth の `Qwen3.5-9B-Q4_K_M.gguf`。Base の Unsloth GGUF は無いので、同じ Q4_K_M の **mradermacher** を使う。量子化元が違うので、差の一部は quantizer 由来になりうる。サイズは約 5.3G。

```bash
curl -fL --retry 3 --retry-delay 2 \
  -o ~/models/Qwen3.5-9B-Base.Q4_K_M.gguf \
  "https://huggingface.co/mradermacher/Qwen3.5-9B-Base-GGUF/resolve/main/Qwen3.5-9B-Base.Q4_K_M.gguf"
ls -lh ~/models/Qwen3.5-9B-Base.Q4_K_M.gguf
```

見る場所: ファイルが約 5.3G。途中で止めたら `.partial` が残るので消して取り直す。

## 起動

既に 8080 が生きていたら先に Ctrl+C。Ollama に載せない。

```bash
# 研究（Base）。省略時 reasoning off
scripts/serve.sh 9b-base

# 同じ口で日常 9B に戻すときは止めてから
scripts/serve.sh 9b
```

見る場所:

- 起動直後の `profile: 9b-base` と `gguf: .../Qwen3.5-9B-Base.Q4_K_M.gguf`
- `listening on http://127.0.0.1:8080`
- `nvidia-smi` の used。9B と同じ帯（約 5400 MiB）なら全載せ

**混同ポイント**: GGUF に公式の chat template が載っている。Web UI は 9b と同じく `<|im_start|>` と空の `<think>` を付ける。見ているのは「生の次トークン予測」そのものではなく、**同じ型に流した Base 重み**。生の続きが欲しいときは `llama-cli -p` でテンプレ無し。

`--reasoning on` は Base でも渡せるが、thinking 習慣は post-train 側。on を試すなら「空 think を埋められるか」の観察用。

## 見る文

固定の品質 3 本（[`../results/07-prompts.md`](../results/07-prompts.md)）を 9b と同じく 1 往復でよい。合格は「日本語メールが丁寧」ではない。

見る場所:

- 質問に答えず、文の続きを書くか
- `<think>` を閉じずに中で ramble するか
- 敬語メールや JSON だけ、のような短い指示を守るか（フェーズ 7 の 3 本で足りる）

## 合格条件

- [ ] `~/models/Qwen3.5-9B-Base.Q4_K_M.gguf` がある
- [ ] `scripts/serve.sh 9b-base` で UI が開く
- [ ] 9b と入れ替えて 1 本ずつ打てる（同時起動しない）
- [ ] このファイルの「混同ポイント」を読んだ（テンプレは付く）

記録するなら [`../results/09-base.md`](../results/09-base.md) にコマンドと観察だけ。必須ではない。

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| missing gguf | 上の curl が未完了、またはファイル名のドット |
| port in use | 前の 9b / 27b が残っている |
| アシスタントとして完璧 | 誤って `9b` を起動している。ログの `alias:` |

## 成果物

- [`../scripts/serve.sh`](../scripts/serve.sh) の `9b-base`
- 任意: `results/09-base.md`
