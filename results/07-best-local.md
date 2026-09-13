# フェーズ 7: 快適全載せと部分 GPU（2026-09-13）

フェーズ 5 の主戦力は Qwen2.5-7B Q4（Gen 78 tok/s、VRAM 4544 MiB）。このフェーズは **日常（GPU 全載せ）** と **上限（部分 GPU）** を同じ RTX 5060 8GB で確定する。

35B-A3B のダウンロードはユーザ指示で中止。上限のチューニングは 27B に集中した。

## なぜ今これか

7B は載るが世代が古い。2026-09 の公式小型は Qwen3.5。9B が快適なら日常を更新する。余った WSL RAM（24GB）で公式 27B を部分 GPU し、スレッド数まで含めて「載るが遅いか」を数値にする。

やらなかったこと: 非公式 distill、ビジョン mmproj、vLLM、WSL 28GB、Cursor Chat、Qwen3.8-Flash-Next、35B-A3B（取得開始後に中止）。

## 7-0. WSL 24GB

| 場所 | 値 |
| --- | --- |
| `sample.wslconfig` | `memory=24GB` |
| `%UserProfile%\.wslconfig` | 同じ |
| `free -h` Mem total | **23Gi**（適用済み） |
| Swap | 6.0Gi（used は 27B 時に約 126Mi。mmap の端。available は約 21Gi） |

見る場所: `free -h` の total。15Gi のままだと未再起動。

## 7-1. GDN は CUDA

`llama-cli` b10938 + Ollama CUDA so。Qwen3.5-9B `-ngl 99` の Generation は **65 tok/s**（CPU ならフェーズ 5 の 6 tok/s 級）。CPU fallback ではない。

`--reasoning off` を付けないと thinking が 128 トークンを食う。速度表はすべて off。

## パターン A（快適）: Qwen3.5-9B Q4

ファイル: `~/models/Qwen3.5-9B-Q4_K_M.gguf`（5.3G、unsloth）。`-ngl 99`、`--reasoning off`。

| tag | ctx | ja Prompt | ja Gen | en Prompt | en Gen | VRAM max |
| --- | --- | --- | --- | --- | --- | --- |
| `9b-q4-ngl99-c2048-*` | 2048 | 186.8 | **65.4** | 190.0 | **65.0** | **5202** |
| `9b-q4-ngl99-c8192-*` | 8192 | 188.7 | **65.9** | 194.7 | **65.6** | **5400** |

合格線: c 8192 で VRAM ≤ 6500、Gen ≥ 50。両方クリア。4B には降りない。

既存 7B Q4（フェーズ 5、c 2048）: Gen 77.6、VRAM 4544。9B は約 **16% 遅い**が、VRAM は 7B Q5（5204）と同じ帯。8K でも 5400 で余裕。

### A の出力（ja）

> WSL からローカル LLM を動かす主な理由は、Windows 上で高機能な Linux 環境を維持しつつ、個人データや機密情報を外部サーバーに送信せず、プライバシーとセキュリティを確保しながらオフラインでも高品質な AI 推論が可能になる点にあります。

7B Q4（フェーズ 5）: 「プライバシー保護とネットワーク遅延」。9B は一文が長いが崩れなし。

### A の出力（en）

Quantization helps 8GB VRAM by compressing model weights into lower precision formats… ノートの定義と一致。

## CPU は遊んでいたか（27B 部分 GPU）

仮説: 全体の CPU% が低い → スレッド不足。

実測（27B、`-ngl 28`、WSL 内 `/proc/stat` + `ps`）:

| `-t` / `-tb` | WSL 全体 CPU max | llama `%CPU`（ps、コア合算） | スレッド数 | Gen tok/s |
| --- | --- | --- | --- | --- |
| 省略（default ≈ 全コア） | **100%** | ~1300 | 46–47 | **1.8** |
| 20 / 20 | **100%** | ~1500 | 46 | **1.9** |
| 8 / 8 | 45% | ~620 | 34 | **3.1** |
| 10 / 10 | （後述スイープ） | | | **3.6** |
| 12 / 12 | | | | **3.6** |

結論: **コアは足りていた。使いすぎていた。** Ultra 7 265 は 8P+12E・HT なし。default / `-t 20` は RAM 帯域で奪い合い、decode が遅くなる。Windows の全体 CPU が低く見えても、WSL 側では default 時にほぼ満杯。9B 全載せ中に CPU が低いのは正常（GPU 待ち）。

見る場所: 推論中の WSL で `mpstat 1`。Task Manager の「全体」だけでは WSL のコア飽和を見落とす。

## パターン B（上限）: Qwen3.8-27B UD-Q4_K_M

ファイル: `~/models/Qwen3.8-27B-UD-Q4_K_M.gguf`（16G、unsloth。標準名 `Q4_K_M` は無く UD 版）。mmproj なし。

ngl を上げすぎると VRAM が 7880 で頭打ちし、**decode が落ちる**（GPU 満杯で KV/バッファが圧迫）。

| ngl | `-t`12 | VRAM | Prompt | Gen |
| --- | --- | --- | --- | --- |
| 24 | 12 | 6416 | 19.5 | 3.5 |
| 28 | 12 | 7292 | 21.1 | 3.6 |
| **30** | **12** | **7714** | **21.7** | **3.7** |
| 32 | 12 | 7880 | 17.2 | 2.9 |
| 34 | 12 | 7880 | 17.6 | 2.5 |

採用: **`-ngl 30 -t 12 -tb 12 --reasoning off -c 2048`**。VRAM 7714（線 7000–7800 の中）。flash-attn on は 3.6 で差なし。`-tb` を 16 にしても decode は伸びない。

c 8192 / ngl 30 は VRAM **7870**（線の上限超えぎみ）、短い `-n 16` では Gen 4.1。日常の上限枠は c 2048 を正とする。

固定プロンプト・n 128（ウォームアップ除外）:

| tag | ja Prompt | ja Gen | en Prompt | en Gen | VRAM |
| --- | --- | --- | --- | --- | --- |
| `27b-q4-ngl30-t12-c2048-*` | 21.7 | **3.7** | 21.6 | **3.7** | **7714** |

対話の目安 8 tok/s は未達。**載るが日常のチャットには使わない。** 品質プローブ用・重い 1 問用。

GPU util max は 33–86%。CPU 層待ちなので 100% に張り付かない。これも「GPU が遊んでいる」ではなく **dense 27B の残り層が RAM 帯域律速**。

### B の出力（ja）

> Windows環境のままLinuxのツールチェーンやGPUドライバをネイティブに活用し、開発・学習・推論のワークフローをシームレスに統合できるため。

一文。崩れなし。GPU ドライバを WSL が「ネイティブ」と言っている点は事実として雑。

## 品質 3 本（think off、n 128）

| | 7B Q4 | 9B Q4（A） | 27B Q4 ngl30（B） |
| --- | --- | --- | --- |
| q-ja 敬語メール | **中国語**（「关于交货期延迟的歉意」） | 日本語。プレースホルダ（〇〇）で n=128 切れ | **日本語で完結** |
| q-code palindrome | 関数本体は正しいが `def` 行が欠け | 同じ欠け | 同じ欠け（`-p` 生文で chat テンプレ無し） |
| q-json | markdown の \`\`\`json 付き | **配列だけ** | 配列（整形あり） |

7B の日本語指示無視は、日常を 9B に替える主因。27B のメールは 9B より短い制約で最後まで書けた。速度は 9B の約 **1/18**。

## 採用

- **日常**: Qwen3.5-9B Q4_K_M、`-ngl 99`、c 8192 まで可、`--reasoning off`
- **上限（低速）**: Qwen3.8-27B UD-Q4_K_M、`-ngl 30 -t 12 -tb 12`、c 2048
- 既存 7B Q4 はベースラインとして残す

コマンド（B）:

```bash
export LD_LIBRARY_PATH="$HOME/opt/llama.cpp/llama-b10938:/usr/local/lib/ollama/cuda_v13:/usr/lib/wsl/lib"
export LLAMA_EXTRA='--reasoning off -t 12 -tb 12'
scripts/bench.sh 27b-q4-ngl30-t12-c2048-ja \
  ~/models/Qwen3.8-27B-UD-Q4_K_M.gguf 30 2048 \
  results/05-prompt-ja.txt
```

A は `LLAMA_EXTRA='--reasoning off'`、ngl 99、同じ bench.sh。`BENCH_OUTDIR=results/07-raw`。

## 合格

- [x] WSL 約 24Gi
- [x] GDN が CUDA（9B 65 tok/s）
- [x] A が線内（5400 MiB / 66 tok/s）。4B 不要
- [x] B の 27B: ngl 30、VRAM 7714、3.7 tok/s。スレッド過不足を実測
- [ ] 35B-A3B: **中止**（ユーザ指示）
- [x] 7B / A / B の ja/en と品質 3 本
- [x] やらなかったことをこのファイルに書いた
