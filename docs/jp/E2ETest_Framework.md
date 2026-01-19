# E2Eテストフレームワーク - 4層アーキテクチャ 技術標準書

**文書バージョン**: 1.0

**作成日**: 2025年9月30日

**対象**: 開発者、QAエンジニア


## 本ドキュメントの位置づけ（4th）

この文書は、Playwright E2E における **4層アーキテクチャの構造的な正（正典）** を定義する。

- 環境構築の手順は `bootstrap.md` を参照すること
- テスト作成の進め方は `test_creation_protocol.md` を参照すること
- 本文書は「どの層に何を書くべきか」「どこに書いてはいけないか」を判断するために使う

本ドキュメントは **常読を前提としない**。  
構造・責務・配置に迷った場合の最終判断として参照される。

---

## 目次

1. [アーキテクチャ概要](#1-アーキテクチャ概要)
2. [ディレクトリ構成](#2-ディレクトリ構成)
3. [Layer 1: Page Objects](#3-layer-1-page-objects)
4. [Layer 2: Actions](#4-layer-2-actions)
5. [Layer 3: Tests](#5-layer-3-tests)
6. [Layer 4: Config/Env](#6-layer-4-configenv)
7. [命名規則](#7-命名規則)
8. [コーディング規約](#8-コーディング規約)
9. [エラーハンドリング](#9-エラーハンドリング)
10. [テストデータ管理](#10-テストデータ管理)

---

## 1. アーキテクチャ概要

### 1.1 4層構造

```
┌─────────────────────────────────────┐
│ Layer 4: Config/Env                 │  ← 環境設定
├─────────────────────────────────────┤
│ Layer 3: Tests                      │  ← 期待結果検証
├─────────────────────────────────────┤
│ Layer 2: Actions                    │  ← ビジネスロジック
├─────────────────────────────────────┤
│ Layer 1: Page Objects               │  ← UI要素管理
└─────────────────────────────────────┘
```

### 1.2 責任分離の原則

| Layer | 責任 | 変更理由 |
| --- | --- | --- |
| **Page Objects** | UI要素の定義と基本操作 | HTML構造の変更 |
| **Actions** | ビジネスフロー、複数画面の制御 | 業務手順の変更 |
| **Tests** | 期待結果の定義と検証 | テスト観点の変更 |
| **Config/Env** | 環境依存の設定値 | 環境の変更 |

### 1.3 設計原則

**単一責任の原則（SRP）**

- 各クラスは1つの責任のみを持つ
- 変更理由が1つのみである

**開放閉鎖の原則（OCP）**

- 拡張には開いている
- 修正には閉じている

**依存性逆転の原則（DIP）**

- 上位層は下位層に依存する
- 下位層は上位層に依存しない

---

## 2. ディレクトリ構成

### 2.1 標準ディレクトリ構造

```
e2e-tests/
├── .circleci/
│   └── config.yml                    # CI/CD設定
├── src/
│   ├── config/                       # Layer 4: 設定
│   │   ├── env.ts                   # 環境変数管理
│   │   └── constants.ts             # 定数定義
│   ├── pages/                       # Layer 1: Page Objects
│   │   ├── BasePage.ts              # 基底クラス
│   │   ├── LoginPage.ts
│   │   ├── CoursePage.ts
│   │   └── DashboardPage.ts
│   ├── actions/                     # Layer 2: Actions
│   │   ├── BaseAction.ts            # 基底クラス
│   │   ├── LoginAction.ts
│   │   ├── CourseEnrollmentAction.ts
│   │   └── UserProfileAction.ts
│   ├── tests/                       # Layer 3: Tests
│   │   ├── scenarios/               # シナリオテスト
│   │   │   ├── user-journey.spec.ts
│   │   │   └── course-management.spec.ts
│   │   ├── smoke/                   # スモークテスト
│   │   │   └── login-smoke.spec.ts
│   │   └── regression/              # リグレッションテスト
│   │       └── critical-path.spec.ts
│   ├── fixtures/                    # テストデータ
│   │   ├── users.json
│   │   └── courses.json
│   └── utils/                       # ユーティリティ
│       ├── logger.ts
│       └── helpers.ts
├── screenshots/                     # スクリーンショット保存先
├── test-results/                    # テスト結果
├── playwright-report/               # HTMLレポート
├── .env.example                     # 環境変数テンプレート
├── .gitignore
├── package.json
├── tsconfig.json
├── playwright.config.ts
└── README.md
```

### 2.2 ファイル命名規則

| 種類 | パターン | 例 |
| --- | --- | --- |
| **Page Object** | `{画面名}Page.ts` | `LoginPage.ts` |
| **Action** | `{機能名}Action.ts` | `LoginAction.ts` |
| **Test** | `{テスト対象}.spec.ts` | `user-journey.spec.ts` |
| **Config** | `{設定種別}.ts` | `env.ts` |
| **Fixture** | `{データ種別}.json` | `users.json` |

---

## 3. Layer 1: Page Objects

### 3.1 基本構造

```typescript
import { Page, Locator } from '@playwright/test';

/**
 * [画面名]のPage Objectクラス
 *
 * 責任:
 * - UI要素（ロケーター）の定義
 * - 単一要素への基本操作メソッド
 * - ページ固有の状態確認メソッド
 *
 * 変更理由: UI構造（HTML/CSS/セレクタ）の変更
 */
export class XxxPage {
  readonly page: Page;

  // UI要素の定義（readonlyで不変に）
  readonly element1: Locator;
  readonly element2: Locator;

  constructor(page: Page) {
    this.page = page;

    // セレクタの定義
    // data-testid属性を優先的に使用
    this.element1 = page.locator('[data-testid="element1"]');
    this.element2 = page.getByRole('button', { name: 'ボタン名' });
  }

  /**
   * 基本操作メソッド
   * 単一責任、1つの要素に対する1つの操作
   */
  async fillSomething(value: string): Promise<void> {
    await this.element1.fill(value);
  }

  async clickSomething(): Promise<void> {
    await this.element2.click();
  }

  /**
   * 状態確認メソッド
   */
  async isVisible(): Promise<boolean> {
    return await this.element1.isVisible();
  }

  async getText(): Promise<string> {
    return await this.element1.textContent() || '';
  }
}
```

### 3.2 Page Object 作成ガイドライン

### Locator に関する原則
- Locator はこの層にのみ存在してよい
- Locator の判断基準は locator/ 配下の Strategy を正とする
- 安定性の理由を説明できない Locator を置いてはならない

**必須事項**

- ✅ 全てのロケーターは `readonly` で定義（**`private readonly` は禁止**）
- ✅ セレクタは `data-testid` 属性を優先
- ✅ メソッドは単一責任（1メソッド = 1操作）
- ✅ 複雑なロジックを含めない
- ✅ JSDocコメントを記述

**ロケーター定義ルール（MUST）**

```typescript
// ❌ 禁止：private readonly
export class Auth0LoginPage extends BasePage {
  private readonly emailInput: Locator;  // ← 禁止
  private readonly passwordInput: Locator;
}

// ✅ 必須：readonly（publicアクセス可能）
export class Auth0LoginPage extends BasePage {
  readonly emailInput: Locator;  // ← 正しい
  readonly passwordInput: Locator;
}
```

**理由**：
- Page Objectsは内部実装ではなくテストのためのインターフェース
- デバッグ時にテストから要素に直接アクセスできると便利
- 一貫性のある設計パターンの維持

**禁止事項**

- ❌ `private readonly` でロケーター定義
- ❌ ビジネスロジックを含める
- ❌ 複数ページにまたがる操作
- ❌ 期待結果の検証（expect）
- ❌ 待機時間の決定（Action層で行う）
- ❌ 環境依存の値を持つ

### 3.3 セレクタ優先順位

```typescript
// 優先順位1: data-testid属性（最も安定）
page.locator('[data-testid="login-button"]')

// 優先順位2: role + name（セマンティック）
page.getByRole('button', { name: 'ログイン' })

// 優先順位3: label（フォーム要素）
page.getByLabel('メールアドレス')

// 優先順位4: placeholder
page.getByPlaceholder('メールアドレスを入力')

// 優先順位5: CSS class/ID（最終手段）
page.locator('.login-button')
```

### 3.4 複雑な要素の管理

```typescript
export class CoursePage {
  // グループ化して管理
  readonly search = {
    input: this.page.locator('[data-testid="search-input"]'),
    button: this.page.locator('[data-testid="search-button"]'),
    suggestions: this.page.locator('[data-testid="suggestions"]')
  };

  readonly filters = {
    category: this.page.locator('[data-testid="filter-category"]'),
    price: this.page.locator('[data-testid="filter-price"]'),
    apply: this.page.locator('[data-testid="apply-filters"]')
  };
}
```

---

## 4. Layer 2: Actions

### 設計指針
- Actions は「ユーザの意図が読める粒度」で分割する
- テスト固有の expect や assertion を含めてはならない
- 複数テストで再利用されない処理は Acrtions に昇格させない

### 4.1 基本構造

```typescript
import { Page } from '@playwright/test';
import { BaseAction } from './BaseAction';
import { XxxPage } from '../pages/XxxPage';

/**
 * [機能名]のActionクラス
 *
 * 責任:
 * - ビジネスフローの実装
 * - 複数ページにまたがる操作
 * - エラーハンドリングと待機処理
 * - Page Objectsの組み合わせ
 *
 * 変更理由: 業務手順・フローの変更
 */
export class XxxAction extends BaseAction {
  private xxxPage: XxxPage;
  private yyyPage: YyyPage;

  constructor(page: Page) {
    super(page, 'アクション名（日本語）');
    this.xxxPage = new XxxPage(page);
    this.yyyPage = new YyyPage(page);
  }

  /**
   * メイン実行メソッド
   * 完全なビジネスフローを実装
   */
  async execute(...args: any[]): Promise<void> {
    console.log('ステップ1: XXX');
    await this.xxxPage.doSomething();
    await this.page.waitForLoadState('networkidle');

    console.log('ステップ2: YYY');
    await this.yyyPage.doSomethingElse();
    await this.page.waitForTimeout(1000);

    console.log('ステップ3: 完了確認');
    // ...
  }

  /**
   * バリエーションメソッド
   * 異なるパターンに対応
   */
  async executeWithOptions(options: Options): Promise<void> {
    // ...
  }
}
```

### 4.2 Action 作成ガイドライン

**必須事項**

- ✅ `BaseAction` を継承
- ✅ 使用する Page Objects をプライベートフィールドで保持
- ✅ `execute()` メソッドで主要フローを実装
- ✅ **各ステップでコンソールログを出力**（MUST）
- ✅ 適切な待機処理を含める
- ✅ エラーハンドリングを実装

**ログ出力ルール（MUST）**

```typescript
// ❌ 禁止：開始・終了ログのみ
async execute(url: string, email: string, password: string): Promise<void> {
  console.log('=== ログイン 開始 ===');
  // ... 処理 ...
  console.log('=== ログイン 完了 ===');
}

// ✅ 必須：各ステップでログ出力
async execute(url: string, email: string, password: string): Promise<void> {
  console.log('=== ログイン処理開始 ===');

  console.log(`Step 1: ページ遷移 - ${url}`);
  await this.termsPage.goto(url);

  console.log('Step 2: 利用規約に同意');
  await this.termsPage.agreeToTerms();

  console.log('Step 3: メールアドレスでログインボタンをクリック');
  await this.termsPage.clickEmailLogin();

  console.log('Step 4: Auth0ページへの遷移を待つ');
  await this.page.waitForURL(URL_PATTERNS.AUTH0_LOGIN, { timeout: TIMEOUTS.DEFAULT });

  // ... 以下同様 ...

  console.log('=== ログイン処理完了 ===');
}
```

**ログ出力フォーマット**：
- 開始: `'=== {Action名}処理開始 ==='`
- 各ステップ: `'Step {番号}: {操作内容}'`
- 完了: `'=== {Action名}処理完了 ==='`
- エラー: `console.error('{Action名}でエラーが発生:', error)`

**理由**：CI/CD環境での失敗時に原因特定が容易になる

**禁止事項**

- ❌ UI要素のセレクタを直接使用
- ❌ 期待結果の検証（expect）
- ❌ 環境設定値の直接参照
- ❌ 中間ステップのログ省略

### 4.3 待機処理のベストプラクティス

```typescript
// ✅ 良い例：明示的な待機
await this.page.waitForLoadState('networkidle');
await this.loginPage.emailInput.waitFor({ state: 'visible', timeout: 5000 });

// ✅ 良い例：条件付き待機
await this.page.waitForFunction(() => {
  return document.querySelectorAll('.course-item').length > 0;
});

// ⚠️ 避けるべき：固定時間待機（最終手段）
await this.page.waitForTimeout(1000);
```

### 4.4 エラーハンドリング

```typescript
async execute(email: string, password: string): Promise<void> {
  try {
    // 利用規約画面（オプション）
    await this.loginPage.termsCheckbox.waitFor({
      state: 'visible',
      timeout: 5000
    });
    await this.loginPage.acceptTerms();
  } catch (error) {
    console.log('利用規約画面スキップ（既に同意済み）');
  }

  // メイン処理
  await this.loginPage.fillEmail(email);
  await this.loginPage.fillPassword(password);
  await this.loginPage.clickLogin();
}
```

---

## 5. Layer 3: Tests

### 5.1 基本構造

```typescript
import { test, expect } from '@playwright/test';
import { XxxAction } from '../actions/XxxAction';
import { XxxPage } from '../pages/XxxPage';
import { EnvConfig } from '../config/env';

test.describe('テストスイート名', () => {

  test('テストケース名（具体的に）', async ({ page }) => {
    // 準備（Arrange）
    const env = EnvConfig.getTestEnvironment();
    await page.goto(`${env.baseUrl}/xxx`);

    // 実行（Act）
    const action = new XxxAction(page);
    await action.execute(param1, param2);

    // 検証（Assert）
    const xxxPage = new XxxPage(page);
    expect(await xxxPage.isSuccess()).toBeTruthy();
    expect(page.url()).toContain('/success');
  });

});
```

### 5.2 Test 作成ガイドライン

**必須事項**

- ✅ AAA（Arrange-Act-Assert）パターンに従う
- ✅ 1テストケース = 1検証観点
- ✅ テスト名は日本語で具体的に
- ✅ 独立性を保つ（他のテストに依存しない）
- ✅ 明確な expect() による検証

**禁止事項**

- ❌ 複雑なロジック（Action層に移動）
- ❌ UI要素の直接操作
- ❌ 環境依存値のハードコード
- ❌ 他のテストケースへの依存###  5.5 禁止事項
- ❌ Locator を直接記述してはならない
- ❌ ページ構造やDOMに依存するロジックを書いてはならない
- ❌ 条件分岐による業務ロジックを持たせてはならない

### 5.3 テストの構造化

```typescript
test.describe('ログイン機能', () => {

  test.describe('正常系', () => {
    test('有効な認証情報でログインできる', async ({ page }) => {
      // ...
    });

    test('ログイン後、ダッシュボードにリダイレクトされる', async ({ page }) => {
      // ...
    });
  });

  test.describe('異常系', () => {
    test('無効なメールアドレスでエラーメッセージが表示される', async ({ page }) => {
      // ...
    });

    test('空のパスワードでエラーメッセージが表示される', async ({ page }) => {
      // ...
    });
  });

});
```

### 5.4 検証のベストプラクティス

```typescript
// ✅ 良い例：明確な検証
expect(await loginPage.isLoggedIn()).toBeTruthy();
expect(page.url()).toContain('/dashboard');
expect(await dashboardPage.getWelcomeMessage()).toBe('おかえりなさい');

// ✅ 良い例：複数項目の検証
const courseCount = await coursePage.getCourseCount();
expect(courseCount).toBeGreaterThan(0);
expect(courseCount).toBeLessThanOrEqual(50);

// ❌ 悪い例：曖昧な検証
expect(true).toBeTruthy(); // 何を検証しているか不明
```



---

## 6. Layer 4: Config/Env

### 環境依存の扱い
- 認証情報・URL・環境差分は `.env` または CI 環境変数から取得する
- PageObject や Actions に環境依存値を直接埋め込んではならない

### 6.1 環境変数管理

```typescript
// config/env.ts
import * as dotenv from 'dotenv';

dotenv.config();

export interface TestEnvironment {
  baseUrl: string;
  credentials: {
    email: string;
    password: string;
  };
  timeout: {
    default: number;
    long: number;
  };
}

export class EnvConfig {
  static getTestEnvironment(): TestEnvironment {
    return {
      baseUrl: process.env.TEST_BASE_URL || '',
      credentials: {
        email: process.env.TEST_USER_EMAIL || '',
        password: process.env.TEST_USER_PASSWORD || '',
      },
      timeout: {
        default: 10000,
        long: 30000,
      },
    };
  }

  static validateEnvironment(): void {
    const required = [
      'TEST_BASE_URL',
      'TEST_USER_EMAIL',
      'TEST_USER_PASSWORD'
    ];

    const missing = required.filter(key => !process.env[key]);

    if (missing.length > 0) {
      throw new Error(`必須の環境変数が設定されていません: ${missing.join(', ')}`);
    }
  }
}
```

### 6.2 定数管理

#### 必須ルール（MUST）

**❌ 禁止：数値・URLパターンのハードコード**
```typescript
// ❌ タイムアウト値のハードコード（禁止）
await page.waitForTimeout(2000);

// ❌ URLパターンのハードコード（禁止）
await this.page.waitForURL('**/u/login**', { timeout: 10000 });
```

**✅ 必須：constants.tsからインポート**
```typescript
import { TIMEOUTS, URL_PATTERNS } from '../config/constants';

// ✅ 正しい実装
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
await this.page.waitForURL(URL_PATTERNS.AUTH0_LOGIN, { timeout: TIMEOUTS.REDIRECT });
```

#### 定数定義の標準構造

```typescript
// config/constants.ts

export const TIMEOUTS = {
  SHORT: 3000,
  MEDIUM: 10000,
  LONG: 30000,
  DEFAULT: 10000,              // デフォルトタイムアウト
  AUTH0_STABILIZATION: 2000,   // Auth0画面の安定化待ち
  MODAL_ANIMATION: 1000,       // モーダルアニメーション完了待ち
  SPA_RENDERING: 2000,         // SPAレンダリング完了待ち
  REDIRECT: 3000,              // リダイレクト完了待ち
} as const;

export const SELECTORS = {
  COMMON: {
    LOADING: '[data-testid="loading"]',
    ERROR: '[data-testid="error"]',
    MODAL: '[role="dialog"]',
    SUBMIT_BUTTON: 'button[type="submit"]',
  },
} as const;

export const URL_PATTERNS = {
  AUTH0_LOGIN: '**/auth.example.com/**',
  DASHBOARD: '**/dashboard**',
  LOGIN: '**/login**',
  // プロジェクト固有のURLパターンを追加
} as const;

export const TEST_DATA = {
  VALID_EMAIL: 'test@example.com',
  INVALID_EMAIL: 'invalid-email',
} as const;
```

#### 新しい定数が必要な場合

1. まず `constants.ts` に定数を追加
2. その後、使用箇所で `TIMEOUTS.XXX` / `URL_PATTERNS.XXX` として参照
3. **絶対にハードコードしない**

---

## 7. 命名規則

### 7.1 TypeScript命名規則

| 種類 | 規則 | 例 |
| --- | --- | --- |
| **クラス** | PascalCase | `LoginPage`, `LoginAction` |
| **メソッド** | camelCase | `fillEmail()`, `clickButton()` |
| **変数** | camelCase | `emailInput`, `userName` |
| **定数** | UPPER_SNAKE_CASE | `MAX_RETRY`, `DEFAULT_TIMEOUT` |
| **インターフェース** | PascalCase | `TestEnvironment`, `UserData` |
| **型エイリアス** | PascalCase | `PageOptions`, `ActionResult` |

### 7.2 テスト名の命名規則

```typescript
// ✅ 良い例：具体的で理解しやすい
test('有効な認証情報でログインできる', async ({ page }) => {});
test('無効なメールアドレスでエラーメッセージが表示される', async ({ page }) => {});
test('コース検索で結果が10件表示される', async ({ page }) => {});

// ❌ 悪い例：抽象的で不明瞭
test('ログインテスト', async ({ page }) => {});
test('エラーチェック', async ({ page }) => {});
test('test1', async ({ page }) => {});
```

---

## 8. コーディング規約

### 8.1 TypeScript設定

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

### 8.2 コードフォーマット

**Prettier設定**

```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100
}
```

### 8.3 コメント規約

```typescript
/**
 * メソッドの説明
 *
 * @param email - メールアドレス
 * @param password - パスワード
 * @returns ログイン成功の可否
 *
 * @example
 * ```typescript
 * const result = await loginAction.execute('user@example.com', 'password');
 * ```
 */
async execute(email: string, password: string): Promise<boolean> {
  // 実装
}
```

---

## 9. エラーハンドリング

### 9.1 エラー処理の原則

```typescript
// ✅ 良い例：具体的なエラーメッセージ
throw new Error(`ログインに失敗しました。メール: ${email}`);

// ❌ 悪い例：不明瞭なエラー
throw new Error('エラーが発生しました');
```

### 9.2 リトライ処理

```typescript
async executeWithRetry(maxRetries: number = 3): Promise<void> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await this.execute();
      return;
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      console.log(`リトライ ${i + 1}/${maxRetries}`);
      await this.page.waitForTimeout(1000);
    }
  }
}
```

---

## 10. テストデータ管理

### 10.1 Fixtureの使用

```typescript
// fixtures/users.json
{
  "validUser": {
    "email": "valid@example.com",
    "password": "ValidPass123"
  },
  "invalidUser": {
    "email": "invalid@example.com",
    "password": "wrong"
  }
}

// テストでの使用
import users from '../fixtures/users.json';

test('有効なユーザーでログイン', async ({ page }) => {
  const loginAction = new LoginAction(page);
  await loginAction.execute(users.validUser.email, users.validUser.password);
});
```

### 10.2 テストデータ生成

```typescript
// utils/testDataGenerator.ts
export class TestDataGenerator {
  static generateEmail(): string {
    return `test-${Date.now()}@example.com`;
  }

  static generatePassword(): string {
    return `Pass${Math.random().toString(36).substring(7)}123`;
  }
}
```

---

## 付録

### A. チェックリスト

**Page Object作成時**

- [ ] `readonly` でロケーター定義
- [ ] `data-testid` 優先でセレクタ定義
- [ ] 単一責任メソッドのみ
- [ ] JSDocコメント記述

**Action作成時**

- [ ] `BaseAction` 継承
- [ ] Page Objects使用
- [ ] 適切な待機処理
- [ ] エラーハンドリング実装

**Test作成時**

- [ ] AAAパターン
- [ ] 独立性確保
- [ ] 明確な検証
- [ ] 意味のあるテスト名

### B. よくある間違い

| 間違い | 正しい方法 |
| --- | --- |
| Page Objectにビジネスロジック | Actionに移動 |
| Testに複雑なロジック | Actionに移動 |
| 固定待機時間の多用 | 明示的待機を使用 |
| セレクタのハードコード | Page Objectで管理 |

---

## License

MIT License

---

**文書管理情報**

- 文書ID: TECH-STD-E2E-001
- 分類: 技術標準
