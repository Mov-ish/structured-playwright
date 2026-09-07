---
name: e2e-test-create
description: "E2Eテスト作成用。テスト追加・Actions/PageObject実装・ユーザーストーリーからのテスト生成時に使用。SOP・Fixture定義・待機パターン・テストデータ設計・JSDocテンプレートを含む。外部認証フロー実装例はauth0-flow.md・失敗パターンはfailure-patterns.mdを参照。"
---

# E2E Test Creation Skill

## §6. AI作業手順（SOP）— まずここから

1. MUSTチェックリスト確認（rules/architecture.md「層間の絶対境界」+ rules/prohibited-patterns.md）
2. **原本を受け取り、テスト単位に分解する**
   - 原本 = テストの意図を記述した文書（テスト手順書 / チェックリスト / 受け入れ条件 / ユーザーストーリー。粒度はまちまちでよい）
   - 原本が提示されていない・意図が読み取れない場合は**推測で補完せず人間に確認する**（勝手な補完は「原本にない検証」を生み、後段の差分欄で説明できなくなる）
3. **テスト手順書を先に書く**（テンプレート・タグ表は §11、規範は `architecture.md`「Test層のヘッダーコメント」）
   - Phase分割・手順番号・検証ポイントを自然言語で整理 — **原本を §11 テンプレートの書式へ正規化する**工程
   - 原本と意図的に変える点（手順の統合・検証の厳密化・データの代替等）は §11 の「元手順書との意図的差分」欄に集約する
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
| **全層共通** | テストが要求したものを満たせない時に黙ってスキップ | 明示的に要求された操作が失敗したら Fail（`prohibited-patterns.md` 参照） |

---

## §2. Fixture定義

**雛形の正本 = `e2e-bootstrap/fixture-template.md`**（`base.extend` の全体構造・worker スコープ stepCounter を含む完全形）。テスト作成時に必要な差分は「新規 Action の登録」のみ:

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

**正本 = `test-data-management.md`（同ディレクトリ）— テストデータ設計・Setup Action 化の判断・[Arrange] の構造を決めるときに必ず読む。** 収録: スコープ設計（複数 `test()` 間の共有 / `beforeAll` / Setup Action パターン）・通しテストの肥大とベース作成の集約・Action の引数化・verify は観測のみ・テストが要求したものを満たせない場合は Fail（Silent Skip 禁止）・Cleanup フェーズの正直な検証。

## §10. 命名規則

| 種類 | パターン | 例 |
|------|---------|---|
| Page Object | `{画面名}Page.ts` | `LoginPage.ts` |
| Action | `{機能名}Action.ts` | `LoginAction.ts` |
| Test | `{テスト対象}.spec.ts` | `user-journey.spec.ts` |

テスト名は日本語で具体的に: `'有効な認証情報でログインできる'` ✅

---

## §11. テスト手順書（JSDoc）テンプレート

**正本 = `jsdoc-template.md`（同ディレクトリ）— テスト手順書を書くときに必ず読む。** 収録: テンプレート全文（元手順書との意図的差分 欄を含む）・configure トップレベル配置・タグの意味表・Cleanup ログアウトの原則。
