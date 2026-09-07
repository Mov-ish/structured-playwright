# docs/jp — 文書の入口

English version: [`docs/en/`](../en/index.md)

## 目的別の入口

| 来訪目的 | 読む場所 |
|---|---|
| Claude Code でキットを導入したい | [`claude-code-guide.md`](./claude-code-guide.md) |
| 禁止パターン・雛形・Locator の書き方を知りたい（Claude Code を使わなくても） | [`for-claude-code/.claude/rules/`](../../for-claude-code/.claude/rules/)（規範 4 本）+ [`skills/`](../../for-claude-code/.claude/skills/) |
| 設計思想を知りたい | [`E2ETest_Framework.md`](./E2ETest_Framework.md) / [`LOCATOR/locator_strategy.md`](./LOCATOR/locator_strategy.md) |
| 規範がどう機械判定されるかを見たい | [`for-claude-code/scripts/gate.sh`](../../for-claude-code/scripts/gate.sh) |
| なぜそう決めたのか、背景を読み物として読みたい | Zenn 連載（下記「[解説記事](#解説記事)」） |

このディレクトリの文書は 2 種類に分かれる。

## 導入・運用（実装とともに更新される）

- [`claude-code-guide.md`](./claude-code-guide.md) — **`for-claude-code/` 運用セットの導入ガイド**。前提条件・導入手順・運用フロー・チェックリストからテストができるまでのウォークスルー・カスタマイズ指針

具体的な規範（禁止パターン・雛形・手順）の正本はドキュメントではなく [`for-claude-code/`](../../for-claude-code/README.md) の rules / skills / gate にある。**rules / skills は AI 専用の設定ファイルではない** — 禁止 → 代替の対応表・判定基準・コード例を備えた、人間がそのまま読める規範集として書かれている。パターン集を探しに来た読者は、ドキュメントよりまずそちらを読むほうが早く、そして古びない（実装と同じ PR で更新され続けるのは rules / skills の側だからである）。

## 設計思想（実装が変わっても真であり続ける読み物）

- [`E2ETest_Framework.md`](./E2ETest_Framework.md) — **4 層アーキテクチャの設計思想**。なぜ層を分けるのか・境界はなぜ絶対か・偽陽性との戦い
- [`LOCATOR/locator_strategy.md`](./LOCATOR/locator_strategy.md) — **Locator Strategy**。Locator は未来値である・意味ベースで操作する・探索スコープを絞る、という思想体系と優先順位ピラミッド

## 解説記事

このリポジトリの設計思想は Zenn の連載として書いている。ここのドキュメントが「何をどう書くか」を規定するのに対し、連載は「なぜそう決めたか」を扱う。

- [Structured Playwright (1) —— 継続性から設計するE2Eテストの4層構造とハーネス](https://zenn.dev/mov_ish/articles/structured-playwright-e2e) — 総論。E2E テストの 3 つの末路（壊れやすい / 太る / 捨てられる）と、4 層で変更の届く範囲を設計する話（[`E2ETest_Framework.md`](./E2ETest_Framework.md) に対応）
- [Structured Playwright (2) —— 変更に強いLocatorの設計](https://zenn.dev/mov_ish/articles/structured-playwright-locator) — Locator の優先順位ピラミッドと、ordinal セレクタの A/B/C 分類（[`LOCATOR/locator_strategy.md`](./LOCATOR/locator_strategy.md) に対応）
- [Structured Playwright (3) —— Passと報告されるFailを構造で止める](https://zenn.dev/mov_ish/articles/structured-playwright-false-positive) — Pass と報告される Fail の 5 つの入口と、規範 / 構造 / gate / ログ / 人のどこで止めているか（[`prohibited-patterns.md`](../../for-claude-code/.claude/rules/prohibited-patterns.md) に対応）
- [「リグレッションベース」——スプリントを重ねても破綻しないテスト管理の考え方](https://zenn.dev/mov_ish/articles/regression-base-concept) — 前提となるテスト管理の考え方。このリポジトリより前の層の話

連載は不定期で継続中。この一覧は更新が遅れることがあるので、最新は [zenn.dev/mov_ish](https://zenn.dev/mov_ish) を見ること。
