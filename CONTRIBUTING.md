# Contributing

[English](#english) | [日本語](#japanese)

---

<a id="english"></a>
## English

Thanks for taking an interest. This repository distributes documentation and a drop-in kit — there is no package to release, and **only `main` is maintained**.

### Before you open a PR

Open an [Issue](https://github.com/Mov-ish/structured-playwright/issues) first. The templates ask the questions that decide whether a change belongs here at all — in particular the 📝 Docs update template, whose three questions (**track record / target / frequency**) govern anything you want to add to `rules/`. Rules are loaded on every turn and spend context, so additions are held to that bar.

Blank issues are disabled on purpose.

### What this repository is not

The kit is designed so that **the project you copy it into never edits `gate.sh`** — the baseline lives in an external file (`.claude/rules-baseline`) and project-specific facts live in the fill-in sections of `CLAUDE.md`. If you need different behaviour for your own project, change it in your copy. A PR here should be a change that every adopter should receive.

### Rules that the CI enforces

**jp / en parity.** `docs/jp` ↔ `docs/en` and `for-claude-code` ↔ `for-claude-code-en` are translation pairs. `tests/check-lang-parity.test.sh` checks that each pair has an identical file list and an identical sequence of Markdown heading levels. Heading *text* is not compared, so wording and terminology can differ — but **adding, removing, or restructuring headings must happen on both sides in the same commit**. Adding a file to one side and not the other fails the build.

**LF line endings.** `.gitattributes` and `.editorconfig` fix this repository to LF. Do not commit CRLF; on Windows, leave `core.autocrlf` alone and let `.gitattributes` win. This matters beyond tidiness: the gate's rules-volume ratchet counts bytes, and CRLF inflates the total by one byte per line.

### If you change a gate check

`scripts/gate.sh` is the canonical source for mechanically detectable prohibitions, but the same norms appear in several other documents. The ★ comment at the top of `gate.sh` lists the sync targets — work through it rather than from memory:

1. `.claude/rules/prohibited-patterns.md` — the gate column (✓ / ⚠️ / —) and the alternative text for that row
2. `.claude/skills/e2e-review/SKILL.md` — the corresponding §2 / §3 check item
3. `.claude/skills/e2e-bootstrap/SKILL.md` — confirm the scaffold does not trip the new check
4. `architecture.md` and friends, where the wording would otherwise contradict

Meta-layer checks (21–23, W6, W7) read `.claude/` itself rather than `src/`, so for those only target 2 applies.

Changes to a check must be made in **both** `for-claude-code/` and `for-claude-code-en/`.

### Raising the rules baseline

`.claude/rules-baseline` caps the total size of the always-loaded rules. Raising it is allowed, but it is a one-way ratchet by nature, so **say in the PR body why the increase is necessary** — the number appears in the diff precisely so that it has to be argued for. The kit does not ship a baseline file: each adopter freezes their own measured value, and the freeze is a human action.

### Running the tests locally

```bash
bash tests/check-lang-parity.test.sh
bash tests/check-verify-wait.test.sh   # installs typescript@5 into a temp dir — needs network
```

Both run in CI on every pull request.

### Style

Match what is already there. In particular, comments in the kit explain **why**, not what — that is the property that makes the rules usable by both a human reviewer and an agent.

---

<a id="japanese"></a>
## 日本語

関心を持っていただきありがとうございます。このリポジトリが配布しているのはドキュメントとドロップイン キットで、リリースするパッケージはなく、**メンテナンス対象は `main` のみ**です。

### PR を出す前に

まず [Issue](https://github.com/Mov-ish/structured-playwright/issues) を立ててください。テンプレートは「その変更がそもそもここに属するか」を決める質問を含んでいます。特に 📝 Docs update テンプレートの3つの質問（**実績 / 対象 / 頻度**）は、`rules/` への追加すべてに掛かります。rules は毎ターン読み込まれてコンテキストを消費するため、追加はこの水準で判断されます。

テンプレートなしの Issue は意図的に無効化しています。

### このリポジトリが引き受けないもの

キットは**導入先が `gate.sh` を編集しない**設計です。baseline は外部ファイル（`.claude/rules-baseline`）に、プロジェクト固有の情報は `CLAUDE.md` の記入欄にあります。自分のプロジェクトだけ挙動を変えたい場合は、手元のコピーを変えてください。ここへの PR は「すべての導入者が受け取るべき変更」であるべきです。

### CI が強制するルール

**jp / en パリティ**。`docs/jp` ↔ `docs/en` と `for-claude-code` ↔ `for-claude-code-en` は翻訳ペアです。`tests/check-lang-parity.test.sh` が、各ペアのファイル一覧の完全一致と、Markdown 見出しレベル列の完全一致を検査します。見出しの**テキスト**は比較しないので訳語や言い回しは自由ですが、**見出しの追加・削除・構成変更は両側を同一コミットで**行ってください。片側にファイルを足して他方に足し忘れると CI が落ちます。

**改行は LF**。`.gitattributes` と `.editorconfig` でこのリポジトリは LF に固定されています。CRLF をコミットしないでください。Windows では `core.autocrlf` をいじらず `.gitattributes` に従わせてください。これは整頓の問題にとどまりません — gate の rules 総量ラチェットはバイト数を数えるので、CRLF は1行あたり1バイト総量を膨らませます。

### gate のチェックを変更する場合

`scripts/gate.sh` は「機械検出できる禁止事項」の正本ですが、同じ規範は他の文書にも載っています。同期先は `gate.sh` 冒頭の ★ コメントに列挙してあるので、記憶に頼らずそのリストを潰してください。

1. `.claude/rules/prohibited-patterns.md` — 該当行の gate 列（✓ / ⚠️ / —）と代替テキスト
2. `.claude/skills/e2e-review/SKILL.md` — §2 / §3 の該当チェック項目
3. `.claude/skills/e2e-bootstrap/SKILL.md` — 雛形が新チェックに発火しないかの確認
4. `architecture.md` 等、文言が矛盾する箇所

メタ層チェック（21〜23・W6・W7）は `src/` ではなく `.claude/` 自体を読むため、これらについては 2 のみが同期先になります。

チェックの変更は `for-claude-code/` と `for-claude-code-en/` の**両方**に入れてください。

### rules baseline を引き上げる場合

`.claude/rules-baseline` は常時ロードされる rules の総量に上限を掛けています。引き上げは禁止しませんが、性質上どうしても一方向のラチェットになるため、**引き上げの必然性を PR 本文に書いてください**。数値が diff に必ず現れるのは、そこで説明を要求するためです。キットは baseline ファイルを同梱していません — 導入者がそれぞれの実測値を凍結する運用で、凍結は人間の作業です。

### テストをローカルで回す

```bash
bash tests/check-lang-parity.test.sh
bash tests/check-verify-wait.test.sh   # typescript@5 を一時ディレクトリに入れるためネットワークが必要
```

どちらも PR ごとに CI で走ります。

### 書き方

既にあるものに合わせてください。特にキット内のコメントは「何をしているか」ではなく **なぜそうするか** を書いています。人間のレビュアーとエージェントの双方が同じ規範を使えるのは、この性質のおかげです。
