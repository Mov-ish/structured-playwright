---
name: e2e-bootstrap
description: "E2E環境構築用Skill。新規セットアップ・Playwright環境が未整備・初回実行可能な状態を作る場合に使用。最小骨格・Definition of Done・4層ディレクトリ構成・Fixture/constants雛形を含む。"
---

# E2E Bootstrap Skill

> **環境構築フェーズで使用。** テスト追加が目的なら `e2e-test-create` Skill を使うこと。

---

## Definition of Done（完了条件）

- `npm test` が実行できる（smoke が 1 本通る）
- Playwright のインストールとブラウザ依存が揃っている
- 4層アーキテクチャの最小ディレクトリが用意されている
- 認証情報は `.env`（またはCI環境変数）で管理
- Fixtureファイル（app.fixture.ts）が存在し、test/expectをexport

---

## 4層の最小骨格

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

| 層 | 責務 | 変更理由 |
|---|---|---|
| tests | 意図・期待結果。Locator書かない | テスト観点変更 |
| fixtures | Actionインスタンス化一元管理 | Action追加時 |
| actions | ビジネスフロー。Page Objectsを組み合わせ | 業務手順変更 |
| pages | Locator定義・基本操作。Locatorはここだけ | HTML構造変更 |
| config | 環境変数・定数・テストデータ | 環境変更 |

---

## 最小Fixture

```typescript
import { test as base } from '@playwright/test';
import { LoginAction } from '../actions/LoginAction';

type AppFixtures = { loginAction: LoginAction };

export const test = base.extend<AppFixtures>({
  loginAction: async ({ page }, use) => { await use(new LoginAction(page)); },
});

export { expect } from '@playwright/test';
```

## 最小constants.ts

```typescript
export const TIMEOUTS = {
  SHORT: 3000, MEDIUM: 10000, LONG: 30000, DEFAULT: 10000,
  EXTERNAL_AUTH_STABILIZATION: 2000, MODAL_ANIMATION: 1000,
  SPA_RENDERING: 2000, REDIRECT: 3000,
} as const;

export const SELECTORS = {
  MODAL: '[role="dialog"]',
  SUBMIT_BUTTON: 'button[type="submit"]',
} as const;

export const URL_PATTERNS = {
  EXTERNAL_AUTH_LOGIN: '**/login.your-auth-domain.example/**',  // 認証プロバイダのURLに変更
  DASHBOARD: '**/dashboard**',
  LOGIN: '**/login**',
} as const;
```

## .env.example

```
TEST_BASE_URL=https://your-app.example.com
TEST_USER_EMAIL=
TEST_USER_PASSWORD=
```

## セキュリティ

- `.env` → `.gitignore`必須
- 本番認証情報は絶対に含めない
- コード内ハードコード厳禁

---

## コーディング規約

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
 *
 * @param email - メールアドレス
 * @param password - パスワード
 * @returns ログイン成功の可否
 */
async execute(email: string, password: string): Promise<boolean> {
  // 実装
}
```

### Playwrightデフォルト構成から4層への変換指針

Playwrightデフォルト（`tests/`直下にspecファイル）から4層に変換する場合：

1. `src/` 配下に4層ディレクトリを作成（上記「4層の最小骨格」参照）
2. specファイル内のLocator → `pages/` のPage Objectに移動
3. specファイル内のフロー操作 → `actions/` のActionに移動
4. specファイルには意図・期待結果のみ残す（Locator・ロジック禁止）
5. Fixture定義を作成し、testのimport元を切り替える
6. ハードコード値 → `config/constants.ts` に移動
7. 認証情報 → `config/env.ts` + `.env` に移動


---

## 追記エリア

新しいパターンを発見した場合、以下の形式で追記する。

### YYYY-MM-DD - パターン名
- **発見の経緯**: （何をして、何が起きたか）
- **解決策**: （コード例）
- **注意事項**: （適用条件・制約）
