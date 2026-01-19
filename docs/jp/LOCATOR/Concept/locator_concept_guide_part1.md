# LOCATOR_CONCEPT_GUIDE_part1.md
### ― Four-Layer Architecture における Locator 設計思想（Concept Layer / Principles）―

---

# 0. Concept Guide の役割

Locator は「第1層（Playwright 技術）」の機能でありながら、
その使い方のルールは **第3層（Concept / Principles）** が支配する。

なぜなら Locator は：

- テストの安定性  
- コードの保守性  
- 自動生成（AI）の品質  
- チームの理解負荷  
- UI 変更への耐性  

すべてに影響する“中核構造”だからである。

Concept 層は **「どう書くか」ではなく「なぜそう書くのか」** を統一する層であり、
4層アーキテクチャの思想的中心となる。

---

# 1. Locator とは何か（概念レベルの定義）

Locator を単なる「要素の取得」と捉えると、
設計思想の深みや Playwright の強みを理解し損なう。

Concept 層での定義はこうなる：

```
Locator =
   “条件セットを持つ探査機（probe）”
 × “局所宇宙（Local Universe）で探索する”
 × “未来値として評価される”
```

---

## 1.1 Locator は「未来値（Future）」である

Locator は今 DOM に要素が存在しなくてもよい。

- 遅延評価（Lazy Evaluation）  
- 自動待機（Auto-Wait）  
- 自動リトライ（Retry）  

これらを内包する「未来に成立する条件式」であり、
動的 UI に強い根本理由がここにある。

---

## 1.2 Locator は「意味空間」で操作されるべき

Playwright が推奨するセマンティック Locator は、
構造ではなく **意味（Semantics）** に基づいて要素を探索する。

- `role` は UI の役割  
- `name` は UI 上のラベル  
- `label` は入力欄の意味  
- `text` は人間が理解する情報  

UI を構造（div の入れ子）ではなく意味によって捉えることが、
テストの安定性と可読性につながる。

---

## 1.3 Locator は「宇宙（Universe）」を持つ

ページ全体は大きすぎる。

Playwright の哲学に近いのは **「局所宇宙（Local Universe）で探索せよ」** の思想。

Local Universe の例：

- モーダル  
- 行（row）  
- カード  
- セクション  
- タブパネル  

探索範囲を限定すると：

- 一意性が向上  
- DOM の変更に強い  
- テストの意図が明確  
- 実行速度も向上  

Locator 設計における最重要概念のひとつ。

---

# 2. Concept 層の目的：思想を統一する

Concept 層は「実装テクニック」ではなく、
**Locator 設計の哲学・優先順位・禁止事項** を定義する。

これにより：

- PageObject（第2層）が迷わなくなる  
- テストコード（第4層）が Locator を書かなくなる  
- AI（Codex / Claude）が誤った Locator を生成しない  
- チーム全体の Locator 品質が統一される  

Concept 層は “Locator の憲法” の役割を持つ。

---

# 3. Locator における普遍原則（Universal Concept）

普遍ルールは次の 4 原則に圧縮される：

---

## 3.1 意味を捉える（Semantic Priority）

優先順位トップは：

```
text-is / role / label / name
```

理由：

- UI の意味は変更されにくい  
- テストコードの意図が読み取りやすい  
- AI の自動生成と相性が良い  

---

## 3.2 宇宙を限定する（Local Universe）

例：

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")');
```

意味の単位で括った範囲で探索することで：

- 一意性が飛躍的に上がる  
- DOM 変更に強い  
- 目的が明確になる  

---

## 3.3 偶然を排除する（Deterministic Behavior）

典型例：`.first()` の乱用

```ts
page.locator('button').first().click();
```

`.first()` は UI の偶然の順番を固定化するだけであり、
**テストは「意図の固定」であって「偶然の固定」ではない。**

---

## 3.4 構造に依存しない（Anti-XPath / Anti-Structural）

- CSS-only  
- XPath  
- div > div > span のような構造追跡

これらは DOM 変更への耐性が低すぎる。

Concept 層では **構造依存そのものを思想として否定**する。

---

# 4. 固有ルールが Concept 層に統合される理由

意味層の薄い UI は以下の構造的特徴を持つ：

- [意味層が薄い](../../CLAUDE_FAQ.md#thin-semantic-ui)
- 構造層が揺れやすい  
- 同じ文言 UI が画面内に多数存在  
- アイコンは data-icon が唯一の anchor  
- モーダルは class で識別できない  

これらにより、普遍原則をそのまま適用するだけでは安定性が足りない。

Concept 層では固有ルールを **「例外」ではなく「構造的必然」** として扱う。

---

## 4.1 near() の哲学的位置づけ

本来 near() は補助的だが、
意味情報が不足する UI では **意味の代替物** として機能する。

Concept 層では次のように規定する：

```
意味情報が不足する UI では、近接関係を意味として扱う。
```

---

## 4.2 role="dialog" の哲学的位置づけ

モーダルと背景の UI が混在しやすいプロダクトのため、
唯一のセマンティック anchor は role 属性。

```
モーダルの Universe は role="dialog" を基点に定義する。
```

---

## 4.3 svg[data-icon] の哲学的位置づけ

UI ライブラリが icon に安定した data-icon を付与するため、
内部仕様だが **意味に相当する安定 anchor** を持つ。

```
アイコンの識別は data-icon が本質 anchor。
```

---

## 4.4 row（行）を Universe とする理由

表（table）は意味層の薄い UI における数少ない「意味単位」。

```
行は UI の意味単位として Universe に採用する。
```

---

（続きは Part 2 に続く）
