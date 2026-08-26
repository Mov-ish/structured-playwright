# docs/en — Documentation Entry Point

日本語版: [`docs/jp/`](../jp/index.md)

## Entry points by purpose

| Why you are here | Where to read |
|---|---|
| I want to adopt the kit with Claude Code | [`claude-code-guide.md`](./claude-code-guide.md) |
| I want to know the prohibited patterns, templates, and how to write Locators (even without using Claude Code) | [`for-claude-code-en/.claude/rules/`](../../for-claude-code-en/.claude/rules/) (4 standards) + [`skills/`](../../for-claude-code-en/.claude/skills/) |
| I want to understand the design philosophy | [`E2ETest_Framework.md`](./E2ETest_Framework.md) / [`LOCATOR/locator_strategy.md`](./LOCATOR/locator_strategy.md) |
| I want to see how the standards are judged mechanically | [`for-claude-code-en/scripts/gate.sh`](../../for-claude-code-en/scripts/gate.sh) |
| I want to read why these decisions were made, as prose | The Zenn series (see "[Articles](#articles)" below) |

The documents in this directory fall into 2 categories.

## Setup and operations (updated alongside the implementation)

- [`claude-code-guide.md`](./claude-code-guide.md) — **the setup guide for the `for-claude-code-en/` operations kit**. Prerequisites, setup steps, operational flow, a walkthrough from a checklist to a finished test, and customization guidance

The canonical source for the concrete standards (prohibited patterns, templates, procedures) is not the documentation but the rules / skills / gate in [`for-claude-code-en/`](../../for-claude-code-en/README.md). **rules / skills are not AI-only configuration files** — they are written as a body of standards a human can read directly, complete with prohibition → alternative mapping tables, judgment criteria, and code examples. A reader looking for a pattern catalog will get there faster by reading those first rather than the documentation, and they will not go stale (because rules / skills are the side that keeps getting updated in the same PR as the implementation).

## Design philosophy (reading that stays true even as the implementation changes)

- [`E2ETest_Framework.md`](./E2ETest_Framework.md) — **the design philosophy of the 4-layer architecture**. Why the layers are separated, why the boundaries are absolute, and the fight against false positives
- [`LOCATOR/locator_strategy.md`](./LOCATOR/locator_strategy.md) — **Locator Strategy**. The conceptual system of "a Locator is a future value," "operate on a semantic basis," and "narrow the search scope," plus the priority pyramid

## Articles

The design philosophy of this repository is written up as a series on Zenn (in Japanese). The documents here specify *what* the standards are; the series covers *why* they were decided that way.

- [Structured Playwright (1) —— 継続性から設計するE2Eテストの4層構造とハーネス](https://zenn.dev/mov_ish/articles/structured-playwright-e2e) — the overview: the three ways an E2E suite dies (fragile / bloated / abandoned), and designing how far a change reaches across the 4 layers (pairs with [`E2ETest_Framework.md`](./E2ETest_Framework.md))
- [Structured Playwright (2) —— 変更に強いLocatorの設計](https://zenn.dev/mov_ish/articles/structured-playwright-locator) — the Locator priority pyramid and the A/B/C classification of ordinal selectors (pairs with [`LOCATOR/locator_strategy.md`](./LOCATOR/locator_strategy.md))
- [「リグレッションベース」——スプリントを重ねても破綻しないテスト管理の考え方](https://zenn.dev/mov_ish/articles/regression-base-concept) — background: the test-management layer this architecture sits on top of

The series is ongoing and this list can lag behind, so treat [zenn.dev/mov_ish](https://zenn.dev/mov_ish) as the current index.
