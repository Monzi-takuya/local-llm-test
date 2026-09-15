# フェーズ 15: Qwen3.5-2B に LoRA SFT（本体）

フェーズ 14 で環境と当て先が確定した。このフェーズで初めて重みを動かす。約 100 件の姓名 JSONL で **LoRA** を足し、held-out 20 件とチャット 3 本を **学習前（フェーズ 13）→ epoch 1 → epoch 3** で比べる。

- 依存: フェーズ 13 の `data/name-split/` と `results/13-name-split.md` の 2b 列、フェーズ 14 の `.venv-train` と `target_modules`
- GPU: 必須。サンドボックス外。`llama-server` は止める
- 先に読む: [`../notes/learn-sft-lora.html`](../notes/learn-sft-lora.html) の 1–6。終わったら 7 を読み直す

## なぜ今これか

**合格は精度表ではない。** 100 件の LoRA で「型・過学習・忘却」のどれが先に出るかを、自分の目で見ることが目的である。

- **型**: 出力が `{"sei":…,"mei":…}` に固定されるか（学習前は説明文やコードフェンスが混ざる）
- **過学習**: train に出した名前は当たるが、held-out は外す
- **破滅的忘却**（catastrophic forgetting）: 特定タスクに寄せた結果、元々できていたこと（挨拶に答える、Python を書く）が崩れる。「こんにちは」が姓名 JSON になる、が典型

三つとも「分布を姓名 JSON 側に寄せた」同じ機構から出る。どれが先に、どの epoch で出るかは実測でしか分からない。

もう一つの本体は **completion-only loss** の確認。学習データはプロンプトと答えを繋いだ 1 本の token 列になる。損失をプロンプト側にも流すと「プロンプトを暗記するモデル」になる。答え側だけに流すための label マスクを、**1 サンプル decode して目で見る**。これが手法確認の中心で、これを見ないなら Unsloth のワンライナーと変わらない。

このフェーズで確定すること:

1. 1 サンプルの `labels` を decode すると、答えの JSON（と EOS）だけが残っている
2. LoRA の学習パラメータ数と、学習中の VRAM ピークが記録されている
3. `results/13-name-split.md` に **adapter 直後**（epoch 1 / epoch 3）の列が足され、型・過学習・忘却のどれが見えたかが実例つきで書いてある

やらなかったこと: 全パラメータ学習、QLoRA、DPO、ハイパーパラメータ探索、9B の学習。

## 用語

- **LoRA**（Low-Rank Adaptation）: 本体の重み `W`（`d_out × d_in`）を凍結し、`W + B·A` の形で小さな `A`（`r × d_in`）と `B`（`d_out × r`）だけを学習する。`r`（rank）が 8 なら、増えるパラメータは `r × (d_in + d_out)` 個。学習後は `B·A` を足し込めば（merge）元と同じ形の 1 枚の重みに戻る
- **alpha**: `B·A` に掛けるスケール `alpha / r`。慣習的に `alpha = 2r`
- **completion-only loss**: 損失を答え側の token だけで計算する。PyTorch では label に `-100` を入れた位置が損失から除外される
- **epoch**: 学習データを 1 周すること。100 件・batch 4 なら 25 step で 1 epoch
- **learning rate（lr）**: 1 step で重みをどれだけ動かすか。LoRA は本体より大きめ（1e-4 〜 2e-4）が慣習

## データの形

`train.jsonl` の 1 行を、**prompt / completion** の 2 欄に変換して `SFTTrainer` に渡す。prompt 側は chat template を通した「assistant の生成開始まで」、completion 側は答えの JSON と EOS。

```python
# prompt: テンプレ込み（<|im_start|>user … <|im_end|>\n<|im_start|>assistant\n まで。空 <think> が入るならそれも含む）
prompt = tok.apply_chat_template(
    [{"role": "user", "content": f"次の日本人の氏名を姓と名に分け、JSON だけを返してください。キーは sei と mei。説明は不要です。\n氏名: {name}"}],
    tokenize=False, add_generation_prompt=True,
)
# completion: 答え + EOS。テンプレの終端トークンで閉じる
completion = json.dumps({"sei": sei, "mei": mei}, ensure_ascii=False) + tok.eos_token
```

プロンプト文はフェーズ 13 の 0-shot と **同じ文** にする。評価時に別の文を使うと、変化が学習のせいかプロンプトのせいか分からなくなる。

**混同ポイント**: Qwen3.5 のテンプレは non-thinking でも空の `<think></think>` を assistant 側に差し込む場合がある（フェーズ 9 で見たもの）。それが prompt 側に入るか completion 側に入るかで損失の範囲が変わる。`apply_chat_template(..., tokenize=False)` を print して、どこまでが prompt かを **文字列で確認** してから進む。

## 実施順

### 1. スクリプト `scripts/train/sft_name_split.py`

引数: `--model`（HF パス）、`--train`、`--out`（adapter 保存先。`~/models/lora/2b-name-split-e{N}`）、`--epochs`、`--rank`、`--alpha`、`--lr`、`--target-modules`（カンマ区切り。フェーズ 14 で決めた名前）、`--max-seq 256`、`--batch 4`、`--seed 0`。

中身の順:

1. tokenizer / model を bf16 で GPU に読む（フェーズ 14 と同じ）
2. `train.jsonl` → prompt / completion の `datasets.Dataset`
3. `peft.LoraConfig(r, lora_alpha, target_modules, lora_dropout=0.05, task_type="CAUSAL_LM")` → `get_peft_model`。`print_trainable_parameters()` を **必ず print**
4. `trl.SFTConfig` で completion-only（trl は prompt / completion 形式なら既定でプロンプト側をマスクする。引数名は版で変わるので `SFTConfig` のドキュメントで `completion_only_loss` 相当を確認し、明示的に True にする）、`max_length`、`per_device_train_batch_size`、`num_train_epochs`、`learning_rate`、`lr_scheduler_type="cosine"`、`warmup_ratio=0.05`、`logging_steps=1`、`bf16=True`、`report_to="none"`
5. **学習前に** `trainer.train_dataset[0]` の `input_ids` と `labels` を取り出し、`labels != -100` の位置だけ decode して print（下の「label 確認」）
6. `trainer.train()`。loss を毎 step ログに残す
7. `model.save_pretrained(out)`（adapter のみ。数十 MB）
8. 学習中の `torch.cuda.max_memory_allocated()` を print

### 2. label 確認（合格条件そのもの）

```bash
source .venv-train/bin/activate
python scripts/train/sft_name_split.py --model ~/models/hf/Qwen3.5-2B \
  --train data/name-split/train.jsonl --out /tmp/dry --epochs 0 --dry-run
```

`--dry-run` は tokenize と label 表示だけして終わるモード。期待する表示:

```text
--- input_ids (decode) ---
<|im_start|>user
次の日本人の氏名を姓と名に分け、JSON だけを返してください。キーは sei と mei。説明は不要です。
氏名: 山田太郎<|im_end|>
<|im_start|>assistant
{"sei":"山田","mei":"太郎"}<|im_end|>
--- labels != -100 (decode) ---
{"sei":"山田","mei":"太郎"}<|im_end|>
--- masked: 4x tokens / total: 6x tokens ---
```

見る場所: 2 つ目のブロックに user の文が **含まれていない** こと。含まれていたら completion-only になっておらず、進めない。EOS（`<|im_end|>`）が labels に含まれていること（含まれないと生成が止まらないモデルになる）。

### 3. 学習（epoch 1 → 3）

同じ seed・同じ設定で epoch 数だけ変えて 2 回。1 回目は短く、2 回目で過学習・忘却が出るかを見る。

```bash
python scripts/train/sft_name_split.py --model ~/models/hf/Qwen3.5-2B \
  --train data/name-split/train.jsonl \
  --out ~/models/lora/2b-name-split-e1 --epochs 1 --rank 8 --alpha 16 --lr 2e-4 \
  --target-modules q_proj,k_proj,v_proj,o_proj,gate_proj,up_proj,down_proj

python scripts/train/sft_name_split.py --model ~/models/hf/Qwen3.5-2B \
  --train data/name-split/train.jsonl \
  --out ~/models/lora/2b-name-split-e3 --epochs 3 --rank 8 --alpha 16 --lr 2e-4 \
  --target-modules q_proj,k_proj,v_proj,o_proj,gate_proj,up_proj,down_proj
```

`--target-modules` はフェーズ 14 の実測名に置き換える。上は典型例で、Gated DeltaNet 層の線形層が別名なら、まず attention / FFN 共通の 7 種だけで 1 回、余力があれば DeltaNet 側も含めて 1 回。

見る場所:

- `trainable params: X || all params: Y || trainable%: Z`。rank 8・7 種なら **全体の 1% 未満** のはず。教材 B の計算と合うか
- 各 step の loss。100 件なら最初 2–3 台から 1 epoch で 1 以下に落ちるのが目安。**0.1 を切ったら暗記が進んでいる**サイン
- `max_memory_allocated`。重み 4 GB + 活性化 + LoRA の optimizer 状態で 5–7 GB の見込み。8GB を超えたら batch 1、`--max-seq 128`、gradient checkpointing の順に削る。**QLoRA には自動で切り替えない**
- 1 epoch の所要時間。数分のはず。10 分を超えるなら CPU に落ちている（`nvidia-smi` の util）

### 4. adapter 直後の評価

GGUF にする前に、`transformers` の `generate` で同じ 20 件 + チャット 3 本を取る。フェーズ 13 の `2b`（学習前）と横に並べる。

`scripts/train/eval_adapter.py`: `--model` と `--adapter`（省略で学習前）、`--probe`、`--chat-prompts`。`PeftModel.from_pretrained` で adapter を載せ、`do_sample=False`、`max_new_tokens 64`。出力の判定（JSON parse / sei 一致 / kind 別）はフェーズ 13 の `name_split_probe.py` と同じ関数を使う（import するか、共通モジュールに切り出す）。

```bash
python scripts/train/eval_adapter.py --model ~/models/hf/Qwen3.5-2B \
  --probe data/name-split/probe.jsonl            # 学習前（bf16。フェーズ 13 の Q4 と並べる）
python scripts/train/eval_adapter.py --model ~/models/hf/Qwen3.5-2B \
  --adapter ~/models/lora/2b-name-split-e1 --probe data/name-split/probe.jsonl
python scripts/train/eval_adapter.py --model ~/models/hf/Qwen3.5-2B \
  --adapter ~/models/lora/2b-name-split-e3 --probe data/name-split/probe.jsonl
```

さらに **train の先頭 20 件** でも同じ評価を取る。held-out との差が過学習の直接の証拠になる。

### 5. 表に写す

`results/13-name-split.md` の 2b 行の右に列を足す。

| 重み | JSON 率 | sei 一致（held-out） | sei 一致（train 20） | q-ja | q-code |
| --- | --- | --- | --- | --- | --- |
| 2b 学習前（Q4、フェーズ 13） | | | | | |
| 2b 学習前（bf16） | | | | | |
| 2b + LoRA e1 | | | | | |
| 2b + LoRA e3 | | | | | |

`results/15-sft.md` には: 設定（rank / alpha / lr / target_modules / seq / batch）、trainable params、loss の推移（step ごと。表か、数字を列挙）、VRAM ピーク、所要時間、そして **見えたもの** を 3 行で（例:「e1 で JSON 率 6/20 → 19/20。held-out sei は 11/20 で train 20 の 19/20 より低い。q-ja は普通に返した」）。

## 合格条件

- [ ] `--dry-run` の labels decode に user 文が無く、JSON と EOS だけが残っている（スクリーンショットか貼り付けを `results/15-sft.md` に）
- [ ] `print_trainable_parameters()` の数字があり、教材 B の手計算と桁が合う
- [ ] e1 / e3 の adapter が `~/models/lora/` にある（git 外）
- [ ] loss の推移と VRAM ピークが記録されている。8GB を超えていない
- [ ] `results/13-name-split.md` に学習前 / e1 / e3 の列があり、held-out と train 20 の両方がある
- [ ] 「型・過学習・忘却」のどれが見えたか（見えなかったか）が実例つきで書いてある
- [ ] QLoRA / Unsloth に切り替えていない。OOM で詰まった場合は現象を書いて質問した

## 失敗したとき

| 現象 | まず疑うこと | 次 |
| --- | --- | --- |
| labels に user 文が残る | prompt / completion 形式になっていない、completion-only の引数名 | trl のドキュメントで版に合う引数を確認。**進めない** |
| `target_modules` が見つからない（peft のエラー） | フェーズ 14 の名前と違う | `named_modules()` を再確認。部分一致の名前を渡す |
| OOM | seq / batch、活性化 | batch 1 → seq 128 → gradient checkpointing。それでも駄目なら質問（QLoRA は人が決める） |
| loss が下がらない（2 台のまま） | lr が小さすぎる、LoRA が当たっていない（trainable 0） | trainable% を見る。lr 2e-4 で動かないなら記録して質問 |
| loss がすぐ 0 近く | 暗記（データが少ないので自然） | 異常ではない。held-out との差を見る本題 |
| 生成が止まらない | EOS が labels に無い | completion の末尾に `eos_token` を付けたか |
| 学習後に日本語が全部 JSON になる | 忘却 | **失敗ではない。観察対象**。件数・epoch を書いて記録 |
| 学習前 bf16 とフェーズ 13 の Q4 で答えが違う | 量子化差 | 異常ではない。両方の列を残す |

## スコープ外

- 全パラメータ FT、QLoRA、DPO / GRPO、Unsloth、Axolotl
- ハイパーパラメータ探索（rank / lr のグリッド）。2 回（e1 / e3）で止める
- 9B / 27B の学習、L4 での学習（詰まったときに人が許可した場合のみ、同じ 2B・同じ JSONL）
- 精度を上げるためのデータ追加

## 成果物

- このファイル
- `scripts/train/sft_name_split.py` / `scripts/train/eval_adapter.py`
- `~/models/lora/2b-name-split-e1` / `-e3`（git 外）
- [`../results/15-sft.md`](../results/15-sft.md)、[`../results/13-name-split.md`](../results/13-name-split.md) の追加列
- [`../notes/learn-sft-lora.html`](../notes/learn-sft-lora.html) 12 節の数字（フェーズ 16 の後にまとめて）
