# フェーズ 5: 計測と比較

同じプロンプトで、サイズ・量子化・コンテキストの差を手で記録する。表計算やダッシュボードは作らない。

- 依存: フェーズ 3 が理想。最低でもフェーズ 2 の Ollama で代用可
- GPU: 必須。計測中は他の CUDA アプリを止める
- 所要の目安: 数本の固定プロンプトを繰り返す時間

量子化の技術（何を何 bit にしているか）は [`../notes/learn-quantization.html`](../notes/learn-quantization.html)。比較表と生成文は [`../results/05-bench.md`](../results/05-bench.md)。

## なぜ今これか

フェーズ 2–4 で分かったこと: 7B Q4 は 8GB に載り GPU で約 80 tok/s、OpenAI 互換 API まで通る。ただし `-n` や温度が実行ごとに違う。

このフェーズで確定すること: 固定 2 本・`temp 0`・`-n 128` で、4B vs 7B、Q4 vs Q5、GPU vs CPU、2K vs 8K の **速度・VRAM・出力文**。

やらなかったこと（このフェーズでは）: Windows ネイティブ、Q8、Ollama 再計測、ダッシュボード、Cursor 接続。Q5 の 8K は必須軸ではない。

## 学習で押さえること

- 4B と 7B: 速度と日本語の質のトレードオフ。このリポジトリの 4B は Gemma、7B は Qwen で **家系が違う**
- Q4 と Q5: 品質と VRAM。Q8 は 8 GB では省略してよい（重みだけで満杯）
- コンテキスト 2K と 8K: KV cache で VRAM が増える。短い入力では decode 速度はほぼ変わらない
- TTFT（最初のトークンまで）と、その後の tok/s は別指標。この llama-cli は一行の tok/s だけなので、ウォームアップ後の Prompt / Generation を使う
- Windows ネイティブとの比較は **必須にしない**。WSL で安定すれば十分
- `temp 0` でも GPU と CPU、Q4 と Q5 で文が一致するとは限らない（logits の末尾で argmax が割れる）

## 固定条件

計測のたびに次を揃える。変えたらメモする。

- プロンプト 2 本（日本語の短い指示、英語の短い指示）。[`../results/05-prompts.md`](../results/05-prompts.md) に本文を固定する
- `-n` / max tokens を固定（128）
- `--temp 0 --top-k 0 --top-p 1.0` / `-s 0`
- 各「モデル × ngl × ctx」の最初の 1 回はウォームアップ（捨てる）

ランタイムは llama.cpp を優先（timings が読める）。繰り返すコマンドは [`../scripts/bench.sh`](../scripts/bench.sh)。

```bash
scripts/bench.sh 7b-q4-ngl99-c2048-ja \
  ~/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf 99 2048 \
  results/05-prompt-ja.txt
```

見る場所: `results/05-raw/<tag>.txt` の `[ Prompt: … | Generation: … ]` と `vram_max_mib`。生成文は `> プロンプト` の次行。

## 手順

すべて Cursor サンドボックス外。計測中は Ollama にモデルを載せない。

### 5-1. 記録テンプレ

[`../results/05-bench.md`](../results/05-bench.md) に、1 行 1 実験で少なくとも次を書く。

- 日時、ランタイムと版、モデル / 量子化、ngl、コンテキスト
- VRAM（生成中ウォッチの最大）、WSL RAM
- prompt eval tok/s、generation tok/s
- 日本語の明らかな崩れ
- 生成文そのもの（軸ごとの比較）

### 5-2. 必須の比較

時間が許す範囲で上から。全部やれなければ、やった番号と省略理由を書く。

1. 4B Q4 vs 7B Q4（GPU 全載せ、コンテキスト 2048）
2. 7B Q4 vs 7B Q5（載る場合のみ。Q5 は公開 GGUF を `~/models` へ。新規ライブラリではない）
3. 7B Q4 の `-ngl 99` vs `-ngl 0`
4. 7B Q4 の `-c 2048` vs `-c 8192`（VRAM が許す場合）

### 5-3. コマンドの控え

[`../scripts/bench.sh`](../scripts/bench.sh)。引数やパスは環境依存なので、実行前に中を読む。

## 合格条件

- [x] 固定プロンプトがファイルに残っている
- [x] 少なくとも「4B vs 7B」または「GPU vs CPU」の 1 軸は数値が揃っている
- [x] 各行に VRAM がある
- [x] 省略した比較には理由がある
- [x] [`../PROGRESS.md`](../PROGRESS.md) を更新した

実施メモ（2026-09-13）:

- 4 軸すべて実施。7B Q5 は 5204 MiB で載った。日本語は Q5 だけ崩れ
- GPU 77.6 tok/s vs CPU 6.0。2K vs 8K は VRAM +342 MiB、文は同一
- Q8 / Windows ネイティブ / Q5-8K は省略
- 詳細: [`../results/05-bench.md`](../results/05-bench.md)

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| 数値が毎回大きく違う | バックグラウンドの GPU 負荷、温度、未ウォームアップ |
| 8K で落ちる | KV cache。必須ではないので省略して記録 |
| 途中から急減速 | フェーズ 3 と同じ mmap / dropcache |

## 成果物

- `results/05-prompts.md`
- `results/05-bench.md`
- `scripts/bench.sh`
- `notes/learn-quantization.html`（量子化の補足）

## 次

完了したら止める。次は [`06-cursor.md`](06-cursor.md)。
