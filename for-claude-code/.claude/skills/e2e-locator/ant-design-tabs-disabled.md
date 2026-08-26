# Ant Design Tabs の disabled 罠

## 結論

**Ant Design Tabs の「中身が空のタブ」は `aria-disabled="true"` でクリック不可になる。**
それを知らずに `tab.click()` を呼ぶと Playwright の `click()` が actionable 待ちで**最大 test timeout（例: 600s）までハング**し、タイムアウト後に Fail する。「正しく Fail しているように見えるが、実際は数分〜10 分間のハング後に判明する」という最悪のフィードバックループになる。

## 背景: 観測される DOM

```html
<!-- 中身が空のタブ（例: ゴミ箱 / アーカイブ / 未読 等） -->
<div
  role="tab"
  aria-disabled="true"
  aria-selected="false"
  class="ant-tabs-tab-btn"
  id="rc-tabs-N-tab-archive"
>削除済み</div>
```

Playwright の `isEnabled()` は `aria-disabled="true"` を解釈して `false` を返す。
`click()` は内部で actionable 待ち（visible + enabled + stable）を行うため、enabled にならない要素を待ち続けてハングする。

## ❌ 失敗するパターン

```typescript
// ❌ 空のときハングする。Playwright のエラーログ:
//   - waiting for getByRole('tab', { name: '削除済み' })
//   - locator resolved to <div role="tab" aria-disabled="true" ...>削除済み</div>
//   - attempting click action
//     - element is not enabled
//     - retrying click action
//     - waiting 500ms
//     ...（タイムアウトまで永久に retry）
await page.getByRole('tab', { name: '削除済み' }).click();

// ❌ Action 層でラップしても挙動は同じ。tab.click 直後に削除など別操作を続けても、
//   そもそも切替が成功していないため到達しない
await navigationAction.switchTab('削除済み');
await action.permanentDeleteAll();  // 上でハングするのでここに到達しない
```

## ✅ 正解パターン: 切替の前に enabled をガードする

タブが空＝該当領域に項目が無い、というドメイン情報を**事前検証**してから切り替える。
ハングではなく即 Fail にすることで真因（前段のソフト削除フローが効いていない、データが想定と違う等）を即座に特定できる。

```typescript
// Page Object: タブの有効性チェック
async isTabEnabled(tabName: string): Promise<boolean> {
  const tab = this.page.getByRole('tab', { name: tabName });
  await tab.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  // isEnabled() は Promise<boolean>。async 関数内では return await で明示する
  // （スタックトレース改善と読み手の誤解防止）
  return await tab.isEnabled();  // aria-disabled を解釈して true/false 返却
}

// Action 層: verify メソッド（boolean を返す。expect は書かない）
async hasItemsInTab(tabName: string): Promise<boolean> {
  return this.pageObject.isTabEnabled(tabName);
}

// Test 層: 切替の "前" に expect で fail-fast
expect(await action.hasItemsInTab('削除済み')).toBeTruthy();
await navigationAction.switchTab('削除済み');
expect(await action.isItemVisible(targetName)).toBeTruthy();
await action.permanentDeleteAll();
expect(await action.isItemHidden(targetName)).toBeTruthy(); // 完全削除の事後検証
```

## なぜ事前ガードが必要か

| アプローチ | 空タブを叩いたとき | 偽陽性リスク | 原因切り分け |
|---|---|---|---|
| `switchTab` を直接呼ぶ | test timeout までハング後 Fail | なし（Fail はする） | **困難**：ハングの原因が空タブか Locator か不明 |
| `hasItemsInTab()` 事前 expect | 即 expect 失敗 | なし | **明確**：「該当領域に項目が無い＝前段フローが効いていない」と即判明 |

## 他のタブ・他の画面への展開

このパターンは Ant Design Tabs 全般に応用できる。「中身ゼロでタブが無効化される」UI（例: 通知一覧の「未読」、課題一覧の「期限切れ」、ファイル管理の「アーカイブ」など）でも同じ罠が発生する可能性があり、その場合は同じ手順で事前ガードする。

判定の汎用形は上記 `isTabEnabled(tabName)` で、タブ名を引数化すれば再利用可能。

## 関連 UI ライブラリでの類似パターン

`aria-disabled` でクリック不可にする UI はライブラリを問わず広く存在する。代表例:

- **MUI Tabs**: `<Tab disabled>` は `aria-disabled="true"` を付与
- **Headless UI**: `disabled` prop が同様
- **Radix UI Tabs**: `data-disabled` を別途付与

いずれも Playwright の `isEnabled()` が解釈するため、同じガードパターンで対処できる。

## 関連事項

- `prohibited-patterns.md` 「ハングという形の偽陽性」: 同じ思想で禁止。
- `locator-principles.md` 「Locatorの本質」の未来値（Future）: `isEnabled()` 自体は即時評価で OK だが、可視性の `waitFor({state:'visible'})` を先に挟むのが安全（Future 値で取得可能になるまで待ってから判定）。
