# docs/en — Documentation Entry Point

日本語版: [`docs/jp/`](../jp/index.md)

## Entry points by purpose

| Why you are here | Where to read |
|---|---|
| I want to adopt the kit with Claude Code | [`claude-code-guide.md`](./claude-code-guide.md) |
| I want to know the prohibited patterns, templates, and how to write Locators (even without using Claude Code) | [`for-claude-code-en/.claude/rules/`](../../for-claude-code-en/.claude/rules/) (4 standards) + [`skills/`](../../for-claude-code-en/.claude/skills/) |
| I want to understand the design philosophy | [`E2ETest_Framework.md`](./E2ETest_Framework.md) / [`LOCATOR/locator_strategy.md`](./LOCATOR/locator_strategy.md) |
| I want to see how the standards are judged mechanically | [`for-claude-code-en/scripts/gate.sh`](../../for-claude-code-en/scripts/gate.sh) |

The documents in this directory fall into 2 categories.

## Setup and operations (updated alongside the implementation)

- [`claude-code-guide.md`](./claude-code-guide.md) — **the setup guide for the `for-claude-code-en/` operations kit**. Prerequisites, setup steps, operational flow, a walkthrough from a checklist to a finished test, and customization guidance

The canonical source for the concrete standards (prohibited patterns, templates, procedures) is not the documentation but the rules / skills / gate in [`for-claude-code-en/`](../../for-claude-code-en/README.md). **rules / skills are not AI-only configuration files** — they are written as a body of standards a human can read directly, complete with prohibition → alternative mapping tables, judgment criteria, and code examples. A reader looking for a pattern catalog will get there faster by reading those first rather than the documentation, and they will not go stale (because rules / skills are the side that keeps getting updated in the same PR as the implementation).

## Design philosophy (reading that stays true even as the implementation changes)

- [`E2ETest_Framework.md`](./E2ETest_Framework.md) — **the design philosophy of the 4-layer architecture**. Why the layers are separated, why the boundaries are absolute, and the fight against false positives
- [`LOCATOR/locator_strategy.md`](./LOCATOR/locator_strategy.md) — **Locator Strategy**. The conceptual system of "a Locator is a future value," "operate in semantic space," and "explore in a local universe," plus the priority pyramid
