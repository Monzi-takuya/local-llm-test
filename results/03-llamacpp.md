# フェーズ 3: llama.cpp で中身を見る（2026-09-13）

Ollama は「100% GPU / 数十 tok/s」まで見せて、`-ngl` は隠していた。同じクラスの GGUF を llama.cpp で回し、**何層を GPU に置くか**と**コンテキスト長で VRAM が増えるか**を自分で指定して測った。用語の図解は [`../notes/learn-gpu-stack.html`](../notes/learn-gpu-stack.html)。

やらなかったこと: OpenAI 互換 API、本格ベンチ表、Cursor 接続、Ollama blob の変換、CUDA Toolkit、Linux 用 NVIDIA ドライバ、`.wslconfig` 変更。急減速は出なかったので `--no-mmap` も未実施。

## なぜ公式 Linux CUDA バイナリを使わなかったか

GitHub Releases（確認タグ `b10938`、2026-09-13）の CUDA 付き zip は **Windows のみ**（`llama-b10938-bin-win-cuda-13.3-x64.zip`）。Linux は CPU / Vulkan / ROCm / SYCL など。

試した公式 Ubuntu Vulkan 版:

```bash
curl -fL -o /tmp/llama-ubuntu-vulkan.tgz \
  "https://github.com/ggml-org/llama.cpp/releases/download/b10938/llama-b10938-bin-ubuntu-vulkan-x64.tar.gz"
mkdir -p ~/opt/llama.cpp
tar -xzf /tmp/llama-ubuntu-vulkan.tgz -C ~/opt/llama.cpp
export LD_LIBRARY_PATH="$HOME/opt/llama.cpp/llama-b10938"
~/opt/llama.cpp/llama-b10938/llama-cli --list-devices
```

結果: `Available devices: (none)`。WSL には `libcuda.so` はあるが、NVIDIA の Vulkan ICD が無い（`/usr/share/vulkan/icd.d` は intel/radeon/nouveau 等）。

## 実際に使ったバイナリ（CUDA Toolkit なし）

フェーズ 2 で入れた Ollama が、すでに `libggml-cuda.so` と CUDA 13 ランタイムを `/usr/local/lib/ollama/cuda_v13/` に持っている。公式 `llama-cli`（b10938）の隣にそれを symlink した。新規パッケージは追加していない。

```bash
BIN="$HOME/opt/llama.cpp/llama-b10938"
ln -sfn /usr/local/lib/ollama/cuda_v13/libggml-cuda.so "$BIN/libggml-cuda.so"
export LD_LIBRARY_PATH="$BIN:/usr/local/lib/ollama/cuda_v13:/usr/lib/wsl/lib"
"$BIN/llama-cli" --list-devices
```

見る場所: 次の 1 行が出れば RTX 5060 を CUDA デバイスとして認識している。

```text
CUDA0: NVIDIA GeForce RTX 5060 (8150 MiB, 7019 MiB free)
```

コマンド名の正本: `/home/kuos1/opt/llama.cpp/llama-b10938/llama-cli`（PATH には未登録）。以降のコマンドは、上の `export LD_LIBRARY_PATH=...` が前提。

注意: Ollama 側 ggml は 0.22、llama-cli は 0.23。list-devices と今回の生成は通ったが、Ollama 更新で ABI がずれたら再確認する。壊れても CUDA Toolkit ビルドに進む前にユーザへ確認する。

## GGUF（`~/models`、WSL ext4）

Ollama の blob は変換していない。Hugging Face の公開 Q4_K_M を置いた。

```bash
curl -fL -o ~/models/gemma-3-4b-it-Q4_K_M.gguf \
  "https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf"
# 2.4G  gemma-3-4b-it-Q4_K_M.gguf  （Ollama の gemma3:4b と同クラス）

curl -fL -o ~/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf \
  "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf"
# 4.4G  Qwen2.5-7B-Instruct-Q4_K_M.gguf  （Ollama の qwen2.5:7b-instruct と同クラス）
```

フェーズ 1 の token ID 列は渡していない。llama.cpp が各 GGUF 付属の tokenizer で切る。

## 3-1 / 3-2. 4B 起動確認（`-ngl 99`）

なぜ: 7B の前に、短いモデルで「コマンドが GPU に載るか」だけ見る。

```bash
"$BIN/llama-cli" \
  -m ~/models/gemma-3-4b-it-Q4_K_M.gguf \
  -ngl 99 -c 2048 -n 64 -st --no-display-prompt \
  -p "WSLからローカルLLMを動かしたい理由を一文で。"
```

| 見る場所 | 実測 |
| --- | --- |
| 画面下 `Generation:` | **108.6 t/s** |
| `Prompt:` | 1.9 t/s（初回 GPU。カーネル準備込みで遅い） |
| 生成中 `nvidia-smi` Memory-Usage | 最大 **2790 MiB**、Util 最大 82% |
| 日本語 | 1 文で返った |

プロセス欄は WSL では空のまま。VRAM 増 + Generation 速度を正とする。終了直後は VRAM が 0 に戻ることがある（常駐しない）。

## 3-2 / 3-3. 7B：GPU 全載せ vs CPU

なぜ: GPU が見えているだけでは「使っている」とは限らない。同じモデル・同じプロンプト・同じ `-c 2048` で `-ngl` だけ変える。

```bash
# GPU 全載せ（層は実質すべて）
"$BIN/llama-cli" \
  -m ~/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf \
  -ngl 99 -c 2048 -n 64 -st --no-display-prompt \
  -p "WSLからローカルLLMを動かしたい理由を一文で。"

# CPU のみ
"$BIN/llama-cli" \
  -m ~/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf \
  -ngl 0 -c 2048 -n 64 -st --no-display-prompt \
  -p "WSLからローカルLLMを動かしたい理由を一文で。"
```

| | `-ngl 99` | `-ngl 0` |
| --- | --- | --- |
| **Generation (token/s)** | **80.0** | **6.4** |
| Prompt (token/s) | 10.2（この実行は GPU 初回） | 84.2 |
| 生成中 VRAM 最大 | **4544 MiB** | 310 MiB |
| GPU-Util 最大 | **94%** | 29%（モデル非搭載。残負荷） |
| 日本語 | 返った | 返った |

**判定は Generation。** 80 tok/s vs 6.4 tok/s で GPU 全載せが明確に速い（約 12 倍）。フェーズ 2 の「数十 vs 数 token/s」と同じ結論を、レバー付きで再確認した。Blackwell 非対応（見えるが CPU 並み）ではない。

Prompt eval を GPU/CPU 比較に使わない。初回 GPU はカーネル準備で遅く、2 回目以降は跳ねる（次節 733.9 t/s）。短い入力では CPU の prompt の方が速く見えることがある。

Ollama フェーズ 2 の decode 約 68 tok/s と、この 80 tok/s は同オーダー。エンジンが違うので一致は要求しない。

## 3-4. コンテキストと VRAM

なぜ: 重みの VRAM はほぼ固定。KV cache（既に計算した Key/Value を残す領域）が `-c` に比例して増えるはず。

```bash
"$BIN/llama-cli" -m ~/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf \
  -ngl 99 -c 2048 -n 64 -st --no-display-prompt \
  -p "WSLからローカルLLMを動かしたい理由を一文で。"

"$BIN/llama-cli" -m ~/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf \
  -ngl 99 -c 8192 -n 64 -st --no-display-prompt \
  -p "WSLからローカルLLMを動かしたい理由を一文で。"
```

生成中ウォッチ（終了後ではなく実行中）:

| `-c` | VRAM 最大 | Generation |
| --- | --- | --- |
| 2048 | **4544 MiB** | 80.0 t/s |
| 8192 | **4886 MiB** | 79.8 t/s |

差分約 **+342 MiB**（4 倍のコンテキスト）。8GB（8151 MiB）には載ったので 8192 は省略していない。Generation はほぼ同じ。増えるのは主に KV cache で、decode 速度の主役ではない。

8192 の Prompt 733.9 t/s は、直前の GPU 実行でカーネルが温まっていたため。初回の 10.2 t/s と比べて「コンテキストを伸ばすと prompt が速くなる」ではない。

## 3-5. mmap / dropcache

Generation が急減速しなかった（80 tok/s 維持）。`--no-mmap` は未実施。`autoMemoryReclaim=dropcache` もこのフェーズでは触っていない。

## 合格

- [x] CUDA で RTX 5060 を認識（`CUDA0`）
- [x] 7B Q4 で `-ngl 99` が通る（VRAM 4544 MiB / 8GB）
- [x] `-ngl 0` より GPU が明確に速い（80.0 vs 6.4 tok/s）
- [x] prompt eval と generation の token/s を記録した
- [x] `-c 2048` vs `8192` で VRAM が増えた（4544 → 4886 MiB）
- [x] コマンド全文がこのファイルにある
