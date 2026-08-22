# for-claude-code — Claude Code 運用セット

テスト手順書・チェックリスト・ユーザーストーリーから、**保守継続性の高い 4 層アーキテクチャの Playwright テスト**を Claude Code で作り、維持し続けるための運用セットです。

- **rules**（常時ロードされる規範）— 4 層の責務境界・禁止パターン・Locator 設計思想
- **skills**（フェーズ別の作業手順）— 環境構築 / テスト作成 / レビュー / Locator 実装
- **gate**（機械ゲート）— 禁止パターンと構造劣化（規範ドキュメント自体の肥大・重複）を exit code で機械検出

規範は「散文で言い聞かせる」のではなく、可能な限り `npm run gate` が機械判定します。AI が生成したコードも人間が書いたコードも、同じゲートを通ります。

## クイックスタート

1. **コピーするのは 3 つ**: このディレクトリの `.claude/` `scripts/` `CLAUDE.md` を、あなたのプロジェクトのルートへコピーする（この README と親リポジトリの他ファイルはコピー不要）
2. `package.json` に gate を登録し、依存をインストールする:

   ```json
   { "scripts": { "gate": "bash scripts/gate.sh" } }
   ```

   devDependencies は typescript **5 系**を使う（gate の AST チェックが 5 系のコンパイラ API を前提とするため。詳細は導入ガイド）。登録したら `npm install` を実行する（未 install だと gate の AST チェックと tsc が偽 fail する）
3. `CLAUDE.md` の「プロジェクト固有情報」欄を記入する（対象プロダクト・UI ライブラリ・認証方式・HTML 特性）
4. Claude Code で `/e2e-bootstrap` を実行し、4 層の骨格（Fixture / BaseAction / constants / uniqueId / tsconfig）を生成する。既存の Playwright プロジェクトの 4 層変換も同じ skill が扱う。gate は `src/` の存在を前提とするため、**初回の gate 実行より先にこのステップ**（bootstrap の Definition of Done に「gate が exit 0」が含まれる = gate が通る状態を作り上げるのは bootstrap の責務）
5. `npm run gate` を実行する — 初回は「Rules 総量 baseline の凍結」を案内されるので、**人間が**指示どおり `.claude/rules-baseline` を作成する（AI エージェントには作成させない — 理由はガイド参照）

以降、テストを作るときは**原本**（テスト手順書 / チェックリスト / 受け入れ条件 / ユーザーストーリー）を渡して `/e2e-test-create`、レビューは `/e2e-review`、Locator で迷ったら `/e2e-locator`。

## 構成

| パス | 役割 |
|------|------|
| `.claude/rules/` | 常時ロードされる規範 4 本（アーキテクチャ / 禁止パターン / Locator 思想 / 定数・セキュリティ） |
| `.claude/skills/` | フェーズ別 skill 4 本 + 条件付きサブファイル（必要な局面でだけ読む詳細） |
| `.claude/settings.json` | Stop フック（ターン終了時に gate を自動実行し、違反があれば AI に自己修正させる） |
| `scripts/gate.sh` | 機械ゲート本体（❌ = exit 1 / ⚠️ = 要目視） |
| `scripts/check-verify-wait.js` | verify メソッド内固定待機の AST 検出（gate から呼ばれる） |
| `CLAUDE.md` | フェーズ判定の入口 + プロジェクト固有情報の記入欄 |

## 詳細ガイド

前提条件・Stop フックの仕組み・gate の各チェックが守るもの・baseline の運用・**サンプル手順書からテストができるまでのウォークスルー**・カスタマイズ指針は、導入ガイドを参照:

**→ [docs/jp/claude-code-guide.md](../docs/jp/claude-code-guide.md)**（英語版は [docs/en/claude-code-guide.md](../docs/en/claude-code-guide.md)）
