# LOCATOR_CONCEPT_GUIDE_part2.md
### ― Locator 思想の完成形：優先順位体系・AI 規範・4 層アーキテクチャ統合 ―

---

# 5. Locator 優先順位体系（Locator Priority Pyramid）

Concept 層では、Locator の選択を **5 段階の優先順位ピラミッド**として体系化する。

```
       ┌──────────────────────────────┐
       │   1. 意味ベース（Semantic）        │
       │   text-is / role / label / name │
       ├──────────────────────────────┤
       │   2. 局所宇宙（Local Universe）     │
       │   dialog / row / card / section │
       ├──────────────────────────────┤
       │   3. 近接（near）による意味補完     │
       ├──────────────────────────────┤
       │   4. data-icon（UI 構造補完）       │
       ├──────────────────────────────┤
       │   5. 最終手段：構造依存（コメント必須） │
       └──────────────────────────────┘
```

**普遍原則 × 固有事情** を統合した公式ルールであり、  
AI も人間も必ずこの優先度に従う。

---

## 5.1 レベル 1：意味ベース（Semantic First）

例：

```ts
page.getByRole('button', { name: '保存' });
page.getByLabel('メールアドレス');
```

理由：

- UI の意味は最も変更されにくい  
- 人間にとって意図が明確  
- AI も正しく目的を把握できる  

---

## 5.2 レベル 2：Local Universe（意味単位で閉じ込める）

例：

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")');
```

メリット：

- 一意性が飛躍的に向上  
- 背景との混在を防止  
- DOM 変更に強い  

---

## 5.3 レベル 3：near()（意味情報の不足を補う）

例：

```ts
page.locator('input[type="checkbox"]:near(:text("利用規約に同意"))');
```

[意味層が薄い](../../CLAUDE_FAQ.md#thin-semantic-ui) UI では near() が **第 3 の正解** になる。

---

## 5.4 レベル 4：data-icon（UI ライブラリの内部仕様を利用）

例：

```ts
row.locator('button:has(svg[data-icon="edit"])');
```

意味層の薄い UI では icon の semantic 情報が弱いため、  
data-icon が **実質的な意味 anchor** として振る舞う。

---

## 5.5 レベル 5：構造（最終手段）

例：

```ts
page.locator('div > div:nth-child(2) > button');
```

使用条件：

- 上位 4 つがすべて不可能  
- かつ コメント必須  
- 後で置き換える前提で一時的に使用する

---

# 6. AI エージェントが守る Locator 思想（Codex / ChatGPT / Claude 用）

Concept 層は **AI の出力品質を統制するルールセット**でもある。

AI が必ず守るべき思想：

---

## 6.1 `.first()` を提案しない

`.first()` は UI の“偶然の順番”を固定化するだけであり、  
テストの本質である「意図の再現」を妨げる。

→ `.first()` を使いたくなったら **一意性の欠如** を疑う。

---

## 6.2 XPath を一切提案しない

理由：

- 構造依存で壊れやすい  
- Playwright の思想と反する  
- 意味層の薄い DOM と相性最悪  
- AI が誤生成しやすい  

→ Concept 層では “構造依存の否定” が必須。

---

## 6.3 Locator の優先順位ピラミッドに従う

AI が Locator を生成する際は：

1. **意味ベース**  
2. **局所宇宙**  
3. **near()**  
4. **data-icon**  
5. **構造依存（最終手段）**

を逐次チェックしながら生成する。

---

## 6.4 Locator に「理由」を付与する

良い AI 出力は常に理由を述べる：

例：

> “この UI は role が無く文言が重複するため、row を Universe とし、中の data-icon を anchor にしています。”

理由を語れる AI は再現性が高く、誤爆しない。

---

# 7. 4 層アーキテクチャとの接続（Concept の位置づけ）

Concept 層は 4 層アーキテクチャにおいて **思想を規定する中心層** である。

```
┌──────────────────────────────┐
│  第4層：Test（Scenario）     │ ← Locator を書かない
├──────────────────────────────┤
│  第3層：Concept（Principles）│ ← Locator の思想・優先度
├──────────────────────────────┤
│  第2層：PageObject / Actions  │ ← Locator を実装する層
├──────────────────────────────┤
│  第1層：Playwright API        │ ← 技術の基盤
└──────────────────────────────┘
```

テストの目的は **UI を操作することではなく、意図を表現すること**。  
Locator は POM（第2層）に閉じ込め、  
Test（第4層）からは排除する。

---

# 8. Concept による「思想 → 実装」変換モデル

Concept はコードそのものではなく、  
**実装を導く思考モデル**である。

---

## 8.1 「保存ボタンを押す」という要求

Concept に従う：

1. 意味 → text-is  
2. Universe → dialog  
3. 一意性 → OK  
4. 近接補完 → 不要  

→ 実装例：

```ts
modal.locator('button:text-is("保存")');
```

---

## 8.2 「チェックボックスをチェックしたい」

1. 意味 → 無い  
2. Universe → 無い  
3. 近接 → Yes  
4. icon → No  

→ 実装：

```ts
page.locator('input[type="checkbox"]:near(:text("プライバシーポリシー"))');
```

---

## 8.3 「編集アイコンを押したい」

1. 意味 → 無い  
2. Universe → row  
3. near → 不要  
4. icon → Yes  

→ 実装：

```ts
row.locator('button:has(svg[data-icon="edit"])');
```

---

# 9. Concept のまとめ（最上位原理）

Concept 層の思想は次の 4 点で集約される：

```
1. 意味を最優先で捉える  
2. UI を小宇宙（Universe）に分解する  
3. 偶然ではなく意図で要素を選択する  
4. 構造依存を排除し、揺れに強い Locator を設計する  
```

これらが **Locator 設計思想の完成形**であり、  
4 層アーキテクチャ全体の品質基盤となる。

---

（Concept Guide 完結）
