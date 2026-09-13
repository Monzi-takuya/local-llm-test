# フェーズ 2: Ollama GPU 確認（2026-09-13）

WSL 内の常駐サーバ `ollama serve`（`127.0.0.1:11434`）経由で、Gemma / Qwen が **各自の tokenizer** で ID を切り、RTX 5060 上で生成した。フェーズ 1 の ID 列は渡していない。

## インストール

| 項目 | 値 |
| --- | --- |
| Ollama | 0.34.0（`/usr/local/bin/ollama`） |
| 入れ方 | 公式 `install.sh`（sudo）。展開に **zstd** 1.5.7 が必要だったので `apt-get install zstd` のみ追加 |
| 常駐 | `ollama.service` enabled / active。`ExecStart=/usr/local/bin/ollama serve`、User=`ollama` |
| Windows 版 | 未導入。11434 の競合なし |
| GPU 検出 | `library=CUDA` / RTX 5060 / compute 12.0 / driver 13.3 / total 8.0 GiB |

zstd は推論ライブラリではなく、配布アーカイブ `.tar.zst` の伸長ツール。CUDA Toolkit（`nvcc`）は入れてない。Ollama 同梱の CUDA で足りた。

### 打ったコマンド

```bash
sudo apt-get install zstd
curl -fsSL https://ollama.com/install.sh | sh
ollama --version
systemctl is-active ollama
```

```bash
ollama pull gemma3:4b
ollama show gemma3:4b
ollama pull qwen2.5:7b-instruct
ollama show qwen2.5:7b-instruct
ollama list
```

生成（フェーズ 1 の token ID は渡していない。文字列だけ）:

```bash
curl -sS http://127.0.0.1:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"model":"gemma3:4b","prompt":"WSLからローカルLLMを動かしたい。日本語で3文だけ、短く答えて。","stream":false}'

curl -sS http://127.0.0.1:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5:7b-instruct","prompt":"WSLからローカルLLMを動かしたい。日本語で4文、短く答えて。","stream":false}'
```

生成中ウォッチ:

```bash
nvidia-smi --query-gpu=memory.used,utilization.gpu,power.draw --format=csv,noheader
ollama ps
```

## モデル

| タグ | パラメータ | 量子化 | `ollama list` サイズ | 実測 VRAM | PROCESSOR |
| --- | --- | --- | --- | --- | --- |
| `gemma3:4b` | 4.3B | Q4_K_M | 3.3 GB | 3762–3764 MiB | 100% GPU |
| `qwen2.5:7b-instruct` | 7.6B | Q4_K_M | 4.7 GB | 4658 MiB / 8151 MiB | 100% GPU |

7B は 8GB に載った。CPU オフロードは出ていない。

blob の実体はサービスユーザのホーム `/usr/share/ollama`（このユーザからは permission denied）。`/mnt/c` には置いていない。`du` は sudo が要るので未実施。`ollama list` 上は 3.3 + 4.7 GB。

## 日本語 1 往復

どちらも `POST /api/generate`、`stream: false`。プロンプトは「WSLからローカルLLMを動かしたい。」系の短文。

- **gemma3:4b**: 日本語 3 文が返った（内容は一般的な手順説明）
- **qwen2.5:7b-instruct**: 日本語 3 文が返った

Qwen 応答の `context` にフェーズ 1 と同じ特殊トークン ID（`151644` `<|im_start|>` など）が見える。渡したのは文字列で、**サーバ側が Qwen 用 tokenizer で切り直した結果**がそこに載っている。Gemma の `context` は別語彙（例: `105`, `2430`）で、ID の互換はない。

## 速度（decode）

| モデル | eval_count | eval_duration | tok/s | load | prompt_eval |
| --- | --- | --- | --- | --- | --- |
| gemma3:4b | 57 | 1.42 s | **40.2** | 25.2 s（初回） | 12.9 s / 33 tok |
| qwen2.5:7b-instruct | 50 | 0.74 s | **67.6** | 9.7 s | 4.9 s / 54 tok |

目安どおり「数十 token/s」で、数 token/s の CPU のみではない。初回の load / prompt_eval はカーネル準備込みで遅い。decode を GPU 判定に使う。

## GPU ログ

生成直後の `nvidia-smi`:

- gemma3:4b: 3764 MiB、GPU-Util **75%**、63 W
- qwen2.5:7b-instruct: 4658 MiB、GPU-Util **72%**（ウォッチ中のピーク **99%**）、58 W

ウォッチ中も VRAM は 0 → モデルサイズまで増加。アイドル時は Util 0% のまま VRAM だけ残る（重みは載っているが、生成していない）。

WSL の `nvidia-smi` プロセス欄は空のまま（VRAM は増えている）。専有の確認は `ollama ps` の PROCESSOR を正とする。

## 合格

- [x] `ollama --version`（0.34.0）
- [x] 4B 級の日本語 1 往復
- [x] 生成中に VRAM 増、Util が 0% のままではない
- [x] 7B Instruct が 8GB に載った（4658 MiB、100% GPU）
- [x] decode が CPU のみの速度ではない
