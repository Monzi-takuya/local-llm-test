# フェーズ 0: WSL 土台

動かない原因を、モデル導入より先に潰す。このフェーズでは **Ollama も llama.cpp も入れない**。

- 依存: なし（リポジトリ骨格の後）
- GPU: `nvidia-smi` の確認のみ。推論はしない
- 所要の目安: パッケージと Python 3.12 が通れば短い

## 学習で押さえること

- WSL2 の RAM 上限は Windows の `.wslconfig` で決まる。Linux 側の `free` が見える量
- GPU は Windows ドライバ経由（`/dev/dxg`）。WSL に Linux 用 NVIDIA ドライバは入れない
- Cursor Agent のサンドボックスでは `nvidia-smi` が失敗し得る。確認は通常ターミナル

## 前提

- [`../docs/environment.md`](../docs/environment.md) を読む
- WSL 設定のリポジトリ正本は [`../sample.wslconfig.txt`](../sample.wslconfig.txt)
- **メモリは 16GB のまま**。OOM が出てから上げる

残す設定: `networkingMode=mirrored`、`localhostForwarding=true`、`systemd=true`、`coreDump=false`、`autoMemoryReclaim=dropcache`

足してよいが必須ではないもの:

- `swap=8GB`（CPU オフロードやピーク用。常用メモリの代わりにしない）
- `processors=16`（計測の再現性や Windows UI 優先が欲しいとき）
- `memory=20GB` または `22GB`（フェーズ 2 以降で不足が判明してから）

## 手順

### 0-1. 通常ターミナルで現状を記録する

サンドボックス外で実行し、出力を [`../results/00-env.txt`](../results/00-env.txt) に残す。

```bash
date
uname -a
free -h
nproc
nvidia-smi
ls -l /dev/dxg
python3 --version
which nvcc cmake ollama llama-cli 2>/dev/null || true
```

合格の目安: `nvidia-smi` が RTX 5060 8 GB を出す。`free -h` が約 16 GB。

### 0-2. Windows 側の `.wslconfig` を確認する

```bash
ls -la /mnt/c/Users/kuos1/.wslconfig
```

- ファイルが無い: 16 GB は既定値か、別経路の設定。フェーズ 0 では **無理にコピーしない**。変更が必要になった時点で `sample.wslconfig.txt` を `%UserProfile%\.wslconfig` に置き、`wsl --shutdown` する
- ファイルがある: 中身を `sample.wslconfig.txt` と突き合わせ、差分があればメモする

このフェーズで memory を上げない。

### 0-3. ビルドと検証用パッケージ

Ubuntu 26.04 向け。CUDA Toolkit と NVIDIA Linux ドライバは入れない。

```bash
sudo apt update
sudo apt install -y build-essential cmake curl jq git
cmake --version
```

### 0-4. Python 3.12 を uv で用意する

システムの 3.14 は学習スクリプトに使わない。

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# 新しいシェル、またはインストール手順が示す PATH を通す
cd /home/kuos1/dev/local-llm-test
uv python install 3.12
uv venv --python 3.12 .venv
source .venv/bin/activate
python --version   # 3.12.x であること
```

### 0-5. モデル用ディレクトリ

```bash
mkdir -p ~/models
df -h ~ /
```

`~/models` は git 管理外。リポジトリの `models/` にも置かない。

### 0-6. GPU が Windows 側で専有されていないこと

ゲーム・配信・他の CUDA アプリを止める。`nvidia-smi` の Processes が空、または自分の検証プロセスだけならよい。

## 合格条件

- [ ] 通常ターミナルで `nvidia-smi` が RTX 5060 8 GB を表示する
- [ ] `free -h` が約 16 GB（上げていない場合）
- [ ] `cmake` と `curl` と `jq` がある
- [ ] `.venv` の Python が 3.12
- [ ] `~/models` がある
- [ ] [`../results/00-env.txt`](../results/00-env.txt) に記録した
- [ ] [`../PROGRESS.md`](../PROGRESS.md) を更新した

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| `nvidia-smi`: GPU access blocked | Cursor サンドボックス。通常ターミナルで再実行 |
| `nvidia-smi` が無い / dxg が無い | Windows の NVIDIA ドライバ、WSL GPU サポート |
| `uv python install 3.12` 失敗 | ネットワーク、uv の PATH |
| apt で cuda / nvidia-driver を入れたくなる | 入れない。フェーズ 2 の Ollama に進む |

## 成果物

- `.venv/`（git 対象外）
- `results/00-env.txt`
- 必要なら `sample.wslconfig.txt` へのコメント追記のみ

## 次

完了したら止める。次は [`01-pipeline-tokenize.md`](01-pipeline-tokenize.md)（GPU 不要）。
