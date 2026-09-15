# フェーズ 16: merge → GGUF → いつもの口（閉じ）

フェーズ 15 の adapter は `transformers` の中でしか動かない。このフェーズは LoRA を基モデルに **merge** し、**GGUF** に変換して Q4 に量子化し、フェーズ 4–12 と同じ `llama-server` で同じ 20 件を取る。学習結果が推論の口でも再現することを確定して、この弧を閉じる。

- 依存: フェーズ 15 の adapter（`~/models/lora/2b-name-split-e3`。e1 でもよい。表で「型」が出た方）、フェーズ 14 の `.venv-train`
- GPU: 推論で必須。merge と変換は CPU でもよい
- 先に読む: [`../notes/learn-sft-lora.html`](../notes/learn-sft-lora.html) の 8

## なぜ今これか

学習スタックだけで推論まで済ませると、フェーズ 4–12 で作った口（`serve.sh`、Web UI、`/v1/chat/completions`、IAP の先の L4）と切れる。同じ口に戻すことで「学習前 2b（フェーズ 13）」と「学習後 2b-sft」を **同じサーバ・同じテンプレ・同じ Q4** で並べられる。

もう一つは量子化との関係。LoRA の差分 `B·A` は小さい値の足し込みで、Q4 は重みをブロック単位で荒く丸める（[`../notes/learn-quantization.html`](../notes/learn-quantization.html)）。差分が丸めに埋もれて消える可能性がある。adapter 直後（bf16）と GGUF 化後（Q4）で held-out の傾向が一致するかを見るのが、このフェーズの観察。

このフェーズで確定すること:

1. merge 済み bf16 の safetensors → f16 GGUF → Q4_K_M GGUF の 3 段が通り、各サイズが記録されている
2. `scripts/serve.sh 2b-sft` で起動し、フェーズ 13 と同じ `name_split_probe.py` で 20 件 + チャット 3 本が取れる
3. `results/13-name-split.md` の表が「学習前 Q4 / 学習前 bf16 / adapter e1 / adapter e3 / merge Q4」で完成する

やらなかったこと: imatrix 量子化、Q5 / Q8 の比較、Ollama への登録、L4 への配置。

## 用語

- **merge**: `W' = W + (alpha / r) · B·A` を実際に計算して、元と同じ形の 1 枚の重みにすること。merge 後は adapter ファイルが不要になり、通常のモデルとして保存できる
- **`convert_hf_to_gguf.py`**: llama.cpp 付属の変換スクリプト。safetensors とメタデータ（語彙、テンプレ、アーキテクチャ）を GGUF に書き出す。Python 製なので llama.cpp の **ソース** が要る（`~/opt/llama.cpp/llama-b10938` はバイナリだけ）
- **`llama-quantize`**: f16 / bf16 の GGUF を Q4_K_M などに量子化するバイナリ。b10938 に同梱済み

## 実施順

### 1. merge（`.venv-train`）

```bash
source .venv-train/bin/activate
python - <<'EOF'
import os, torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
base = os.path.expanduser("~/models/hf/Qwen3.5-2B")
adapter = os.path.expanduser("~/models/lora/2b-name-split-e3")
out = os.path.expanduser("~/models/hf/Qwen3.5-2B-name-split-merged")
tok = AutoTokenizer.from_pretrained(base)
model = AutoModelForCausalLM.from_pretrained(base, dtype=torch.bfloat16, device_map="cpu")
model = PeftModel.from_pretrained(model, adapter)
model = model.merge_and_unload()
model.save_pretrained(out, safe_serialization=True)
tok.save_pretrained(out)
print("saved", out)
EOF
du -sh ~/models/hf/Qwen3.5-2B-name-split-merged
ls ~/models/hf/Qwen3.5-2B-name-split-merged
```

見る場所:

- サイズが元の `Qwen3.5-2B` とほぼ同じ（差分は足し込まれたので、ファイルは増えない）
- `config.json` と tokenizer 一式（`tokenizer.json`、`chat_template` を含むファイル）が揃っている。テンプレが落ちると GGUF 側でチャットの型が崩れる
- 元モデルに vision 側の重みが同梱されていた場合、merge 後もそのまま残る。GGUF 変換がそれを扱えるかは次で分かる

merge 後の 1 サンプル確認（任意だが推奨）: merge 済みモデルを bf16 で読み、山田太郎を `generate`。adapter 直後（フェーズ 15）と同じ出力なら merge は正しい。

### 2. llama.cpp のソース（変換スクリプト用）

バイナリと同じ b10938 のソースを取り、Python 依存を `.venv-train` に足す。ビルドはしない。

```bash
mkdir -p ~/opt/llama.cpp/src
cd ~/opt/llama.cpp/src
git clone --depth 1 --branch b10938 https://github.com/ggml-org/llama.cpp.git llama.cpp-b10938
cd llama.cpp-b10938
uv pip install -r requirements/requirements-convert_hf_to_gguf.txt
python convert_hf_to_gguf.py --help | head -20
```

見る場所: `--outtype` に `f16` / `bf16` があること。タグ名が違って clone できなければ、`llama-server --version` の出力から正しいタグを確認する。

### 3. GGUF（f16）

```bash
cd ~/opt/llama.cpp/src/llama.cpp-b10938
python convert_hf_to_gguf.py ~/models/hf/Qwen3.5-2B-name-split-merged \
  --outtype f16 \
  --outfile ~/models/Qwen3.5-2B-name-split-f16.gguf
ls -lh ~/models/Qwen3.5-2B-name-split-f16.gguf
```

見る場所:

- サイズ。2B f16 なら約 4 GB
- ログに `chat_template` を書き込んだ行があるか。無いとサーバ側のテンプレが無くなる
- アーキテクチャが認識されるか（Qwen3.5 は 9B GGUF を llama-server で動かせているので b10938 の変換側も対応しているはず。**未対応エラーなら記録して質問**。新しい b の変換スクリプトを混ぜるかは人が決める）
- multimodal の重みで失敗する場合、text 側だけを書き出すオプションや、mmproj を別に切り出すオプションの有無を `--help` で見る

### 4. Q4_K_M

```bash
export LD_LIBRARY_PATH=$HOME/opt/llama.cpp/llama-b10938:/usr/local/lib/ollama/cuda_v13:/usr/lib/wsl/lib
~/opt/llama.cpp/llama-b10938/llama-quantize \
  ~/models/Qwen3.5-2B-name-split-f16.gguf \
  ~/models/Qwen3.5-2B-name-split-Q4_K_M.gguf Q4_K_M
ls -lh ~/models/Qwen3.5-2B-name-split-Q4_K_M.gguf
```

見る場所:

- サイズがフェーズ 13 で取った公式 2B Q4 GGUF と同程度（1.2–1.6 GB）
- ログの tensor ごとの型。`_M` は層によって Q4 / Q6 が混ざる（[`../notes/learn-quantization.html`](../notes/learn-quantization.html) 4 節）
- Unsloth の公式 Q4 と自分の Q4 は **quantizer と imatrix の有無** が違う。差分の一部はそこから来る。フェーズ 9 で 9B-Base（mradermacher）と 9B（Unsloth）で注意したのと同じ話

### 5. `serve.sh 2b-sft`

`scripts/serve.sh` にプロファイルを足す。フラグは `2b` と同一（`-ngl 99 -c 8192 --reasoning off`）。alias `qwen3.5-2b-sft`。

```bash
scripts/serve.sh 2b-sft
# 別ターミナル
source .venv/bin/activate
python scripts/name_split_probe.py --model qwen3.5-2b-sft --shots 0
python scripts/name_split_probe.py --model qwen3.5-2b-sft --shots 3
```

見る場所:

- 起動ログの `chat template` が読めているか。Web UI で「こんにちは」を 1 本打ち、姓名 JSON になるかどうか（忘却の最終確認）
- `nvidia-smi` の used（2B Q4 なら 2 GB 前後）
- 20 件の JSON 率と sei 一致が、フェーズ 15 の adapter e3 の列と **傾向として一致** するか。1–2 件のずれは Q4 の丸め。10 件ずれるなら merge かテンプレを疑う

### 6. 任意: adapter を GGUF にして `--lora` で足す

merge せず、adapter だけを GGUF にして実行時に足す方式。同じ結果になるか、速度差はあるかを見る。

```bash
cd ~/opt/llama.cpp/src/llama.cpp-b10938
python convert_lora_to_gguf.py ~/models/lora/2b-name-split-e3 \
  --base ~/models/hf/Qwen3.5-2B \
  --outfile ~/models/lora/2b-name-split-e3.gguf
# 学習前の公式 2B Q4 に adapter を足して起動（serve.sh には入れず手で）
~/opt/llama.cpp/llama-b10938/llama-server \
  -m ~/models/Qwen3.5-2B-Q4_K_M.gguf \
  --lora ~/models/lora/2b-name-split-e3.gguf \
  --alias qwen3.5-2b-lora -ngl 99 -c 8192 --reasoning off --webui
```

見る場所: 「Q4 の本体 + bf16 の adapter」なので、merge → Q4 とは丸めの入り方が違う。held-out の結果が merge 版とどう違うか。Gated DeltaNet 層に当てた adapter を llama.cpp 側が読めるかも、ここで分かる（読めなければ記録するだけ。深追いしない）。

### 7. 表を完成させる

`results/13-name-split.md` の 2b 行を完成させる。

| 重み | 形式 | JSON 率 | sei 一致（held-out） | sei 一致（train 20） | q-ja | q-code |
| --- | --- | --- | --- | --- | --- | --- |
| 2b 学習前 | Q4（公式） | | | | | |
| 2b 学習前 | bf16 | | | | | |
| 2b + LoRA e1 | bf16 adapter | | | | | |
| 2b + LoRA e3 | bf16 adapter | | | | | |
| 2b-sft（merge e3） | Q4（自分で量子化） | | | | | |
| 2b + `--lora` e3（任意） | Q4 本体 + adapter | | | | | |

`results/16-merge.md` には各段のファイルサイズ、所要時間、変換ログの要点（テンプレ書き込み、tensor 型）、そして「Q4 で差分は残ったか」を 2–3 行で。

### 8. 片付け

`scripts/serve.sh 9b` で日常に戻せることを確認。f16 GGUF（約 4 GB）は消してよい（Q4 と merge 済み safetensors から再生成できる）。

## 合格条件

- [ ] merge 済み safetensors、f16 GGUF、Q4_K_M GGUF の 3 つがあり、サイズが `results/16-merge.md` にある
- [ ] `scripts/serve.sh 2b-sft` が起動し、Web UI で 1 往復できる
- [ ] `name_split_probe.py` で 2b-sft の 20 件 + チャット 3 本が取れ、`results/13-name-split.md` の表が完成している
- [ ] adapter 直後（bf16）と merge Q4 の held-out の傾向が一致する、または一致しない理由が書いてある
- [ ] `scripts/serve.sh 9b` に戻せる
- [ ] 教材 B（`notes/learn-sft-lora.html`）12 節「この検証の数字」を、フェーズ 14–16 の数字で埋めた

## 失敗したとき

| 現象 | まず疑うこと | 次 |
| --- | --- | --- |
| `merge_and_unload` 後の出力が adapter 直後と違う | alpha / r のスケール、dtype | fp32 で merge してから bf16 に落として比較 |
| 変換スクリプトがアーキテクチャ未対応 | b10938 の変換側が Qwen3.5 を知らない | 記録して質問。新しいタグのソースを使うかは人 |
| 変換が vision 重みで落ちる | multimodal 同梱 | `--help` で text-only 系のオプション。無ければ質問 |
| GGUF に chat template が無い | merge 保存時に tokenizer 一式が欠けた | `tokenizer_config.json` の `chat_template` を確認して再保存 |
| 2b-sft の JSON 率が adapter 直後より大きく低い | Q4 で差分が潰れた、テンプレ差 | f16 GGUF で同じ 20 件を取り、Q4 化前後を分ける（**これも観察結果**） |
| `--lora` が読めない | DeltaNet 層の adapter 未対応 | 記録だけ。merge 版で閉じる |
| port in use / VRAM 不足 | 前のサーバ | Ctrl+C |

## スコープ外

- imatrix 付き量子化、Q5 / Q6 / Q8 との比較
- Ollama への登録（Modelfile）
- L4 への配置（`2b-sft` を IAP 先で動かす必要はない）
- 9B / 27B の merge

## 成果物

- このファイル
- [`../scripts/serve.sh`](../scripts/serve.sh) の `2b-sft`
- `~/models/Qwen3.5-2B-name-split-Q4_K_M.gguf`（git 外）
- [`../results/16-merge.md`](../results/16-merge.md)、[`../results/13-name-split.md`](../results/13-name-split.md) の完成表
- [`../notes/learn-sft-lora.html`](../notes/learn-sft-lora.html) 12 節
