# CLAUDE.md - E2Eテストプロジェクト ルーター

**プロジェクト**: Playwright + TypeScript E2E（4層アーキテクチャ）
**対象プロダクト**: <!-- your-product-name -->（技術スタックに応じて下記を設定）

<!-- 🔧 プロジェクト設定:
  以下を自プロジェクトに合わせて編集すること:
  - 対象プロダクト名
  - UIライブラリ（Ant Design / MUI / Chakra UI 等）
  - 認証プロバイダ（Auth0 / Cognito / Firebase Auth 等）
  - SPA フレームワーク（React / Vue / Angular 等）
-->

---

## 絶対ルール（5行で覚える）

1. **Locatorは Page Object 層にのみ存在する**（Test層・Action層に書かない）
2. **Action層にexpect()禁止、Test層にLocator禁止**（verifyメソッドパターンで両立）
3. **`@playwright/test`から直接importしない**（Fixtureファイル経由）
4. **数値・URL・セレクタのハードコード禁止**（constants.tsの定数を使う）
5. **認証情報は.env / CI環境変数から取得**（コード内にハードコード厳禁）

---

## AI 作業フェーズ判定（必須）

作業開始前に、必ず以下のフェーズを判定し、**対応するSkillを読んでから**作業を開始すること。
Skills は `.claude/skills/` にある。ClaudeCodeが自動判定で読み込むが、
判定が曖昧な場合は明示的に `/e2e-test-create` 等で呼び出すこと。

### 1) テスト作成フェーズ（Test Authoring）

**判定条件**: 既存環境へのE2Eテスト追加 / ユーザーストーリーに基づくテスト実装 / Actions・PageObjectの追加・修正

**必須Skill**:
1. `e2e-test-create` ← 最初に読む
2. `e2e-locator` ← Locator選択が必要なら読む

### 2) レビューフェーズ（Code Review）

**判定条件**: 既存テストコードのレビュー / PR確認 / コード品質チェック

**必須Skill**:
1. `e2e-review` ← 最初に読む
2. `e2e-locator` ← Locator関連の指摘をする場合に読む

### 3) 環境構築フェーズ（Bootstrap）

**判定条件**: 新規セットアップ / Playwright環境未整備 / 初回実行可能な状態を作る

**必須Skill**:
1. `e2e-bootstrap` ← 読む

**AIは作業フェーズを誤認してはならない。**
フェーズが不明な場合は、作業開始前に人間へ確認を求めること。

---

## ディレクトリ構成（参照用）

```
src/
├── config/          # Layer 4: 環境設定（constants.ts / env.ts）
├── pages/           # Layer 1: Page Objects（Locatorはここだけ）
├── actions/         # Layer 2: Actions（ビジネスフロー）
├── fixtures/        # Fixture定義（app.fixture.ts）
└── tests/           # Layer 3: Tests（期待結果検証のみ）
    └── scenarios/
```

## 開発コマンド

```bash
npm test                    # 全テスト実行
npm run test:headed         # ブラウザ表示モード
npm run test:debug          # デバッグモード
npm run test:ui             # Playwright UI モード
npm run report              # HTML レポート表示
```

---

**最終更新**: 2026-03-06
