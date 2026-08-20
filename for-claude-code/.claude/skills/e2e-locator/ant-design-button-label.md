# Ant Design Button のラベル罠（span 包み / 自動スペース挿入）

## 結論

**Ant Design の Button は「見えているラベル」と「DOM テキスト」を2段階で乖離させる。**
罠1（span 包み）は `:text-is` / `:text` を沈黙させ、罠2（自動スペース挿入）は正規表現以外の全テキスト一致手段を沈黙させる。どちらも「マッチ0件 → タイムアウト」という、エラーメッセージが真因を教えてくれない壊れ方をする。

## 罠1: ラベルは span に包まれる

```html
<button class="ant-btn"><span>保存</span></button>
```

| Locator | 結果 | 理由 |
|---|---|---|
| `button:text-is("保存")` | ❌ 0件 | `:text-is` は要素**直下**のテキストノードのみ判定。button 直下にテキストはない |
| `button:text("保存")` | ❌ 0件 | `:text` は条件を満たす**最小の要素**（= span）だけにマッチ |
| `button:has-text("保存")` | ✅ | 子孫込み全テキストで判定（入れ子を貫通する唯一のエンジン） |
| `getByRole('button', { name: '保存', exact: true })` | ✅ | アクセシブルネームは子孫から計算される（**葉の完全一致の既定**） |

## 罠2: 漢字2文字ラベルに半角スペースが挿入される（autoInsertSpace）

Button のラベルが**ちょうど漢字2文字**（「検索」「保存」「削除」「編集」等）のとき、antd は DOM テキストに本物の半角スペースを挿入する。「検索」は DOM 上では「検 索」。中国語圏の視覚慣習（「确 定」）由来の仕様で、既定で有効。

```typescript
// ❌ すべて 0 件 → タイムアウト。DOM テキストは「検 索」
page.locator('button:text-is("検索")')
page.locator('button:has-text("検索")')                  // 部分一致ですら「検索」を含まない
page.getByRole('button', { name: '検索', exact: true })  // アクセシブルネームも「検 索」

// ✅ 生き残るのは正規表現のみ（スペースの有無どちらでも通る）
page.getByRole('button', { name: /検\s*索/ })
```

「検 索」とリテラルで書くのは antd 設定への結合（アプリ側が autoInsertSpace を無効化した瞬間に逆に壊れる）。`\s*` を挟んだ正規表現が両対応。

Playwright の空白正規化は「連続空白を1個に畳む」処理であり、スペースを**消してはくれない**ことに注意。

## 対処の使い分け

| 状況 | 対処 |
|---|---|
| 漢字2文字以外のラベル（かな混じり・3文字以上） | `getByRole` + `name` + `exact: true`（罠1のみ考慮すればよい） |
| 漢字2文字ラベル | `getByRole` + `name` + 正規表現 `/X\s*Y/` + 理由コメント |
| 根本解決 | アプリ側 `<ConfigProvider button={{ autoInsertSpace: false }}>` を開発チームに依頼（`data-testid` 依頼と同じ「根本解決の TODO の置き場所」） |
