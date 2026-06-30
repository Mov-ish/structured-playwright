# Select コンポーネントのポータル問題（UI ライブラリ共通）

## 背景: 2層構造

多くの UI ライブラリ（Ant Design / MUI / Headless UI 等）は Select / Combobox のドロップダウンを**2層構造**で描画する：

| 層 | 要素 | 可視性 | 用途 |
|----|------|--------|------|
| listbox層 | `<div role="option">` | **非表示**（viewport外） | アクセシビリティ（スクリーンリーダー用） |
| ポータル層 | ライブラリ固有クラス（例: Ant Design `.ant-select-item-option`） | **表示** | 実際のUI。ダイアログ外のルートDOMに描画 |

ポータル層はダイアログ外（`body` 直下など）にレンダリングされるため、モーダルスコープで探すと見つからない。

## ❌ 失敗するパターン

```typescript
// ❌ option role は非表示 → waitFor('visible') がタイムアウト
await page.getByRole('option', { name: targetName }).click();

// ❌ force:true でも「Element is outside of the viewport」エラー
await page.getByRole('option', { name: targetName }).click({ force: true });

// ❌ fill() で検索 API の debounce が正しくトリガーされず、ローディングが永続する
await combobox.fill(targetName);
await page.locator('.ant-select-item-option').filter({ hasText: targetName }).click();
```

## ✅ 正解パターン

```typescript
// combobox を開いて、ポータル側の表示要素を直接クリック
const modal = page.getByRole('dialog');
const combobox = modal.getByRole('combobox');
await combobox.click();
// ポータルは dialog 外にレンダリングされるため page スコープで取る
const option = page.locator('.ant-select-item-option')  // 例: Ant Design
  .filter({ hasText: targetName }).first();
await option.click();
// ドロップダウンを閉じる
await page.keyboard.press('Escape');
```

**ポイント**:
- `fill()` は使わない — combobox を click で開いてから、表示されたオプションを直接選択する
- オプションの Locator は `page.locator()`（モーダルスコープではなくページ全体）— ポータルはダイアログ外に描画されるため
- `.first()` を付ける場合は曖昧マッチの応急処置（カテゴリA）。まず **exact 一致**で曖昧性を消せないか検討する
  - `filter({ has: page.getByText(name, { exact: true }) })` — リテラル一致でメタ文字に安全（`new RegExp(...)` は避ける。名前に `[` `]` `.` `(` `)` 等が含まれると正規表現メタ文字と解釈されて完全一致が壊れる）
  - exact 一致で消せず `.first()` を残す場合は**理由コメント + TODO** が必須（`prohibited-patterns.md`「ordinal セレクタの許容境界」/ `e2e-locator` §11）

## 検索が必要な場合

オプションが多くスクロールが必要な場合は `pressSequentially` を試す：

```typescript
await combobox.click();
await combobox.pressSequentially(targetName, { delay: 100 });
// debounce 完了を待つ
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
// ライブラリ固有のオプションクラスで取得（例: Ant Design）
const option = page.locator('.ant-select-item-option')
  .filter({ hasText: targetName }).first();
await option.click();
```

## テストデータの注意

- 対象名が長いと UI で**省略表示**される（`text-overflow: ellipsis`）→ `:text-is()` でマッチしない
- テストデータには**短い名前**を使うと安定する

## ライブラリごとのオプションクラス

プロジェクト導入時に使用している UI ライブラリのポータルクラスを確認し、上記パターンのクラス名部分を置き換える。

| ライブラリ | ポータルオプションクラスの例 |
|------------|------------------------------|
| Ant Design | `.ant-select-item-option` |
| MUI (Material-UI) | `.MuiMenuItem-root` |
| Headless UI | `[role="option"]`（ポータル展開後に表示されるもの） |
