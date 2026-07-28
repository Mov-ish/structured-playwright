# docs/jp — 文書の入口

## 目的別の入口

| 来訪目的 | 読む場所 |
|---|---|
| Claude Code でキットを導入したい | [`claude-code-guide.md`](./claude-code-guide.md) |
| 禁止パターン・雛形・Locator の書き方を知りたい（Claude Code を使わなくても） | [`for-claude-code/.claude/rules/`](../../for-claude-code/.claude/rules/)（規範 4 本）+ [`skills/`](../../for-claude-code/.claude/skills/) |
| 設計思想を知りたい | [`E2ETest_Framework.md`](./E2ETest_Framework.md) / [`LOCATOR/locator_strategy.md`](./LOCATOR/locator_strategy.md) |
| 規範がどう機械判定されるかを見たい | [`for-claude-code/scripts/gate.sh`](../../for-claude-code/scripts/gate.sh) |

このディレクトリの文書は 2 種類に分かれる。

## 導入・運用（実装とともに更新される）

- [`claude-code-guide.md`](./claude-code-guide.md) — **`for-claude-code/` 運用セットの導入ガイド**。前提条件・導入手順・運用フロー・チェックリストからテストができるまでのウォークスルー・カスタマイズ指針

具体的な規範（禁止パターン・雛形・手順）の正本はドキュメントではなく [`for-claude-code/`](../../for-claude-code/README.md) の rules / skills / gate にある。**rules / skills は AI 専用の設定ファイルではない** — 禁止 → 代替の対応表・判定基準・コード例を備えた、人間がそのまま読める規範集として書かれている。パターン集を探しに来た読者は、ドキュメントよりまずそちらを読むほうが早く、そして古びない（実装と同じ PR で更新され続けるのは rules / skills の側だからである）。

## 設計思想（実装が変わっても真であり続ける読み物）

- [`E2ETest_Framework.md`](./E2ETest_Framework.md) — **4 層アーキテクチャの設計思想**。なぜ層を分けるのか・境界はなぜ絶対か・偽陽性との戦い
- [`LOCATOR/locator_strategy.md`](./LOCATOR/locator_strategy.md) — **Locator Strategy**。Locator は未来値である・意味空間で操作する・局所宇宙で探索する、という思想体系と優先順位ピラミッド
