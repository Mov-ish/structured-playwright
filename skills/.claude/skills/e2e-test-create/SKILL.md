---
name: e2e-test-create
description: "E2Eテスト作成用。テスト追加・Actions/PageObject実装・ユーザーストーリーからのテスト生成時に使用。MUSTチェックリスト・Fixture定義・待機パターン・外部認証フロー・既に試して失敗したパターンを含む。"
---

# E2E Test Creation Skill

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

```typescript
// fixtures/app.fixture.ts
import { test as base } from '@playwright/test';
import { StepCounter } from '../actions/StepCounter';
import { LoginAction } from '../actions/LoginAction';
import { XxxAction } from '../actions/XxxAction';

type AppFixtures = { loginAction: LoginAction; xxxAction: XxxAction; };

// Worker スコープ Fixture — stepCounter は describe 境界で自動リセットするため、
// worker 全体で 1 インスタンス共有する（test スコープだと test() 跨ぎで番号が継続しない）
type WorkerFixtures = { stepCounter: StepCounter; };

export const test = base.extend<AppFixtures, WorkerFixtures>({
  stepCounter: [
    async ({}, use) => { await use(new StepCounter()); },
    { scope: 'worker' },
  ],
  loginAction: async ({ page, stepCounter }, use) => { await use(new LoginAction(page, stepCounter)); },
  xxxAction: async ({ page, stepCounter }, use) => { await use(new XxxAction(page, stepCounter)); },
});
export { expect } from '@playwright/test';
```

**新規Action → Fixtureにもimport+登録（stepCounter注入）→ テストで引数宣言**

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

## §4. 外部認証フロー（該当する場合）

外部認証（Auth0、Okta、AzureAD等）を使うプロダクトでは、外部ドメインへの遷移が発生する。

### 基本原則
- **ドメインが異なるページは必ず別のPage Objectに分離する**
- URL遷移の明示的な待機が必須
- 画面安定化の待機が必須
- ログイン成功検証（MUST）— URLがログインページでないことを確認

### 実装パターン
```typescript
async execute(url: string, email: string, password: string): Promise<void> {
  this.beginAction();
  await this.step('ログインページへ遷移', async () => {
    await this.loginPage.goto(url);
  });

  // （プロダクト固有のログイン前操作がある場合ここに）

  await this.step('外部認証ページへの遷移を待機', async () => {
    await this.page.waitForURL(URL_PATTERNS.AUTH_LOGIN, { timeout: TIMEOUTS.DEFAULT });
    // 外部認証画面の安定化待ち
    await this.page.waitForTimeout(TIMEOUTS.AUTH_STABILIZATION);
  });

  await this.step('認証情報入力', async () => {
    await this.authPage.fillEmail(email);
    await this.authPage.fillPassword(password);
    await this.authPage.clickSubmit();
  });

  await this.step('リダイレクト完了待機', async () => {
    await this.page.waitForURL(URL_PATTERNS.DASHBOARD, { timeout: TIMEOUTS.LONG });
  });

  // ログイン成功検証（MUST）
  if (this.page.url().includes(URL_PATTERNS.LOGIN_PATH)) {
    throw new Error('ログインに失敗しました（ログインページのままです）');
  }
}
```

---

## §5. 既に試して失敗したパターン（再発明するな）

### 外部認証の待機

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| `waitForLoadState('networkidle')` のみ | ❌ | 外部ドメイン遷移前に次の操作が走る |
| `page.waitForURL()` のみ | ⚠️ 不安定 | URL変化は検知するが画面描画完了を待たない |
| `waitForURL()` + `waitForTimeout()` | ✅ | URL遷移確認+画面安定化の組み合わせ |

### SPA描画待機

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| `networkidle` のみ | ❌ 不安定 | フレームワークの描画はnetwork完了後に発生 |
| 固定5000ms | ❌ 遅い | 不必要に遅く環境差で不足する場合も |
| `networkidle` + `TIMEOUTS.SPA_RENDERING` | ✅ | 両方カバー |

### 削除後の変化確認

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| `waitFor({ state: 'hidden' })` | ❌ | SPAでDOM完全削除→参照無効 |
| `waitFor({ state: 'detached' })` | ❌ 不安定 | DOM依存で環境差 |
| URL遷移確認 | ✅ | 間接的だが安定 |

### モーダル内ボタン

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| 表示直後クリック | ❌ | CSSアニメーション中は処理されない |
| `waitFor` のみ | ⚠️ 不安定 | visibleでもアニメーション中あり |
| `waitFor` + `MODAL_ANIMATION` + `scrollIntoView` + `force:true` | ✅ | 全対策 |

### セレクタ選択

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| 属性不足要素に `getByLabel()` | ❌ | label要素が存在しない場合がある |
| `getByRole('checkbox')` スコープなし | ❌ | 一意に特定できない |
| `button[aria-label="more"]` | ❌ | aria-label未設定の場合がある |
| `button:has-text("...")` で三点リーダー | ❌ | 三点リーダーはSVGでありテキストではない |
| `getByRole('row', { name })` | ❌ | accessible nameが設定されていないテーブルがある |
| `filter({ hasNot })` でテキスト除外 | ❌ | hasNotは子要素チェック。hasNotTextが必要 |

---

## §6. AI作業手順（SOP）

1. MUSTチェックリスト確認（§1）
2. ストーリーをテスト単位に分解
3. **テスト手順書を先に書く**（`architecture.md`「Test層のヘッダーコメント」参照）
   - Phase分割・手順番号・検証ポイントを自然言語で整理
   - これがテスト実装の設計書になる
4. `fixtures/app.fixture.ts` の **Action カタログを確認**
   - 既存 Action のメソッド一覧から再利用可能なものを特定
   - 必要な Action が TODO にあれば新規作成が必要
5. 既存資産の探索（Actions/PageObject/類似Test）→ 再利用優先
   > ⚠️ **既存コードがルール違反の場合がある。** コピー前に §1 MUSTチェックリストと照合すること。
   > 違反を見つけたらコピーせず正しいパターンで実装する。
6. 追加ファイルを最小限に → 新規Actionは**Fixtureにも登録 + Action カタログを更新**（`architecture.md`「Action カタログ規約」参照）
7. 実装（rulesの4層責務に従う）
8. `npx playwright test <file>` で動作確認
9. 実行時間をヘッダーコメントに記載
10. MUSTチェックリストで最終確認

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

### リトライパターン（不安定な操作向け）
```typescript
async clickWithRetry(locator: Locator, maxRetries = 3): Promise<void> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await locator.click({ timeout: TIMEOUTS.SHORT });
      return;
    } catch {
      if (i === maxRetries - 1) throw;
      await this.page.waitForTimeout(TIMEOUTS.SHORT);
    }
  }
}
```

---

## §9. テストデータ管理

- **静的テストデータ**: `config/testdata/` に JSON ファイル配置
- **動的テストデータ**: ユーティリティ関数で生成（タイムスタンプ付き名前等）
- **テスト後クリーンアップ**: 作成したデータの削除を Action として実装

### 複数 `test()` 間でデータを共有する場合

**禁止**: module スコープに `const random = Date.now()` を置いて複数 `test()` が暗黙参照する構造（`prohibited-patterns.md`「テスト間データ依存」参照）。

**推奨パターン早見表**（`architecture.md`「テストデータの共有と再利用」参照）:

| 状況 | 実装 |
|------|------|
| 単一 `test()` 完結 | `test()` 内で `const random = Date.now()` |
| 同一 describe 内 Phase 分割 | `test.beforeAll` でデータ準備 + describe スコープ変数で共有 |
| 別 spec / 別 TC から再利用したい | Setup Action + Fixture（後述） |
| TC全体が通しユーザーストーリー | `test()` を分割せず 1つの `test()` 内に収め、`test.step()` で Phase 表現 |

#### `beforeAll` パターン（同一 describe 内 Phase 分割）

```typescript
test.describe('TC-XX: リソース利用ストーリー', () => {
  let resourceName: string;
  let subItemName: string;

  test.beforeAll(async ({ browser }) => {
    const context = await browser.newContext();
    const page = await context.newPage();
    // セットアップ Action でリソース作成
    const random = Date.now().toString();
    resourceName = `リソース名${random}`;
    subItemName = `サブ項目${random}`;
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
    return { resourceName, subItemName: `サブ項目${opts.random}` };
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
  const random = Date.now().toString();
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

外部テストツール（MagicPod 等）の Shared Step に対応する粒度（リソース操作・状態確認・後始末等）は、最初から Action 引数化しておくこと。

---

## §10. 命名規則

| 種類 | パターン | 例 |
|------|---------|---|
| Page Object | `{画面名}Page.ts` | `LoginPage.ts` |
| Action | `{機能名}Action.ts` | `LoginAction.ts` |
| Test | `{テスト対象}.spec.ts` | `user-journey.spec.ts` |

テスト名は具体的に: `'有効な認証情報でログインできる'` ✅ / `'ログインテスト'` ❌
