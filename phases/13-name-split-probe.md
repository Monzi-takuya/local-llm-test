# フェーズ 13: 姓名分割の学習なしベースライン（プローブ）

フェーズ 0–12 で推論の口は閉じた。ここから **事後学習の弧**（13 → 14 → 15 → 16 → 17）に入る。このフェーズは学習をしない。「SFT する前に、プロンプトだけでどこまで型が出せるか」を固定 20 件で確定し、あとのフェーズが列を足していく **比較の基準表** を作る。

- 依存: フェーズ 8 の `scripts/serve.sh`、フェーズ 7 の 9B Q4、フェーズ 9 の 9B-Base Q4
- GPU: 必須（推論）。サンドボックス外のターミナル。8GB では同時に 1 モデルだけ
- 学習: しない。PyTorch も入れない（フェーズ 14）
- 先に読む: [`../notes/learn-llm-basics.html`](../notes/learn-llm-basics.html)（Base と Instruct はどこが違うか）

## なぜ今これか

**SFT**（Supervised Fine-Tuning）は、入力と望ましい出力の対を見せて次トークン予測の損失を下げる事後学習である。フェーズ 15 でこれをやるが、学習前の出力を同じ条件で取っておかないと「LoRA で変わった」と言えない。before が無い after は観察にならない。

題材は **姓名分割**。スペース無しの「山田太郎」を `{"sei":"山田","mei":"太郎"}` に切る。出力が短く、当たり外れが目で分かり、JSON の型が守れたかも機械で判定できる。本番の正解器は LLM ではなく辞書＋統計（namedivider など）で、**精度で辞書に勝つことは目的にしない**。小さいモデルに小さいデータで LoRA を足したとき、出力がどう動くかを見るための題材である。

もう一つの狙いは、フェーズ 9 の続き。9B-Base は「指示を守らず続きを書く」ことを見たが、記録が薄い。同じ 20 件を 9B / 9B-Base / 2B / 2B-Base の 4 重みで取り、**Base と Instruct の差** を数字と実例で残す。フェーズ 17（2B-Base に SFT）の before にもなる。

このフェーズで確定すること:

1. 手書きデータ `data/name-split/` が 3 ファイル揃い、held-out と train に重複が無い
2. 4 重み × 2 プロンプト方式（0-shot / 3-shot）の JSON 率・姓一致・チャット 3 本の壊れが `results/13-name-split.md` の 1 表にある
3. 2B-Instruct の学習前の列が「フェーズ 15 の before」として使える

やらなかったこと: 学習、精度のチューニング、実名データ、namedivider との比較表。

## データ設計

すべて **架空名**。公開の住民名簿、namedivider の苗字 pickle、実在人物のリストは使わない。件数は精度のためではなく「型・過学習・忘却」を見るのに足りる最小。

| ファイル | 件数 | 用途 |
| --- | --- | --- |
| `data/name-split/train.jsonl` | 約 100 | フェーズ 15 の学習データ |
| `data/name-split/heldout.jsonl` | 20 | 学習に出さない。過学習の検出用 |
| `data/name-split/probe.jsonl` | 20 | 全フェーズ共通の観察セット。**heldout と同じ 20 件**（`train` には無い） |

`probe.jsonl` と `heldout.jsonl` を分けているのは役割の名前を分けるためで、中身は同じ 20 件でよい。学習後に「train の名前は当たるが probe は外す」が見えれば過学習の観察になる。

1 行の形（JSONL。1 行 1 JSON）:

```json
{"name": "山田太郎", "sei": "山田", "mei": "太郎", "kind": "kanji-2-2"}
```

`kind` は集計用のタグ。次の分布で書く。

| kind | 例（架空） | 意図 |
| --- | --- | --- |
| `kanji-2-2` | 山田太郎、高橋美咲 | いちばん多い型。半分程度 |
| `kanji-1-x` | 森健太、林美咲 | 1 文字姓。「森健」と切る誤りが出やすい |
| `kanji-3-x` | 佐々木翔、長谷川陸 | 3 文字姓。「佐々」で切る誤りが出やすい |
| `kanji-x-1` | 田中翔、鈴木蓮 | 1 文字名 |
| `kana` | やまだたろう、サトウハナ | かな・カナ。漢字辞書が効かない |
| `ambiguous` | 小林檎（小林・檎 / 小・林檎）、大塚本人 | 切れ目が複数ありうる。学習でどう寄るか見る |

チャットの壊れを見る 3 本は [`../results/07-prompts.md`](../results/07-prompts.md) の q-ja / q-code / q-json をそのまま使う。姓名と無関係な入力が姓名 JSON にならないか、を見るためのもの。

**混同ポイント**: 学習データと評価データを分けるのは、モデルが「答えを暗記した」のと「切り方を覚えた」のを区別するため。20 件の held-out はその最小構成で、統計的に有意な精度は出ない。出す気もない。

## プロンプト

出力指定は固定。0-shot と 3-shot の 2 方式。3-shot の例は `train.jsonl` の先頭 3 件から取る（probe には入っていない名前）。

0-shot（system 無し。user 1 本）:

```text
次の日本人の氏名を姓と名に分け、JSON だけを返してください。キーは sei と mei。説明は不要です。
氏名: 山田太郎
```

3-shot は同じ文の前に、例を 3 組（`氏名: … ` → `{"sei":…}`）を user / assistant の往復として付ける。**temperature 0**、`max_tokens 64`、`--reasoning off`。

見る場所:

- 出力が JSON として `json.loads` できるか（前後の説明文、コードフェンス、`<think>` の残りは不合格）
- `sei` が正解と一致するか（`mei` は sei が合えばほぼ決まる）
- チャット 3 本が普通に答えるか（`q-json` は元から JSON を求める文なので、壊れの判定は q-ja / q-code が主）

## 実施順

### 1. データを書く

`data/name-split/` に 3 ファイル。手書き。Agent が下書きしてよいが、実在人物名になっていないかを人が目で見る。

```bash
mkdir -p data/name-split
# train / heldout / probe を書いたあと
wc -l data/name-split/*.jsonl
python - <<'EOF'
import json
tr = {json.loads(l)["name"] for l in open("data/name-split/train.jsonl")}
ho = {json.loads(l)["name"] for l in open("data/name-split/heldout.jsonl")}
pr = {json.loads(l)["name"] for l in open("data/name-split/probe.jsonl")}
print("train∩heldout:", tr & ho)
print("heldout==probe:", ho == pr)
EOF
```

合格: `train∩heldout` が空集合、`heldout==probe` が True。

### 2. 2B の GGUF を取る

学習前の 2B-Instruct と、対照の 2B-Base。Q4_K_M。ファイル名と配布元は取得時に Hugging Face で確認する（Unsloth が 2B の GGUF を出している。Base GGUF は mradermacher 等。**無ければ記録して 2B-Base の列は空欄にし、質問する**。自分で量子化はフェーズ 16 で覚えるので、ここでは急がない）。

```bash
# 例。実際のファイル名は HF のページで確認してから
curl -fL --retry 3 --retry-delay 2 \
  -o ~/models/Qwen3.5-2B-Q4_K_M.gguf \
  "https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf"
ls -lh ~/models/Qwen3.5-2B-Q4_K_M.gguf
# 合格: 1.2–1.6G 程度
```

`scripts/serve.sh` に `2b` / `2b-base` プロファイルを足す。フラグは 9b と同じ `-ngl 99 -c 8192 --reasoning off`。alias は `qwen3.5-2b` / `qwen3.5-2b-base`。

### 3. プローブスクリプト

`scripts/name_split_probe.py`（`.venv`、openai 3.x。`chat_client.py` と同じ口）。

- 入力: `probe.jsonl`、`07-prompt-q-*.txt`、`--shots 0|3`、`--model`（alias）
- 各件を `/v1/chat/completions` に temperature 0 で送り、生の応答・parse 可否・sei 一致を 1 行ずつ出す
- 最後に集計: JSON 率（20 中）、sei 一致（20 中）、kind 別の一致
- 出力は Markdown 表 1 枚と、生応答の JSONL（`results/13-raw/<alias>-<shots>shot.jsonl`。`.gitignore` の `results/*.jsonl` は直下だけなので、サブディレクトリは残す。巨大にはならない）

```bash
source .venv/bin/activate
# 別ターミナルで scripts/serve.sh 9b を起動しておく
python scripts/name_split_probe.py --model qwen3.5-9b --shots 0
python scripts/name_split_probe.py --model qwen3.5-9b --shots 3
```

### 4. 4 重みを順に回す

同時起動はしない。1 つ止めて次を立てる。

```bash
scripts/serve.sh 9b        # → probe 0 / 3 shot + チャット 3 本
scripts/serve.sh 9b-base   # → 同じ
scripts/serve.sh 2b        # → 同じ（フェーズ 15 の before）
scripts/serve.sh 2b-base   # → 同じ（フェーズ 17 の before）
```

見る場所: 起動ログの `alias:`。9b と 9b-base を取り違えると「Base が完璧」に見える（フェーズ 9 の失敗表と同じ）。

### 5. 表に写す

`results/13-name-split.md` に次の形で。あとのフェーズは **列を足す**（行は増やさない）。

| 重み | shots | JSON 率 | sei 一致 | kanji-1-x | kanji-3-x | kana | ambiguous | q-ja | q-code |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 9b | 0 | /20 | /20 | | | | | 正常/壊れ | |
| 9b | 3 | | | | | | | | |
| 9b-base | 0 | | | | | | | | |
| … | | | | | | | | | |
| 2b（学習前） | 0 | | | | | | | | |
| 2b-base（学習前） | 0 | | | | | | | | |

生の応答は 2–3 件だけ本文に貼る（Base が続きを書いた例、1 文字姓を外した例、`<think>` が漏れた例など）。全文は `results/13-raw/`。

## 合格条件

- [ ] `data/name-split/{train,heldout,probe}.jsonl` があり、train と heldout の名前が重複していない。全件架空
- [ ] `scripts/serve.sh 2b` / `2b-base` が起動する（Base GGUF が無い場合はその旨を記録して質問済み）
- [ ] `scripts/name_split_probe.py` が JSON 率・sei 一致・kind 別を出す
- [ ] `results/13-name-split.md` に 9b / 9b-base / 2b（/ 2b-base）× 0/3-shot の行が揃っている
- [ ] Base 2 種の「続きを書く／JSON を出さない」実例が 1 つ以上貼ってある
- [ ] チャット 3 本の学習前の応答が残っている（フェーズ 15 の忘却判定の before）

## 失敗したとき

| 現象 | まず疑うこと | 次 |
| --- | --- | --- |
| 2B の GGUF が HF に無い／名前が違う | 配布元・ファイル名 | HF のファイル一覧を見て直す。Base が無ければ空欄にして質問 |
| 出力に `<think>` が混ざる | `--reasoning off` 漏れ | serve.sh のフラグ確認。テンプレが空 think を入れるのは正常 |
| 9b-base が完璧に JSON を返す | 9b を起動している | ログの `alias:` |
| JSON 率が 0（Instruct でも） | プロンプト文、`max_tokens` 不足 | 生応答を見る。3-shot で上がるなら記録して次へ。**プロンプトを凝らない** |
| port in use | 前のサーバが残っている | Ctrl+C してから |

## スコープ外

- 学習、PyTorch、Hugging Face の safetensors 取得（フェーズ 14）
- 精度を上げるためのプロンプト工夫。3-shot を超える few-shot
- namedivider や辞書との精度比較
- 実名・公開名簿

## 成果物

- このファイル
- `data/name-split/train.jsonl` / `heldout.jsonl` / `probe.jsonl`
- [`../scripts/serve.sh`](../scripts/serve.sh) の `2b` / `2b-base`
- `scripts/name_split_probe.py`
- [`../results/13-name-split.md`](../results/13-name-split.md) と `results/13-raw/`
