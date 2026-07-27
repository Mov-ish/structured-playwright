# 定数管理・セキュリティルール

## インポート必須（全ファイル共通）

`test`/`expect` は `@playwright/test` からではなく `fixtures/app.fixture` 経由で import する。定数（TIMEOUTS / SELECTORS / URL_PATTERNS）は `../config/constants` から import する。定数形式の正本は `e2e-bootstrap` §4、Fixture 形式は `e2e-bootstrap/fixture-template.md`。

## 定数の最小必須構造

**雛形の正本 = `e2e-bootstrap` §4**（環境構築時に必ず含める TIMEOUTS / SELECTORS / URL_PATTERNS の完全形 + プロジェクト固有の拡張例。数値定数の宣言行コメント必須 — gate が機械検出）。rules はコードを持たない。`SELECTORS.MODAL` は単一モーダルにスコープする宇宙定数（`.last()` なし — 下記「使い分け」参照）。

## constants.ts に入れるもの / 入れないもの

| 入れる | 入れない |
|--------|---------|
| **複数ファイルで共通**のセレクタ・URL・タイムアウト | **特定画面でしか使わない** Locator |
| 静的な値のみ | 動的な値（引数で変わるもの）→ Page Object 内で処理 |

特定画面固有の Locator は Page Object の constructor 内で定義するのが正しい設計。

### `SELECTORS.MODAL` と `activeDialog()` の使い分け

`SELECTORS.MODAL`（`[role="dialog"]`）は **`.last()` を付けず単一モーダルにスコープする**用途専用。アクティブモーダルの曖昧性解消（`activeDialog()`）やハイブリッド禁止の詳細は重複記載を避け、**正本である `prohibited-patterns.md`「アクティブモーダルのイディオム — `activeDialog()` と `SELECTORS.MODAL` の使い分け」を参照**（使い分け表はそちらが canonical。本節は `SELECTORS.MODAL` の用途＝スコープ限定だけを説明し、アクティブモーダルの曖昧性解消は扱わない）。

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
- コード内にハードコード厳禁（必ず `.env` + `EnvConfig.getTestEnvironment()` 経由で取得）
