# 4層アーキテクチャの責務と境界

## 層構造

```
Layer 4: Config/Env     → 環境設定・定数（constants.ts / env.ts）
Layer 3: Tests          → 期待結果検証（AAAパターン）
Layer 2: Actions        → ビジネスフロー・複数画面制御
Layer 1: Page Objects   → UI要素定義・基本操作
```

```
src/
├── config/      # Layer 4
├── pages/       # Layer 1（Locatorはここだけ）
├── actions/     # Layer 2
├── fixtures/    # Test層のインフラ（app.fixture.ts）
└── tests/       # Layer 3
```

## 層間の絶対境界

| ルール | 理由 |
|--------|------|
| **Test層にLocatorを書かない** | テストは意図と期待結果の表現。UI構造を知る必要がない |
| **Action層にexpect()を書かない** | expectはテスト固有のアサーション。Actionは再利用可能なフロー |
| **Page Objectにビジネスロジックを書かない** | POはUI要素と単一操作のみ。フローはAction層 |
| **`@playwright/test`から直接importしない** | Fixture経由で`test`/`expect`をインポートする |
| **Actionを手動`new`しない** | Fixture引数で受け取る（依存の明示化） |

## Test層とAction層の検証の両立

Test層でLocatorが書けず、Action層でexpectが書けない。この2つを同時に満たすパターン：

**Action層**: `waitFor()`ベースのverifyメソッドを実装（waitForは待機操作でありアサーションではない）
```typescript
// Action層 — waitFor() は許可
async isRegistrationComplete(): Promise<boolean> {
  try {
    await this.completionMessage.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    return true;
  } catch { return false; }
}
```

**Test層**: verifyメソッドの戻り値をexpect()で検証
```typescript
// Test層 — Locator直接書かない
expect(await memberAction.isRegistrationComplete()).toBeTruthy();
```

## Page Objectのアクセス修飾子

```typescript
// ❌ 禁止: private readonly
private readonly emailInput: Locator;

// ✅ 必須: readonly（publicアクセス可能）
readonly emailInput: Locator;
```

## Page Objectで許可される待機

`waitFor()` + try-catchでbooleanを返す状態確認メソッドは許可。
`expect()`によるアサーション、`waitForTimeout()`による固定待機は禁止。

## Action層のステップログ

Action層の各ステップは `this.step()` ヘルパーで記録する（`console.log`単体は非推奨）。
`test.step()` によりreport.json・HTMLレポートにステップ構造が残り、Fail時にどのステップで落ちたか即特定できる。

### BaseActionの必須ヘルパー

```typescript
// BaseAction に必ず実装する
protected async step(name: string, fn: () => Promise<void>): Promise<void> {
  console.log(`Step: ${name}`);
  try {
    const { test } = await import('@playwright/test');
    await test.step(name, fn);
  } catch {
    // テストコンテキスト外（デバッグ時等）→ そのまま実行
    await fn();
  }
}
```

### 使い方
```typescript
// Action内
async execute(url: string, email: string, password: string): Promise<void> {
  await this.step('ログインページへ遷移', async () => {
    await this.loginPage.goto(url);
  });
  await this.step('認証情報入力', async () => {
    await this.authPage.fillEmail(email);
    await this.authPage.fillPassword(password);
  });
}
```

### ネスト防止ルール

**Test層では `test.step()` で包まない。** ステップの粒度はAction層が管理する。
Test層でstep()を使うとreportのネストが深くなり可読性が下がる。

## Fixture

```typescript
import { test as base } from '@playwright/test';
export const test = base.extend<AppFixtures>({
  loginAction: async ({ page }, use) => { await use(new LoginAction(page)); },
});
export { expect } from '@playwright/test';
```

新規Action追加時 → Fixtureにも登録必須。
