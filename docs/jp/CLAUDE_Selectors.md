# CLAUDE_Selectors.md - セレクタ戦略・パターン集

**最終更新**: 2026-01-13

---

## 📘 このドキュメントについて

このドキュメントは、**このプロジェクト固有のセレクタ戦略とパターン**を記載しています。

**対象**：
- Claude.code / CodexCLIによるコード生成
- AIレビュー時の基準
- 開発者の実装時の参照

**メインルールブック**：👉 [CLAUDE.md](./CLAUDE.md)
**詳細なLocator設計思想**：👉 [locator_strategy.md](./LOCATOR/locator_strategy.md)

---

## § 1. このプロジェクトのセレクタ戦略

### 1.1 ルール化の背景

**日付**: 2025-10-01（2026-01-13 更新）
**発見**: Playwright推奨のセレクタ（data-testid、セマンティック）が一部の要素で動作しない
**原因**: 既存HTMLの一部要素に以下の属性が不足：
- `data-testid`属性（全体的に不足）
- `aria-label`属性（チェックボックス、アイコンボタン等で不足）
- 適切な`label`要素（フォーム要素で不足）

**試行錯誤**: フロントエンドチームに属性追加を依頼 → 優先度の問題で対応困難
**結論**: 要素の「意味層の厚さ」に応じてセマンティックロケータとCSSセレクタを使い分ける

---

### 1.2 このプロジェクトでのセレクタ優先順位

| 優先順位 | セレクタ種類 | 使用可否 | 理由・用途 |
|---------|------------|---------|------|
| ❌ 1 | data-testid | **使用不可** | HTMLに存在しない |
| ✅ 2 | セマンティック（getByRole等） | **条件付き使用可** | モーダル、テキスト付きボタン、placeholder付き入力欄で有効 |
| ✅ 3 | CSSセレクタ + :has-text() / :text-is() | **推奨** | テキストで要素を特定 |
| ✅ 4 | :near() セレクタ | **推奨** | 意味層の薄い要素（チェックボックス等）に最適 |
| ✅ 5 | svg[data-icon] | **推奨** | アイコンボタンに有効 |
| ✅ 6 | 属性セレクタ（name, type） | **推奨** | フォーム要素に有効 |
| ✅ 7 | 親要素絞り込み（Local Universe） | **推奨** | モーダル内要素、行内要素に有効 |
| ⚠️ 8 | 構造セレクタ | **最終手段** | 変更に弱い、コメント必須 |

### 1.3 意味層の厚さによる判断基準

| 意味層 | 要素の例 | 推奨ロケータ |
|-------|---------|-------------|
| **厚い** | モーダル、テキスト付きボタン | `getByRole('dialog')`, `getByRole('button', { name: '...' })` |
| **中程度** | テキストリンク、入力欄 | `:has-text()`, `:text-is()`, `getByPlaceholder()` |
| **薄い** | チェックボックス、ラジオ | `:near()` セレクタ |
| **なし** | アイコンボタン | `svg[data-icon]` |

---

### 1.4 基本セレクタパターン

#### ✅ 推奨パターン1：セマンティックロケータ（意味層が厚い要素）

```typescript
// モーダル
page.getByRole('dialog', { name: 'テキストを追加' })
page.getByRole('dialog')  // 名前なしでも可

// テキスト付きボタン
page.getByRole('button', { name: '保存' })
page.getByRole('button', { name: /削除|delete/ })

// placeholder付き入力欄
page.getByPlaceholder('検索')
page.getByPlaceholder('メールアドレスを入力')
```

**用途**：意味層が厚い要素（role, name, placeholderが設定されている）

#### ✅ 推奨パターン2：:has-text() / :text-is()

```typescript
// 部分一致（:has-text）
page.locator('button:has-text("ログイン")')
page.locator('a:has-text("マイページ")')

// 完全一致（:text-is）- 複数マッチを避けたい場合
page.locator('span:text-is("マイページ")')
page.locator('button:text-is("保存")')
```

**注意**：`:has-text()`は部分一致のため、複数要素がマッチする可能性あり。`:text-is()`で完全一致を推奨。

#### ✅ 推奨パターン3：:near() セレクタ（意味層が薄い要素）

```typescript
// チェックボックス（labelがない場合）
page.locator('input[type="checkbox"]:near(:text("同意する"))')
page.locator('input[type="checkbox"]:near(:text("通知を受け取る"))')

// ラジオボタン
page.locator('input[type="radio"]:near(:text("はい"))')
```

**用途**：意味層の薄い要素（label, aria-labelがない）。周辺テキストで特定。

#### ✅ 推奨パターン4：svg[data-icon]（アイコンボタン）

```typescript
// アイコンボタン
page.locator('button:has(svg[data-icon="edit"])')
page.locator('button:has(svg[data-icon="delete"])')
page.locator('button:has(svg[data-icon="ellipsis"])')  // 三点リーダー
page.locator('button:has(svg[data-icon="close"])')
```

**用途**：テキストがないアイコンボタン。UIライブラリの内部属性を利用。

#### ✅ 推奨パターン5：属性セレクタ

```typescript
// name属性（Auth0フォーム等）
page.locator('input[name="username"]')
page.locator('input[name="password"]')

// type属性
page.locator('input[type="email"]')
page.locator('input[type="checkbox"]')
```

#### ✅ 推奨パターン6：親要素で絞り込み（Local Universe）

```typescript
// モーダル内のボタン
page.locator('[role="dialog"] button:has-text("保存")')
page.locator('[role="dialog"] input[type="checkbox"]')

// テーブル行内の要素
const row = page.locator('tr:has-text("TypeScript入門")');
row.locator('button:has(svg[data-icon="edit"])');
```

**用途**：同じ文言が複数存在する場合。親要素でスコープを限定。

---

### 1.5 XPath → CSS変換の注意点

**重要**：`text()='...'` と `:has-text()` は動作が異なる！

```typescript
// ❌ 間違い：完全一致 → 部分一致
page.locator(`//span[text()='ログイン']`)
→ page.locator(`span:has-text("ログイン")`) // 「ログインする」「再ログイン」もマッチ！

// ✅ 正しい：完全一致 → 完全一致
page.locator(`//span[text()='ログイン']`)
→ page.locator(`span:text-is("ログイン")`) // 「ログイン」のみマッチ
```

---

## § 2. constants.ts セレクタ定義集

### 2.1 セレクタ定義の方針

**原則**：静的なセレクタは、一意に特定できるように具体的に定義し、`.first()`を削減する

#### ❌ 非推奨：汎用的すぎる定義

```typescript
// 古いアプローチ（非推奨）
export const SELECTORS = {
  FIRST_CHECKBOX: 'input[type="checkbox"]',  // .first()が必要
  FIRST_TEXT_INPUT: 'input[type="text"]',    // .first()が必要
}
```

#### ✅ 推奨：具体的な定義

```typescript
// 新しいアプローチ（推奨）
export const SELECTORS = {
  // モーダルなどの共通要素
  MODAL: '[role="dialog"]',
  SUBMIT_BUTTON: 'button[type="submit"]',
  
  // ページごとに具体的に定義（.first()不要）
  AGREEMENT_CHECKBOX: 'input[type="checkbox"]:near(:text("同意する"))',
  AUTH0_EMAIL_INPUT: 'input[name="username"]',
  AUTH0_PASSWORD_INPUT: 'input[name="password"]',
  AUTH0_SUBMIT_BUTTON: 'button[type="submit"], button:has-text("続ける"), button:has-text("ログイン")',
  
  CONFIRM_CHECKBOX: '[role="dialog"] input[type="checkbox"]:near(:text("下記事項を確認"))',
  NOMINATED_COURSE_BUTTON: '[role="dialog"] button:has-text("指名コース")',
} as const;
```

---

### 2.2 現在定義されているセレクタ

#### 共通要素

```typescript
export const SELECTORS = {
  // モーダル
  MODAL: '[role="dialog"]',
  
  // ボタン
  SUBMIT_BUTTON: 'button[type="submit"]',
  
  // その他共通要素
  // ...
} as const;
```

#### Auth0関連

```typescript
// Auth0ログインページ
AUTH0_EMAIL_INPUT: 'input[name="username"]',
AUTH0_PASSWORD_INPUT: 'input[name="password"]',
AUTH0_SUBMIT_BUTTON: 'button[type="submit"], button:has-text("続ける"), button:has-text("ログイン")',
```

#### 同意チェックボックス関連

```typescript
// 同意チェックボックス（:near() で周辺テキストから特定）
AGREEMENT_CHECKBOX: 'input[type="checkbox"]:near(:text("同意する"))',
```

#### モーダル内要素

```typescript
// 確認チェックボックス
CONFIRM_CHECKBOX: '[role="dialog"] input[type="checkbox"]:near(:text("下記事項を確認"))',

// 指名コースボタン
NOMINATED_COURSE_BUTTON: '[role="dialog"] button:has-text("指名コース")',
```

---

### 2.3 新しいセレクタの追加ガイドライン

新しいセレクタパターンを追加する際は、以下の形式で記録してください：

```markdown
### [追加日] - [要素名]

**発見の経緯**：
- どのテストで必要になったか
- なぜこのセレクタが必要だったか

**試行錯誤**：
- 最初に試したセレクタ → 失敗した理由
- 次に試したセレクタ → 失敗した理由
- 最終的に採用したセレクタ → 成功した理由

**セレクタ定義**：
```typescript
ELEMENT_NAME: 'selector',
```

**使用例**：
```typescript
page.locator(SELECTORS.ELEMENT_NAME)
```
```

---

## § 3. `.first()`使用ルール

### 3.1 基本方針：できる限り避ける

**`.first()`の危険性**：
- ❌ 一度テストがPassすると、誰も修正しない（技術的負債化）
- ❌ UI変更時に突然失敗し、原因特定が困難
- ❌ 保守性が著しく低下し、将来の変更コストが増大

---

### 3.2 推奨対応（優先順位順）

#### 1. **最優先**：data-testid属性の追加依頼

```markdown
フロントエンドチームに依頼：
「data-testid="terms-checkbox" を追加してください（Issue #123）」
```

#### 2. **次善策**：`:near()` セレクタで周辺要素から特定

```typescript
// ✅ 周辺テキストから一意に特定
page.locator('input[type="checkbox"]:near(:text("同意する"))')
```

#### 3. **妥協策**：親要素で十分に絞り込んでから`.first()`

```typescript
// ✅ モーダル内に絞り込んでから.first()
page.locator('[role="dialog"] input[type="checkbox"]').first()
```

#### 4. **最終手段**：`.first()` + 詳細コメント + TODO

```typescript
// ✅ やむを得ない場合は詳細コメント必須
this.agreeCheckbox = page
  .locator('[role="dialog"] input[type="checkbox"]')
  .first();
// TODO: data-testid="agreement-checkbox" の追加を依頼（Issue #123）
// 理由: モーダル内に複数チェックボックスが存在するが、
//       最初の要素が常に同意チェックボックスであることを確認済み（2025-10-15）
```

---

### 3.3 `.first()`削減の実例

| 項目 | 改善前 | 改善後 |
|------|--------|--------|
| **総セレクタ数** | 20個 | 6個 |
| **`.first()`使用** | 14箇所 | 1箇所（動的な値） |
| **保守性** | 低い | 高い |

**改善アプローチ**：
- 汎用的セレクタ → 具体的セレクタ
- `:near()` セレクタの活用
- 親要素での絞り込み

---

## § 4. セレクタパターン集

### 4.1 フォーム要素

#### チェックボックス

```typescript
// ✅ 推奨：周辺テキストで特定
page.locator('input[type="checkbox"]:near(:text("同意する"))')

// ⚠️ 許容：親要素で絞り込み
page.locator('[role="dialog"] input[type="checkbox"]').first()
// TODO: より具体的なセレクタに置き換え
```

#### テキスト入力

```typescript
// ✅ 推奨：name属性で特定
page.locator('input[name="username"]')
page.locator('input[name="password"]')

// ⚠️ 許容：placeholder + 親要素
page.locator('[role="dialog"] input[placeholder*="メール"]')
```

#### ボタン

```typescript
// ✅ 推奨：テキスト + type属性
page.locator('button[type="submit"]:has-text("ログイン")')

// ✅ 推奨：親要素で絞り込み
page.locator('[role="dialog"] button:has-text("保存")')

// ✅ 許容：複数候補を指定
page.locator('button[type="submit"], button:has-text("続ける"), button:has-text("ログイン")')
```

---

### 4.2 アイコンボタン（SVG）

**問題**：3点リーダーボタン（...）などのアイコンボタンには、テキストやaria-labelが無い

**解決策**：SVGアイコンの`data-icon`属性でフィルタリング

```typescript
// ✅ Ellipsisアイコンを含むボタン
page.getByRole('button').filter({ has: page.locator('svg[data-icon="ellipsis"]') })

// ✅ Editアイコンボタン
page.getByRole('button').filter({ has: page.locator('svg[data-icon="edit"]') })

// ✅ Deleteアイコンボタン
page.getByRole('button').filter({ has: page.locator('svg[data-icon="delete"]') })

// ✅ Closeアイコンボタン
page.getByRole('button').filter({ has: page.locator('svg[data-icon="close"]') })
```

---

### 4.3 モーダル内要素

```typescript
// モーダル表示を待つ
await page.locator(SELECTORS.MODAL).waitFor({ state: 'visible', timeout: TIMEOUTS.SHORT });
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION); // アニメーション完了

// モーダル内の要素を操作
await page.locator('[role="dialog"] button:has-text("保存")').click();
```

---

### 4.4 動的な値を扱う要素

**原則**：動的な値（実行時に決まる値）は、Page Object内で処理し、`.first()`の使用もやむを得ない

```typescript
/**
 * コース名をクリック（動的な値）
 * @param courseName - クリックするコース名
 */
async clickCourseName(courseName: string): Promise<void> {
  // 注意: 動的な値のため、.first()の使用は避けられない
  // 理想的には、コースIDやdata-testid属性で特定すべき
  await this.page.locator(`a:has-text("${courseName}")`).first().click();
  // TODO: data-testid="course-{courseId}" による特定を検討（Issue #XXX）
}
```

---

## § 5. AIレビューチェックリスト

Claude.code、CodexCLI、Cursor等がコードレビューする際は、以下を確認すること。

### 5.1 MUST FIX（必須修正）

#### セキュリティ
- [ ] 認証情報がハードコードされていない
- [ ] `.env`ファイルが`.gitignore`に含まれている

#### 定数管理
- [ ] **constants.tsからTIMEOUTS、SELECTORS、URL_PATTERNSをインポートしている**
- [ ] タイムアウト値が直接記述されていない（`2000`, `10000`など）
- [ ] 共通セレクタが直接記述されていない（`'button[type="submit"]'`など）
- [ ] URLパターンが直接記述されていない（`'**/login**'`など）

#### ロケータ
- [ ] `text=`ロケータを使用していない
- [ ] ロケータ優先順位に従っている（セマンティック → :has-text() → :near() → data-icon）
- [ ] 意味層の薄い要素には`:near()`や`svg[data-icon]`を使用している
- [ ] 構造依存のセレクタを避けている
- [ ] 共通セレクタは`SELECTORS`から読み込んでいる

#### Page Objects
- [ ] `readonly`でロケーター定義している（`private readonly`は禁止）

#### Actions
- [ ] 各ステップでconsole.log出力している
- [ ] LoginActionはログイン成功検証を実装している

### 5.2 SHOULD FIX（推奨修正）

#### コード品質
- [ ] **`.first()`使用時にコメントあり**
  - なぜ最初の要素で良いか説明
  - TODO でリファクタリング計画を明記

- [ ] **waitForTimeout使用時にコメントあり**
  - なぜ必要か説明
  - TIMEOUTS定数を使用

- [ ] 意味層の厚さに応じたロケータを選択している
- [ ] 汎用的すぎるセレクタではなく、具体的なセレクタを使用している
- [ ] Local Universe（親要素での絞り込み）を活用している

#### テスト品質
- [ ] AAAパターンに従っている
- [ ] 結果検証が実装されている
- [ ] データクリーンアップが実装されている（必要な場合）

### 5.3 INFO（情報）

- [ ] **成功パターンを参照しているか**
  - test2（ログインフロー）
  - test（セレクタ定義）
  - test5（モーダル処理）
- [ ] CLAUDE_Patterns.mdの実装パターンを参考にしているか

---

## § 6. 新パターン追記エリア

### [日付] - [要素名]

**発見の経緯**：  
**試行錯誤**：  
**セレクタ定義**：  
**使用例**：  

---

## License

MIT License

---

**最終更新**: 2026-01-13
**管理者**: QA Team
