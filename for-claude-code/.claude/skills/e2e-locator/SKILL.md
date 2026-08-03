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

**⚠️ ポータルレンダリング Select の罠**: 多くの UI ライブラリ（Ant Design / MUI / Headless UI 等）は、Select / Combobox のドロップダウンを `body` 直下のポータルにレンダリングする。

- `getByRole('option')` は **非表示の元 select 要素** にもマッチし、クリックできない場合がある
- `combobox.fill()` は検索 debounce が発火しない場合がある
- 解決策: ドロップダウンを click で開いてから、ポータル側の表示要素を直接クリックする

```typescript
// ❌ option role は非表示要素にマッチ
await page.getByRole('option', { name: targetName }).click();
// ❌ fill() で検索が発火しない場合がある
await combobox.fill(targetName);

// ✅ ドロップダウン展開 → ポータル側の表示要素を直接クリック
await combobox.click();
await page.locator('.ant-select-item-option')   // ライブラリ固有クラス
  .filter({ hasText: targetName }).first().click();
```

→ 詳細（2層構造の背景・検索が必要な場合・省略表示の注意・ライブラリ別クラス表）は [ant-design-select.md](./ant-design-select.md) 参照

**⚠️ 漢字2文字ラベルの自動スペース挿入で `:text-is()` が落ちる罠**: Ant Design の Button は、アイコンなしでラベルが**ちょうど漢字2文字**のとき、自動で文字の間に空白を挿入する（v4: ConfigProvider の `autoInsertSpaceInButton` / v5: `autoInsertSpace`。既定で有効）。DOM 上のテキストは `保 存` になるため、`:text-is("保存")` も `getByRole('button', { name: '保存' })` もマッチしない。3文字以上（「保存する」）・かな・英字では発生しないため、「このボタンだけなぜか取れない」という不可解な症状に見える。なお [ant-design-select.md](./ant-design-select.md) の省略表示（`text-overflow: ellipsis`）も `:text-is()` を壊すが、あちらは視覚的な切り詰め・こちらは DOM への文字挿入で**別現象**。

```typescript
// ❌ DOM 上は「保 存」（空白入り）— マッチせずタイムアウト
page.locator('button:text-is("保存")')
page.getByRole('button', { name: '保存' })

// ✅ 空白を許容する正規表現で吸収（テスト側の非侵襲な対処）
page.getByRole('button', { name: /^保\s?存$/ })
```

挿入の有無は antd のバージョンと ConfigProvider 設定に依存するため、導入プロジェクトで実際の DOM を確認してから対処を選ぶこと（アプリ側を触れるなら `autoInsertSpace` の無効化も選択肢）。

**⚠️ 中身が空のタブが `aria-disabled` でクリック不可になる罠**: Ant Design Tabs / MUI Tabs / Radix UI Tabs などはタブの中身がゼロのとき `aria-disabled="true"` を付与する。これを知らずに `tab.click()` を呼ぶと Playwright の `click()` が actionable 待ちで **test timeout までハング**し、最悪のフィードバックループになる（数分後に Fail、原因切り分け困難）。
→ 詳細は [ant-design-tabs-disabled.md](./ant-design-tabs-disabled.md) 参照

```typescript
// ❌ 空タブで test timeout まで永久ハング
await page.getByRole('tab', { name: 'アーカイブ' }).click();

// ✅ 切替前に enabled をガード（即 fail-fast）
async isTabEnabled(tabName: string): Promise<boolean> {
  const tab = this.page.getByRole('tab', { name: tabName });
  await tab.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  return tab.isEnabled();  // aria-disabled を解釈
}
// Test 層
expect(await action.hasItemsInTab('アーカイブ')).toBeTruthy();
await navigationAction.switchTab('アーカイブ');
```

**⚠️ モーダル閉鎖後の `[role="dialog"]` 残存（stale dialog）**: Ant Design Modal をはじめ多くの UI ライブラリのモーダルは、閉じても `[role="dialog"]` を持つ要素が DOM にしばらく残ることがある。複数モーダル経由フローや、同フローの再表示で `getByRole('dialog')` が複数マッチし、strict mode 違反でクリックできなくなる。
→ "最後に開いた dialog" を取る `activeDialog()` ヘルパーで吸収する。

**置き場の指針**: 単一の Page Object 内でしか使わないなら当該 Page Object に置く。複数の Page Object で使い始める前に `BasePage` に `protected activeDialog()` として上げて重複定義を防ぐ。

```typescript
// 単一 Page Object 内
activeDialog(): Locator {
  // DOM 末尾に積まれる最新モーダルを取る
  return this.page.getByRole('dialog').last();
}

// 使用例
await this.activeDialog().getByRole('button', { name: '削除する' }).click();
```

**`activeDialog()` と `SELECTORS.MODAL` の使い分け**（競合ではなく役割が違う。canonical は `prohibited-patterns.md`「アクティブモーダルのイディオム」、本表は skill 層の実務クイックリファレンス）:

| 用途 | 使うもの |
|------|---------|
| stale dialog の中から「最後に開いた＝アクティブ」を取る（`.last()` が要る） | `getByRole('dialog').last()`（`activeDialog()`）— getByRole は hidden 自動除外で stale に堅牢 |
| 単一モーダルにスコープして中の要素を取る（`.last()` 不要） | `SELECTORS.MODAL`（`[role="dialog"]`）— Local Universe の宇宙定数 |
| ハイブリッド `page.locator(SELECTORS.MODAL).last()` | ❌ 禁止（hidden 除外しない属性セレクタに stale 対策の `.last()` を貼る矛盾。詳細 `prohibited-patterns.md`「アクティブモーダルのイディオム」） |

> `activeDialog()` の `.last()` は「フレームワーク不変条件（DOM 末尾＝最前面）」に基づくカテゴリB の ordinal。理由コメントは要るが TODO は不要（`prohibited-patterns.md`「ordinal セレクタの許容境界」）。

**カードリストの Local Universe**: カード型 UI（Ant Design `.ant-card`, MUI `.MuiCard-root`, Tailwind 独自 card class など）で項目が並ぶ画面では、同じテキストがパンくず / サイドメニュー / 一覧で重複しがち。カード本体にスコープを絞ると安定する。

```typescript
// ❌ page スコープ → パンくず / サイドメニューの同名テキスト誤爆リスク
await page.locator(`:text-is("${itemName}")`).click();

// ✅ カード本体で囲んで text-is で filter（strict mode で複数検知）
const card = page.locator('.ant-card')  // ライブラリ固有クラス
  .filter({ has: page.locator(`:text-is("${itemName}")`) });
await card.click();
```

ライブラリごとの詳細パターンは、プロジェクト固有のドキュメントに切り出して保守する。

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

## §11. ordinal セレクタ（`.first()` / `.last()` / `.nth()`）の対応手順

ordinal は用途で3カテゴリに分かれ、要求が異なる（詳細 `prohibited-patterns.md`「ordinal セレクタの許容境界」）。

### カテゴリA: 曖昧マッチの応急処置（`.first()` が典型）
「複数マッチしたから位置で選ぶ」= 偶然の固定化。次の順で消す努力をし、消せなければ理由コメント **+ TODO**（順序は `locator-principles.md`「優先順位ピラミッド」に対応）。

1. **最優先**: name / 完全一致（`getByRole(..., { name, exact: true })` / `:text-is()`）/ Local Universe で一意特定（セマンティック）
2. **次善**: `:near()` で周辺テキストから特定
3. **妥協**: 親要素で絞り込んでから ordinal
4. **最終**: ordinal + 詳細コメント + TODO

> `data-testid` を開発チームに追加依頼するのは根本解決として有効だが長期施策。TODO に記載するのは可。

```typescript
// ❌ A をノーコメントで使う（最も多い違反）
await this.page.locator(`:text-is("${name}")`).first().click();

// ✅ A: ピラミッドで消せないか先に検討 → 無理なら理由 + TODO
// リソース名は <a> + 内部 <span> の 2 要素にマッチ。先頭の <a> を取る
// TODO: リソース名要素に data-testid 等が付与されたら .first() を排除する
return this.page.locator(`:text-is("${name}")`).first();

// ✅ A の別例: 候補が構造的に1つしかないことを確認した上での妥協
// このダイアログには1つのチェックボックスのみ存在（YYYY-MM-DD確認）
// TODO: data-testid="agreement-checkbox" の追加を依頼
page.locator('[role="dialog"] input[type="checkbox"]').first()
```

### カテゴリB: フレームワークの不変条件（`.last()` が典型）
`.last()` が「最後に開いた＝最前面」のように z-order / DOM append 順という**実在の不変条件**を符号化している場合。代替が物理的に無いので消さない。**理由コメントは必須だが TODO は不要**（恒久的に正しい設計）。

```typescript
// 不変条件の説明のみ（B・TODO 不要）
// モーダルライブラリは閉じても role="dialog" が DOM に残る。最後に開いたものが
// DOM 末尾に積まれるため last() でアクティブなモーダルを取る
this.page.getByRole('dialog').last()
```

### カテゴリC: ループ消化型イテレーション（`.first()` が典型）
「先頭1件を取り処理して、また先頭を取る」を0件になるまで繰り返す用途（一括クリーンアップ・janitor 処理）。どの順でも全件消化されるため A の偶然の固定化が起きない。**理由コメント必須・TODO 不要**（B と同等）。判定条件2つ（①0件までのループで全件消化 ②順序が結果に影響しない）と maxLoops + throw ガード必須の正本は `prohibited-patterns.md`。

> **A/B/C 判定の対象外**（正本 `prohibited-patterns.md` 同節）: ordinal が曖昧さ解消でなく**意図の直接表現**である用途（count 走査の `nth(i)` ループイテレータ・引数由来 index の `nth(param)`）は本分類の対象外 — 理由コメントのみ付与する（例: `// ループイテレータ（A/B 外: 位置固定でなく全件走査）`）。

```typescript
// ✅ C: 呼び出し元が0件になるまで消化するループのため first() の順序は結果に影響しない（TODO 不要）
return this.rowContaining(text).first();
```
