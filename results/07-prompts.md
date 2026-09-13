# フェーズ 7: 品質プローブ（固定文）

速度表の ja/en はフェーズ 5 のまま（[`05-prompts.md`](05-prompts.md)）。こちらは **7B / A / B の文の差**を見る 3 本。変えたら `07-best-local.md` に書く。

think（推論トークンを先に出すモード）は **off が正**。on は任意。

## q-ja（日本語・敬語）

```text
取引先に納期が2日遅れることを謝る短いメールを書いてください。件名と本文。丁寧語。中国語は混ぜない。
```

ファイル: [`07-prompt-q-ja.txt`](07-prompt-q-ja.txt)

見る場所: 日本語として通るか、英大文字の断片や中国語が混ざるか。

## q-code（短い Python）

```text
Write a Python function is_palindrome(s: str) -> bool that ignores case and non-alphanumeric characters. Return only the function, no markdown.
```

ファイル: [`07-prompt-q-code.txt`](07-prompt-q-code.txt)

見る場所: 動く関数か、説明の前置きだけか。

## q-json（指示追従）

```text
次の3件を JSON 配列だけ返せ。キーは name と os。値: WSL2 と Linux、Windows 11 と Windows、RTX 5060 と GPU。説明文は不要。
```

ファイル: [`07-prompt-q-json.txt`](07-prompt-q-json.txt)

見る場所: 配列としてパースできるか、余分な文があるか。
