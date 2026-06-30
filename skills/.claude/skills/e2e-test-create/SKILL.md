---
name: e2e-test-create
description: "E2Eテスト作成用。テスト追加・Actions/PageObject実装・ユーザーストーリーからのテスト生成時に使用。SOP・Fixture定義・待機パターン・テストデータ設計・JSDocテンプレートを含む。外部認証フロー実装例はauth0-flow.md・失敗パターンはfailure-patterns.mdを参照。"
---

# E2E Test Creation Skill

## §6. AI作業手順（SOP）— まずここから

1. MUSTチェックリスト確認（rules/architecture.md「層間の絶対境界」+ rules/prohibited-patterns.md）
2. ストーリーをテスト単位に分解
3. **テスト手順書を先に書く**（テンプレート・タグ表は §11、規範は `architecture.md`「Test層のヘッダーコメント」）
   - Phase分割・手順番号・検証ポイントを自然言語で整理
   - これがテスト実装の設計書になる
4. `fixtures/app.fixture.ts` の **Action カタログを確認**
   - 既存 Action のメソッド一覧から再利用可能なものを特定
   - 必要な Action が TODO にあれば新規作成が必要
5. 既存資産の探索（Actions/PageObject/類似Test）→ 再利用優先
   > ⚠️ **既存コードがルール違反の場合がある。** コピー前に rules/architecture.md と rules/prohibited-patterns.md の禁止事項と照合すること。
   > 違反を見つけたらコピーせず正しいパターンで実装する。
6. 追加ファイルを最小限に → 新規Actionは**Fixtureにも登録 + Action カタログを更新**（`architecture.md`「Action カタログ規約」参照）
   - **`LoginAction` を新規実装・修正する場合は §4（auth0-flow.md）を先に参照**
7. 実装（rulesの4層責務に従う）
8. `npx playwright test <file>` で動作確認
   - **テストが通らない場合は §5（failure-patterns.md）の既知パターンを確認**
9. 実行時間をヘッダーコメントに記載
10. rules/architecture.md「層間の絶対境界」+ rules/prohibited-patterns.md で最終確認
11. **`npm run gate` を実行し exit 0 を確認**（機械ゲート — 正本は `scripts/gate.sh`。CI でも同一判定が走る）
    - ❌ が出たら fail メッセージの「→ 代替」に従って修正してから PR 化する
    - ⚠️ 警告は自分が追加・変更した行に該当があれば解消する（既存行は対象外）

---

## §1. MUSTチェックリスト（コード生成前に確認）

### 層別ルール早見表

| 層 | ❌ 禁止 | ✅ 必須 |
|---|---|---|
| **Page Object** | `private readonly` | `readonly`（public）+ constructor初期化 |
| **Page Object** | expect / waitForTimeout | 単一責任メソッド、waitFor+try-catchは許可 |
| **Action** | expect() | waitFor()、各ステップで`this.step()` |
| **Action** | `console.log`単体でステップログ | `this.step('名前', async () => { ... })` |
| **Action** | `beginAction()` 忘れ | `this.step()` を使う public メソッドの先頭に `this.beginAction()` |
| **Action** | 数値/URLハードコード | TIMEOUTS/URL_PATTERNS定数 + 理由コメント |
| **Test** | `from '@playwright/test'` | `from '../fixtures/app.fixture'` |
| **Test** | `new XxxAction(page)` | Fixture引数 `async ({ xxxAction }) =>` |
| **Test** | Locator直接記述 | Action verify メソッド経由 |
| **Test** | ヘッダーコメントなし | テスト手順書を JSDoc で記載（`architecture.md` 参照） |
| **全層共通** | テスト条件を満たせない時に黙ってスキップ | 明示的に要求された操作が失敗したら Fail（`prohibited-patterns.md` 参照） |

---

## §2. Fixture定義

**雛形の正本 = `e2e-bootstrap` §3**（`base.extend` の全体構造・worker スコープ stepCounter を含む完全形）。テスト作成時に必要な差分は「新規 Action の登録」のみ:

```typescript
// fixtures/app.fixture.ts — 新規 Action 追加で書くのはこの3点
import { XxxAction } from '../actions/XxxAction';            // ① import
type AppFixtures = { /* 既存 */ xxxAction: XxxAction };     // ② 型に追加
// ③ 登録（stepCounter を constructor に注入）
xxxAction: async ({ page, stepCounter }, use) => { await use(new XxxAction(page, stepCounter)); },
```

**新規Action → Fixtureにもimport+登録（stepCounter注入）→ テストで引数宣言 + Action カタログ更新（`architecture.md`「fixture.ts の Action カタログ規約」）**

---

## §3. 待機処理パターン

| 状況 | 待機方法 | 定数 |
|------|---------|------|
| ページ遷移後 | `networkidle` + `waitForTimeout` | `TIMEOUTS.SPA_RENDERING` |
| モーダル表示 | `waitFor({state:'visible'})` + `waitForTimeout` | `TIMEOUTS.MODAL_ANIMATION` |
| 外部認証遷移 | `waitForURL()` + `waitForTimeout` | `TIMEOUTS.AUTH_STABILIZATION` |
| リダイレクト | `waitForTimeout` | `TIMEOUTS.REDIRECT` |
| 確認ダイアログ | `waitFor({state:'visible'})` | `TIMEOUTS.DEFAULT` |

### モーダル操作パターン
```typescript
await page.locator(SELECTORS.MODAL).waitFor({ state: 'visible', timeout: TIMEOUTS.SHORT });
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION); // CSSアニメーション完了
const button = page.locator('[role="dialog"] button:has-text("保存")');
await button.scrollIntoViewIfNeeded();
await button.click({ force: true });
```

---

### try-catch の境界（コード例）

catch してよいのは「要素の状態遷移のタイムアウト」のみ（判定基準の正本は `prohibited-patterns.md`「try-catch の許容/禁止の境界」）。

```typescript
// ✅ waitFor のタイムアウトのみを catch — 「見えなかった」という事実を返す
async isSectionVisible(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    return true;
  } catch { return false; }
}

// ❌ waitFor 成功後の textContent 失敗も false になり、真の原因が隠れる
async hasValue(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    const text = await this.section.textContent(); // ← これの失敗も catch される
    return /\d+/.test(text ?? '');
  } catch { return false; }
}

// ✅ waitFor と値取得を分離する
async hasValue(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  } catch { return false; }
  const text = await this.section.textContent();
  return /\d+/.test(text ?? '');
}
```

### optional modal パターン（出る場合と出ない場合があるモーダル・ボタン）

モーダルやボタンが「環境によって出る場合と出ない場合がある」フローでは、**waitFor のみ try-catch に入れ、click/fill は外に出す**。click を try 内に入れると click 失敗が「モーダルなし」として隠蔽される（gate W5 で検出）。

```typescript
// ❌ click が try ブロック内 — click 失敗も「モーダルなし」扱いになる
try {
  await confirmBtn.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  await confirmBtn.click(); // ← click 失敗も「モーダルなし」扱いになる
} catch { /* 確認モーダルなし */ }

// ✅ waitFor のみ try-catch に入れ、click は外に出す
let modalVisible = false;
try {
  await confirmBtn.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  modalVisible = true;
} catch { /* 確認モーダルなし */ }
if (modalVisible) await confirmBtn.click();
```

判定基準の正本は `prohibited-patterns.md`「try-catch の許容/禁止の境界」。

---

## §4. 外部認証フロー

→ **`.claude/skills/e2e-test-create/auth0-flow.md`** 参照（LoginAction を新規実装・修正するときに読む）

---

## §5. 既に試して失敗したパターン

→ **`.claude/skills/e2e-test-create/failure-patterns.md`** 参照（ハマったときに確認する）

---

## §7. コンポーネント別パターン

### フォーム入力
```typescript
await this.step('フォーム入力', async () => {
  await inputField.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  await inputField.fill(value);
  await submitButton.click();
  await this.page.waitForLoadState('networkidle');
});
```

### リスト操作（三点リーダーメニュー）
```typescript
await this.step('メニューを開く', async () => {
  const row = this.page.locator('tr').filter({ hasText: targetText });
  await row.locator('button:has(svg[data-icon="ellipsis"])').click();
});
await this.step('メニュー項目を選択', async () => {
  await this.page.locator('li:has-text("編集")').click();
});
```

### ファイルアップロード
```typescript
await this.step('ファイルアップロード', async () => {
  await this.page.locator('input[type="file"]').setInputFiles(filePath);
  await this.page.waitForResponse(resp => resp.url().includes('/upload'));
  await this.page.waitForLoadState('networkidle');
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // アップロード後のUI更新待ち
});
```

---

## §8. エラーハンドリングパターン

### エラー時スクリーンショット保存
```typescript
// BaseAction に追加可能なヘルパー
protected async executeWithScreenshot(
  fn: () => Promise<void>,
  context: string
): Promise<void> {
  try {
    await fn();
  } catch (error) {
    await this.page.screenshot({ path: `test-results/error-${context}-${Date.now()}.png` });
    throw error;
  }
}
```

### Action 層でのリトライパターン（遷移直後の未反映対応）

「ページ遷移や操作直後に要素が一覧へ反映されていない」ような環境差異には、**PO メソッド呼び出し1行のみを try で囲み、Action 層でリロード＋再試行する**。

```typescript
// ✅ Action 層 — PO 呼び出し1行のみを try で囲む
async processRequest(itemName: string): Promise<void> {
  this.beginAction();
  await this.step('申請を処理する', async () => {
    try {
      await this.listPage.processItem(itemName); // PO 呼び出し1行のみ
    } catch {
      // 一覧未反映の場合にリロードして再試行（PO 内の waitFor タイムアウトを捕まえる）
      await this.page.reload();
      await this.page.waitForLoadState('networkidle');
      await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
      await this.listPage.processItem(itemName);
    }
  });
}
```

**ポイント**:
- try に入れるのは **PO 呼び出し1行だけ**（Action 全体を囲むのではない）
- PO 内部のナビゲーション・`click` が失敗した場合は throw がそのまま伝播し、catch には到達しない（隠蔽されない）
- catch が捕まえるのは PO 内の `waitFor` タイムアウト（要素未反映）のみ
- PO 側は `waitFor` タイムアウト時に throw を伝播させるだけでよい（リロード判断は Action 層の責務）

> ⚠️ `click` を直接 try で囲むリトライ（`try { locator.click() } catch { retry }`）は W5 違反。click 失敗の原因が隠蔽される。`waitFor` で存在を確認してから click する設計に変える。

---

## §9. テストデータ管理（テスト増加時に対応）

- 静的テストデータ: `src/config/testdata/` に JSON ファイル配置
- 動的テストデータ: `uniqueId()`（`src/utils/uniqueId.ts`）で一意名を生成。**`Date.now()` 単独は並列ワーカー衝突のため禁止**（`prohibited-patterns.md`「一意テストデータ名は uniqueId() で生成する（Date.now() 単独依存禁止）」参照）。TC 識別子はプレフィックスに含める（`リソース名TC01_${random}`）
- テスト後のクリーンアップ: 作成したデータの削除を Action として実装

### 複数 `test()` 間でデータを共有する場合

**禁止**: module スコープに `const random = uniqueId()` を置いて複数 `test()` が暗黙参照する構造（判定基準・弊害の正本は `prohibited-patterns.md`「テスト間データ依存」）。一意性確保のため `Date.now()` 単独で名前を作るのも禁止（同「一意テストデータ名は uniqueId() で生成する」参照）。

```typescript
// ❌ 禁止の典型形
const random = uniqueId();                       // module スコープ
const RESOURCE_NAME = `リソース名${random}`;

test.describe('TC-XX', () => {
  test('Phase 1: 作成', async () => { /* RESOURCE_NAME でリソース作成 */ });
  test('Phase 2: 利用', async () => { /* RESOURCE_NAME で検索 — Phase 1 に暗黙依存 */ });
});
```

**推奨パターン早見表**（本節が実装パターンの正本。スコープ設計の規範は `architecture.md`「テストデータの共有と再利用」）:

| 状況 | 実装 |
|------|------|
| 単一 `test()` 完結 | `test()` 内で `const random = uniqueId()` |
| 同一 describe 内 Phase 分割 | `test.beforeAll` でデータ準備 + describe スコープ変数で共有 |
| 別 spec / 別 TC から再利用したい | Setup Action + Fixture（後述） |
| TC全体が通しユーザーストーリー | `test()` を分割せず 1つの `test()` 内に収め、`test.step()` で Phase 表現 |

**判断フロー**:
1. 同じ spec 内の別 `test()` から呼ばれうる？ → **Yes なら Action 引数化必須**
2. 別 spec / 別 TC から呼ばれうる？ → **Yes なら Setup Action + Fixture 化**
3. 一意性の確保 → `uniqueId()` で生成（`Date.now()` 単独禁止）。**生成は Action の外（test() 内 or beforeAll）で行い引数で渡す**

> ⚠️ **「Phase = `test()` ブロック」と短絡しないこと。** 手順書（JSDoc）の Phase 表記と `test()` の分割は別物。後段が前段の生成物に依存する連続ストーリー（作成 → 利用 → 完了）は**単一 `test()` + `test.step()`**。Phase ごとに `test()` を割って `describe`/module スコープ変数で状態を渡すと Implicit Test Coupling になる。是正は **「縦に束ねる（Arrange をビルダー化）＋ 単一 `test()`」** であって test() 分割ではない。

#### 通しテストの肥大とベース作成の集約

`create → use → complete` を**単一 `test()` に通すのは「その条件下での完了」自体がテスト対象（subject）のときのみ**。
テスト対象が別（詳細動作・アクセス条件など）でリソース作成が単なる前提なら、**作成を Setup Action に追い出してテスト本体を絞る**。

そのうえで、**ベース作成フロー（設定 → サブ項目追加 → 公開 → 利用者登録）をテストや TC にインライン展開しない**。
共有ビルダー（Setup Action）に集約し、各 TC は構成パラメータだけを渡す。

> **理由（AI 模倣の伝播）**: インライン展開した大きな作成ブロックは「最強の正解」として次の TC にコピーされ、肥大が伝播する。共有ビルダーに移せば、コピーされても伝播するのは「ビルダー呼び出し + きれいな構造」になる。

作成自体が subject の通し TC（＝単一 `test()` を保つもの）には、**荷重コメント**で意図と禁止を明記する:

```typescript
/**
 * TC-XX: ○○リソースの作成（意図的に end-to-end）
 * このテストは「○○リソースの作成 + その条件での完了」が subject のため単一 test() で通す。
 * subject が狭いテスト（詳細動作のみ等）でこの monolithic な形を真似ないこと。
 * ベース作成は ResourceSetupAction（共有ビルダー）経由。
 */
```

**可読性ガード（抽出してよいのは `[Arrange]`/`[Cleanup]` のみ）**: ビルダーに `[Act]`/`[Assert]` を畳まない（主題はインラインに残す）/ 引数は boolean 羅列でなく options + 意図名 / ビルダー名は終状態を語り戻り値で生成名を返す / 似てるだけの双子を分岐で1本化しない。受け入れ基準は「spec を開いた人間がファイルを離れず (a)どんな状態から始まるか (b)何を検証するか を答えられる」。

#### `beforeAll` パターン（同一 describe 内 Phase 分割）

```typescript
test.describe('TC-XX: リソース利用ストーリー', () => {
  let resourceName: string;
  let subItemName: string;

  test.beforeAll(async ({ browser }) => {
    const context = await browser.newContext();
    const page = await context.newPage();
    // セットアップ Action でリソース作成
    const random = uniqueId();
    resourceName = `リソース名${random}`;
    subItemName = `サブ項目名${random}`;
    // ... 実装
    await context.close();
  });

  test('Phase 2: ユーザーがリソースを利用', async ({ resourceUseAction }) => {
    await resourceUseAction.searchAndOpen(resourceName);  // 引数で受け取る
    // ...
  });
});
```

#### Setup Action パターン（別 TC から再利用）

```typescript
// actions/ResourceSetupAction.ts — 「利用可能なリソース一式」を作る共通フロー
export class ResourceSetupAction extends BaseAction {
  async createPublishedResource(opts: {
    random: string;
    ownerName: string;
  }): Promise<{ resourceName: string; subItemName: string }> {
    this.beginAction();
    const resourceName = `リソース名${opts.random}`;
    // ... リソース作成 → サブ項目追加 → 公開
    return { resourceName, subItemName: `サブ項目名${opts.random}` };
  }
}

// fixtures/app.fixture.ts に登録
resourceSetupAction: async ({ page, stepCounter }, use) => {
  await use(new ResourceSetupAction(page, stepCounter));
},
```

```typescript
// 利用側
test('TC-XX: 利用ストーリー', async ({ resourceSetupAction, resourceUseAction }) => {
  const random = uniqueId();
  const { resourceName } = await resourceSetupAction.createPublishedResource({ random, ownerName: 'ユーザー' });
  await resourceUseAction.searchAndOpen(resourceName);
  // ...
});
```

### Action の引数化（再利用に備える）

「再利用される可能性が少しでもある」フロー（リソース利用・完了確認・別画面遷移など）は、**最初から引数化**しておく。後で再利用するときの改修コストの方が大きい。

```typescript
// ❌ Action 内で外部スコープ参照（モジュール定数 RESOURCE_NAME 等）
async openResource(): Promise<void> { await this.searchInput.fill(RESOURCE_NAME); }

// ✅ 引数で受け取る
async openResource(resourceName: string): Promise<void> { await this.searchInput.fill(resourceName); }
```

外部テストツールの Shared Step に対応する粒度（リソース操作・状態確認・後始末等）は、最初から Action 引数化しておくこと。

### verify は観測のみ — 固定待機は操作メソッドへ

verify（boolean 返却）内の `waitForTimeout` は判定の正しさが待ち時間に賭かる偽陽性/偽陰性の温床（判定基準の正本は `prohibited-patterns.md`「verify 内の固定待機」）。

```typescript
// ❌ 禁止: verify 内の固定待機 — 判定の正しさが 2 秒に賭かる
async isItemAbsent(title: string): Promise<boolean> {
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // ← 外部 action の結果を待つ
  const values = await this.collectItemTitles();
  return !values.includes(title);
}

// ✅ 正しい: 待機は操作メソッド側に集約、verify は観測のみ
async deleteItem(): Promise<void> {
  await this.deleteButton.click();
  await this.confirmButton.click();
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // ← 自 action の余波待ち (慣習)
}
async isItemAbsent(title: string): Promise<boolean> {
  const values = await this.collectItemTitles();
  return !values.includes(title);
}
```

**「遷移検証」パターン**: verify が「ある状態であること」を返すなら、呼び出し側で変化前後を両方検証する。「`isAbsent` 単独」では「最初から存在しなかった」のか「削除で消えた」のかを区別できない。

```typescript
// 削除前: 対象が存在する (この前提検証がないと「削除で消えた」と言えず偽陽性)
expect(await resourceAction.isItemPresent(title)).toBeTruthy();
await resourceAction.deleteItem();
// 削除後: 対象が消えた
expect(await resourceAction.isItemAbsent(title)).toBeTruthy();
```

### テスト条件を満たせない場合は Fail（Silent Skip 禁止のコード例）

テスト条件（引数・パラメータで明示）と環境差異吸収の判定基準は `prohibited-patterns.md`「テスト条件の黙殺禁止」が正本。

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

### Cleanup フェーズの正直な検証

`permanentDeleteAll()` / `clearAll()` 等の「全件削除」操作は対象が無くても素通りするため、**前後で対象の存在/消失を expect する**ことで空振り（偽陽性）を防ぐ。

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| タブ切替 → `permanentDeleteAll()` のみ | ❌ | 対象が空でも素通りして Pass する偽陽性 |
| 削除前: 対象が存在する `expect(isXxxVisible).toBeTruthy()` + 削除後: 対象が消えた `expect(isXxxHidden).toBeTruthy()` | ✅ | 削除フローが本当に動いた証跡が残る |

```typescript
// ✅ 偽陽性ゼロの cleanup パターン
// isItemHidden は waitFor({state:'hidden'}) 方向の待機 — !isItemVisible では代替不可
expect(await action.hasItemsInTab('アーカイブ')).toBeTruthy();         // タブ切替前ガード
await navigationAction.switchTab('アーカイブ');
expect(await action.isItemVisible(targetName)).toBeTruthy();           // 対象がアーカイブに実在
await action.permanentDeleteAll();
expect(await action.isItemHidden(targetName)).toBeTruthy();            // 完全削除されたことを検証
```

```typescript
// ❌ domcontentloaded は遷移完了待機にならない
await this.page.locator(':text-is("ログアウト")').click();
await this.page.waitForLoadState('domcontentloaded');  // 即 return される
await this.page.context().clearCookies();              // → /logout 遷移中で ERR_ABORTED

// ✅ 遷移先要素 visible で確実に待つ
await this.page.locator(':text-is("ログアウト")').click();
await this.loginPage.usernameInput.waitFor({ state: 'visible', timeout: TIMEOUTS.LONG });
```

```typescript
// ❌ URL 到達で即 click → React init 中の親ハンドラに吸われる
await this.page.waitForURL('**/dashboard**');
await sideMenu.click();  // 遷移しない or 別タブ選択になる

// ✅ init 完了の目印要素 visible 後に click
await this.page.waitForURL('**/dashboard**');
await this.page.getByRole('main').getByRole('tablist').waitFor({ state: 'visible' });
await sideMenu.click();
```

---

## §10. 命名規則

| 種類 | パターン | 例 |
|------|---------|---|
| Page Object | `{画面名}Page.ts` | `LoginPage.ts` |
| Action | `{機能名}Action.ts` | `LoginAction.ts` |
| Test | `{テスト対象}.spec.ts` | `user-journey.spec.ts` |

テスト名は日本語で具体的に: `'有効な認証情報でログインできる'` ✅

---

## §11. テスト手順書（JSDoc）テンプレート

規範（必須項目・Phase=test.step 原則・同期 MUST）の正本は `architecture.md`「Test層のヘッダーコメント」。本節は**書く局面で使うテンプレートとタグ早見**。

```typescript
/**
 * TC-XX: テストケース名
 *
 * 実行時間: 約X.X分
 *
 * ■ [Arrange] データ準備（約X分）
 *   1. ○○する
 *   2. △△する
 *
 * ■ [Act] Phase 1: フェーズ名（約X分）
 *   3. ○○する
 *   4. △△する → ✅ □□を検証
 *
 * ■ [Assert] Phase 2: フェーズ名（約X分）
 *   5. ✅ □□を検証
 *
 * ■ [Cleanup] クリーンアップ（約X分）
 *   6. データ削除
 *
 * ■ 検証ポイント（expect）
 *   - Phase 1: ○○の検証（N箇所）
 *   - Phase 2: △△の検証
 */
```

**タグの意味**:

| タグ | 意味 | テストの目的との関係 |
|------|------|-------------------|
| `[Arrange]` | テストに必要なデータ・状態の準備 | テスト対象ではない。ここが失敗してもテスト対象の不具合ではない |
| `[Act]` | テスト対象の操作 | ここが本題。ユーザーストーリーで検証したい操作 |
| `[Assert]` | 期待結果の検証 | `[Act]` と同じ Phase 内でインラインに書いてもよい |
| `[Cleanup]` | テストデータの削除・環境の復元 | テスト対象ではない。省略可（データが残っても問題ない場合）。**ログアウトは書かない**（Playwright がテスト終了時に browser context を自動破棄するため不要）。ただし下記「Cleanup ログアウトの原則」参照 |

### Cleanup ログアウトの原則

Playwright はテスト終了時に browser context を自動破棄する。`storageState` 未使用環境では認証状態は次テストに持ち越されない。そのため **Cleanup 末尾にログアウトを書く必要はない**。

ただし以下の場合はログアウトを保持する：

| カテゴリ | 説明 | 例 |
|---------|------|---|
| ❌ **末尾 Cleanup ログアウト** | 書かない（不要・冗長） | `await logoutAction.execute()` を test の最後に置く |
| ✅ **mid-flow ユーザー切替** | 保持（次のログインに必要） | 管理者でデータ作成 → logout → 別ロールでログイン |
| ✅ **ログアウト自体が subject** | 保持（検証対象） | ログアウト機能そのものを検証するテスト（`isLogoutComplete()` 等） |

**gate 化しない理由**: Cleanup の `execute()` と mid-flow の `execute()` は grep で区別できず誤爆するため、生成時誘導（この skill）で対応する。
