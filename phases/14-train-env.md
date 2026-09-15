# フェーズ 14: 学習環境と 1 forward（失敗の切り分け専用）

学習の本体はフェーズ 15。このフェーズは **学習をしない**。「Blackwell で PyTorch が動く」「Qwen3.5-2B が bf16 で 8GB に載る」「LoRA を当てる層の名前が分かる」の 3 点だけを確定する。フェーズ 0 と同じ思想で、動かない原因を先に潰す。

- 依存: フェーズ 13 の 2B の学習前の列（無くても環境作りは進められるが、順番は 13 → 14）
- GPU: 必須。サンドボックス外のターミナル。`llama-server` は止めておく（VRAM を空ける）
- 学習: しない。forward 1 回だけ
- 先に読む: [`../notes/learn-sft-lora.html`](../notes/learn-sft-lora.html) の 1–6

## なぜ今これか

このマシンの学習スタックは未検証で、詰まる候補が 3 つある。

1. **RTX 5060 は Blackwell（compute capability 12.0 = sm_120）**。PyTorch は 2.7 以降の CUDA 12.8 ビルドで対応済みだが、古い wheel や cu124 を掴むと「GPU は見えるが kernel が無い」で落ちる（`no kernel image is available`）。llama.cpp で GPU が動いたことは PyTorch の保証にならない
2. **Ubuntu 26.04 に CUDA Toolkit の公式パッケージが無い**（[`../docs/environment.md`](../docs/environment.md) 制約 6）。PyTorch の wheel は CUDA ランタイムを同梱するので Toolkit 無しで動くはずだが、それを実測する
3. **Qwen3.5 は hybrid attention**（一部の層が Gated DeltaNet）で natively multimodal。`transformers` のモデルクラスが text 専用ではない可能性があり、`peft` の既定の `target_modules` が層名と合わないかもしれない

これらを **学習ループの中で** 踏むと、OOM・データ・マスクの問題と混ざって切り分けられない。だから forward 1 回で止める。

このフェーズで確定すること:

1. `.venv-train` で `torch.cuda.get_arch_list()` に `sm_120` が含まれ、GPU でテンソル演算が通る
2. `Qwen/Qwen3.5-2B` が bf16 で GPU に載り、1 forward の VRAM が記録されている
3. `named_modules()` の線形層一覧から、フェーズ 15 の `target_modules` が **名前で** 書けている

やらなかったこと: LoRA の付与、optimizer、bitsandbytes、Unsloth、CUDA Toolkit の導入。

## 用語

- **bf16**（bfloat16）: 16bit の浮動小数。FP16 より指数部が広く、学習で桁あふれしにくい。重み 1 個 2 バイト。2B なら重みだけで約 4 GB
- **forward**: 入力 token 列を層に通して logits を出す計算。推論と同じ。学習ではこの後に **backward**（勾配を逆向きに流す）が足されるが、このフェーズでは forward だけ
- **`named_modules()`**: PyTorch のモデルが持つ部品（層）を「名前 → 部品」で列挙する関数。LoRA は「この名前の線形層に足す」と指定するので、名前を先に知る必要がある

## 実施順

### 1. 別 venv

推論用の `.venv`（openai、Flask）に PyTorch を入れない。学習スタックは重く、依存が衝突しやすい。

```bash
cd ~/dev/local-llm-test
uv venv .venv-train --python 3.12
source .venv-train/bin/activate
python -V
# 合格: 3.12.x（システムの 3.14 ではない）
```

### 2. PyTorch（cu128 以降の wheel）

CUDA Toolkit は入れない。wheel 同梱のランタイムと、Windows 側ドライバ（WSL の `/usr/lib/wsl/lib/libcuda.so`）で動くかを見る。

```bash
uv pip install torch --index-url https://download.pytorch.org/whl/cu128
python - <<'EOF'
import torch
print("torch", torch.__version__)
print("cuda available", torch.cuda.is_available())
print("device", torch.cuda.get_device_name(0))
print("capability", torch.cuda.get_device_capability(0))
print("arch list", torch.cuda.get_arch_list())
x = torch.randn(1024, 1024, device="cuda", dtype=torch.bfloat16)
print("matmul ok", (x @ x).float().sum().item() != 0)
EOF
```

見る場所:

- `capability (12, 0)`、`arch list` に `sm_120`
- `matmul ok True`。ここで `no kernel image` が出たら wheel が古い（cu124 以前）か、index-url を間違えている
- `nvidia-smi` に python プロセスが載る

cu128 の index に目的の torch が無い場合は cu129 / cu130 系の index を試してよい（sm_120 は CUDA 12.8 以降ならどれも含む）。**nightly には行かない**。行くなら質問。

### 3. 学習ライブラリ

```bash
uv pip install transformers peft trl datasets accelerate huggingface_hub
python -c "import transformers, peft, trl; print(transformers.__version__, peft.__version__, trl.__version__)"
```

bitsandbytes は入れない（QLoRA はこの弧の対象外）。Unsloth も入れない。

### 4. モデル取得（safetensors）

学習は Q4 GGUF ではなく **Hugging Face の bf16 重み**を使う。GGUF は推論用の実行形式で、`transformers` は読まない。置き場は `~/models/hf/`（git 外。`.gitignore` に `*.safetensors` はある）。

```bash
mkdir -p ~/models/hf
hf download Qwen/Qwen3.5-2B --local-dir ~/models/hf/Qwen3.5-2B
du -sh ~/models/hf/Qwen3.5-2B
ls ~/models/hf/Qwen3.5-2B
```

見る場所:

- サイズ。2B bf16 なら 4–5 GB 前後。**大きく超えるなら vision tower が同梱**されている（Qwen3.5 は natively multimodal）
- `config.json` の `architectures`。`...ForCausalLM` か `...ForConditionalGeneration` か。後者ならテキスト側だけを読む方法（`AutoModelForCausalLM` で読めるか、text config を取り出すか）を実測して記録する
- `config.json` の `layer_types` や `linear_attn` 系のキー。**どの層が Gated DeltaNet か** がここに書いてあることが多い

公開モデルなので `HF_TOKEN` は不要。ログイン状態をディスクに残さない。

### 5. bf16 で 1 forward

```bash
python - <<'EOF'
import torch, time
from transformers import AutoModelForCausalLM, AutoTokenizer
path = "~/models/hf/Qwen3.5-2B"
import os; path = os.path.expanduser(path)
tok = AutoTokenizer.from_pretrained(path)
model = AutoModelForCausalLM.from_pretrained(path, dtype=torch.bfloat16, device_map="cuda")
model.eval()
print("params (M):", sum(p.numel() for p in model.parameters()) / 1e6)
print("VRAM after load (MiB):", torch.cuda.memory_allocated() / 2**20)
msgs = [{"role": "user", "content": "次の日本人の氏名を姓と名に分け、JSON だけを返してください。キーは sei と mei。\n氏名: 山田太郎"}]
ids = tok.apply_chat_template(msgs, add_generation_prompt=True, return_tensors="pt").to("cuda")
print("prompt tokens:", ids.shape[1])
with torch.no_grad():
    out = model.generate(ids, max_new_tokens=32, do_sample=False)
print(tok.decode(out[0, ids.shape[1]:], skip_special_tokens=True))
print("VRAM peak (MiB):", torch.cuda.max_memory_allocated() / 2**20)
EOF
```

見る場所:

- `params` が約 2000M。大きく違えば vision 込みか、別モデル
- `VRAM after load` が約 4000–4500 MiB。`nvidia-smi` の used はそれより数百 MiB 多い（CUDA コンテキスト）
- `prompt tokens`。フェーズ 1 の「テンプレで 14 → 43」と同じく、生の文字数よりずっと多い。テンプレが空 `<think>` を入れているかは `tok.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True)` を print して確かめる
- 出力が JSON になるか。**フェーズ 13 の `2b` 0-shot と同じ答えになるはず**（Q4 と bf16 の差で 1 トークン変わることはある。それも記録）

### 6. 線形層の名前を列挙する

LoRA の当て先を決めるための本体。

```bash
python - <<'EOF'
import os, torch, collections
from transformers import AutoModelForCausalLM
path = os.path.expanduser("~/models/hf/Qwen3.5-2B")
model = AutoModelForCausalLM.from_pretrained(path, dtype=torch.bfloat16, device_map="cpu")
counts = collections.Counter()
shapes = {}
for name, mod in model.named_modules():
    if isinstance(mod, torch.nn.Linear):
        leaf = name.split(".")[-1]
        counts[leaf] += 1
        shapes.setdefault(leaf, tuple(mod.weight.shape))
for leaf, n in counts.most_common():
    print(f"{leaf:24s} x{n:3d}  weight {shapes[leaf]}")
print()
# 層 0 と、途中の層で構造が違うかを見る
for i in (0, 1, 2, 3):
    print(i, type(model.model.layers[i]).__name__, [n for n, _ in model.model.layers[i].named_children()])
EOF
```

見る場所:

- `q_proj / k_proj / v_proj / o_proj`（通常 attention）と `gate_proj / up_proj / down_proj`（FFN）の個数。全 24 層に attention が無ければ hybrid の証拠
- Gated DeltaNet 層の線形層の名前（`in_proj_*`、`out_proj`、`conv1d` などが候補。実測で確定する）
- `weight` の形（`out × in`）。教材 B の「LoRA で何パラメータ増えるか」の計算に使う。`d_model` はここで読める
- `lm_head` と `embed_tokens` は LoRA の対象にしない（語彙側は動かさない）

この出力を **そのまま** `results/14-train-env.md` に写す。フェーズ 15 の `target_modules` はこの名前から選ぶ。第一候補は「全層に共通する attention / FFN の 7 種」。Gated DeltaNet 側の線形層を含めるかはフェーズ 15 で 2 通り試す余地として残す。

### 7. 片付け

```bash
deactivate
nvidia-smi
# 合格: python が居ない。used が 0 に近い
```

## 合格条件

- [ ] `.venv-train` が Python 3.12 で、`torch.cuda.get_arch_list()` に `sm_120`、bf16 の matmul が GPU で通る
- [ ] `~/models/hf/Qwen3.5-2B` があり、`config.json` の `architectures` と層構成（どの層が Gated DeltaNet か）を記録した
- [ ] bf16 1 forward の VRAM（load 後・peak）と、山田太郎の出力が `results/14-train-env.md` にある
- [ ] 線形層の名前・個数・形の一覧が `results/14-train-env.md` にあり、`target_modules` の第一候補が名前で書いてある
- [ ] CUDA Toolkit、bitsandbytes、Unsloth を入れていない
- [ ] 教材 B（`notes/learn-sft-lora.html`）の 6 節に、この一覧の抜粋を貼った

## 失敗したとき

| 現象 | まず疑うこと | 次 |
| --- | --- | --- |
| `cuda available False` | WSL の `/usr/lib/wsl/lib` が見えていない、Windows ドライバが古い | `nvidia-smi` が通るか。通るなら wheel の CUDA 版を疑う |
| `no kernel image is available` | cu124 以前の wheel、sm_120 が arch list に無い | index-url を cu128 以降に。nightly には行かず質問 |
| `from_pretrained` で未知の architectures | transformers が古い | `uv pip install -U transformers`。それでも無理なら質問（Qwen3-1.7B 退避は人が決める） |
| load 後 VRAM が 6 GB 超 | vision tower 込み、fp32 で読んでいる | `dtype=torch.bfloat16` 確認。text 側だけ読む方法を調べて記録 |
| OOM（forward だけで） | 別の llama-server が VRAM を使っている | `nvidia-smi` で確認して止める |
| 出力がフェーズ 13 の 2b と違う | Q4 と bf16 の差、テンプレの差（GGUF 側と HF 側） | 両方の生テンプレ文字列を並べて記録。異常ではない |

ここで詰まって解けない場合の選択肢は 2 つで、**どちらも人が決める**: (a) L4（`scripts/gcp/start.sh`。同じ 2B・同じ手順。Ada なので sm_120 の問題は消える）、(b) Qwen3-1.7B（素の Transformer）に退避。Agent が自動でどちらにも行かない。

## スコープ外

- LoRA の付与、SFTTrainer、学習ループ（フェーズ 15）
- QLoRA / bitsandbytes / Unsloth / Axolotl
- CUDA Toolkit（`nvcc`）の導入。カスタム kernel のビルド
- 9B / 27B の safetensors 取得

## 成果物

- このファイル
- `.venv-train`（git 外。`.gitignore` に追加）
- `~/models/hf/Qwen3.5-2B`（git 外）
- [`../results/14-train-env.md`](../results/14-train-env.md): バージョン、arch list、VRAM、層一覧、target_modules 候補
- [`../notes/learn-sft-lora.html`](../notes/learn-sft-lora.html) 6 節の層一覧抜粋
