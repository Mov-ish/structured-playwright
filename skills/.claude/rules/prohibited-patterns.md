# 禁止事項一覧

このファイルのパターンは**いかなるタスクでも**使用してはならない。

## コード禁止パターン

| 禁止 | 理由 | 代替 |
|------|------|------|
| `text=ログイン` 記法 | プロジェクトで動作しない | `:has-text("ログイン")` or `getByRole` |
| XPath (`//div/span`) | 構造依存・AI誤生成の温床 | CSS + セマンティック |
| CSS構造セレクタ (`div > div > button`) | DOM揺れで即破壊 | 意味ベース + Local Universe |
| `.first()` コメントなし | 偶然の固定化、保守不能 | `:near()` / 具体セレクタ / コメント+TODO付き |
| `.catch(() => false)` / `.catch(() => true)` | タイムアウト隠蔽・false positive | 下記「try-catch の許容/禁止の境界」参照 |
| `private readonly` でLocator定義（Page Object層） | デバッグ困難 | `readonly`（public） |
| `import { test } from '@playwright/test'` | Fixture未経由 | `from '../fixtures/app.fixture'` |
| `new XxxAction(page)` をTest内で直接 | 依存が明示されない | Fixture引数で受け取る |
| Action層で `expect()` | アサーションはTest層の責務 | `waitFor()` ベースの verify メソッド |
| Test層で Locator 直接記述 | UIは Page Object層の責務 | Action の verify メソッド経由 |
| Page Objectで `waitForTimeout()` | 固定待機はAction層で行う | `waitFor()` + try-catch |
| verify メソッド (boolean) 内の `waitForTimeout()` | 判定の正しさが待ち時間に賭かる + 二重待機（下記参照） | 待機は操作メソッド側に集約、verify は観測のみ |
| 意味層の薄い要素にセマンティックLocator | 属性不足で動作しない | `:near()` / `svg[data-icon]` |
| `has-text` をスコープなしで使用 | 同じ文言が複数→誤爆 | `text-is` or Local Universe で絞る |
| モーダルを `page` 全体で探索 | 背景ボタン誤クリック | `[role="dialog"]` で閉じ込め |
| module スコープ乱数 + 複数 `test()` 暗黙依存 | 部分実行不可・別TC再利用不可（下記参照） | 引数化 / Setup Action / `beforeAll`（`architecture.md` 参照） |
| Action 内で module スコープ変数を直接参照 | 別 TC から呼ぶと挙動が変わる | 引数で受け取る |

## 値の禁止パターン

| 禁止 | 理由 | 代替 |
|------|------|------|
| タイムアウト数値ハードコード (`2000`, `10000`) | 保守性低下 | `TIMEOUTS.SPA_RENDERING` 等の定数 |
| URLパターンハードコード (`'**/login**'`) | 環境変更時の修正漏れ | `URL_PATTERNS.LOGIN` 等の定数 |
| 共通セレクタハードコード (`'[role="dialog"]'`) | 一貫性欠如 | `SELECTORS.MODAL` 等の定数 |
| 認証情報ハードコード | セキュリティリスク | `.env` + `EnvConfig` |
| `waitForTimeout` に理由コメントなし | 意図不明で保守不能 | TIMEOUTS定数 + 理由コメント必須 |

## try-catch の許容/禁止の境界

catch で `false` を返すコード全てが禁止ではない。**catch が何を捕まえているか**で判断する。

| | 待っている条件 | falseの意味 | 判定 |
|---|---|---|---|
| `waitFor({ state: 'visible' })` のタイムアウト | 要素の状態遷移（非表示→表示） | 「その状態にならなかった」 | ✅ 許容 |
| `click()` / `fill()` 等の操作失敗 | 操作の成功 | 「何かが失敗した」（原因不明） | ❌ 禁止 |
| `textContent()` / `inputValue()` 等の取得失敗 | 値の取得 | 「何かが失敗した」（原因不明） | ❌ 禁止 |

**許容パターン**（`architecture.md`「Test層とAction層の検証の両立」参照）:
```typescript
// ✅ waitFor のタイムアウトのみを catch — 「見えなかった」という事実を返す
async isSectionVisible(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    return true;
  } catch { return false; }
}
```

**禁止パターン**: waitFor 以外の操作を同じ try-catch に入れる
```typescript
// ❌ waitFor 成功後の textContent 失敗も false になり、真の原因が隠れる
async hasValue(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    const text = await this.section.textContent(); // ← これの失敗も catch される
    return /\d+/.test(text ?? '');
  } catch { return false; }
}
```

```typescript
// ✅ waitFor と値取得を分離する
async hasValue(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  } catch { return false; }
  const text = await this.section.textContent();
  return /\d+/.test(text ?? '');
}
```

**判断基準**: catch ブロックが捕まえるのは「要素の状態遷移のタイムアウト」だけか？ Yes なら許容、No なら禁止。

## verify 内の固定待機 — 待機は操作メソッドに集約

**boolean を返す検証メソッド (verify) の内部に `waitForTimeout` を置かない。** 同じ Page Object でも「操作メソッド (void) 末尾の固定待機」とは性質が異なる。

| | 操作メソッド (void) | verify メソッド (boolean) |
|---|---|---|
| 例 | `selectItem()` / `deleteItem()` | `isItemVisible()` / `isItemAbsent()` |
| 責務 | DOM を変える action | 現在の状態を観測して真偽を返す |
| 待機対象 | **自メソッド内の action の余波**（click 直後の再描画） | 自メソッドの外で起きた変化（他のメソッドの action 結果） |
| 待ち時間不足の影響 | 後続操作が遅延するだけ | **判定が誤って通る**（偽陰性 / 偽陽性で flaky） |
| 待機所有者 | action の付随処理 | （本来は呼び出し側のフロー制御） |
| 判定 | 既存慣習として許容 | ❌ **禁止** |

### なぜ禁止か

1. **判定の正しさが待ち時間に賭かる** — verify の責務は「観測して真偽を返す」こと。固定 sleep が混ざると `SPA_RENDERING(2s)` で削除後遷移が終わらなければ、まだ消えていない値を読んで「消えた」と返却（flaky な偽陰性）。
2. **二重待機の症状** — 操作メソッド (`deleteItem()`) 末尾と verify (`isItemAbsent()`) 冒頭が **同じ「削除後の描画安定」を別々に待つ** ことになる。待機対象が同じなのに所有者が分散しているのは層の責務が崩れているサイン。
3. **層分離の意図** — 「待機戦略（いつ・何を・どれだけ待つか）はフロー制御の関心事」。verify が「外の action の余波」を待ち始めると、フロー制御の関心事が観測メソッドに漏れ込む。
4. **AI 拡散リスク** — 1 件でも残っていると AI が「正解パターン」として模倣・増殖する（`locator-principles.md` の AI 行動規範と同構図）。

### コード例

```typescript
// ❌ 禁止: verify 内の固定待機 — 判定の正しさが 2 秒に賭かる
async isItemAbsent(name: string): Promise<boolean> {
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // ← 外部 action の結果を待つ
  const names = await this.collectItemNames();
  return !names.includes(name);
}

// ✅ 正しい: 待機は操作メソッド側に集約、verify は観測のみ
async deleteItem(): Promise<void> {
  await this.itemDeleteButton.click();
  await this.confirmDeleteButton.click();
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // ← 自 action の余波待ち（慣習）
}
async isItemAbsent(name: string): Promise<boolean> {
  const names = await this.collectItemNames();
  return !names.includes(name);
}
```

### 「遷移検証」パターンで偽陽性も同時に排除する

verify が「ある状態であること」を返すなら、**呼び出し側で「変化前後」を両方検証する**:

```typescript
// 削除前: 対象が存在する（この前提検証がないと「削除で消えた」と言えず偽陽性）
expect(await itemAction.isItemPresent(name)).toBeTruthy();
await itemAction.deleteItem();
// 削除後: 対象が消えた
expect(await itemAction.isItemAbsent(name)).toBeTruthy();
```

「`isAbsent` 単独」では「最初から存在しなかった」のか「削除で消えた」のかを区別できない。`isPresent → action → isAbsent` の対で観測することで偽陽性（action が効かなくても緑）を排除する。

### 例外

判定対象が「状態遷移のタイムアウト」そのものの場合、`waitFor({state:'visible'/'hidden'})` + try-catch は許可（`architecture.md`「Page Object で許可される待機」参照）。これは「観測そのものに待機戦略が含まれる」ケースで、`waitForTimeout` のような盲目的な固定待機とは別物。

## テスト条件の黙殺禁止（Silent Skip）

テストが明示的に要求した操作が実行できなかった場合、**スキップではなく Fail する**。

| 状況 | 判定 | 理由 |
|------|------|------|
| `required: true` → チェックボックスが見つからない | ❌ Fail必須 | テスト条件が満たされていない |
| `submitAnswer()` → 提出ボタンが見つからない | ❌ Fail必須 | テスト操作が実行されていない |
| 確認モーダルが出る場合と出ない場合がある → 出なかった | ✅ スキップ可 | 環境差異の吸収（テスト条件ではない） |
| ログアウト後のリダイレクト先が環境で異なる | ✅ スキップ可 | 環境差異の吸収 |

**判断基準**: その操作は**テストが明示的に要求したもの**か、**環境差異を吸収するための防御コード**か？

- テスト条件（引数・パラメータで明示）→ **見つからなければ Fail**
- 環境差異の吸収（モーダルの有無・遷移先の違い）→ **スキップ可**

```typescript
// ❌ 禁止: テスト条件を黙殺
async checkRequired(): Promise<void> {
  try {
    await this.checkbox.waitFor({ state: 'visible', timeout: TIMEOUTS.ELEMENT_CHECK });
  } catch {
    console.log('見つからないのでスキップ');  // ← テスト条件が満たされず Pass する偽陽性
    return;
  }
  await this.checkbox.check();
}

// ✅ 正しい: テスト条件を満たせなければ Fail
async checkRequired(required: boolean): Promise<void> {
  try {
    await this.checkbox.waitFor({ state: 'visible', timeout: TIMEOUTS.ELEMENT_CHECK });
  } catch {
    if (required) {
      throw new Error('必須チェックボックスが見つかりません（required=true）');
    }
    return; // required=false で存在しないのは許容
  }
  if (required) {
    await this.checkbox.check();
  } else {
    await this.checkbox.uncheck();
  }
}
```

## ハングという形の偽陽性

`waitForTimeout` だけでなく、**disabled な要素に対する click/hover も「ハングという偽陽性」を生む**。Playwright の `click()` は内部で actionable 待ち（visible + enabled + stable）を行うため、`aria-disabled="true"` や `disabled` 属性の要素を待ち続けて test timeout までハングする。「ハング → タイムアウト Fail」は形上は Fail だが、**真因が「データが想定と違う」か「Locator が違う」か切り分けに時間がかかり、フィードバックが遅延する**点で偽陽性に近い害がある。

| 状況 | 判定 | 推奨 |
|------|------|------|
| 中身が空で disabled になるタブ・ボタンを直接 `click()` | ❌ ハング偽陽性 | 事前に `isEnabled()` を検証して即 fail-fast |
| 「対象が存在する前提」の操作（一括削除 / 全件処理 等）を空コンテキストで実行 | ❌ 空振り偽陽性 | 操作前に対象の存在を `expect(...).toBeTruthy()` で検証 |

代表例: **UI ライブラリの Tabs で中身が空のとき `aria-disabled="true"` になる罠**（Ant Design Tabs / MUI Tabs / Radix UI Tabs 等）。
詳細は `.claude/skills/e2e-locator/ant-design-tabs-disabled.md` を参照。

```typescript
// ❌ 空のとき test timeout までハング → 真因が即時に判らない
await navigationAction.switchTab('アーカイブ');
await action.permanentDeleteAll();

// ✅ 事前ガード → ハングなしで即 Fail、原因も明確
expect(await action.hasItemsInTab('アーカイブ')).toBeTruthy();
await navigationAction.switchTab('アーカイブ');
expect(await action.isItemVisible(targetName)).toBeTruthy();
await action.permanentDeleteAll();
expect(await action.isItemHidden(targetName)).toBeTruthy(); // 後始末の空振りも検知
```

## AI生成コードの警戒パターン

- `.catch(() => false)` が5箇所以上 → AIコピペを疑う
- 同じエラーハンドリングパターンの大量重複 → 一箇所でも問題なら全体が問題
- **「動く」≠「正しい」** — テストは失敗することに意味がある

## テスト間データ依存（Implicit Test Coupling）

複数の `test()` が module スコープ変数や、前のテストで作られた状態に**暗黙的に**依存している構造は禁止。

### 何が問題か

```typescript
// ❌ 禁止
const random = Date.now().toString();
const RESOURCE_NAME = `リソース名${random}`;

test.describe('TC-XX', () => {
  test('Phase 1: 作成', async () => { /* RESOURCE_NAME でリソース作成 */ });
  test('Phase 2: 利用', async () => { /* RESOURCE_NAME で検索 — Phase 1 に暗黙依存 */ });
});
```

| 弊害 | 具体例 |
|------|-------|
| 部分実行不可 | `-g "Phase 2"` で Phase 2 だけ走らせるとリソースが存在せず失敗 |
| 再利用不可 | 別 spec から Phase 2 のフローを呼べない |
| デバッグ困難 | Phase 1 失敗時に Phase 2 がスキップされず、別の理由で失敗して原因が紛らわしい |
| 暗黙結合 | `[Arrange]` と `[Act]` がテスト境界を跨ぎ、テスト独立性が崩れる |

### 判定基準

- module スコープ（`describe` の外）に `Date.now()` などの動的値を持つ → ❌
- Action が module スコープ変数を直接参照する → ❌
- `test()` の中だけで完結する乱数（`const random = Date.now()` を `test()` 内で宣言） → ✅
- `test.beforeAll` でデータ準備し、`describe` スコープ変数 で共有 → ✅
- Setup Action + Fixture でデータ準備 → ✅（推奨、`architecture.md` 参照）

### 例外

「TC全体が1つの長いユーザーストーリーで、最初から最後まで通しで動くことが本質」のテストは、`test()` を分割せず **単一の `test()` 内で全 Phase を実行する** ことで暗黙依存を回避する。Phase 分割が欲しいなら `test.step()` または Action 単位の粒度で表現する。
