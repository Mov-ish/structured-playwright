---
name: e2e-review
description: "E2Eコードレビュー用。PR確認・品質チェック時に使用。MUST FIX/SHOULD FIXチェックリスト・エラーメッセージ別対処法・.catch隠蔽問題の検出方法・FAQを含む。禁止事項の詳細は .claude/rules/prohibited-patterns.md を参照。"
---

# E2E Code Review Skill

> 禁止事項・4層責務・Locator原則は rules/（常時読み込み済み）。
> このSkillは**レビュー手順とチェックリスト**に特化。

## §1. レビュー手順

1. §2のMUST FIXチェックリストを上から確認
2. `grep -rn ".catch(() =>" src/` で§4のパターン検出
3. §3のSHOULD FIX確認
4. Locator具体指摘が必要なら `/e2e-locator` Skill参照
5. 指摘は「理由」+「正しい実装例」をセットで

---

## §2. MUST FIX（PR差し戻し基準）

### セキュリティ
- [ ] 認証情報がハードコードされていない
- [ ] `.env`が`.gitignore`に含まれている

### 定数管理
- [ ] `TIMEOUTS`・`SELECTORS`・`URL_PATTERNS`をconstants.tsからインポート
- [ ] タイムアウト数値・URLパターン・共通セレクタが直書きされていない

### Locator
- [ ] `text=` ロケータ未使用
- [ ] 優先順位に従っている（rules参照）
- [ ] 構造依存セレクタを避けている
- [ ] data-testidがある要素ではdata-testidを使用している
- [ ] 意味層の薄い要素に `:near()` / `svg[data-icon]` を使用

### 4層責務
- [ ] Page Object: `readonly`（`private readonly`禁止）、expect/waitForTimeout未使用
- [ ] Action: 各ステップ`this.step()`でログ記録（`console.log`単体は禁止）、expect未使用、LoginAction はログイン成功検証あり
- [ ] Fixture: `stepCounter` が worker スコープで定義されている（`scope: 'worker'`）
- [ ] Test: Fixture経由import、Fixture引数でAction取得、Locator直書きなし
- [ ] 新規Action → Fixtureに登録済み、かつ TODO → 実装済みセクションに昇格済み

### エラーハンドリング
- [ ] `.catch(() => false)` パターン未使用（§4参照）

### テスト条件の黙殺
- [ ] テストが明示的に要求した操作（引数・パラメータで指定）が見つからない場合に Fail するか（スキップして Pass は偽陽性）

---

## §3. SHOULD FIX

- [ ] `.first()` にコメント + TODO
- [ ] `waitForTimeout` に理由コメント + TIMEOUTS定数
- [ ] `:has-text()` → `:text-is()`（完全一致）を検討したか
- [ ] Local Universe（親要素絞り込み）活用
- [ ] AAAパターン、結果検証、データクリーンアップ
- [ ] テスト名が具体的か
- [ ] `.spec.ts` にテスト手順ヘッダーコメントがあるか（Phase・手順番号・検証ポイント）
- [ ] 各 Phase に `[Arrange]` / `[Act]` / `[Cleanup]` タグが付いているか（データ準備とテスト本体の区別）
- [ ] `this.step()` を使う public メソッドに `this.beginAction()` があるか（ステップ番号付与）

---

## §4. `.catch(() => false)` 検出と修正

**検出**:
```bash
grep -rn ".catch(() => false)" src/
grep -rn ".catch(() => true)" src/
```
5箇所以上 → AIコピペを強く疑う。

**修正**:
```typescript
// ❌
const isVisible = await element.isVisible({ timeout: 5000 }).catch(() => false);

// ✅
try {
  await expect(element).toBeVisible({ timeout: TIMEOUTS.CHECK });
  await element.click();
} catch {
  // Optional element, skip
}
```

---

## §5. エラーメッセージ別対処

### `Target page, context or browser has been closed`
**原因**: URL遷移未待機（外部認証遷移時に多発）
```typescript
await this.page.waitForURL(URL_PATTERNS.AUTH_LOGIN, { timeout: TIMEOUTS.DEFAULT });
await this.page.waitForTimeout(TIMEOUTS.AUTH_STABILIZATION);
```

### `Timeout exceeded`
**原因**: SPA描画待機不足 / モーダルアニメーション / セレクタ誤り
```typescript
await page.waitForLoadState('networkidle');
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
```

### `Element is not visible / outside of the viewport`
```typescript
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
await button.scrollIntoViewIfNeeded();
await button.click({ force: true });
```

### `strict mode violation`
**原因**: `:has-text()`部分一致で複数マッチ
```typescript
page.locator('span:text-is("ログイン")')                    // 完全一致
page.locator('[role="dialog"] span:has-text("ログイン")')    // スコープ絞り
```

---

## §6. FAQ

**Q: Action層でwaitFor()は使える？**
はい。waitFor()は待機操作でアサーションではない。禁止はexpect()のみ。

**Q: 意味層の厚さとは？**
要素のセマンティック情報の充実度。厚い（data-testidあり、ラベル付きフォーム、テキストボタン）→セマンティックLocator可。薄い（ラベルなしチェックボックス、アイコンのみボタン）→`:near()`/data属性。プロジェクト導入時にUI全体の意味層の厚さを評価すること。

**Q: waitForTimeoutは使っていい？**
はい。SPA/外部認証/モーダルでは必要。TIMEOUTS定数+理由コメントが条件。

**Q: `.first()`は常にダメ？**
できる限り避ける。使う場合: 親要素で絞り込み + 理由コメント + TODO。

**Q: 既存コードがルール違反していたら？**
コピーせず正しいパターンで実装。可能なら既存も修正。
