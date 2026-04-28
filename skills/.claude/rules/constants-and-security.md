# 定数管理・セキュリティルール

## インポート必須（全ファイル共通）

```typescript
import { TIMEOUTS } from '../config/constants';     // 全ファイル
import { SELECTORS } from '../config/constants';     // Page Object
import { URL_PATTERNS } from '../config/constants';  // Action
import { test, expect } from '../fixtures/app.fixture'; // Test（Fixture経由）
```

## 定数の最小必須構造

環境構築時に必ず含める定数。`e2e-bootstrap` §4 と一致。

```typescript
export const TIMEOUTS = {
  SHORT: 3000, MEDIUM: 10000, LONG: 30000, DEFAULT: 10000,
  AUTH_STABILIZATION: 2000, MODAL_ANIMATION: 1000,
  SPA_RENDERING: 2000, REDIRECT: 3000,
} as const;

export const SELECTORS = {
  MODAL: '[role="dialog"]',
  SUBMIT_BUTTON: 'button[type="submit"]',
} as const;

export const URL_PATTERNS = {
  LOGIN: '**/login**',
  DASHBOARD: '**/dashboard**',
  LOGIN_PATH: '/login',
  // 例: AUTH_LOGIN: '**/auth.example.com/**',
} as const;
```

## 拡張例（プロジェクト固有の要素が増えたら追加）

```typescript
// TIMEOUTS 拡張例
ELEMENT_VISIBLE: 5000,

// SELECTORS 拡張例（複数画面で共通のセレクタのみ）
AGREEMENT_CHECKBOX: 'input[type="checkbox"]:near(:text("同意する"))',
AUTH_EMAIL_INPUT: 'input[name="username"]',
AUTH_PASSWORD_INPUT: 'input[name="password"]',
```

## constants.ts に入れるもの / 入れないもの

| 入れる | 入れない |
|--------|---------|
| **複数ファイルで共通**のセレクタ・URL・タイムアウト | **特定画面でしか使わない** Locator |
| 静的な値のみ | 動的な値（引数で変わるもの）→ Page Object 内で処理 |

特定画面固有の Locator は Page Object の constructor 内で定義するのが正しい設計。

## 新しい定数が必要な場合

1. 「複数ファイルで使うか？」を判断
2. Yes → `constants.ts` に追加してインポート
3. No → Page Object / Action 内で定義
4. **絶対にハードコードしない**（タイムアウト数値・URLパターン・共通セレクタ）

## セキュリティ

- 認証情報（メール・パスワード・トークン・APIキー）は **`.env`から取得**
- `.env`は`.gitignore`に含める
- `.env.example`をテンプレートとして用意
- 本番環境の認証情報は絶対に含めない
- コード内にハードコード厳禁

```typescript
// ❌
const email = 'user@example.com';

// ✅
const env = EnvConfig.getTestEnvironment();
const email = env.credentials.email;
```
