# 実行環境と制約

計画時点（2026-09-13）の実測。フェーズ実行中に変わったら、日付付きで追記する。

## ハードウェア

| 項目 | 値 |
| --- | --- |
| PC | Dell Tower Plus EBT2250 |
| CPU | Intel Core Ultra 7 265（20 コア / 20 スレッド、AVX2） |
| ホスト RAM | 32 GB |
| GPU | NVIDIA GeForce RTX 5060 8 GB（Blackwell, compute capability 12.0） |
| iGPU | Intel Graphics（今回は使わない） |

## WSL2

| 項目 | 値 |
| --- | --- |
| ディストロ | Ubuntu 26.04 LTS |
| カーネル | 6.18.33.2-microsoft-standard-WSL2 |
| systemd | 有効 |
| WSL RAM（実測） | 約 16 GB（`free -h`） |
| swap（実測） | 4 GB |
| Linux ディスク | `/` 約 1 TB 空き |
| GPU パススルー | `/dev/dxg` あり。通常ターミナルでは `nvidia-smi` 成功 |

設定の正本はリポジトリの [`../sample.wslconfig.txt`](../sample.wslconfig.txt)。Windows への適用先は `%UserProfile%\.wslconfig`。変更後は `wsl --shutdown` が必要。

現行の要点:

- `memory=16GB`
- `autoMemoryReclaim=dropcache`
- `networkingMode=mirrored`
- `localhostForwarding=true`
- `coreDump=false`
- `processors` / `swap` は未指定

## ソフトウェア（計画開始時）

未導入: CUDA Toolkit（`nvcc` なし）、cmake、Ollama、llama.cpp。

システム Python は **3.14**。学習用スクリプトは **Python 3.12** を `uv` で別途使う。

## 守る制約

1. **VRAM 8 GB**: 主戦力は 7–8B の Q4_K_M。14B は CPU オフロード前提。32B は対象外。
2. **WSL RAM 16 GB**: 7B を GPU 全載せするなら足りる。CPU オフロード・長コンテキスト・複数モデルで不足し得る。最初から 24 GB には上げない。
3. **モデルは WSL の ext4 に置く**（例: `~/models`）。`/mnt/c` は 9P 経由で遅い。
4. **WSL に Linux 用 NVIDIA ドライバは入れない**。Windows ドライバ +（必要なら）WSL 側 CUDA toolkit のみ。
5. **Blackwell（sm_120）**: 古いバイナリは GPU が見えても CPU に落ちることがある。
6. **Ubuntu 26.04**: CUDA Toolkit 公式パッケージが無い可能性が高い。先に Ollama か llama.cpp 公式 CUDA バイナリで GPU を確認する。
7. **Cursor Agent サンドボックスは GPU をブロックする**。推論・`nvidia-smi` 確認は通常ターミナルで行う。
8. **Cursor Chat はクラウド経由**。`mirrored` でも Cursor サーバから PC の localhost には届かない。

## 推奨モデル

- 最初の成功: Gemma 3 4B Instruct Q4 前後
- 主戦力: Qwen2.5-7B-Instruct Q4_K_M
- 比較用: 同じ 7B の Q5（Q8 は VRAM 不足になりやすい）

## 意図的にやらないこと

- vLLM / PyTorch での非量子化フル推論
- ファインチューニング
- 32B 級、画像マルチモーダルの本格運用
- WSL への NVIDIA Linux ドライバ導入
