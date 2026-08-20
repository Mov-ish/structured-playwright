# Ant Design Button のラベル罠（span 包み / 自動スペース挿入）

## 結論

**Ant Design の Button は「見えているラベル」と「DOM テキスト」を2段階で乖離させる。**
罠1（span 包み）は `:text-is` / `:text` を沈黙させ、罠2（自動スペース挿入）は正規表現以外の全テキスト一致手段を沈黙させる。どちらも「マッチ0件 → タイムアウト」という、エラーメッセージが真因を教えてくれない壊れ方をする。

**罠1は常に起きる。罠2は条件付き**（発動条件は下記）。この非対称を押さえておくと、対処を過剰にしないで済む。

## 罠1: ラベルは span に包まれる

```html
<button class="ant-btn"><span>保存</span></button>
```

文字列の children は無条件に span 化される（`autoInsertSpace` の設定とは独立）。つまり antd Button を使っている限り、この罠は常に有効。

| Locator | 結果 | 理由 |
|---|---|---|
| `button:text-is("保存")` | ❌ 0件 | `:text-is` は要素**直下**のテキストノードのみ判定。button 直下にテキストはない |
| `button:text("保存")` | ❌ 0件 | `:text` は条件を満たす**最小の要素**（= span）だけにマッチ |
| `button:has-text("保存")` | ✅ | 子孫込み全テキストで判定（入れ子を貫通する唯一のエンジン） |
| `getByRole('button', { name: '保存', exact: true })` | ✅ | アクセシブルネームは子孫から計算される（**葉の完全一致の既定**） |
| `getByText('保存', { exact: true })` | ✅（span にマッチ） | `getByText` の `exact` は子孫込み全テキスト判定。`:text-is` と違い span 包みを貫通する |

## 罠2: 漢字2文字ラベルに半角スペースが挿入される（autoInsertSpace）

Button のラベルが**ちょうど漢字2文字**（「検索」「保存」「削除」「編集」等）のとき、antd は DOM テキストに本物の半角スペースを挿入する。「検索」は DOM 上では「検 索」。中国語圏の視覚慣習（「确 定」）由来の仕様で、既定で有効。

判定は `/^[一-龥]{2}$/`（CJK 統合漢字の基本ブロックちょうど2文字）。かな混じり・3文字以上・「々」等は対象外。

**発動条件**（すべて満たしたときだけスペースが入る）:

- children がひとつだけ（複数要素を並べたラベルは対象外）
- `icon` prop なし（**アイコン付きボタンには入らない**）
- variant が `text` / `link` 以外（`type="text"` / `type="link"` のボタンには入らない）

裏を返すと、アイコン付きボタンで「検索」が見えているなら DOM も「検索」のままである。罠2 を疑う前に、まず実 DOM を確認すること。

```typescript
// ❌ すべて 0 件 → タイムアウト。DOM テキストは「検 索」
page.locator('button:text-is("検索")')
page.locator('button:has-text("検索")')                  // 部分一致ですら「検索」を含まない
page.getByRole('button', { name: '検索', exact: true })  // アクセシブルネームも「検 索」

// ✅ 生き残るのは正規表現のみ（スペースの有無どちらでも通る）
page.getByRole('button', { name: /^検\s*索$/ })
```

**`^` `$` のアンカーを省かないこと。** role の `name` に渡した正規表現は部分一致で評価されるため、`/検\s*索/` は「再検索」「検索条件」にも当たる。完全一致を既定にする方針の逃げ道が部分一致では意味がない。

「検 索」とリテラルで書くのは antd 設定への結合（アプリ側が autoInsertSpace を無効化した瞬間に逆に壊れる）。`\s*` を挟んだ正規表現が両対応。

Playwright の空白正規化は「連続空白を1個に畳む」処理であり、スペースを**消してはくれない**ことに注意。

## 対処の使い分け

| 状況 | 対処 |
|---|---|
| 漢字2文字以外のラベル（かな混じり・3文字以上） | `getByRole` + `name` + `exact: true`（罠1のみ考慮すればよい） |
| 漢字2文字ラベル・アイコンなし・`type` が text/link 以外 | `getByRole` + `name` + 正規表現 `/^X\s*Y$/` + 理由コメント |
| 漢字2文字ラベルだがアイコン付き / `type="text"` / `type="link"` | 罠2 は発動しない。`getByRole` + `name` + `exact: true` で足りる |
| 根本解決 | アプリ側で autoInsertSpace を切るよう開発チームに依頼（`data-testid` 依頼と同じ「根本解決の TODO の置き場所」） |

根本解決の書式は antd のバージョンで変わる:

```tsx
// antd 5.17 以降
<ConfigProvider button={{ autoInsertSpace: false }}>
// antd 4.x / 5.17 未満
<ConfigProvider autoInsertSpaceInButton={false}>
```
