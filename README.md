# Structured Playwright for Sustainability

[English](#english) | [日本語](#japanese)

---

<a id="english"></a>
## English

Maintainable and scalable Playwright test design patterns—and the associated skills and rules to implement them—focused on maintainability, extensibility, and sustainability.

### Core Principles

- **Reviewability**: Easy to understand and review
- **Maintainability**: Resilient to changes  
- **Sustainability**: Transferable and long-lasting

### Architecture Overview

This architecture separates concerns across 4 distinct layers:

1. **Layer 1: Page Objects** - UI element definitions and basic operations
2. **Layer 2: Actions** - Business logic and multi-page flows
3. **Layer 3: Tests** - Test scenarios and assertions (AAA pattern)
4. **Layer 4: Config/Env** - Environment configuration and settings


### Articles

The thinking behind this repository is written up as an ongoing series on Zenn (in Japanese). The documentation says *what* the standards are; the articles say *why* they were decided that way.

- [Structured Playwright (1) —— 継続性から設計するE2Eテストの4層構造とハーネス](https://zenn.dev/mov_ish/articles/structured-playwright-e2e) — the overview: the three ways E2E suites die (fragile / bloated / abandoned), and how the 4 layers bound the reach of a change
- [Structured Playwright (2) —— 変更に強いLocatorの設計](https://zenn.dev/mov_ish/articles/structured-playwright-locator) — the Locator priority pyramid and the A/B/C classification of ordinal selectors
- [Structured Playwright (3) —— Passと報告されるFailを構造で止める](https://zenn.dev/mov_ish/articles/structured-playwright-false-positive) — the five ways a failing test gets reported as a pass, and where each one is stopped: norms, structure, the gate, the logs, and people
- [「リグレッションベース」——スプリントを重ねても破綻しないテスト管理の考え方](https://zenn.dev/mov_ish/articles/regression-base-concept) — background: the test-management idea this architecture assumes

The series is ongoing — the current list is at [zenn.dev/mov_ish](https://zenn.dev/mov_ish).


### Getting Started (Claude Code)

The [`for-claude-code-en/`](./for-claude-code-en/) directory is a drop-in kit for Claude Code: copy `.claude/`, `scripts/`, and `CLAUDE.md` into your project, and generate maintainable 4-layer Playwright tests from test procedures, checklists, or user stories — guarded by a mechanical gate (`npm run gate`). See [for-claude-code-en/README.md](./for-claude-code-en/README.md) and the setup guide at [docs/en/claude-code-guide.md](./docs/en/claude-code-guide.md). (The Japanese original of the kit lives in [`for-claude-code/`](./for-claude-code/).)

**Not using Claude Code?** The `rules/` and `skills/` under [`for-claude-code-en/.claude/`](./for-claude-code-en/.claude/) are written to be read by humans as well — prohibited-pattern tables with alternatives, decision criteria, and code examples you can adopt directly as team conventions. The documents under [`docs/en/`](./docs/en/index.md) carry the setup guide and the design philosophy; the operational canon lives next to the implementation so it never drifts.


### Contributing

Issues and pull requests are welcome. Please open an Issue first — the templates ask the questions that decide whether a change belongs here, and the 📝 Docs update template's three questions govern anything added to `rules/`. See [CONTRIBUTING.md](./CONTRIBUTING.md) for the jp/en parity rule, the sync targets when a gate check changes, and how to run the tests locally.

### Author

**Ray-ish** ([@Mov-ish](https://github.com/Mov-ish))

Developed through years of experience maintaining E2E test frameworks in the education technology sector.

### License

MIT — free to use, modify, and distribute. When redistributing, please keep the copyright notice (`Copyright (c) 2026 Ray-ish`) as required by the license.

If this template helps your project, a mention in your README or blog — or a star — is always appreciated (welcome, not required).

---

<a id="japanese"></a>
## 日本語

持続可能性のための構造化Playwright設計

保守性・拡張性・継続性に焦点を当てた、メンテナブルでスケーラブルなPlaywrightテスト設計パターンと、それを実現するためのSkills/rules群です。

### コアコンセプト

- **レビュー性**: 理解しやすく、レビューしやすい
- **保守性**: 変更に強い
- **継続性**: 引き継ぎ可能で長期運用できる

### アーキテクチャ概要

責任を4つの層に明確に分離：

1. **Layer 1: Page Objects** - UI要素定義・基本操作
2. **Layer 2: Actions** - ビジネスロジック・複数画面フロー  
3. **Layer 3: Tests** - テストシナリオ・検証（AAAパターン）
4. **Layer 4: Config/Env** - 環境設定・環境変数


### 解説記事

この設計の背景は Zenn の連載として書いています。ドキュメントが「何をどう書くか」を規定するのに対し、連載は「なぜそう決めたか」を扱います。

- [Structured Playwright (1) —— 継続性から設計するE2Eテストの4層構造とハーネス](https://zenn.dev/mov_ish/articles/structured-playwright-e2e) — 総論。E2E テストの 3 つの末路（壊れやすい / 太る / 捨てられる）と、4 層で変更の届く範囲を設計する話
- [Structured Playwright (2) —— 変更に強いLocatorの設計](https://zenn.dev/mov_ish/articles/structured-playwright-locator) — Locator の優先順位ピラミッドと、ordinal セレクタの A/B/C 分類
- [Structured Playwright (3) —— Passと報告されるFailを構造で止める](https://zenn.dev/mov_ish/articles/structured-playwright-false-positive) — Pass と報告される Fail の 5 つの入口と、規範 / 構造 / gate / ログ / 人のどこで止めているか
- [「リグレッションベース」——スプリントを重ねても破綻しないテスト管理の考え方](https://zenn.dev/mov_ish/articles/regression-base-concept) — 前提となるテスト管理の考え方（このリポジトリより前の話）

連載は不定期で継続中です。最新の一覧は [zenn.dev/mov_ish](https://zenn.dev/mov_ish) にあります。


### はじめかた（Claude Code）

[`for-claude-code/`](./for-claude-code/) は Claude Code 用のドロップイン キットです。`.claude/` `scripts/` `CLAUDE.md` をプロジェクトへコピーするだけで、テスト手順書・チェックリスト・ユーザーストーリーから保守継続性の高い 4 層 Playwright テストを生成・維持できます（機械ゲート `npm run gate` 付き）。入口は [for-claude-code/README.md](./for-claude-code/README.md)、詳細は [docs/jp/claude-code-guide.md](./docs/jp/claude-code-guide.md)。英語版キットは [`for-claude-code-en/`](./for-claude-code-en/)、英語版ドキュメントは [`docs/en/`](./docs/en/index.md) にあります。

**Claude Code を使わない場合でも**、[`for-claude-code/.claude/`](./for-claude-code/.claude/) の rules / skills は人間がそのまま読める規範集（禁止 → 代替の対応表・判定基準・コード例つき）として書かれており、チーム規約として直接採用できます。[`docs/`](./docs/jp/index.md) が担うのは導入ガイドと設計思想で、運用規範の正本はドリフトしないよう実装の隣に置いています。


### コントリビュートについて

Issue・Pull Request を歓迎します。まず Issue を立ててください — テンプレートは「その変更がここに属するか」を決める質問を含んでおり、📝 Docs update テンプレートの3つの質問は `rules/` への追加すべてに掛かります。jp/en パリティのルール、gate のチェックを変えたときの同期先、テストのローカル実行は [CONTRIBUTING.md](./CONTRIBUTING.md) を参照してください。

### 著者について

**Ray-ish**（[@Mov-ish](https://github.com/Mov-ish)）

教育テクノロジー分野でのE2Eテスト基盤構築・運用の経験から、
長期的に維持可能なテスト設計の重要性を実感し体系化。

### ライセンス

MIT ライセンスです。利用・改変・再配布は自由ですが、再配布の際はライセンス条件に従い著作権表示（`Copyright (c) 2026 Ray-ish`）を保持してください。

このテンプレートが役に立ったら、README やブログでの言及・スターを歓迎します（義務ではなく、歓迎です）。