# フェーズ 3: llama.cpp で中身を可視化する

Ollama が隠しているパラメータを、同じクラスの GGUF で直接見る。学習の本番。

- 依存: フェーズ 2（GPU パスが生きていること）。フェーズ 0 の cmake
- GPU: 必須
- 所要の目安: バイナリ取得と GGUF ダウンロードが支配的

## 学習で押さえること

- **GPU レイヤー数 (`-ngl`)**: 何層を VRAM に置くか。`99` は実質すべて
- **prompt eval**: 入力をまとめて処理する速度（token/s）
- **token generation**: 1 トークンずつ出す速度
- **コンテキスト (`-c`)**: 長いほど KV キャッシュで VRAM が増える
- **mmap**: ファイルをメモリにマップする。`dropcache` と相性が悪いことがある → `--no-mmap`

## 導入順（失敗しにくい順）

1. GitHub Releases の **CUDA ビルド**（sm_120 を含む新しいタグ）
2. 動かない / GPU に落ちないときだけ、CUDA Toolkit 12.8 を WSL に入れてソースビルド  
   `-DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=120`  
   Ubuntu 26.04 で toolkit が入らなければ、このステップは後回しにしてブロック理由を書く
3. **Linux 用 NVIDIA ドライバは入れない**

バイナリの置き場所は例えば `~/opt/llama.cpp`。PATH を通したコマンド名をメモする。

GGUF は `~/models` に置く。候補はフェーズ 2 と同クラス:

- まず 4B 級 Q4 で起動確認
- 主比較は Qwen2.5-7B-Instruct Q4_K_M

Hugging Face の GGUF リポジトリから取る。Ollama blob を無理に変換しなくてよい。

## 手順

サンドボックス外。

### 3-1. デバイス確認

```bash
llama-cli --list-devices
# または配布物の同等コマンド
nvidia-smi
```

RTX 5060 が見えること。

### 3-2. GPU 全オフロード

4B または 7B Q4、コンテキストはまず 2048。

```bash
llama-cli -m ~/models/<model>.gguf -ngl 99 -c 2048 -n 64 -p "WSLからローカルLLMを動かしたい理由を一文で。"
```

timings（prompt eval / generation）を [`../results/03-llamacpp.md`](../results/03-llamacpp.md) に写す。生成中の `nvidia-smi` でプロセス名が llama 系になること。

### 3-3. CPU 比較

同じモデル・同じプロンプトで `-ngl 0`。GPU 全載せより明確に遅いこと。ここが Blackwell 非対応（見えるが遅い）の判定にもなる。

### 3-4. コンテキスト

可能なら同じ 7B で `-c 2048` と `-c 8192`。VRAM が増えることを記録する。8 GB を超えるなら 8192 は省略し、その旨を書く。

### 3-5. 急減速が出たら

`autoMemoryReclaim=dropcache` による mmap 追い出しを疑う。

- 一度 `--no-mmap` で再実行
- まだ遅い / Windows が RAM を欲しがっているなら、フェーズ 0 の方針で reclaim を切る実験。設定変更は `sample.wslconfig.txt` に同期

## 合格条件

- [ ] llama.cpp 系バイナリが CUDA で RTX 5060 を認識する
- [ ] 7B Q4（無理なら 4B）で `-ngl 99` が通る
- [ ] `-ngl 0` より GPU 実行が明確に速い
- [ ] prompt eval と generation の token/s を記録した
- [ ] コンテキストと VRAM の関係を 1 つ以上記録した（または VRAM 不足で省略した理由）
- [ ] [`../PROGRESS.md`](../PROGRESS.md) を更新した

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| デバイスは見えるが CPU 並みの速度 | sm_120 非対応ビルド。新しい CUDA バイナリへ |
| ソースビルドで nvcc が無い | toolkit 12.8。26.04 非対応ならここで止めて記録 |
| CUDA のため Linux ドライバを要求される | 入れない。Windows ドライバ + WSL GPU の経路を維持 |
| OOM / プロセスキル | `-c` を小さく、モデルを 4B に戻す。memory=16GB のままでよいか判断 |

## 成果物

- `results/03-llamacpp.md`
- 任意: 使ったコマンドを後で [`../scripts/bench.sh`](../scripts/bench.sh) に回す（本体はフェーズ 5）

## 次

完了したら止める。次は [`04-openai-api.md`](04-openai-api.md)。
