# フェーズ 2: Ollama で GPU 推論を通す

仕組みより先に、**WSL から RTX 5060 でトークンが出ること**を確定する。Ollama は CUDA を同梱するため、Ubuntu 26.04 でも成功しやすい。

- 依存: フェーズ 0。フェーズ 1 は推奨（chat template のイメージがあるとログが読める）
- GPU: 必須
- 所要の目安: 初回はモデル取得が支配的

## 学習で押さえること

Ollama は「便利な薄いラッパ」である。

- モデルの取得とタグ管理
- llama.cpp 系の推論エンジン
- デフォルトで `localhost:11434` の HTTP

このフェーズでは中の `ngl` までは追わない。それはフェーズ 3。ここでは **VRAM が増え、速度が CPU 並みでないこと**だけを見る。

## 手順

すべて **Cursor サンドボックス外**のターミナルで行う。

### 2-1. インストール

公式の Linux 手順で WSL 内に入れる。Windows 版 Ollama と二重起動しない。

```bash
which ollama || curl -fsSL https://ollama.com/install.sh | sh
ollama --version
```

systemd が有効ならサービス起動を確認する。

```bash
ollama serve   # 既に listen していれば不要
```

### 2-2. 最初の成功（4B 級）

```bash
ollama run gemma3:4b
```

タグが無ければ、同等の小型 Instruct（4B 前後、Q4）に差し替える。名前と実際に pull したタグを [`../results/02-ollama.md`](../results/02-ollama.md) に書く。

別ターミナルで生成中に:

```bash
nvidia-smi
ollama ps
```

見るもの: GPU Memory、GPU-Util、`ollama ps` の PROCESSOR が GPU であること。

短い日本語プロンプトを 1 回投げ、返答が返ること。

### 2-3. 主戦力（7B Instruct）

```bash
ollama run qwen2.5:7b-instruct
```

タグは `ollama show` / ライブラリで実在を確認してから。VRAM に載るか、生成中の `nvidia-smi` を記録する。

8 GB を超えて落ちる / 極端に遅い場合は、より小さい量子化や 4B に戻し、現象をメモしてブロックにする。無理に 14B は入れない。

### 2-4. CPU フォールバック検知

目安（正確なベンチはフェーズ 5）:

- GPU 利用時: 数十 token/s 規模になり得る
- CPU のみ: 数 token/s になりやすい

GPU は見えているのに遅い → Blackwell 非対応バイナリ、ドライバ、他プロセスの専有を疑う。Ollama を上げ直す前に `nvidia-smi` のプロセス一覧を保存する。

### 2-5. モデルの実体

Ollama の blob は Linux ホーム配下に溜まる。`/mnt/c` に移さない。ディスク使用を `du` で一度記録する。

## 合格条件

- [ ] `ollama --version` が通る
- [ ] 4B 級で日本語 1 往復できた
- [ ] 生成中に VRAM 使用が増え、GPU-Util が 0% のままではない
- [ ] 7B Instruct が 8 GB に載るか、載らない理由を書いた
- [ ] 速度が「明らかに CPU のみ」ではない（またはその仮説とログがある）
- [ ] [`../results/02-ollama.md`](../results/02-ollama.md) と [`../PROGRESS.md`](../PROGRESS.md) を更新した

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| GPU access blocked | サンドボックス |
| pull が極端に遅い | ネットワーク。中断して再開可能か確認 |
| ロードで WSL ごと固まる | RAM 16 GB と dropcache / mmap。まずはモデルを小さくする。`.wslconfig` 変更は記録してから |
| Windows 版とポート競合 | 片側を止める。この計画は WSL 側を正とする |

## 成果物

- `results/02-ollama.md`（バージョン、タグ、VRAM、体感速度、日本語の可否）

スクリプトは必須にしない。

## 次

完了したら止める。次は [`03-llamacpp.md`](03-llamacpp.md)。
