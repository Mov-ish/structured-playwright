---
name: e2e-test-create
description: "E2Eテスト作成用Skill。テスト追加・Actions/PageObject実装・ユーザーストーリーからのテスト生成時に使用。4層アーキテクチャの責務・Fixtureルール・MUSTチェックリスト・待機パターン・外部認証フロー・成功事例を含む。"
---

# E2E Test Creation Skill

> **テスト作成フェーズで使用。** Locator選択の詳細は `e2e-locator` Skill を参照。

---

## §1. コード生成前の必須チェックリスト（MUST）

**コードを1行も書く前に確認。**

### インポート必須

```typescript
// 全ファイルで必須
import { TIMEOUTS } from '../config/constants';

// Page Object では追加で
import { SELECTORS } from '../config/constants';

// Action では追加で
import { URL_PATTERNS } from '../config/constants';

// Test では必須（Fixture経由）
import { test, expect } from '../fixtures/app.fixture';
// ❌ 禁止: import { test, expect } from '@playwright/test';
```

### 層別ルール早見表

| 層 | ❌ 禁止 | ✅ 必須 |
|---|---|---|
| **Page Object** | `private readonly` でLocator定義 | `readonly`（public）で定義、constructorで初期化 |
| **Page Object** | ビジネスロジック・expect・waitForTimeout | 単一責任メソッド、waitFor+try-catchは許可 |
| **Action** | expect()（アサーション） | waitFor()（待機操作）、各ステップでconsole.log |
| **Action** | タイムアウト数値ハードコード | TIMEOUTS定数 + 理由コメント |
| **Action** | URLパターンハードコード | URL_PATTERNS定数 |
| **Test** | `from '@playwright/test'` | `from '../fixtures/app.fixture'` |
| **Test** | `new XxxAction(page)` | Fixture引数 `async ({ xxxAction }) =>` |
| **Test** | Locator直接記述 | Action の verify メソッド経由で検証 |
| **全層** | `text=ログイン` 記法 | `:has-text("ログイン")` または `getByRole` |
| **全層** | `.first()` コメントなし | `.first()` + 理由コメント + TODO |
| **全層** | `.catch(() => false)` | expect().toBeVisible() + try-catch |

---

## §2. 4層アーキテクチャの責務

```
Layer 4: Config/Env     → 環境設定・定数（constants.ts / env.ts）
Layer 3: Tests          → 期待結果検証（AAAパターン）← Locator書かない
Layer 2: Actions        → ビジネスフロー・複数画面制御 ← expect書かない
Layer 1: Page Objects   → UI要素定義・基本操作 ← Locatorはここだけ
```

### Layer 1: Page Objects

```typescript
export class XxxPage {
  readonly page: Page;
  readonly emailInput: Locator;      // ✅ readonly（publicアクセス可能）
  readonly submitButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.locator('input[name="username"]');
    this.submitButton = page.locator('button[type="submit"]');
  }

  async fillEmail(email: string): Promise<void> {
    await this.emailInput.fill(email);
  }

  // 状態確認 — waitFor() + try-catch は許可（expectは禁止）
  async isMemberDisplayed(memberName: string): Promise<boolean> {
    const row = this.getMemberRow(memberName);
    try {
      await row.waitFor({ state: 'visible', timeout: TIMEOUTS.ELEMENT_VISIBLE });
      return true;
    } catch {
      return false;
    }
  }
}
```

**禁止**: ビジネスロジック / expect() / waitForTimeout() / 複数ページまたがり / 環境依存値

### Layer 2: Actions

```typescript
export class XxxAction extends BaseAction {
  private xxxPage: XxxPage;

  constructor(page: Page) {
    super(page, 'アクション名');
    this.xxxPage = new XxxPage(page);
  }

  async execute(...args: any[]): Promise<void> {
    console.log('=== Xxx処理開始 ===');
    console.log('Step 1: XXX');
    await this.xxxPage.doSomething();
    await this.page.waitForLoadState('networkidle');
    console.log('Step 2: YYY');
    // SPAレンダリング完了を待つ
    await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
    console.log('=== Xxx処理完了 ===');
  }

  // verify メソッド — waitFor()ベースでbooleanを返す（Test層でexpectする）
  async isRegistrationComplete(): Promise<boolean> {
    try {
      await this.completionMessage.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
      return true;
    } catch {
      return false;
    }
  }

  async getDisplayedMemberName(): Promise<string> {
    await this.memberNameCell.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    return await this.memberNameCell.textContent() || '';
  }
}
```

**重要**: `waitFor()` は待機操作でありアサーションではないためAction層で使用可能。
**禁止**: expect() / UIセレクタ直接使用 / 環境設定値直接参照 / ログ省略

### Layer 3: Tests

```typescript
import { test, expect } from '../fixtures/app.fixture';  // ✅ Fixture経由
import { EnvConfig } from '../config/env';

test.describe('テストスイート名', () => {
  test('テストケース名（具体的に）', async ({ xxxAction, page }) => {
    // Arrange
    const env = EnvConfig.getTestEnvironment();
    // Act
    await xxxAction.execute(param1, param2);
    // Assert — Action の verify メソッド経由（Locator直接書かない）
    expect(await xxxAction.isRegistrationComplete()).toBeTruthy();
    expect(await xxxAction.getDisplayedMemberName()).toBe('山田太郎');
  });
});
```

**禁止**: Locator直接記述 / 複雑なロジック / UI要素直接操作 / 環境依存値ハードコード

### Layer 4: Config/Env

```typescript
// config/constants.ts
export const TIMEOUTS = {
  SHORT: 3000, MEDIUM: 10000, LONG: 30000, DEFAULT: 10000,
  EXTERNAL_AUTH_STABILIZATION: 2000, MODAL_ANIMATION: 1000,
  SPA_RENDERING: 2000, REDIRECT: 3000, ELEMENT_VISIBLE: 5000,
} as const;

export const URL_PATTERNS = {
  EXTERNAL_AUTH_LOGIN: '**/login.your-auth-domain.example/**',  // 認証プロバイダURLに変更
  DASHBOARD: '**/dashboard**', LOGIN: '**/login**',
} as const;

export const SELECTORS = {
  MODAL: '[role="dialog"]', SUBMIT_BUTTON: 'button[type="submit"]',
  AGREEMENT_CHECKBOX: 'input[type="checkbox"]:near(:text("同意する"))',
} as const;
```

**新しい定数が必要 →** constants.tsに追加 → インポート → **絶対にハードコードしない**

---

## §3. Fixture定義

```typescript
// fixtures/app.fixture.ts
import { test as base } from '@playwright/test';
import { LoginAction } from '../actions/LoginAction';
import { XxxAction } from '../actions/XxxAction';

type AppFixtures = {
  loginAction: LoginAction;
  xxxAction: XxxAction;
};

export const test = base.extend<AppFixtures>({
  loginAction: async ({ page }, use) => { await use(new LoginAction(page)); },
  xxxAction: async ({ page }, use) => { await use(new XxxAction(page)); },
});

export { expect } from '@playwright/test';
```

**新規Action追加時**: 1) Actionクラス作成 → 2) Fixtureにimport+登録 → 3) テストで引数宣言

---

## §4. 待機処理パターン

| 状況 | 待機方法 | 定数 |
|------|---------|------|
| ページ遷移後 | `networkidle` + `waitForTimeout` | `TIMEOUTS.SPA_RENDERING` |
| モーダル表示 | `waitFor({state:'visible'})` + `waitForTimeout` | `TIMEOUTS.MODAL_ANIMATION` |
| 外部認証遷移 | `waitForURL()` + `waitForTimeout` | `TIMEOUTS.EXTERNAL_AUTH_STABILIZATION` |
| リダイレクト | `waitForTimeout` | `TIMEOUTS.REDIRECT` |
| 確認ダイアログ | `waitFor({state:'visible'})` | `TIMEOUTS.DEFAULT` |

### モーダル待機パターン
```typescript
await page.locator(SELECTORS.MODAL).waitFor({ state: 'visible', timeout: TIMEOUTS.SHORT });
// CSSアニメーション中はクリックが正しく処理されない
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
const button = page.locator('[role="dialog"] button:has-text("保存")');
await button.scrollIntoViewIfNeeded();
await button.click({ force: true });
```

### 削除後のリスト変化確認パターン
```typescript
// ❌ 不安定: SPAではDOM削除で参照無効化
await targetRow.waitFor({ state: 'hidden' });
// ✅ 安定: URL遷移で削除完了を確認
await this.page.waitForURL('**/items?tab=archive', { timeout: TIMEOUTS.DEFAULT });
```

### 検証待機パターン（expect系）

```typescript
// URL遷移の検証待機
await expect(page).toHaveURL(/\/dashboard/);

// 要素の有効化待機
await expect(page.locator('button:has-text("保存")')).toBeEnabled();

// テキスト内容の検証待機
await expect(page.locator('[role="alert"]')).toContainText('保存しました');

// 動的な値をポーリングして待機（カウント変化等）
await expect.poll(async () => {
  return await page.locator('.item').count();
}, {
  timeout: TIMEOUTS.DEFAULT,
  message: 'アイテム数が期待値に達しませんでした'
}).toBeGreaterThan(0);

// エラーバナー検出
await expect(page.locator('[role="alert"]')).toBeVisible();
```

---

## §4.5. コンポーネント別パターン集

### フォーム入力パターン

```typescript
// 基本フォーム入力
await this.nameInput.fill(data.name);
await this.emailInput.fill(data.email);

// ドロップダウン操作（汎用パターン）
await page.getByRole('combobox').click();
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // 選択肢描画待ち
const option = page.locator('.dropdown-option')  // UIライブラリに応じてセレクタを変更
  .filter({ hasText: targetName }).first();
await option.click();
await page.keyboard.press('Escape'); // ドロップダウンを閉じる

// チェックボックス（:near()で特定）
await page.locator('input[type="checkbox"]:near(:text("同意する"))').check();
```

### リスト操作パターン

```typescript
// リスト項目クリック
await page.waitForLoadState('networkidle');
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
await page.locator(`li:has-text("${itemText}")`).click();

// 3点リーダーメニュー（行のLocal Universe内で操作）
const item = page.locator(`li:has-text("${itemText}")`);
const moreButton = item.locator('button:has(svg[data-icon="ellipsis"])');
await moreButton.click();
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);

// 検索・フィルタ
await page.getByPlaceholder('検索').fill(searchText);
await page.waitForLoadState('networkidle');
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
```

### ファイルアップロードパターン

```typescript
// ファイル選択（input[type="file"]に直接セット）
await this.fileInput.setInputFiles(filePath);

// アップロード完了をAPIレスポンスで待機
await this.page.waitForResponse(resp =>
  resp.url().includes('/api/upload') && resp.status() === 200
);
await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // UI更新待ち
```

---

## §4.6. データクリーンアップ・テストデータ管理

### ユニークなテストデータ生成（衝突回避）
```typescript
const groupName = `テストグループ_${Date.now()}`;
const email = `test-${Date.now()}@example.com`;
```

### テスト内クリーンアップ（推奨）
```typescript
test('新規グループ作成テスト', async ({ createGroupAction, deleteGroupAction, page }) => {
  const groupName = `テストグループ_${Date.now()}`;
  // Act
  await createGroupAction.execute(groupName);
  // Assert
  await expect(page.getByText(groupName)).toBeVisible();
  // Cleanup（重要！テストデータを残さない）
  await deleteGroupAction.execute(groupName);
});
```

### afterEachによるクリーンアップ（共通化）
```typescript
test.afterEach(async ({ cleanupAction }) => {
  await cleanupAction.execute();
});
```

**クリーンアップ未実装のテストはレビューで差し戻し対象。**

---

## §5. 外部認証フロー（成功パターン）

<!-- 以下はAuth0を例としたパターン。Cognito/Firebase Auth等でも構造は同じ。 -->

```
1. 利用規約ページ → チェック → メールログインボタン
2. 外部認証ページ(外部ドメイン) → 【URL遷移待機+安定化待機】→ メール/パスワード → ログイン
3. アプリケーション → 【リダイレクト完了待機+ログイン成功検証】
```

**Page Objects分離必須**: TermsPage / ExternalAuthLoginPage を別クラスにする（ドメインが異なる）

```typescript
async execute(url: string, email: string, password: string): Promise<void> {
  console.log('=== ログイン処理開始 ===');
  console.log('Step 1: 利用規約ページへ遷移');
  await this.termsPage.goto(url);
  console.log('Step 2: 利用規約に同意');
  await this.termsPage.agreeToTerms();
  console.log('Step 3: メールログインボタンクリック');
  await this.termsPage.clickEmailLogin();
  console.log('Step 4: 外部認証ページへの遷移を待機');
  await this.page.waitForURL(URL_PATTERNS.EXTERNAL_AUTH_LOGIN, { timeout: TIMEOUTS.DEFAULT });
  await this.page.waitForTimeout(TIMEOUTS.EXTERNAL_AUTH_STABILIZATION);
  console.log('Step 5: メールアドレス入力');
  await this.externalAuthLoginPage.fillEmail(email);
  console.log('Step 6: パスワード入力とログイン');
  await this.externalAuthLoginPage.fillPassword(password);
  await this.externalAuthLoginPage.clickSubmit();
  console.log('Step 7: リダイレクト完了を待機');
  await this.page.waitForURL(URL_PATTERNS.DASHBOARD, { timeout: TIMEOUTS.LONG });
  // ログイン成功検証（MUST）
  const currentURL = this.page.url();
  if (currentURL.includes('/login')) {
    throw new Error('ログインに失敗しました（ログインページのままです）');
  }
  console.log('✅ ログイン成功を確認');
  console.log('=== ログイン処理完了 ===');
}
```

---

## §6. エラーハンドリング

### `.catch(() => false)` は絶対禁止
```typescript
// ❌ 危険: タイムアウトエラーを隠蔽
const isVisible = await element.isVisible({ timeout: 5000 }).catch(() => false);

// ✅ 正しい
try {
  await expect(element).toBeVisible({ timeout: TIMEOUTS.CHECK });
  await element.click();
} catch {
  // Optional element, skip
}
```

---

## §6.5. 既に試して失敗したパターン（再発明するな）

以下のアプローチは実際に試行して失敗が確認されている。
AIはこれらを「新しいアイデア」として提案してはならない。

### 外部認証（Auth0等）の待機

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| `waitForLoadState('networkidle')` のみ | ❌ 失敗 | 外部ドメイン遷移前に次の操作が走る |
| `page.waitForURL()` のみ | ⚠️ 不安定 | URL変化は検知するが認証画面の描画完了を待たない |
| `page.waitForURL()` + `waitForTimeout()` | ✅ 成功 | URL遷移確認 + 画面安定化の組み合わせ |

### SPA描画待機

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| `waitForLoadState('networkidle')` のみ | ❌ 不安定 | Reactのレンダリングはnetwork完了後に発生 |
| 固定待機時間（5000ms）のみ | ❌ 遅い | 不必要に遅く、かつ環境によっては不足 |
| `networkidle` + `waitForTimeout(TIMEOUTS.SPA_RENDERING)` | ✅ 成功 | ネットワーク完了+SPA描画の両方をカバー |

### 削除後の変化確認

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| `waitFor({ state: 'hidden' })` | ❌ 失敗 | SPAでDOMから要素が完全削除され参照が無効に |
| `waitFor({ state: 'detached' })` | ❌ 不安定 | DOM依存で環境差がある |
| `expect().toHaveCount(0)` | ❌ 失敗 | 削除済みタブでは動作せず |
| URL遷移確認 | ✅ 成功 | 間接的だが安定 |

### モーダル内ボタンクリック

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| モーダル表示直後にクリック | ❌ 失敗 | CSSアニメーション中はクリックイベントが処理されない |
| `waitFor({state:'visible'})` のみ | ⚠️ 不安定 | visible=trueでもアニメーション中の場合がある |
| `waitFor` + `waitForTimeout(MODAL_ANIMATION)` + `scrollIntoViewIfNeeded` + `force:true` | ✅ 成功 | 表示+アニメーション+スクロール+強制クリックの全対策 |

### セレクタ選択の失敗（data-testid/aria-labelが不足する環境）

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| `getByLabel('同意する')` | ❌ 失敗 | label要素が存在しない |
| `getByRole('checkbox')` | ❌ 失敗 | 一意に特定できない |
| `button[aria-label="more"]` | ❌ 失敗 | aria-labelが存在しない |
| `button:has-text("...")` | ❌ 失敗 | 3点リーダーはSVGアイコンでありテキストではない |
| `getByRole('row', { name })` | ❌ 失敗 | 行のaccessible nameが設定されていない |
| `filter({ hasNot: getByText(...) })` | ❌ 失敗 | hasNotは子要素チェック、テキスト除外にはhasNotTextが必要 |

---

## §7. AI作業手順（SOP）

1. MUSTチェックリスト確認（§1）
2. ストーリーをテスト単位に分解
3. 既存資産の探索（Actions/PageObject/類似Test）→ 再利用優先
4. 追加ファイルを最小限に → 新規Actionは**Fixtureにも登録**
5. 実装（4層責務に従う）
6. 実行して動作確認（`npx playwright test <file>`）
7. MUSTチェックリストで最終確認

**既存コードがルール違反している可能性あり。コピー前にMUSTリストと照合。**

---

## §8. 命名規則

| 種類 | パターン | 例 |
|------|---------|---|
| Page Object | `{画面名}Page.ts` | `LoginPage.ts` |
| Action | `{機能名}Action.ts` | `LoginAction.ts` |
| Test | `{テスト対象}.spec.ts` | `user-journey.spec.ts` |

テスト名は日本語で具体的に: `'有効な認証情報でログインできる'` ✅ / `'ログインテスト'` ❌

---

## 🔌 Appendix A: Auth0 固有パターン

<!-- Auth0を使用するプロジェクトのみ。不要なら削除可。 -->

### Auth0用 constants.ts 追加定数
```typescript
export const SELECTORS = {
  ...SELECTORS,
  AUTH0_EMAIL_INPUT: 'input[name="username"]',
  AUTH0_PASSWORD_INPUT: 'input[name="password"]',
} as const;
```

### Auth0固有の注意点
- Auth0ログインページは外部ドメイン → Page Objectsを必ず分離（TermsPage / Auth0LoginPage）
- URL遷移待機 + `EXTERNAL_AUTH_STABILIZATION` の組み合わせが必須（§6.5参照）
- Auth0のユニバーサルログイン画面はバージョンアップで構造が変わることがある

---

## 🔌 Appendix B: Ant Design 固有パターン

<!-- Ant Designを使用するプロジェクトのみ。MUI/Chakra UI等の場合は適宜書き換え。 -->

### Ant Design ドロップダウン操作（定型手順）
```typescript
await page.getByRole('combobox').click();
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
const option = page.locator('.ant-select-item-option')
  .filter({ hasText: targetName }).first();
await option.click();
await page.keyboard.press('Escape');
```

### Ant Design セレクタ定数
```typescript
export const SELECTORS = {
  ...SELECTORS,
  ANT_MODAL_CONTENT: '.ant-modal-content',
  ANT_SELECT_OPTION: '.ant-select-item-option',
  ANT_SELECT_DROPDOWN: '.ant-select-dropdown',
} as const;
```

**注意**: Ant Designのクラス名はバージョンアップで変更される可能性がある。

---

## 追記エリア

新しいパターンを発見した場合、以下の形式で追記する。

### YYYY-MM-DD - パターン名
- **発見の経緯**: （何をして、何が起きたか）
- **解決策**: （コード例）
- **注意事項**: （適用条件・制約）
