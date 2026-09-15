# フェーズ 17: Qwen3.5-2B-Base に同じ SFT（任意）

フェーズ 15 は Instruct（事後学習済み）に LoRA を足した。このフェーズは **同じ JSONL・同じ設定** を Base（事前学習のみ）に当て、「指示に従う型」が 100 件でどこまで付くかを見る。フェーズ 9 の問い（Base と Instruct の差は重みか、テンプレか）に、学習側から答える。

- 依存: フェーズ 15 のスクリプト、フェーズ 13 の `2b-base` の学習前の列
- GPU: 必須。サンドボックス外
- 任意。Instruct 側（15 → 16）が閉じてから。時間が無ければやらなくてよい
- 先に読む: [`../notes/learn-llm-basics.html`](../notes/learn-llm-basics.html) の 6（Base と Instruct はどこが違うか）

## なぜ今これか

Instruct は既に「user / assistant の型の続きを書く」分布を持っている。そこに姓名 JSON を足しても、動いたのは「答えの中身の型」だけで、「質問に答える」という習慣は最初からあった。

Base はその習慣が無い。フェーズ 9 と 13 で見たとおり、同じテンプレを付けても続きを書く。ここに同じ 100 件を当てると、次のどれかが見える。

- **型が付く**: held-out でも JSON を返すようになる。100 件で「assistant らしく答える」最小の習慣が付いたということ
- **型が付かない**: train の名前だけ JSON、他は続きを書く。100 件は Instruct 化には足りない、と分かる
- **壊れ方が違う**: チャット 3 本は元から壊れているので「忘却」の見え方が Instruct と違う。q-ja に JSON を返すなら「姓名 JSON しか出せないモデル」になっている

Instruct 側の e1 / e3 と Base 側の e1 / e3 を **同じ表** に並べることで、事後学習が何を足しているのかが、100 件という小さなスケールで手触りになる。

このフェーズで確定すること:

1. 2B-Base に同じ設定で LoRA が当たり、trainable params が Instruct と同じ数になる（重みの形が同じだから）
2. `results/13-name-split.md` の 2b-base 行に、学習前 / e1 / e3 の列が足されている
3. Instruct 側と Base 側の差が 3 行で書いてある

やらなかったこと: Base 用のプロンプト工夫、Base 側の merge → GGUF（見えたら十分。閉じは Instruct 側で済んでいる）、epoch 増し。

## 用語

- **Base**（事前学習のみ）: 大量テキストの次トークン予測だけで作られた重み。「質問に答える」「指示を守る」は学習していないので、入力の続きとして最もありそうな文を書く
- **Instruct**（事後学習済み）: Base に SFT と選好最適化を足し、user / assistant の型で答える分布に寄せたもの。重みの形は Base と同じで、値だけが違う

## 実施順

### 1. Base の safetensors

```bash
source .venv-train/bin/activate
hf download Qwen/Qwen3.5-2B-Base --local-dir ~/models/hf/Qwen3.5-2B-Base
du -sh ~/models/hf/Qwen3.5-2B-Base
```

見る場所: サイズと `config.json` の `architectures` が Instruct と同じであること。tokenizer の `chat_template` が **あるか**。Base にテンプレが載っていない場合、フェーズ 15 の prompt 生成（`apply_chat_template`）は Instruct 側の tokenizer を使うか、同じ文字列を手で組む。どちらにしたかを記録する（Instruct と同じ token 列にしないと比較にならない）。

### 2. 学習前の bf16 評価

```bash
python scripts/train/eval_adapter.py --model ~/models/hf/Qwen3.5-2B-Base \
  --probe data/name-split/probe.jsonl
```

見る場所: フェーズ 13 の `2b-base`（Q4）の列と同じ傾向か。JSON 率がほぼ 0 で、続きを書くはず。

### 3. 学習（フェーズ 15 と同一設定）

```bash
python scripts/train/sft_name_split.py --model ~/models/hf/Qwen3.5-2B-Base \
  --train data/name-split/train.jsonl \
  --out ~/models/lora/2b-base-name-split-e1 --epochs 1 --rank 8 --alpha 16 --lr 2e-4 \
  --target-modules <フェーズ 15 と同じ>

python scripts/train/sft_name_split.py --model ~/models/hf/Qwen3.5-2B-Base \
  --train data/name-split/train.jsonl \
  --out ~/models/lora/2b-base-name-split-e3 --epochs 3 --rank 8 --alpha 16 --lr 2e-4 \
  --target-modules <フェーズ 15 と同じ>
```

`--dry-run` で labels の確認をここでもやる（テンプレの扱いを変えた場合は特に）。

見る場所:

- `trainable params` が Instruct と一致する
- loss の初期値。Base は「assistant の型」自体を知らないので、Instruct より高いところから始まるはず。落ち方の速さも比べる

### 4. 評価と表

```bash
python scripts/train/eval_adapter.py --model ~/models/hf/Qwen3.5-2B-Base \
  --adapter ~/models/lora/2b-base-name-split-e1 --probe data/name-split/probe.jsonl
python scripts/train/eval_adapter.py --model ~/models/hf/Qwen3.5-2B-Base \
  --adapter ~/models/lora/2b-base-name-split-e3 --probe data/name-split/probe.jsonl
```

train の先頭 20 件でも取る。`results/13-name-split.md` に行を足す。

| 重み | JSON 率 | sei 一致（held-out） | sei 一致（train 20） | q-ja | q-code |
| --- | --- | --- | --- | --- | --- |
| 2b-base 学習前（Q4、フェーズ 13） | | | | | |
| 2b-base 学習前（bf16） | | | | | |
| 2b-base + LoRA e1 | | | | | |
| 2b-base + LoRA e3 | | | | | |

見る場所:

- 生成が止まるか。Base は EOS の習慣も弱いので、JSON の後に続きを書き足すことがある。`max_new_tokens 64` の中で `<|im_end|>` を出したかを記録
- q-ja / q-code に何を返すか。Instruct 側の「壊れた / 壊れなかった」と並べる

### 5. まとめ

`results/17-base-sft.md` に: loss の初期値と推移（Instruct と並べる）、上の表の要点、そして **Instruct との差** を 3 行で。例:「Base は e1 で held-out JSON 率 0 → 12/20。train 20 は 18/20。q-ja には JSON を返した（元から答えられないので忘却とは言えない）。Instruct は e1 で 19/20、q-ja は正常」。

## 合格条件

- [ ] `~/models/hf/Qwen3.5-2B-Base` があり、テンプレの扱い（Base にあるか、Instruct のを借りたか）が記録されている
- [ ] `--dry-run` の labels が Instruct 側と同じ範囲（JSON と EOS のみ）
- [ ] trainable params が Instruct 側と一致
- [ ] `results/13-name-split.md` に 2b-base の学習前 / e1 / e3 の列がある
- [ ] Instruct 側との差が実例つきで `results/17-base-sft.md` にある

## 失敗したとき

| 現象 | まず疑うこと | 次 |
| --- | --- | --- |
| Base に `chat_template` が無い | Base の配布は素の tokenizer のことがある | Instruct の tokenizer でテンプレを組む。記録する |
| `Qwen3.5-2B-Base` が HF に無い／名前が違う | 配布名 | HF で確認。無ければこのフェーズは中止して記録 |
| loss が Instruct より高いまま | 正常（型を知らない） | 異常ではない。数字を残す |
| 生成が止まらない | EOS 習慣が弱い | 異常ではない。`<|im_end|>` を出した件数を数える |
| OOM | Instruct と同じ設定なら出ないはず | フェーズ 15 と同じ手順で削る |

## スコープ外

- Base 側の merge → GGUF → serve（必要なら人が言ったとき）
- Base を Instruct 化するための汎用チャットデータの追加
- DPO / GRPO
- 9B-Base の学習

## 成果物

- このファイル
- `~/models/lora/2b-base-name-split-e1` / `-e3`（git 外）
- [`../results/17-base-sft.md`](../results/17-base-sft.md)、[`../results/13-name-split.md`](../results/13-name-split.md) の追加行
