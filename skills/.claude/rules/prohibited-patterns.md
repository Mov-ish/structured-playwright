# 禁止事項一覧

このファイルのパターンは**いかなるタスクでも**使用してはならない。

## コード禁止パターン

| 禁止 | 理由 | 代替 |
|------|------|------|
| XPath (`//div/span`) | 構造依存・AI誤生成の温床 | CSS + セマンティック |
| CSS構造セレクタ (`div > div > button`) | DOM揺れで即破壊 | 意味ベース + Local Universe |
| `.first()` コメントなし | 偶然の固定化、保守不能 | `:near()` / 具体セレクタ / コメント+TODO付き |
| `.catch(() => false)` / `.catch(() => true)` | タイムアウト隠蔽・false positive | `expect().toBeVisible()` + try-catch |
| `private readonly` でLocator定義 | デバッグ困難 | `readonly`（public） |
| `import { test } from '@playwright/test'` | Fixture未経由 | `from '../fixtures/app.fixture'` |
| `new XxxAction(page)` をTest内で直接 | 依存が明示されない | Fixture引数で受け取る |
| Action層で `expect()` | アサーションはTest層の責務 | `waitFor()` ベースの verify メソッド |
| Test層で Locator 直接記述 | UIは Page Object層の責務 | Action の verify メソッド経由 |
| Page Objectで `waitForTimeout()` | 固定待機はAction層で行う | `waitFor()` + try-catch |
| `has-text` をスコープなしで使用 | 同じ文言が複数→誤爆 | `text-is` or Local Universe で絞る |
| モーダルを `page` 全体で探索 | 背景ボタン誤クリック | `[role="dialog"]` 等で閉じ込め |

## 値の禁止パターン

| 禁止 | 理由 | 代替 |
|------|------|------|
| タイムアウト数値ハードコード (`2000`, `10000`) | 保守性低下 | `TIMEOUTS.SPA_RENDERING` 等の定数 |
| URLパターンハードコード | 環境変更時の修正漏れ | `URL_PATTERNS` 定数 |
| 共通セレクタハードコード | 一貫性欠如 | `SELECTORS` 定数 |
| 認証情報ハードコード | セキュリティリスク | `.env` + `EnvConfig` |
| `waitForTimeout` に理由コメントなし | 意図不明で保守不能 | TIMEOUTS定数 + 理由コメント必須 |

## AI生成コードの警戒パターン

- `.catch(() => false)` が5箇所以上 → AIコピペを疑う
- 同じエラーハンドリングパターンの大量重複 → 一箇所でも問題なら全体が問題
- **「動く」≠「正しい」** — テストは失敗することに意味がある
