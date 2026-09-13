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

設定の正本はリポジトリの [`../sample.wslconfig`](../sample.wslconfig)。Windows への適用先は `%UserProfile%\.wslconfig`（拡張子なし）。変更後は `wsl --shutdown` が必要。

2026-09-13 再起動後の要点（適用済み）:

- `memory=16GB`（実測 Mem total 約 15Gi）
- `networkingMode=mirrored`（実測: NAT の `172.26.x` ではなく、LAN の `192.168.40.85` が `eth2` に載っている）
- `maxCrashDumpCount=0`
- `[experimental] autoMemoryReclaim=dropcache`
- `localhostForwarding` / `coreDump` / `[boot] systemd` は `.wslconfig` に無い。systemd は WSL 内 `/etc/wsl.conf`
- `processors` / `swap` は未指定（実測 CPU 20、swap 4GB）

## ソフトウェア（フェーズ 0 完了後）

- cmake 4.1.1 / jq 1.8.1: `~/.local/bin`（`sudo apt` はパスワードが必要だったためユーザ領域に導入）
- uv 0.12.13、リポジトリの `.venv` は **Python 3.12.14**
- システム Python は **3.14.4**（学習スクリプトには使わない）
- `~/models`: `gemma-3-4b-it-Q4_K_M.gguf`（2.4G）、`Qwen2.5-7B-Instruct-Q4_K_M.gguf`（4.4G）、`Qwen2.5-7B-Instruct-Q5_K_M.gguf`（5.1G、フェーズ 5）
- Ollama **0.34.0**（公式 `install.sh`、systemd `ollama.service`）。展開用に **zstd** 1.5.7 を apt で追加。モデル blob は `/usr/share/ollama`
- llama.cpp **b10938** の `llama-cli` / `llama-server`（`~/opt/llama.cpp/llama-b10938`）。Linux 公式 CUDA zip は無いため、Ollama 同梱 `libggml-cuda.so` を symlink。CUDA Toolkit（`nvcc`）は未導入
- `.venv` に **openai 3.13.0**（フェーズ 4 の `scripts/chat_client.py`。クラウド OpenAI には未接続）
- Windows `%UserProfile%\.wslconfig`: **作成済み**（2026-09-13 16:44）。中身は `sample.wslconfig` と一致。以前の `.wslconfig.txt` は使われないため削除済み

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
