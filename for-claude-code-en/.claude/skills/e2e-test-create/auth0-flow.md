---
name: e2e-test-create/auth0-flow
description: "Implementation pattern for external authentication flows (Auth0 etc.). Refer to this when implementing or modifying LoginAction."
---

# External Authentication Flow (Auth0 etc.) — Working Pattern

```
Login page → (product-specific pre-login steps) → external auth service (Auth0 etc.)
→ [wait for URL transition + stabilization] → enter email/password
→ application → [redirect complete + verify login success]
```

**Page Object separation is mandatory**: pages on different domains must be split into separate Page Objects (e.g. `LoginPage` / `AuthLoginPage`)

```typescript
async execute(url: string, email: string, password: string): Promise<void> {
  this.beginAction();

  await this.step('Navigate to the login page', async () => {
    await this.loginPage.goto(url);
  });

  // (add product-specific pre-login steps here if any)
  // e.g. accepting the terms of service, choosing a login method, etc.

  await this.step('Wait for the transition to the external auth page', async () => {
    await this.page.waitForURL(URL_PATTERNS.AUTH_LOGIN, { timeout: TIMEOUTS.DEFAULT });
    // Wait for the external auth screen to stabilize (rendering + JS initialization complete)
    await this.page.waitForTimeout(TIMEOUTS.AUTH_STABILIZATION);
  });

  await this.step('Enter the email address', async () => {
    await this.authLoginPage.fillEmail(email);
  });

  await this.step('Enter the password and log in', async () => {
    await this.authLoginPage.fillPassword(password);
    await this.authLoginPage.clickSubmit();
  });

  await this.step('Wait for the redirect to complete', async () => {
    await this.page.waitForURL(URL_PATTERNS.DASHBOARD, { timeout: TIMEOUTS.LONG });
  });

  // Verify login success (MUST)
  if (this.page.url().includes(URL_PATTERNS.LOGIN_PATH)) {
    throw new Error('Login failed (still on the login page)');
  }
}
```

## Constants that must be added to constants.ts

```typescript
export const URL_PATTERNS = {
  AUTH_LOGIN: '**/authorize**',   // URL pattern of the external auth service
  DASHBOARD: '**/dashboard**',    // destination after login
  LOGIN_PATH: '/login',           // identifying path of the login page
} as const;

export const TIMEOUTS = {
  AUTH_STABILIZATION: 2000,  // wait for the external auth screen rendering to stabilize
  LONG: 30000,               // long waits such as redirect completion
} as const;
```

## Minimal Page Object

```typescript
// pages/AuthLoginPage.ts — the page on the external auth service side
export class AuthLoginPage {
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;

  constructor(page: Page) {
    this.emailInput = page.getByLabel('Email');        // adjust to the actual attributes
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

## Notes

- **Always add `waitForTimeout(TIMEOUTS.AUTH_STABILIZATION)` after transitioning to an external domain** — even when the URL change is detected, the next operation would otherwise run before rendering and JS initialization have finished
- **Login success verification is mandatory** — if the login page URL persists after the redirect completes, throw explicitly as an authentication failure
- If there are **product-specific pre-login steps** (accepting terms of service, choosing a login method, etc.), add methods to the `LoginPage` Page Object and make them explicit as Action steps

For failed wait patterns, see `failure-patterns.md` "External auth waits".
