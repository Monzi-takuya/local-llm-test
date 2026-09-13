# フェーズ 5: 計測と比較（2026-09-13）

フェーズ 3 は「GPU が CPU より速いか」「`-c` で VRAM が増えるか」を短い `-n 64` で見た。このフェーズは **同じ 2 本のプロンプト**で、サイズ・量子化・ngl・コンテキストを表に揃え、**生成文そのもの**も並べる。

やらなかったこと: Windows ネイティブ比較、Q8、Ollama 経由の再計測、ダッシュボード、CUDA Toolkit。Q5 の `-c 8192` は必須軸ではないので省略（2048 で載ることは確認済み）。

量子化の中身（scale、K-quant、on-the-fly dequant）は [`../notes/learn-quantization.html`](../notes/learn-quantization.html)。

## なぜ今これか

フェーズ 2–4 で分かったこと: 7B Q4 は 8GB に載り、GPU 全載せで約 80 tok/s、API まで通る。ただし条件が実行ごとに少しずつ違う（`-n`、温度、ウォームアップ）。

このフェーズで確定すること: 固定プロンプト・`temp 0`・`-n 128` の下で、(1) 4B vs 7B、(2) Q4 vs Q5、(3) GPU vs CPU、(4) 2K vs 8K の **速度・VRAM・出力文**。

## 固定条件

- ランタイム: llama-cli **b10938**（`~/opt/llama.cpp/llama-b10938`）。`LD_LIBRARY_PATH` はフェーズ 3 と同じ
- プロンプト: [`05-prompts.md`](05-prompts.md)（ja / en）
- `-n 128` / `--temp 0 --top-k 0 --top-p 1.0` / `-s 0` / `-st --no-display-prompt`
- 各「モデルファイル × ngl × ctx」で最初の 1 回はウォームアップ（表に載せない）
- スクリプト: [`../scripts/bench.sh`](../scripts/bench.sh)
- 生ログ: `results/05-raw/<tag>.txt`
- 他の CUDA アプリなし。Ollama はモデル未ロード。計測中 WSL RAM used は **2.0–2.1Gi / 15Gi**
- TTFT のミリ秒はこの llama-cli の一行表示に出ない。代わりにウォームアップ後の Prompt tok/s を載せる。初回 GPU だけ遅い例: Q5 ウォームアップ Prompt **11.5 t/s** → 直後 **671 t/s**

見る場所: ログ末尾の `[ Prompt: … t/s | Generation: … t/s ]` と `vram_max_mib`。生成文は `> プロンプト` の次の行。

## 数値表（ウォームアップ除外）

日時はすべて 2026-09-13。Generation を速度の判定に使う。

| tag | モデル | 量子化 | ngl | ctx | ja Prompt | ja Gen | en Prompt | en Gen | VRAM max | Util max | 日本語崩れ |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `4b-q4-ngl99-c2048-*` | Gemma 3 4B IT | Q4_K_M | 99 | 2048 | 226.7 | **109.2** | 240.8 | **108.3** | **2790** | 86 | なし |
| `7b-q4-ngl99-c2048-*` | Qwen2.5 7B Instruct | Q4_K_M | 99 | 2048 | 687.1 | **77.6** | 647.8 | **78.0** | **4544** | 91 | なし |
| `7b-q5-ngl99-c2048-*` | 同上 | Q5_K_M | 99 | 2048 | 671.2 | **69.1** | 592.7 | **69.4** | **5204** | 92 | **あり（ja）** |
| `7b-q4-ngl0-c2048-*` | 同上 | Q4_K_M | 0 | 2048 | 75.7 | **6.0** | 75.3 | **5.1** | **310** | 38 | なし |
| `7b-q4-ngl99-c8192-*` | 同上 | Q4_K_M | 99 | 8192 | 658.4 | **78.4** | 617.3 | **79.4** | **4886** | 92 | なし |

VRAM 単位 MiB。Generation 単位 tok/s。ファイルサイズ: 4B Q4 2.4G、7B Q4 4.4G、7B Q5 5.1G（`GGUF` マジック確認済み）。

## 検証 1: 4B Q4 vs 7B Q4（GPU 全載せ、c 2048）

なぜ: 速度と日本語の質のトレードオフ。ただし **アーキテクチャが違う**（Gemma 3 4B vs Qwen2.5 7B）。パラメータ数だけの差ではない。

### 速度 / VRAM

| | 4B Q4 | 7B Q4 | 比 |
| --- | --- | --- | --- |
| Generation ja | 109.2 | 77.6 | 4B が約 **1.4 倍** |
| VRAM | 2790 | 4544 | 7B が **+1754 MiB** |

どちらも 8GB に余裕。4B は空きが多い。7B は KV を伸ばす余地がまだある（検証 4）。

### 出力（ja）

**4B Gemma:**

> WSLからローカルLLMを動かすことで、インターネット接続に依存せず、プライバシーを保護しながら、オフライン環境でもLLMの利用や実験が可能になります。

**7B Qwen Q4:**

> ローカルで動作するLLMを使用することで、プライバシー保護とネットワーク遅延を避けることができます。

どちらも日本語として通る。4B は「オフライン / 実験」、7B は「遅延」に寄る。指示どおり一文。崩れなし。

### 出力（en）

**4B:** Quantization reduces the precision of model weights, significantly decreasing the memory footprint required to store them, allowing larger models to fit within a 8GB VRAM limit.

**7B Q4:** Quantization helps 8GB VRAM by reducing the precision of weights in neural networks, thereby decreasing memory usage without significantly compromising model performance, thus allowing more data or larger models to fit within the limited VRAM.

どちらも「重みの精度を落とす → 容量が減る → 8GB に載る」で、ノートの定義と一致。7B は "without significantly compromising" まで足している。

### この軸の結論

速度と VRAM は 4B が軽い。品質はこの 2 本だけでは「7B が上手」とは言い切れない（モデル家系が違う）。主戦力を 7B にする理由は、フェーズ 2–4 で Instruct / tokenizer / API を揃えた連続性。4B は起動確認と空き VRAM 用。

## 検証 2: 7B Q4 vs 7B Q5（GPU 全載せ、c 2048）

なぜ: 同じモデルで bit を増やしたときの VRAM・速度・文面。Q8 は重みだけで 8GB 級なので省略（[`learn-quantization.html`](../notes/learn-quantization.html) の表）。

Q5 は Hugging Face `bartowski/Qwen2.5-7B-Instruct-GGUF` の `Qwen2.5-7B-Instruct-Q5_K_M.gguf`（5.1G）。新規 Python パッケージは無し。

### 速度 / VRAM

| | Q4_K_M | Q5_K_M | 差 |
| --- | --- | --- | --- |
| ファイル | 4.4G | 5.1G | +0.7G |
| VRAM | 4544 | 5204 | **+660 MiB** |
| Generation ja | 77.6 | 69.1 | Q5 が約 **11% 遅い** |
| 8GB に載るか | 載る | 載る（残り約 2.9GB） | Q8 は未実施 |

Q5 が遅いのは、on-the-fly dequant で読む bit が増える（帯域）ため、と読んで矛盾しない。品質のためだけに常に Q5、ではない。

### 出力（ja）— ここが本命の差

**Q4:**

> ローカルで動作するLLMを使用することで、プライバシー保護とネットワーク遅延を避けることができます。

**Q5:**

> ローカルLLMをWSLから動かすことで、 EFFICIENTLY ACCESSING LOCAL AI RESOURCES成为可以在本地高效访问AI资源。

Q5 の日本語は **崩れあり**。英大文字の断片のあと、中国語が続く。同じプロンプト・temp 0・seed 0。

解釈: Q5 が「常に Q4 より賢い」わけではない。重みの近似が違う → logits が少し動く → greedy の **最初のトークンがずれると全文が別物**。N=1 なのでベンチマークスコアではないが、8GB マシンで Q5 を選ぶ理由は「日本語が必ずきれい」ではない。VRAM +660 MiB と 11% 減速の対価として、このプロンプトでは悪化した。

### 出力（en）

**Q4:** …allowing more data or larger models to fit **within** the limited VRAM.

**Q5:** …allowing more data or larger models to fit **into** the limited VRAM.

一文の骨格は同じ。末尾の前置詞だけ違う。英語では argmax が最後までほぼ同じ軌道。

### この軸の結論

このマシンの主戦力は **Q4_K_M のままが妥当**。Q5 は載るが、速度も VRAM も損で、今回の日本語は悪化。Q8 は省略（重みで 8GB を食う）。

## 検証 3: 7B Q4 `-ngl 99` vs `-ngl 0`

なぜ: GPU が見えているだけでは使っているとは限らない。フェーズ 3 の再確認を、固定プロンプトと `-n 128` でやり直す。

### 速度 / VRAM

| | ngl 99 | ngl 0 | 比 |
| --- | --- | --- | --- |
| Generation ja | 77.6 | 6.0 | GPU が約 **13 倍** |
| Generation en | 78.0 | 5.1 | GPU が約 **15 倍** |
| VRAM | 4544 | 310 | CPU は重みを VRAM に載せない |
| Prompt ja | 687.1 | 75.7 | 判定に使わない（短い入力） |

フェーズ 3 の 80.0 vs 6.4（`-n 64`）と同オーダー。Blackwell 非対応（見えるが CPU 並み）ではない。

### 出力（ja）— 同じ重みなのに一致しない

**GPU:** ローカルで動作するLLMを使用することで、プライバシー保護とネットワーク遅延を避けることができます。

**CPU:** ローカルの大型言語モデルを動かすことで、高速な応答とプライバシー保護を実現できます。

どちらも日本語として通るが、**文が違う**。temp 0・seed 0・同じ GGUF。CUDA カーネルと CPU カーネルで浮動小数の加算順が違い、argmax が割れた、が第一仮説。

### 出力（en）

**GPU と CPU は同一文**（Q4 の英語と一致、`within the limited VRAM`）。

英語は最初のトークンから同じ軌道。日本語だけ割れた。品質比較はデバイスを揃える。

### この軸の結論

速度は GPU が明確に速い。出力の同一性は保証されない。ベンチの「同じ答え」を GPU/CPU に期待しない。

## 検証 4: 7B Q4 `-c 2048` vs `-c 8192`（ngl 99）

なぜ: 重みの VRAM はほぼ固定。KV cache がコンテキストに比例して増えるはず。

### 速度 / VRAM

| | 2048 | 8192 | 差 |
| --- | --- | --- | --- |
| VRAM | 4544 | 4886 | **+342 MiB**（フェーズ 3 と同じ） |
| Generation ja | 77.6 | 78.4 | ほぼ同じ |
| Generation en | 78.0 | 79.4 | ほぼ同じ |

入力が短いので、8K の枠を使い切っていない。増えたのは予約された KV 領域。decode 速度の主役ではない。8GB には載ったので省略していない。

### 出力

ja / en とも **2048 の GPU Q4 と完全一致**。コンテキスト上限を広げても、短い 1 ターンでは logits が変わらない（使う KV 長が同じ）。

### この軸の結論

`-c` を 4 倍にしても、この短文では速度も文も変わらず、VRAM だけ +342 MiB。長文を入れる実験はこのフェーズの範囲外。

## 横断

| 仮説 | 今回の証拠 |
| --- | --- |
| 4B は速い・軽い | Gen 109 vs 78、VRAM 2790 vs 4544 |
| Q5 は Q4 より丁寧、とは限らない | ja が Q5 だけ崩壊。en はほぼ同文。VRAM +660、Gen -11% |
| GPU は CPU より桁で速い | 78 vs 6 tok/s |
| GPU と CPU で greedy が一致する | 英語は一致、日本語は不一致 |
| コンテキストを伸ばすと短文でも遅くなる | ならない。VRAM だけ増える |
| Q8 が必要 | 8GB では重みで終端。未実施 |

急減速（mmap / dropcache）は出ていない。`--no-mmap` 未実施。

## 合格

- [x] 固定プロンプトが [`05-prompts.md`](05-prompts.md) にある
- [x] 4B vs 7B と GPU vs CPU の数値が揃っている（Q4 vs Q5、2K vs 8K も実施）
- [x] 各行に VRAM がある
- [x] Q8 と Windows ネイティブと Q5-8K は省略理由あり
- [x] 出力文を軸ごとに比較した
