# Security Policy

[English](#english) | [日本語](#japanese)

---

<a id="english"></a>
## English

### Scope and supported versions

This repository has no releases and publishes no package. It distributes documentation and a drop-in kit (`for-claude-code/`, `for-claude-code-en/`) that you copy into your own project — there is no version to upgrade and nothing that can be patched remotely on your behalf.

**Only `main` is maintained.** Fixes land on `main`; if you have copied the kit into a project, re-copy the changed files to pick them up.

The executable surface is small and worth naming explicitly:

- `scripts/gate.sh`, `scripts/stop-gate.sh` — shell scripts you run locally via `npm run gate`
- `scripts/check-verify-wait.js` — a Node AST check invoked by the gate
- `.claude/settings.json` — the Claude Code Stop hook, which runs the gate at the end of a turn

Everything else is Markdown.

### Reporting a vulnerability

Open an [Issue](https://github.com/Mov-ish/structured-playwright/issues) using the 🐛 Bug report template — for example, a way to make the gate execute unintended commands, or a hook configuration that could leak credentials.

If you would rather not describe the problem in public, open an Issue saying only that you have a security report, and wait for a reply before posting details.

This is a personal project maintained in spare time, so there is no guaranteed response time.

---

<a id="japanese"></a>
## 日本語

### 対象範囲とサポート対象

このリポジトリはリリースを持たず、パッケージも公開していません。配布しているのはドキュメントと、自分のプロジェクトへコピーして使うドロップイン キット（`for-claude-code/` / `for-claude-code-en/`）です。上げるべきバージョンは存在せず、こちらから遠隔で修正を配ることもできません。

**メンテナンス対象は `main` のみ**です。修正は `main` に入ります。キットをプロジェクトへコピー済みの場合は、変更されたファイルを再コピーして取り込んでください。

実行されるコードは限られているので、明示しておきます。

- `scripts/gate.sh` / `scripts/stop-gate.sh` — `npm run gate` でローカル実行されるシェルスクリプト
- `scripts/check-verify-wait.js` — gate から呼ばれる Node の AST チェック
- `.claude/settings.json` — ターン終了時に gate を実行する Claude Code の Stop フック

これ以外はすべて Markdown です。

### 脆弱性の報告

[Issue](https://github.com/Mov-ish/structured-playwright/issues) を 🐛 Bug report テンプレートで立ててください。たとえば「gate に意図しないコマンドを実行させられる」「フック設定が認証情報を漏らしうる」といった内容です。

公開の場で詳細を書きたくない場合は、「セキュリティに関する報告がある」とだけ書いた Issue を立て、返信を待ってから詳細を送ってください。

個人が余暇で維持しているプロジェクトのため、応答時間の保証はありません。
