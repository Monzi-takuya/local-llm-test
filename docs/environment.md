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
| WSL RAM（実測） | 約 24 GB（`free -h` で Mem total **23Gi**、2026-09-13 24GB 化後） |
| swap（実測） | 6 GB（24GB 化後。16GB 時は 4GB） |
| Linux ディスク | `/` 約 1 TB 空き |
| GPU パススルー | `/dev/dxg` あり。通常ターミナルでは `nvidia-smi` 成功 |

設定の正本はリポジトリの [`../sample.wslconfig`](../sample.wslconfig)。Windows への適用先は `%UserProfile%\.wslconfig`（拡張子なし）。変更後は `wsl --shutdown` が必要。

2026-09-13 再起動後の要点（適用済み）:

- `memory=16GB`（当時の実測 Mem total 約 15Gi）
- **2026-09-13 夜**: `memory=24GB` に変更。実測 Mem total 約 23Gi。ホスト 32GB のうち Windows 側に約 8GB。28GB 以上にはしない
- `networkingMode=mirrored`（実測: NAT の `172.26.x` ではなく、LAN の `192.168.40.85` が `eth2` に載っている）
- `maxCrashDumpCount=0`
- `[experimental] autoMemoryReclaim=dropcache`
- `localhostForwarding` / `coreDump` / `[boot] systemd` は `.wslconfig` に無い。systemd は WSL 内 `/etc/wsl.conf`
- `processors` / `swap` は未指定（実測 CPU 20。swap は 16GB 時 4GB、24GB 時 6GB）

## ソフトウェア（フェーズ 0 完了後）

- cmake 4.1.1 / jq 1.8.1: `~/.local/bin`（`sudo apt` はパスワードが必要だったためユーザ領域に導入）
- uv 0.12.13、リポジトリの `.venv` は **Python 3.12.14**
- システム Python は **3.14.4**（学習スクリプトには使わない）
- `~/models`: `gemma-3-4b-it-Q4_K_M.gguf`（2.4G）、`Qwen2.5-7B-Instruct-Q4_K_M.gguf`（4.4G）、`Qwen2.5-7B-Instruct-Q5_K_M.gguf`（5.1G、フェーズ 5）、`Qwen3.5-9B-Q4_K_M.gguf`（5.3G、フェーズ 7 日常、unsloth）、`Qwen3.5-9B-Base.Q4_K_M.gguf`（約 5.3G、フェーズ 9 研究、mradermacher）、`Qwen3.8-27B-UD-Q4_K_M.gguf`（16G、フェーズ 7 上限）
- Ollama **0.34.0**（公式 `install.sh`、systemd `ollama.service`）。展開用に **zstd** 1.5.7 を apt で追加。モデル blob は `/usr/share/ollama`
- llama.cpp **b10938** の `llama-cli` / `llama-server`（`~/opt/llama.cpp/llama-b10938`）。Linux 公式 CUDA zip は無いため、Ollama 同梱 `libggml-cuda.so` を symlink。CUDA Toolkit（`nvcc`）は未導入
- `.venv` に **openai 3.13.0**（フェーズ 4 の `scripts/chat_client.py`。クラウド OpenAI には未接続）
- Windows `%UserProfile%\.wslconfig`: **作成済み**（2026-09-13 16:44）。中身は `sample.wslconfig` と一致。以前の `.wslconfig.txt` は使われないため削除済み

## 守る制約

1. **VRAM 8 GB**: 日常は 9B Q4 全載せ。27B は `-ngl 30` 程度の部分 GPU（VRAM 約 7714 MiB）。ngl を 32 以上にすると 7880 で頭打ちし decode が落ちる。
2. **WSL RAM 24 GB**（2026-09-13 夜から）: 27B Q4（16G）の CPU 側重み用。ホスト 32GB なので 28GB 以上にはしない。35B-A3B は未実施。
3. **モデルは WSL の ext4 に置く**（例: `~/models`）。`/mnt/c` は 9P 経由で遅い。
4. **WSL に Linux 用 NVIDIA ドライバは入れない**。Windows ドライバ +（必要なら）WSL 側 CUDA toolkit のみ。
5. **Blackwell（sm_120）**: 古いバイナリは GPU が見えても CPU に落ちることがある。
6. **Ubuntu 26.04**: CUDA Toolkit 公式パッケージが無い可能性が高い。先に Ollama か llama.cpp 公式 CUDA バイナリで GPU を確認する。
7. **Cursor Agent サンドボックスは GPU をブロックする**。推論・`nvidia-smi` 確認は通常ターミナルで行う。
8. **Cursor Chat はクラウド経由**。`mirrored` でも Cursor サーバから PC の localhost には届かない。

## 推奨モデル

- 最初の成功: Gemma 3 4B Instruct Q4 前後
- **日常**: Qwen3.5-9B Q4_K_M、`-ngl 99`、c 8192 まで。VRAM 5400 MiB、Gen 約 66 tok/s。`--reasoning off`
- **研究**: Qwen3.5-9B-Base Q4_K_M（mradermacher）。同じ ngl / ctx。チャット相手ではない。`scripts/serve.sh 9b-base`
- **上限（低速）**: Qwen3.8-27B UD-Q4_K_M、`-ngl 30 -t 12 -tb 12`、c 2048。VRAM 7714 MiB、Gen 約 3.7 tok/s。チャット日常には使わない
- ベースライン: Qwen2.5-7B-Instruct Q4_K_M（フェーズ 5。日本語指示で中国語に寄ることがある）
- 比較用: 同じ 7B の Q5（Q8 は VRAM 不足になりやすい）

## Google Cloud（27B 全載せ、2026-09-14）

ローカル 27B は部分 GPU で 3.7 tok/s。対話速度にするなら GCP の **L4 24GB / `g2-standard-8`（東京）**。T4 16GB は 27B Q4 に足りない。

実測（プロジェクト `monzi-sandbox`、gcloud JSON）: 東京 a/b/c に `nvidia-l4` あり。地域 `NVIDIA_L4_GPUS=1`。2026-09-14 夜に **`GPUS_ALL_REGIONS=1`**（申請が約 1 分で承認）。GPU VM は未作成。詳細 [`../results/10-gcp-27b.md`](../results/10-gcp-27b.md)。

9B 日常をクラウドに載せる理由は薄い（ローカル 66 tok/s の方が速く、限界費用は電気）。

## 意図的にやらないこと

- vLLM / PyTorch での非量子化フル推論
- ファインチューニング
- 32B 級、画像マルチモーダルの本格運用
- WSL への NVIDIA Linux ドライバ導入
