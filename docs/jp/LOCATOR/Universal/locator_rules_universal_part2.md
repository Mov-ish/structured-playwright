# LOCATOR_RULES_UNIVERSAL_FULL_part2.md

## 3. 一意性（Uniqueness）の原則

Locator の品質は「一意であるかどうか」で決まる。
曖昧な Locator は UI 変更の影響を最も受けやすく、E2E 崩壊の主要因となる。

### 3.1 一意性が崩れる典型例（NG）

```
input[type="checkbox"]
button
div.card
```

これらは “意味がない” ため、複数一致しやすく、DOM の構造変化にも弱い。

### 3.2 一意性を確保した例（OK）

```
button:text-is("保存")
input[name="email"]
role=button with name="削除"
```

UI の “意味” を基準にすることで驚くほど壊れにくくなる。

---

## 4. テキスト一致：text-is と has-text の正しい使い分け

Playwright Locator の強力な機能のひとつが「テキスト一致」だが、
誤用するともっとも壊れやすい地雷になる。

### 4.1 text-is（完全一致） ― 最優先で使うべき

```
button:text-is("保存")
```

- 意図が明確  
- 誤爆が極めて少ない  
- “意味” を最も正しく取得できる  

基本方針：**text-is を最優先する。**

---

### 4.2 has-text（部分一致） ― 使い方を誤ると危険

```
button:has-text("保存")
```

次のような UI 全部が一致し得る：

- 「保存する」  
- 「下書きを保存」  
- 「保存済みです」  

部分一致は「曖昧性」を増幅するため、使用判断は慎重にする。

---

## 5. 親コンテナ anchoring（Local Universe の概念）

Locator は「局所宇宙（Local Universe）」で使うと安定する。

例：モーダル内だけを探索する

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")').click();
```

### 5.1 なぜ Local Universe が重要なのか？

- DOM 全体を探索すると一致候補が増える  
- UI の揺れに強くなる  
- パフォーマンスが向上  
- テストの意図が明確になる  

### 5.2 Local Universe の代表例

- モーダル  
- カード  
- テーブル行  
- タブパネル  
- 設定セクション

UI を「宇宙」として区切ることで、一意性と安定性が同時に高まる。

---

**最終更新**: 2026-02-02
**管理者**: Ray Ishida

