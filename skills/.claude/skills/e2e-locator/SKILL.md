---
name: e2e-locator
description: "Locatorセレクタ実装パターン集。新しいPage Objectを作るとき、Locatorの具体的な書き方で迷ったとき、UIライブラリ固有要素を扱うときに使用。設計思想と優先順位は .claude/rules/locator-principles.md を参照。"
---

# E2E Locator Implementation Patterns

> 設計思想・優先順位・判断フローは rules/locator-principles.md（常時読み込み済み）。
> このSkillは**具体的な書き方とコード例**に特化。

## §1. セマンティックLocator（意味層が厚い要素）

```typescript
// data-testid（最優先 — 存在する場合）
page.locator('[data-testid="login-button"]')

// role + name
page.getByRole('dialog', { name: 'テキストを追加' })
page.getByRole('button', { name: '保存' })
page.getByRole('button', { name: /削除|delete/ })

// label
page.getByLabel('メールアドレス')

// placeholder
page.getByPlaceholder('検索')
```

## §2. :has-text() / :text-is()

```typescript
page.locator('button:has-text("ログイン")')       // 部分一致
page.locator('span:text-is("マイページ")')         // 完全一致（推奨）
```

**has-text の危険性**: 部分一致のため意図しない要素にマッチする。
```typescript
// ❌ 「保存」で部分一致 → 以下すべてにマッチ → strict mode violation
//   「保存する」「下書きを保存」「保存済みです」「一時保存」
page.locator('button:has-text("保存")')

// ✅ text-is で完全一致
page.locator('button:text-is("保存")')

// ✅ has-text を使う場合は必ず Local Universe で絞る
page.locator('[role="dialog"] button:has-text("保存")')
```

**XPath変換時の罠**:
```typescript
// ❌ 完全一致→部分一致に変換してしまう
page.locator(`span:has-text("ログイン")`)  // 「ログインする」もマッチ！

// ✅ 完全一致→完全一致
page.locator(`span:text-is("ログイン")`)
```

**正規表現の変更耐性**:
```typescript
// ❌ 脆弱: UI文言の微変更でマッチしなくなる
.getByRole('button', { name: /完全削除する/ })

// ✅ 堅牢: 広いパターン+除外フィルター
.getByRole('button', { name: /完全削除/ }).filter({ hasNotText: 'すべて' })
```

## §3. :near()（意味層が薄い要素）

```typescript
// チェックボックス（labelがない）
page.locator('input[type="checkbox"]:near(:text("同意する"))')

// ラジオボタン
page.locator('input[type="radio"]:near(:text("はい"))')
```

## §4. data属性（UIライブラリ固有）

```typescript
// SVGアイコンボタン（data-icon属性がある場合）
page.locator('button:has(svg[data-icon="edit"])')
page.locator('button:has(svg[data-icon="delete"])')
page.locator('button:has(svg[data-icon="ellipsis"])')

// getByRoleとfilterの組み合わせ
page.getByRole('button').filter({ has: page.locator('svg[data-icon="ellipsis"]') })
```

**プロジェクト導入時**: UIライブラリが付与する安定data属性を特定し、constants.tsに定義する。

## §5. 属性セレクタ

```typescript
page.locator('input[name="username"]')
page.locator('input[name="password"]')
page.locator('input[type="email"]')
```

## §6. 親要素で絞り込み（Local Universe）

```typescript
// モーダル内
page.locator('[role="dialog"] button:has-text("保存")')

// テーブル行内
const row = page.locator('tr').filter({ hasText: targetText });
row.locator('button:has(svg[data-icon="edit"])');
```

## §7. テーブル行のLocator

```typescript
// ❌ 不安定: accessible nameに依存
table.getByRole('row', { name: new RegExp(targetText) })

// ✅ 安定: テキストでフィルタリング
table.locator('tr').filter({ hasText: targetText })
```

## §8. フィルターの使い分け

```typescript
// ❌ hasNot は子要素チェック（テキスト除外には使えない）
.filter({ hasNot: page.getByText('すべて完全削除') })

// ✅ hasNotText でテキスト除外
.filter({ hasNotText: 'すべて' })

// 応用: 「編集」を選択（「一括編集」を除外）
page.getByRole('button', { name: /編集/ }).filter({ hasNotText: '一括' })
```

## §9. UIライブラリ固有セレクタ（プロジェクトに合わせて追記）

UIライブラリ固有のセレクタはここに追記する。
セマンティックLocatorを優先し、ライブラリ固有セレクタは補助的に使用。
ライブラリのバージョンアップでクラス名が変わる可能性に注意。

```typescript
// 例: Ant Design
// page.locator('.ant-modal-content')
// page.locator('.ant-select-item-option').filter({ hasText: optionText })

// 例: MUI (Material-UI)
// page.locator('.MuiDialog-root')
// page.locator('.MuiMenuItem-root').filter({ hasText: optionText })
```

## §10. constants.ts セレクタ定義方針

```typescript
// ❌ 汎用的すぎる（.first()が必要になる）
FIRST_CHECKBOX: 'input[type="checkbox"]',

// ✅ 具体的（.first()不要）
AGREEMENT_CHECKBOX: 'input[type="checkbox"]:near(:text("同意する"))',
```

**動的値はPageObject層で**:
```typescript
// ❌ constants.tsに動的値を入れない
USER_ROW: (name) => `tr:has-text("${name}")`,

// ✅ PageObjectで補完
async clickUser(name: string) {
  await this.page.locator(`tr:has-text("${name}")`).click();
}
```

## §11. `.first()` 具体的な対応手順

1. **最優先**: `data-testid`追加を開発チームに依頼
2. **次善**: `:near()` で周辺テキストから特定
3. **妥協**: 親要素で絞り込んでから `.first()`
4. **最終**: `.first()` + 詳細コメント + TODO

```typescript
// やむを得ない場合の書き方
// このダイアログには1つのチェックボックスのみ存在（YYYY-MM-DD確認）
// TODO: data-testid="agreement-checkbox" の追加を依頼（Issue #XXX）
page.locator('[role="dialog"] input[type="checkbox"]').first()
```
