---
name: e2e-locator
description: "Locator設計・セレクタ選択用Skill。Locatorの書き方に迷ったとき、新しいPage Objectを作るとき、セレクタのレビュー時に使用。設計思想・優先順位ピラミッド・意味層の薄いUI対応・near()/data-icon/Local Universe・UIライブラリ固有対応を含む。"
---

# E2E Locator Strategy Skill

> **Locator選択・設計時に使用。** 判断フローチャート → 優先順位ピラミッド → 実装パターンの順で参照。

---

## §1. Locator判断フローチャート（最初にこれを使う）

```
① UI に明確な role / label がある？
   └ Yes → セマンティック Locator（getByRole / getByLabel / getByPlaceholder）
   └ No →
        ② UI 文言は唯一か？
           └ Yes → text-is（完全一致）
           └ No →
                ③ 文言と対象要素は近接しているか？
                   └ Yes → near()
                   └ No →
                        ④ UI はモーダル内か？
                           └ Yes → role="dialog" + scope（Local Universe）
                           └ No →
                                ⑤ 対象はアイコンか？
                                   └ Yes → svg[data-icon]
                                   └ No → 特例：構造 + コメント必須
```

---

## §2. Locator優先順位ピラミッド

```
  1. 意味ベース（Semantic）       getByRole / getByLabel / text-is
  2. 局所宇宙（Local Universe）   dialog / row / card / section
  3. 近接（near）による意味補完    :near(:text("..."))
  4. data-icon（UIライブラリ補完） svg[data-icon="edit"]
  5. 最終手段：構造依存           CSS構造セレクタ（XPath禁止）コメント必須
```

---

## §3. 意味層の薄いUIへの対応（data-testid/aria-label不足時）

<!-- 多くのプロダクトで該当する。自プロジェクトの制約に合わせてカスタマイズすること。 -->

以下の制約がある環境で特に有効：
- ❌ `data-testid`がほぼ存在しない
- ⚠️ `aria-label`・`label`が不足（チェックボックス、アイコンボタン等）
- UIライブラリ（React SPA等）によりDOM構造が頻繁に揺れる
- 同じ文言のUI要素が画面内に複数存在する

| 優先度 | 方法 | 使用可否 |
|--------|------|----------|
| ❌ 1 | data-testid | **使用不可**（属性が存在しない場合） |
| ✅ 2 | セマンティック（getByRole等） | **条件付き**（意味層が厚い要素のみ） |
| ✅ 3 | `:has-text()` / `:text-is()` | **推奨** |
| ✅ 4 | `:near()` | **推奨**（意味層の薄い要素に最適） |
| ✅ 5 | `svg[data-icon]` | **推奨**（アイコンボタン） |
| ✅ 6 | 属性セレクタ（name, type） | **推奨** |
| ✅ 7 | 親要素絞り込み（Local Universe） | **推奨** |
| ⚠️ 8 | 構造セレクタ | **最終手段**（コメント+TODO必須） |

### 意味層の厚さ判断

| 意味層 | 例 | 推奨Locator |
|-------|---|-------------|
| **厚い** | モーダル、テキスト付きボタン | `getByRole('dialog')`, `getByRole('button', { name })` |
| **中程度** | placeholder付き入力欄 | `getByPlaceholder()`, `:text-is()` |
| **薄い** | ラベルなしチェックボックス | `:near()` |
| **なし** | アイコンのみボタン | `svg[data-icon]` |

---

## §4. 設計思想（Concept） — なぜそう選ぶのか

Locator設計で未知のパターンに遭遇したとき、フローチャートに当てはまらないケースが必ず出る。
そのとき**この思想から推論して判断する**こと。フローチャートの最下段（構造+コメント）に安易に落ちてはならない。

### Locatorの3つの本質

**1. 未来値（Future）である**
Locatorは今DOMに要素が存在しなくてもよい。遅延評価・自動待機・自動リトライを内包する
「未来に成立する条件式」。これがPlaywrightが動的UIに強い根本理由。
→ だから`isVisible()`（即時評価）より`waitFor()`（未来値評価）が適切な場面が多い。

**2. 意味空間で操作されるべき**
構造（divの入れ子）ではなく意味（role, name, label, text）で要素を捉える。
UIの意味は変更されにくいが、構造は頻繁に変わる。
→ だからCSS構造セレクタやXPathは原則禁止。意味が取れないときだけ代替手段を使う。

**3. 局所宇宙（Local Universe）で探索する**
ページ全体は探索空間として大きすぎる。モーダル・行・カード・セクション等の
意味の単位で括ると：一意性が向上、DOM変更に強い、テストの意図が明確、実行速度も向上。
→ だからスコープなしの`page.locator()`より、`modal.locator()`や`row.locator()`が優れる。

### 4つの普遍原則 — 各原則が何を防いでいるか

**1. 意味を捉える（Semantic Priority）**
text-is / role / label / name を最優先。
**防ぐもの**: UI変更時のLocator崩壊。意味は最も変更されにくい層。

**2. 宇宙を限定する（Local Universe）**
意味の単位で探索範囲を限定。
**防ぐもの**: 同一文言の誤爆。「保存」ボタンが背景とモーダルに2つある場面で、
スコープなしだと背景の保存を押してしまう。

**3. 偶然を排除する（Deterministic Behavior）**
`.first()`はUIの偶然の順番を固定化するだけ。テストは「意図の再現」であり「偶然の固定」ではない。
**防ぐもの**: UI並び替え・A/Bテスト・要素追加時の突然の破壊。

**4. 構造に依存しない（Anti-XPath / Anti-Structural）**
`div > div > span` のような構造追跡は禁止。
**防ぐもの**: UIライブラリがdivを1つ追加しただけでの全Locator崩壊。
特にAIはXPathの安定生成が苦手で、保守不能なコードが量産される。

### 意味層の薄いUIにおける固有ルール — 「例外」ではなく「構造的必然」

意味層の薄いUI（data-testidなし、aria-label不足、class名が意味を持たない）では、
普遍原則をそのまま適用するだけでは安定性が足りない。
根本原因は**「構造層が揺れまくる」**こと：
- UIライブラリが大量のdivを生成し、画面ごとにネストが異なる
- class名がスタイル制御目的で付与され、意味を持たない
- 同じ文言UIが画面内に多数存在する

この構造的制約から、以下の固有ルールが**必然的に**導かれる：

| 固有ルール | なぜ必然か |
|-----------|-----------|
| `near()` を主戦力にする | 要素自身に識別子がない。テキストとの近接関係だけが安定anchor |
| `role="dialog"` でモーダルを閉じ込める | モーダルのclass名は意味を持たない。roleが唯一のセマンティックanchor |
| `svg[data-icon]` をアイコンanchorにする | ボタンにテキストもaria-labelもない。UIライブラリが付与するdata-iconだけが安定 |
| 行（row）をUniverseにする | 表は意味層の薄いUIにおける数少ない「意味単位」 |

**これらは例外対応ではなく、構造的制約に最適化された合理的戦略である。**

### 未知のパターンに遭遇したときの推論手順

1. まず§1の判断フローチャートを試す
2. どの分岐にも当てはまらない場合、**上の4原則に立ち戻る**
3. 「この要素の意味は何か」「探索を閉じ込められるUniverseはあるか」「一意性は確保できるか」を順に考える
4. それでも解決しない場合に初めて構造依存を検討する（コメント+TODO必須）
5. **自分で新しいパターンを発明する前に、人間に確認を求める**

---

## §5. セレクタ実装パターン集

### セマンティック（意味層が厚い要素）
```typescript
page.getByRole('dialog', { name: 'テキストを追加' })
page.getByRole('button', { name: '保存' })
page.getByPlaceholder('検索')
```

### :has-text() / :text-is()
```typescript
page.locator('button:has-text("ログイン")')       // 部分一致
page.locator('span:text-is("マイページ")')         // 完全一致（推奨）
```
**注意**: `:has-text()`は「ログインする」「再ログイン」もマッチする。完全一致なら`:text-is()`。

### :near()（意味層が薄い要素）
```typescript
page.locator('input[type="checkbox"]:near(:text("同意する"))')
page.locator('input[type="radio"]:near(:text("はい"))')
```

### svg[data-icon]（アイコンボタン）
```typescript
page.locator('button:has(svg[data-icon="edit"])')
page.locator('button:has(svg[data-icon="ellipsis"])')   // 三点リーダー
page.locator('button:has(svg[data-icon="delete"])')
```

### 属性セレクタ
```typescript
page.locator('input[name="username"]')    // 認証フォーム等
page.locator('input[name="password"]')
```

### 親要素で絞り込み（Local Universe）
```typescript
page.locator('[role="dialog"] button:has-text("保存")')
const row = page.locator('tr').filter({ hasText: targetText });
row.locator('button:has(svg[data-icon="edit"])');
```

### テーブル行
```typescript
// ❌ 不安定: accessible nameに依存
table.getByRole('row', { name: new RegExp(targetText) })
// ✅ 安定: テキストでフィルタリング
table.locator('tr').filter({ hasText: targetText })
```

### フィルターの使い分け
```typescript
// ❌ hasNot は子要素チェック
.filter({ hasNot: page.getByText('すべて完全削除') })
// ✅ hasNotText でテキスト除外
.filter({ hasNotText: 'すべて' })
```

---

## §6. `.first()`使用ルール

**基本: できる限り避ける。** 推奨対応（優先順位順）:
1. data-testid追加依頼
2. `:near()` で特定
3. 親要素絞り込み + `.first()`
4. `.first()` + 詳細コメント + TODO

---

## §7. 禁止事項

| パターン | 理由 |
|---------|------|
| `text=ログイン` | Playwrightプロジェクトで動作しない場合がある |
| XPath | 構造依存・AI誤生成の温床 |
| CSS構造セレクタ (`div > div > button`) | DOM揺れで即破壊 |
| `.first()` コメントなし | 偶然の固定化 |
| `has-text` スコープなし | 誤爆（同じ文言が複数） |
| モーダルをpage全体で探索 | 背景ボタン誤クリック |
| 意味層薄い要素にセマンティック | 動作しない |

---

## §8. AIが守るLocator思想

1. `.first()` を提案しない → 一意性の欠如を疑う
2. XPath を一切提案しない
3. 優先順位ピラミッドに従う（上から順に検討）
4. Locatorに「理由」を付与する（なぜそのLocatorを選んだか）

---

## 🔌 Appendix: Ant Design 固有 Locator

<!-- Ant Designを使用するプロジェクトのみ。MUI/Chakra UI等の場合は適宜書き換え。 -->

### Locator定義
```typescript
page.locator('.ant-modal-content')                              // モーダル
page.locator('.ant-select-item-option').filter({ hasText })     // ドロップダウン選択肢
page.locator('.ant-select-dropdown')                            // ドロップダウンコンテナ
page.locator('.ant-table-row')                                  // テーブル行
page.locator('.ant-message')                                    // メッセージ/トースト
page.locator('.ant-notification')                               // 通知
```

### モーダル操作フロー
```typescript
const modal = page.locator('.ant-modal-content');
await modal.waitFor({ state: 'visible', timeout: TIMEOUTS.SHORT });
await modal.locator('input[type="text"]').first().fill(value);
await modal.getByRole('button', { name: '作成する' }).click();
await modal.waitFor({ state: 'hidden', timeout: TIMEOUTS.DEFAULT });
```

### ドロップダウン操作フロー（定型手順）
```typescript
await page.getByRole('combobox').click();
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
const option = page.locator('.ant-select-item-option')
  .filter({ hasText: targetName }).first();
await option.click();
await page.keyboard.press('Escape');
```

**注意**: Ant Designのクラス名はバージョンアップで変更される可能性がある。
可能な限りセマンティックLocatorを優先し、Ant Design固有セレクタは補助的に使用。

---

## 追記エリア

新しいパターンを発見した場合、以下の形式で追記する。

### YYYY-MM-DD - パターン名
- **発見の経緯**: （何をして、何が起きたか）
- **解決策**: （コード例）
- **注意事項**: （適用条件・制約）
