# docs/jp — 文書の入口

このディレクトリの文書は 2 種類に分かれる。

## 導入・運用（実装とともに更新される）

- [`claude-code-guide.md`](./claude-code-guide.md) — **`for-claude-code/` 運用セットの導入ガイド**。前提条件・導入手順・運用フロー・チェックリストからテストができるまでのウォークスルー・カスタマイズ指針

具体的な規範（禁止パターン・雛形・手順）の正本はドキュメントではなく [`for-claude-code/`](../../for-claude-code/README.md) の rules / skills / gate にある。

## 設計思想（実装が変わっても真であり続ける読み物）

- [`E2ETest_Framework.md`](./E2ETest_Framework.md) — **4 層アーキテクチャの設計思想**。なぜ層を分けるのか・境界はなぜ絶対か・偽陽性との戦い
- [`LOCATOR/locator_strategy.md`](./LOCATOR/locator_strategy.md) — **Locator Strategy**。Locator は未来値である・意味空間で操作する・局所宇宙で探索する、という思想体系と優先順位ピラミッド
