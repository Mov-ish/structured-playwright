# CLAUDE.md - E2Eテストプロジェクト（4層アーキテクチャ）

**Playwright + TypeScript / 4層アーキテクチャ**

## フェーズ判定（必須）

作業開始前にフェーズを判定し、対応するSkillを読んでから着手すること。
`.claude/rules/` のルールは常に有効。Skillsは `.claude/skills/` にある。

### テスト作成
テスト追加 / Actions・PageObject実装 / ユーザーストーリーからのテスト生成
→ `/e2e-test-create` + 必要に応じて `/e2e-locator`

### レビュー
コードレビュー / PR確認 / 品質チェック
→ `/e2e-review` + 必要に応じて `/e2e-locator`

### 環境構築
新規セットアップ / 既存プロジェクトの4層変換 / Playwright導入
→ `/e2e-bootstrap`

**フェーズ不明 → 人間に確認を求めること。**

## プロジェクト固有情報（編集してください）

```
対象プロダクト: （ここに記入）
UIライブラリ: （例: Ant Design / MUI / 独自）
認証方式: （例: Auth0外部認証 / 独自ログイン / SSO）
HTML特性: （例: data-testidなし / aria-label不足 / 十分に整備済み）
```

## 開発コマンド

```bash
npm test                    # 全テスト実行
npm run test:headed         # ブラウザ表示モード
npm run test:debug          # デバッグモード
```
