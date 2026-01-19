# LOCATOR_RULES_UNIVERSAL_FULL_part1.md

## 0. 本書の目的
Playwright による E2E テストの成否は、Locator の設計品質に依存する。
Locator はテスト全体の保守性・実行安定性・AI 自動生成との相性を決定する中核要素である。

本書は「どのプロダクトでも通用する」普遍的な Locator 設計原則を体系化する。

---

## 1. Locator の根本理解：未来の UI を扱う条件式

Playwright の Locator はただの “要素の取得” ではなく、
「未来に出現する UI に対して成立する条件セット」として振る舞う。

### 1.1 遅延評価（Lazy Evaluation）
Locator は生成時に DOM を探索せず、操作実行時に探索して条件を満たすまで待機する。

### 1.2 自動待機（Auto-Wait）
クリックや入力などの操作時に、可視化・有効化・安定化まで自動で待つ。

### 1.3 自動リトライ（Retry）
UI が不安定でも Playwright が内部で探索を繰り返すため、E2E が壊れにくい。

---

## 2. Locator 設計思想：構造ではなく“意味”を捉える
HTML の構造は変化するが、UI の意味（role, name, label, text）は変化しにくい。

Playwright の推奨戦略は DOM を辿るのではなく、意味を基準に Locator を設計することである。

