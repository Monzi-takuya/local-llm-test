# フェーズ 7: 2026-09 の快適全載せと部分 GPU 上限

フェーズ 0–5 で分かったこと: この RTX 5060 8GB では Qwen2.5-7B Q4 が `-ngl 99` で約 78 tok/s、VRAM 4544 MiB。世代は 2024 末。このフェーズは **日常用（GPU 全載せで快適）** と **上限（部分 GPU）** を同じマシンで確定する。

- 依存: フェーズ 5（固定プロンプトと `scripts/bench.sh`）。llama.cpp b10938 は出発点
- GPU: 必須。計測はサンドボックス外。Ollama にモデルを載せない
- WSL RAM: **24GB 適用済み**（`free -h` で約 23Gi）が前提

## なぜ今これか

7B Q4 は載るが、2026-09 の公式小型は Qwen3.5。9B 全載せが快適なら日常を更新する。余った WSL RAM で公式 27B / 35B-A3B を部分 GPU し、速度が落ちても品質が上がるかを取る。

このフェーズで確定すること:

1. Gated DeltaNet（線形注意。Qwen3.5 系の層）が **CUDA** で動くか
2. パターン A: Qwen3.5-9B Q4 が c 8192・ngl 99 で VRAM **6500 MiB 以下**かつ **50 tok/s 以上**か。だめなら 4B
3. パターン B: Qwen3.8-27B Q4 を ngl 詰め、続けて Qwen3.6-35B-A3B Q4。swap なし
4. 同じ ja/en と品質 3 本で 7B / A / B の文

やらなかったこと: 非公式 distill、ビジョン mmproj、vLLM、WSL 28GB、Cursor Chat、Qwen3.8-Flash-Next。

## 合格線

- **A 快適**: `-ngl 99`、c 8192、VRAM max ≤ 6500 MiB、Generation ≥ 50 tok/s、swap なし
- **B 上限**: VRAM 7000–7800 MiB、swap used が増えない。対話可否の目安は ≥ 8 tok/s（未満は記録のみ）

## 固定条件（速度表）

フェーズ 5 と同じ greedy。プロンプトは [`../results/05-prompts.md`](../results/05-prompts.md)。品質 3 本は [`../results/07-prompts.md`](../results/07-prompts.md)。

```bash
export BENCH_OUTDIR="$PWD/results/07-raw"
scripts/bench.sh <tag> ~/models/<file>.gguf <ngl> <ctx> results/05-prompt-ja.txt
```

見る場所: `results/07-raw/<tag>.txt` の `[ Prompt: … | Generation: … ]`、`vram_max_mib`、生成文、`free -h` の swap。

各「モデル × ngl × ctx」の最初の 1 回はウォームアップ（表に載せない）。

## 手順

すべて Cursor サンドボックス外。

### 7-0. WSL 24GB

`sample.wslconfig` と `%UserProfile%\.wslconfig` が `memory=24GB`。`free -h` の Mem total が約 24Gi。15Gi のままなら `wsl --shutdown` が未実施。

### 7-1. GDN が CUDA か

小さい Qwen3.5 または 9B を `-ngl 99`。Generation が 10 tok/s 未満、または GDN の CPU fallback なら、新しい CUDA ビルドを `~/opt/llama.cpp/` に並列配置（b10938 は残す）。

### 7-2. パターン A

`Qwen3.5-9B-Q4_K_M.gguf` を `~/models`。ngl 99、c 2048 と 8192。線を超えたら 4B Q4（余裕があれば Q6）。

既存 7B Q4 のフェーズ 5 数値をベースラインにする。必要なら 7B を同じ bench.sh で 1 本再測。

### 7-3. パターン B

1. Qwen3.8-27B Q4。`-ngl` を 16, 32, … と上げ、VRAM 7800 MiB 手前で止める
2. その ngl でフェーズ 5 条件
3. Qwen3.6-35B-A3B Q4。MoE なら `--n-cpu-moe`（または当時のフラグ）を 1 軸
4. swap 増または OOM なら 35B 不採用。B は 27B Q4

mmproj は入れない。

### 7-4. 品質プローブ

[`../results/07-prompts.md`](../results/07-prompts.md) の 3 本を A 採用と B 採用と 7B に。think off が正。think on は任意で数問。

### 7-5. 記録

[`../docs/environment.md`](../docs/environment.md) に日常枠と上限枠、WSL 24GB。[`../PROGRESS.md`](../PROGRESS.md) を更新。

## 合格条件

- [x] `free -h` で約 24Gi
- [x] GDN が CUDA
- [x] A の VRAM / tok/s が線に対して合格、または 4B へ降りた理由（9B が線内、4B 不要）
- [x] B の 27B 記録。35B はユーザ指示で取得中止
- [x] 7B / A / B の ja/en と品質 3 本
- [x] environment.md と PROGRESS を更新
- [x] やらなかったことがこのファイルにある

実施メモ（2026-09-13）: 詳細は [`../results/07-best-local.md`](../results/07-best-local.md)。日常は 9B Q4。27B は `-t 12 -ngl 30` で 3.7 tok/s。default スレッドは CPU を満杯にして遅くなる。

## 失敗したとき

| 現象 | まず疑うこと |
| --- | --- |
| 9B が数 tok/s | GDN が CPU。llama.cpp / CUDA so を更新 |
| 8K で 6500 超 | A は 4B。9B は短コンテキスト専用と記録 |
| 27B/35B で swap | 量子化を落とす。WSL 28GB にはしない |
| mmap 急減速 | `--no-mmap`（フェーズ 3 と同じ） |

## 成果物

- `results/07-best-local.md`
- `results/07-prompts.md`
- `results/07-raw/`

## 次

完了したら止める。主戦力は environment.md の 2 枠を見る。
