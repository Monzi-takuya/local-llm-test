# フェーズ 5: 固定プロンプト

全実験でこの 2 本だけ使う。変えたら `results/05-bench.md` に書く。

ランタイム共通条件（`scripts/bench.sh`）:

- `-n 128`（生成トークン上限）
- `--temp 0 --top-k 0 --top-p 1.0`（argmax。ばらつきを抑える）
- `-s 0`
- `-st --no-display-prompt`
- 各 **モデルファイル × ngl × コンテキスト** の組み合わせで、最初の 1 回はウォームアップ（数値も出力も比較に使わない）

## ja

```text
WSLからローカルLLMを動かしたい理由を一文で。
```

ファイル: [`05-prompt-ja.txt`](05-prompt-ja.txt)

## en

```text
Summarize in one sentence why quantization helps 8GB VRAM.
```

ファイル: [`05-prompt-en.txt`](05-prompt-en.txt)

フェーズ 1 の tokenizer 用文と同じ系統。英語は量子化の説明を求めているので、Q4 / Q5 の出力比較とノート [`../notes/learn-quantization.html`](../notes/learn-quantization.html) の内容が対応する。
