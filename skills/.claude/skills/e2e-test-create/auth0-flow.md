---
name: e2e-test-create/auth0-flow
description: "外部認証フロー（Auth0 等）の実装パターン。LoginActionを新規実装・修正するときに参照。"
---

# 外部認証フロー（Auth0 等）— 成功パターン

```
ログインページ → （プロダクト固有の前操作） → 外部認証サービス（Auth0 等）
→ 【URL遷移待機 + 安定化】→ メール/パスワード入力
→ アプリケーション → 【リダイレクト完了 + ログイン成功検証】
```

**Page Objects分離必須**: ドメインが異なるページは必ず別の Page Object に分離する（例: `LoginPage` / `AuthLoginPage`）

```typescript
async execute(url: string, email: string, password: string): Promise<void> {
  this.beginAction();

  await this.step('ログインページへ遷移', async () => {
    await this.loginPage.goto(url);
  });

  // （プロダクト固有のログイン前操作がある場合ここに追加）
  // 例: 利用規約への同意、ログイン方法の選択、等

  await this.step('外部認証ページへの遷移を待機', async () => {
    await this.page.waitForURL(URL_PATTERNS.AUTH_LOGIN, { timeout: TIMEOUTS.DEFAULT });
    // 外部認証画面の安定化待ち（画面描画 + JS 初期化完了）
    await this.page.waitForTimeout(TIMEOUTS.AUTH_STABILIZATION);
  });

  await this.step('メールアドレス入力', async () => {
    await this.authLoginPage.fillEmail(email);
  });

  await this.step('パスワード入力とログイン', async () => {
    await this.authLoginPage.fillPassword(password);
    await this.authLoginPage.clickSubmit();
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

## constants.ts に追加が必要な定数

```typescript
export const URL_PATTERNS = {
  AUTH_LOGIN: '**/authorize**',   // 外部認証サービスの URL パターン
  DASHBOARD: '**/dashboard**',    // ログイン後の遷移先
  LOGIN_PATH: '/login',           // ログインページの識別パス
} as const;

export const TIMEOUTS = {
  AUTH_STABILIZATION: 2000,  // 外部認証画面の描画安定化待ち
  LONG: 30000,               // リダイレクト完了等の長い待機
} as const;
```

## Page Object の最小構成

```typescript
// pages/AuthLoginPage.ts — 外部認証サービス側のページ
export class AuthLoginPage {
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;

  constructor(page: Page) {
    this.emailInput = page.getByLabel('Email');        // 実際の属性に合わせて変更
    this.passwordInput = page.getByLabel('Password');
    this.submitButton = page.getByRole('button', { name: 'Continue' });
  }

  async fillEmail(email: string): Promise<void> {
    await this.emailInput.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    await this.emailInput.fill(email);
  }

  async fillPassword(password: string): Promise<void> {
    await this.passwordInput.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    await this.passwordInput.fill(password);
  }

  async clickSubmit(): Promise<void> {
    await this.submitButton.click();
  }
}
```

## 注意点

- **外部ドメインへの遷移後は必ず `waitForTimeout(TIMEOUTS.AUTH_STABILIZATION)` を入れる** — URL 変化を検知しても画面描画・JS 初期化が終わっていない状態で次操作が走るため
- **ログイン成功検証は必須** — リダイレクト完了後もログインページ URL が残っていれば認証失敗として明示的に throw する
- **プロダクト固有の前操作**（利用規約同意・ログイン方法選択 等）がある場合は、`LoginPage` の Page Object にメソッドを追加し、Action のステップとして明示する

待機パターンの失敗例は `failure-patterns.md`「外部認証の待機」参照。
