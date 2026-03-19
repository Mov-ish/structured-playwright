---
name: e2e-bootstrap
description: "E2E環境構築用。新規セットアップ・Playwright導入・既存プロジェクトの4層アーキテクチャ変換時に使用。Definition of Done・最小骨格・Fixture/constants雛形・コーディング規約・Playwrightデフォルトからの変換手順を含む。"
---

# E2E Bootstrap Skill

> テスト追加が目的なら `/e2e-test-create` を使うこと。

## §1. Definition of Done

- `npm test` が実行できる（smokeが1本通る）
- `npx tsc --noEmit` が通る（型エラー・未使用importがゼロ）
- Playwrightとブラウザ依存が揃っている
- 4層アーキテクチャの最小ディレクトリが存在する
- 認証情報は`.env`/CI環境変数で管理
- Fixtureファイル（app.fixture.ts）が存在しtest/expectをexport

---

## §2. 4層の最小骨格

```
src/
├── tests/           # Layer 3: シナリオ
├── actions/         # Layer 2: ユーザ操作の流れ
├── pages/           # Layer 1: 画面要素と操作（Locatorはここ）
├── fixtures/        # Fixture定義
│   └── app.fixture.ts
└── config/          # Layer 4: 環境差分・設定
    ├── env.ts
    └── constants.ts
```

---

## §3. 最小Fixture

```typescript
import { test as base } from '@playwright/test';
import { LoginAction } from '../actions/LoginAction';

type AppFixtures = { loginAction: LoginAction; };

export const test = base.extend<AppFixtures>({
  loginAction: async ({ page }, use) => { await use(new LoginAction(page)); },
});
export { expect } from '@playwright/test';
```

---

## §4. 最小constants.ts

```typescript
export const TIMEOUTS = {
  SHORT: 3000,
  MEDIUM: 10000,
  LONG: 30000,
  DEFAULT: 10000,
  MODAL_ANIMATION: 1000,
  SPA_RENDERING: 2000,
  REDIRECT: 3000,
  // プロジェクト固有: 外部認証画面安定化等を追加
} as const;

export const SELECTORS = {
  MODAL: '[role="dialog"]',
  SUBMIT_BUTTON: 'button[type="submit"]',
  // プロジェクト固有のセレクタを追加
} as const;

export const URL_PATTERNS = {
  LOGIN: '**/login**',
  DASHBOARD: '**/dashboard**',
  LOGIN_PATH: '/login',
  // プロジェクト固有のURLパターンを追加
  // 例: AUTH_LOGIN: '**/auth.example.com/**',
} as const;
```

---

## §5. playwright.config.ts 必須設定

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './src/tests',
  timeout: 60000,                          // テスト全体のタイムアウト
  expect: {
    timeout: 10000,                        // 各expectのタイムアウト
  },
  reporter: [
    ['json', { outputFile: 'test-results/report.json' }],  // 構造化レポート
    ['html', { open: 'never' }],                            // HTMLレポート
    ['list'],                                                // ターミナル表示
  ],
  use: {
    trace: 'retain-on-failure',            // 失敗時のtrace自動保存
    screenshot: 'only-on-failure',         // 失敗時のスクリーンショット
    video: 'retain-on-failure',            // 失敗時の動画
  },
});
```

**なぜこの設定が必須か**:
- `timeout` + `expect.timeout`: 無限に待たせない。偽Passの防止
- `json` reporter: report.jsonにステップ構造が残る。Fail時の追跡に必須
- `trace/screenshot/video on failure`: Fail時の原因特定を高速化
- `html` reporter: 人間がブラウザで結果を確認できる

---

## §6. BaseAction 雛形

全ActionはBaseActionを継承する。`step()`ヘルパーにより`test.step()`とconsole.logが両方出力される。

```typescript
// actions/BaseAction.ts
import { Page } from '@playwright/test';

export class BaseAction {
  protected readonly page: Page;
  protected readonly actionName: string;

  constructor(page: Page, actionName: string) {
    this.page = page;
    this.actionName = actionName;
  }

  /**
   * ステップ記録ヘルパー
   * test.step() でreport.jsonにステップ構造を記録しつつ、
   * console.log でCI環境のstdoutにもログを出す。
   * テストコンテキスト外（デバッグ時等）ではフォールバックで直接実行。
   *
   * 重要: fn() 実行中のエラー（Timeout, Browser crash等）は
   * catch せずそのまま伝播させる。catch するのはテストコンテキスト
   * 判定のみ。これにより偽陽性（flaky pass）を防止する。
   */
  protected async step(name: string, fn: () => Promise<void>): Promise<void> {
    console.log(`Step: ${name}`);
    let hasTestContext = false;
    try {
      const { test } = await import('@playwright/test');
      const info = test.info();
      hasTestContext = info !== undefined;
    } catch {
      hasTestContext = false;
    }

    if (hasTestContext) {
      const { test } = await import('@playwright/test');
      await test.step(name, fn);  // エラーはそのまま伝播
    } else {
      await fn();                 // テストコンテキスト外のみフォールバック
    }
  }
}
```

---

## §7. .env.example

```
TEST_BASE_URL=
TEST_USER_EMAIL=
TEST_USER_PASSWORD=
```

---

## §8. コーディング規約

### package.json 必須devDependencies
```json
{
  "devDependencies": {
    "@playwright/test": "^1.50.0",
    "dotenv": "^16.4.0",
    "typescript": "^5.7.0",
    "@types/node": "^22.0.0"
  }
}
```

> `typescript` と `@types/node` がないと `npx tsc --noEmit` による型チェックが実行できない。
> §1 Definition of Done の型チェック要件を満たすために必須。

### TypeScript設定（tsconfig.json）
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

### コードフォーマット（Prettier）
```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100
}
```

### 命名規則

| 種類 | 規則 | 例 |
|------|------|---|
| クラス | PascalCase | `LoginPage`, `LoginAction` |
| メソッド | camelCase | `fillEmail()`, `clickButton()` |
| 変数 | camelCase | `emailInput`, `userName` |
| 定数 | UPPER_SNAKE_CASE | `MAX_RETRY`, `DEFAULT_TIMEOUT` |
| インターフェース | PascalCase | `TestEnvironment` |

### JSDocコメント規約
```typescript
/**
 * メソッドの説明
 * @param email - メールアドレス
 * @param password - パスワード
 * @returns ログイン成功の可否
 */
async execute(email: string, password: string): Promise<boolean> {
  // 実装
}
```

---

## §9. Playwrightデフォルト構成から4層への変換手順

1. `src/` 配下に4層ディレクトリ作成（§2参照）
2. `config/constants.ts` と `config/env.ts` を作成（§4, §5参照）
3. specファイル内のLocator → `pages/` のPage Objectに移動
4. specファイル内のフロー操作 → `actions/` のActionに移動
5. Fixture定義を作成（§3参照）し、testのimport元を切り替える
6. specファイルには意図・期待結果のみ残す（Locator・ロジック禁止）
7. ハードコード値 → `constants.ts` に移動
8. 認証情報 → `env.ts` + `.env` に移動
9. `npx playwright test` で全テスト通過を確認

**変換時の注意**:
- 一度に全部変換しない。1テストずつ移行して確認
- 既存のテストが通る状態を常に維持する
- 新規Actionを作ったらFixtureに登録を忘れない

---

## §10. プロジェクト固有設定チェックリスト

新プロジェクトに導入する際、以下を確認してCLAUDE.mdに記入する：

- [ ] 対象プロダクト名
- [ ] UIライブラリ（Ant Design / MUI / 独自 / なし）
- [ ] 認証方式（外部認証 / 独自ログイン / SSO / なし）
- [ ] HTML意味層の状況（data-testid有無 / aria-label整備状況）
- [ ] SPA or MPA
- [ ] CI/CD環境（CircleCI / GitHub Actions等）
