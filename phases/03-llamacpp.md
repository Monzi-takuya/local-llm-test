# フェーズ 3: llama.cpp で中身を可視化する

Ollama が隠しているパラメータを、同じクラスの GGUF で直接見る。学習の本番。

- 依存: フェーズ 2（GPU パスが生きていること）。フェーズ 0 の cmake
- GPU: 必須
- 所要の目安: バイナリ取得と GGUF ダウンロードが支配的

## なぜ今これか

フェーズ 2 で分かったこと: WSL から RTX 5060 で日本語が出る。`qwen2.5:7b-instruct` は VRAM 約 4.7GB で 100% GPU、decode 約 68 tok/s。Ollama は常駐 HTTP の箱なので、**何層を GPU に置いたか**・**コンテキストを伸ばすと VRAM がどう増えるか**はログに出てこない。

このフェーズで確定すること: 同じ系統の 7B Q4 を llama.cpp で回し、`-ngl`（GPU に載せる層数）と `-c`（コンテキスト長）を自分で変えたときの timings と VRAM。Ollama の「速い」が、Blackwell 対応の GPU 実行なのかを `-ngl 0`（CPU）との差で再証明する。

やらなかったこと（このフェーズでは）: OpenAI 互換 API、本格ベンチの表、Cursor からの接続。それらは 4–6。Ollama の blob を GGUF に変換もしない（レイアウトが内部用で、公開 GGUF を `~/models` に置く方が再現しやすい）。

## 学習で押さえること

- **GPU レイヤー数 (`-ngl`)**: Transformer の何層を VRAM に置くか。`99` は実質すべて。`0` は全部 CPU
- **prompt eval**: 入力トークンをまとめて処理する速度（token/s）。フェーズ 2 の `prompt_eval_duration` に相当
- **token generation**（eval time）: 1 トークンずつ出す速度。フェーズ 2 の decode に相当
- **コンテキスト (`-c`)**: モデルが見られる過去トークンの上限。長いほど **KV cache**（既に計算した Key/Value を GPU に残す領域）で VRAM が増える
- **mmap**: モデルファイルをメモリにマップする読み方。WSL の `autoMemoryReclaim=dropcache` と相性が悪いと急減速することがある → `--no-mmap`

## 導入順（失敗しにくい順）

新規パッケージ（CUDA Toolkit など）は入れる前にユーザへ確認する。このフェーズの本命は llama.cpp の **CUDA 付き公式バイナリ**。Linux 用 NVIDIA ドライバは入れない。

1. GitHub Releases の **CUDA ビルド**（sm_120 / Blackwell を含む新しいタグ）を `~/opt/llama.cpp` などに展開する
2. 動かない、または GPU に落ちないときだけ、CUDA Toolkit 12.8 を WSL に入れてソースビルドを **提案**する  
   `-DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=120`  
   Ubuntu 26.04 で toolkit が入らなければ、このステップは後回しにしてブロック理由を書く
3. PATH に通した実際のコマンド名（`llama-cli` かフルパスか）を `results/03-llamacpp.md` に書く

GGUF は `~/models`（WSL ext4）。`/mnt/c` に置かない。候補はフェーズ 2 と同クラス:

- まず 4B 級 Q4 で起動確認（Ollama の `gemma3:4b` に相当する公開 GGUF）
- 主比較は Qwen2.5-7B-Instruct Q4_K_M（Ollama の `qwen2.5:7b-instruct` と同じクラス。tokenizer はモデル付属のものを使う。フェーズ 1 の ID 列は渡さない）

Hugging Face の GGUF リポジトリから取る。タグとファイル名は取得時に実在を確認して記録する。

## 手順

すべて Cursor サンドボックス外。推論のたびに `nvidia-smi` を別ターミナルで見る。

### 3-1. デバイス確認

なぜ: バイナリが RTX 5060 を CUDA デバイスとして見ているか。見えないのに生成だけ速い、はあり得ない。見えるが後で CPU 並みなら、sm_120 非対応を疑う。

```bash
# 展開後の実パスに置き換える
~/opt/llama.cpp/llama-cli --list-devices
nvidia-smi
```

合格: デバイス一覧に RTX 5060（または CUDA0）がある。

### 3-2. GPU 全オフロード

なぜ: Ollama の「100% GPU」に相当する状態を、自分で `-ngl 99` と指定して再現する。コンテキストはまず 2048（8GB で余裕を見る）。`-n 64` は生成トークン数の上限で、速度計測に十分な短さ。

```bash
llama-cli \
  -m ~/models/<実際のファイル名>.gguf \
  -ngl 99 \
  -c 2048 \
  -n 64 \
  -p "WSLからローカルLLMを動かしたい理由を一文で。"
```

見る場所: 終了付近の timings（`prompt eval` と `eval time` の token/s）。生成中の `nvidia-smi` で VRAM が増え、可能ならプロセス名が llama 系（WSL ではプロセス欄が空のことがある。そのときは VRAM 増 + timings を正とする）。

写す先: [`../results/03-llamacpp.md`](../results/03-llamacpp.md)（コマンド全文、モデルパス、ngl、c、timings、VRAM）。

4B で起動を確認してから 7B に進む。7B が載らなければ 4B の数値で合格とし、載らない理由を書く。

### 3-3. CPU 比較

なぜ: GPU が見えているだけで「使っている」とは限らない。同じモデル・同じプロンプト・同じ `-c` で `-ngl 0` にし、generation が明確に遅いことを見る。フェーズ 2 の「数十 token/s vs 数 token/s」の判定を、レバー付きでやり直す。

```bash
llama-cli \
  -m ~/models/<3-2 と同じファイル>.gguf \
  -ngl 0 \
  -c 2048 \
  -n 64 \
  -p "WSLからローカルLLMを動かしたい理由を一文で。"
```

合格: `-ngl 99` の generation token/s が `-ngl 0` より明確に大きい。差がほぼ無い → バイナリが GPU に乗っていない仮説。新しい CUDA ビルドへ。

### 3-4. コンテキスト

なぜ: 重みの VRAM はほぼ固定、KV cache は `-c` に比例して増える。同じ 7B・`-ngl 99` で短い/長いを 1 回ずつ。

```bash
llama-cli -m ~/models/<7B>.gguf -ngl 99 -c 2048 -n 64 \
  -p "WSLからローカルLLMを動かしたい理由を一文で。"
llama-cli -m ~/models/<7B>.gguf -ngl 99 -c 8192 -n 64 \
  -p "WSLからローカルLLMを動かしたい理由を一文で。"
```

各実行中（または直後）の `nvidia-smi` の Memory-Usage を記録する。8192 で 8GB を超える / 落ちるなら省略し、「8192 は VRAM 不足で未実施」と書く。それでも 2048 の VRAM は残す。

### 3-5. 急減速が出たら

なぜ: `.wslconfig` の `autoMemoryReclaim=dropcache` が、mmap したモデルをホスト RAM から追い出すことがある。GPU の問題に見せかけて、実体はページキャッシュの話。

```bash
llama-cli -m ~/models/<同じ>.gguf -ngl 99 -c 2048 -n 64 --no-mmap \
  -p "WSLからローカルLLMを動かしたい理由を一文で。"
```

まだ遅い / Windows が RAM を欲しがっているなら、reclaim を切る実験は **設定を変える前に** `sample.wslconfig` へ同期する案を出す。勝手にホスト設定は変えない。

## 合格条件

- [ ] llama.cpp 系バイナリが CUDA で RTX 5060 を認識する
- [ ] 7B Q4（無理なら 4B）で `-ngl 99` が通る
- [ ] `-ngl 0` より GPU 実行が明確に速い
- [ ] prompt eval と generation の token/s を記録した
- [ ] コンテキストと VRAM の関係を 1 つ以上記録した（または VRAM 不足で省略した理由）
- [ ] [`../PROGRESS.md`](../PROGRESS.md) を更新した
- [ ] 使ったコマンド全文が [`../results/03-llamacpp.md`](../results/03-llamacpp.md) にある

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| デバイスは見えるが CPU 並みの速度 | sm_120 非対応ビルド。新しい CUDA バイナリへ |
| ソースビルドで nvcc が無い | toolkit 12.8 を入れるかは確認してから。26.04 非対応ならここで止めて記録 |
| CUDA のため Linux ドライバを要求される | 入れない。Windows ドライバ + WSL GPU の経路を維持 |
| OOM / プロセスキル | `-c` を小さく、モデルを 4B に戻す。memory=16GB のままでよいか判断 |

## 成果物

- `results/03-llamacpp.md`（なぜ、コマンド全文、timings、VRAM、ngl 0 との差）
- 任意: 使ったコマンドを後で [`../scripts/bench.sh`](../scripts/bench.sh) に回す（本体はフェーズ 5）

## 次

完了したら止める。次は [`04-openai-api.md`](04-openai-api.md)（llama.cpp または Ollama の口を、アプリから叩ける HTTP にする）。
