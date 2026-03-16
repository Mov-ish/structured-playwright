# 定数管理・セキュリティルール

## インポート必須（全ファイル共通）

```typescript
import { TIMEOUTS } from '../config/constants';     // 全ファイル
import { SELECTORS } from '../config/constants';     // Page Object
import { URL_PATTERNS } from '../config/constants';  // Action
import { test, expect } from '../fixtures/app.fixture'; // Test（Fixture経由）
```

## 定数の標準構造

```typescript
export const TIMEOUTS = {
  SHORT: 3000,
  MEDIUM: 10000,
  LONG: 30000,
  DEFAULT: 10000,
  MODAL_ANIMATION: 1000,    // モーダルCSSアニメーション完了
  SPA_RENDERING: 2000,      // SPA描画完了（networkidle後）
  REDIRECT: 3000,            // リダイレクト完了
  ELEMENT_VISIBLE: 5000,     // 要素表示待ち
  // プロジェクト固有のタイムアウトを追加
} as const;

export const SELECTORS = {
  MODAL: '[role="dialog"]',
  SUBMIT_BUTTON: 'button[type="submit"]',
  // プロジェクト固有のセレクタを追加
} as const;

export const URL_PATTERNS = {
  // プロジェクト固有のURLパターンを追加
  // 例: LOGIN: '**/login**',
  // 例: DASHBOARD: '**/dashboard**',
} as const;
```

## 新しい定数が必要な場合

1. `constants.ts` に定数を追加
2. 使用箇所でインポート
3. **絶対にハードコードしない**

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
