---
name: e2e-review
description: "E2Eテストコードレビュー用Skill。コードレビュー・PR確認・品質チェック時に使用。MUST FIX/SHOULD FIX判定基準・禁止事項一覧・.catch隠蔽問題・よくあるエラーと対処法・FAQを含む。"
---

# E2E Code Review Skill

> **コードレビュー時に使用。** Locator設計の詳細判断は `e2e-locator` Skill を参照。

---

## §1. MUST FIX（必須修正 — これがあればPR差し戻し）

### セキュリティ
- [ ] 認証情報がハードコードされていない
- [ ] `.env`が`.gitignore`に含まれている

### 定数管理
- [ ] constants.tsから`TIMEOUTS`・`SELECTORS`・`URL_PATTERNS`をインポート
- [ ] タイムアウト値が直接記述されていない（`2000`, `10000`等）
- [ ] 共通セレクタが直接記述されていない
- [ ] URLパターンが直接記述されていない

### Locator
- [ ] `text=`ロケータを使用していない
- [ ] 優先順位に従っている
- [ ] 意味層の薄い要素に`:near()`や`svg[data-icon]`を使用
- [ ] 構造依存セレクタを避けている

### Page Objects
- [ ] `readonly`で定義（`private readonly`は禁止）
- [ ] ビジネスロジック・expect()を含めていない

### Actions
- [ ] 各ステップで`console.log`出力
- [ ] LoginActionはログイン成功検証を実装
- [ ] expect()を使用していない（waitFor()は許可）

### Tests
- [ ] Fixtureから`test`/`expect`をインポート（`@playwright/test`直接は禁止）
- [ ] Actionを手動`new`せずFixture引数で受け取り
- [ ] Locatorを直接記述していない

### Fixture
- [ ] 新規ActionがFixtureに登録されている

### エラーハンドリング
- [ ] `.catch(() => false)` パターンを使用していない（§4参照）

---

## §2. SHOULD FIX（推奨修正）

- [ ] `.first()`使用時にコメント + TODO
- [ ] `waitForTimeout`使用時に理由コメント + TIMEOUTS定数
- [ ] `:has-text()`ではなく`:text-is()`（完全一致）を検討したか
- [ ] Local Universe（親要素絞り込み）を活用
- [ ] AAAパターン、結果検証、データクリーンアップ

---

## §3. よくあるエラーと解決策

### `Target page, context or browser has been closed`
**原因**: URL遷移を待たずに要素操作（外部認証遷移時に多発）
```typescript
// ✅ waitForURL + 安定化待機を入れる
await this.page.waitForURL(URL_PATTERNS.EXTERNAL_AUTH_LOGIN, { timeout: TIMEOUTS.DEFAULT });
await this.page.waitForTimeout(TIMEOUTS.EXTERNAL_AUTH_STABILIZATION);
```

### `Timeout exceeded`
**原因**: SPA描画待機不足 / モーダルアニメーション / セレクタ誤り
```typescript
// ✅ networkidle + SPA_RENDERING
await page.waitForLoadState('networkidle');
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
```

### `Element is not visible / outside of the viewport`
```typescript
// ✅ アニメーション完了待ち + スクロール + force
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
await button.scrollIntoViewIfNeeded();
await button.click({ force: true });
```

### `strict mode violation`
**原因**: `:has-text()`の部分一致で複数マッチ
```typescript
// ✅ 完全一致 or 親要素で絞り込み
page.locator('span:text-is("ログイン")')
page.locator('[role="dialog"] span:has-text("ログイン")')
```

### セマンティックLocatorで要素が見つからない
**原因**: 意味層の薄い要素（`aria-label`/`label`がない）
```typescript
// ✅ :near() or svg[data-icon]
page.locator('input[type="checkbox"]:near(:text("同意する"))')
```

### エラーバナー / アラート検出
**用途**: 操作失敗時のエラー表示確認（レビューで検証漏れを指摘する際に使用）
```typescript
// ✅ role="alert" で検出（セマンティック）
await expect(page.locator('[role="alert"]')).toBeVisible();
await expect(page.locator('[role="alert"]')).toContainText('エラーメッセージ');

// UIライブラリ固有のメッセージ/トースト（例: Ant Design）
await expect(page.locator('.ant-message')).toBeVisible();  // プロジェクトのUIライブラリに合わせて変更
```

### 不安定な操作のリトライ
**用途**: クリック失敗が散発するフレーキーテストへの対処
```typescript
async clickWithRetry(locator: Locator, maxRetries: number = 3): Promise<void> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await locator.click({ timeout: TIMEOUTS.SHORT });
      return;
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      console.log(`⚠️ クリック失敗、リトライ ${i + 1}/${maxRetries}`);
      await this.page.waitForTimeout(1000);
    }
  }
}
```

---

## §4. `.catch(() => false)` 隠蔽パターン（絶対禁止）

AI Coding Toolが大量生成しがち。タイムアウトが隠蔽され false positive になる。

**検出**: `grep -rn ".catch(() => false)" src/` — 5箇所以上ならAIコピペを疑う

```typescript
// ❌ 危険
const isVisible = await element.isVisible({ timeout: 5000 }).catch(() => false);

// ✅ 正しい
try {
  await expect(element).toBeVisible({ timeout: TIMEOUTS.CHECK });
  await element.click();
} catch {
  // Optional element, skip
}
```

---

## §5. 禁止事項クイックリファレンス

| 禁止 | 代替 |
|------|------|
| 認証情報ハードコード | .env |
| タイムアウト数値ハードコード | TIMEOUTS定数 |
| `private readonly` Locator | `readonly` |
| Actionログ省略 | 各ステップconsole.log |
| ログイン成功検証省略 | URL検証ロジック |
| `.first()` 安易使用 | `:near()` / 具体的セレクタ |
| `text=` ロケータ | `:has-text()` / getByRole |
| `@playwright/test`直接import | Fixture経由 |
| Action手動new | Fixture引数 |
| `.catch(() => false)` | expect + try-catch |
| XPath | CSS + セマンティック |

---

## §6. FAQ

**Q: Action層でwaitFor()は使える？**
A: はい。waitFor()は待機操作でアサーションではない。禁止はexpect()。
verifyメソッドパターン: Action層でwaitFor()→boolean返却、Test層でexpect()。

**Q: 意味層の厚さとは？**
A: HTML要素のセマンティック情報の充実度。厚い（モーダル、テキストボタン）→セマンティックLocator可。薄い（ラベルなしチェックボックス）→`:near()`/`svg[data-icon]`。

**Q: E2ETest_Framework.mdとCLAUDE.mdが矛盾したら？**
A: CLAUDE.mdを優先。

---

## §7. レビュー手順

1. §1のMUST FIXチェックリストを上から確認
2. `grep -rn ".catch"` で§4のパターン検出
3. §2のSHOULD FIX確認
4. Locator指摘が必要なら `e2e-locator` Skill参照
5. 指摘は「理由」+「正しい実装例」をセットで


---

## 追記エリア

新しいパターンを発見した場合、以下の形式で追記する。

### YYYY-MM-DD - パターン名
- **発見の経緯**: （何をして、何が起きたか）
- **解決策**: （コード例）
- **注意事項**: （適用条件・制約）
