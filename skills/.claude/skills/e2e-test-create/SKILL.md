---
name: e2e-test-create
description: "E2Eテスト作成用。テスト追加・Actions/PageObject実装・ユーザーストーリーからのテスト生成時に使用。MUSTチェックリスト・Fixture定義・待機パターン・外部認証フロー・既に試して失敗したパターンを含む。"
---

# E2E Test Creation Skill

## §1. MUSTチェックリスト（コード生成前に確認）

| 層 | ❌ 禁止 | ✅ 必須 |
|---|---|---|
| **Page Object** | `private readonly` | `readonly`（public）+ constructor初期化 |
| **Page Object** | expect / waitForTimeout | 単一責任メソッド、waitFor+try-catchは許可 |
| **Action** | expect() | waitFor()、各ステップで`this.step()` |
| **Action** | `console.log`単体でステップログ | `this.step('名前', async () => { ... })` |
| **Action** | 数値/URLハードコード | TIMEOUTS/URL_PATTERNS定数 + 理由コメント |
| **Test** | `from '@playwright/test'` | `from '../fixtures/app.fixture'` |
| **Test** | `new XxxAction(page)` | Fixture引数 `async ({ xxxAction }) =>` |
| **Test** | Locator直接記述 | Action verify メソッド経由 |

---

## §2. Fixture定義

```typescript
// fixtures/app.fixture.ts
import { test as base } from '@playwright/test';
import { LoginAction } from '../actions/LoginAction';
import { XxxAction } from '../actions/XxxAction';

type AppFixtures = { loginAction: LoginAction; xxxAction: XxxAction; };

export const test = base.extend<AppFixtures>({
  loginAction: async ({ page }, use) => { await use(new LoginAction(page)); },
  xxxAction: async ({ page }, use) => { await use(new XxxAction(page)); },
});
export { expect } from '@playwright/test';
```

**新規Action → Fixtureにもimport+登録 → テストで引数宣言**

---

## §3. 待機処理パターン

| 状況 | 待機方法 | 定数 |
|------|---------|------|
| ページ遷移後 | `networkidle` + `waitForTimeout` | `TIMEOUTS.SPA_RENDERING` |
| モーダル表示 | `waitFor({state:'visible'})` + `waitForTimeout` | `TIMEOUTS.MODAL_ANIMATION` |
| 外部認証遷移 | `waitForURL()` + `waitForTimeout` | プロジェクト固有定数 |
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
3. 既存資産の探索（Actions/PageObject/類似Test）→ 再利用優先
4. 追加ファイルを最小限に → 新規Actionは**Fixtureにも登録**
5. 実装（rulesの4層責務に従う）
6. `npx playwright test <file>` で動作確認
7. MUSTチェックリストで最終確認

**既存コードがルール違反の可能性あり。コピー前にMUSTリストと照合。**

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

---

## §10. 命名規則

| 種類 | パターン | 例 |
|------|---------|---|
| Page Object | `{画面名}Page.ts` | `LoginPage.ts` |
| Action | `{機能名}Action.ts` | `LoginAction.ts` |
| Test | `{テスト対象}.spec.ts` | `user-journey.spec.ts` |

テスト名は具体的に: `'有効な認証情報でログインできる'` ✅ / `'ログインテスト'` ❌
