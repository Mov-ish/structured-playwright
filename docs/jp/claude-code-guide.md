# Claude Code 導入ガイド — for-claude-code 運用セット

`for-claude-code/` を自分のプロジェクトに導入し、テスト手順書・チェックリストから保守継続性の高い Playwright テストを作り続けるための詳細ガイドです。クイックスタートは [for-claude-code/README.md](../../for-claude-code/README.md) を参照。

---

## 1. 前提条件

| 要件 | 内容 |
|------|------|
| Claude Code | CLI / IDE 拡張のいずれか。skills と Stop フックを使うため必須 |
| Node.js | Playwright が動作するバージョン（LTS 推奨） |
| bash | gate / Stop フックは bash スクリプト（macOS / Linux / WSL で動作） |
| TypeScript | **5 系必須**。gate の verify 内固定待機チェックが TypeScript 5 系の JS コンパイラ API を使用する。7 系はコンパイラ API を公開しないためチェックがエラー停止する（静かに素通りはしない）。`"typescript": "^5.9.0"` の semver レンジが `npm update` での major 昇格を防ぐ |

## 2. 導入手順（詳細）

### 2-1. コピー

`for-claude-code/` 配下の **`.claude/` `scripts/` `CLAUDE.md` の 3 つ**をプロジェクトルートへコピーする。ルートに置く理由: gate のメタ層チェックは cwd 相対で `.claude/` を読み、Claude Code は プロジェクトルートの `CLAUDE.md` / `.claude/` を自動認識する。

### 2-2. package.json

```json
{
  "scripts": {
    "gate": "bash scripts/gate.sh"
  },
  "devDependencies": {
    "@playwright/test": "^1.50.0",
    "dotenv": "^16.4.0",
    "typescript": "^5.9.0",
    "@types/node": "^22.0.0"
  }
}
```

記入したら `npm install` を実行する。未 install のまま gate を回すと、AST チェック（typescript の解決）と末尾の tsc が偽 fail する。

### 2-3. CLAUDE.md の固有情報欄

「プロジェクト固有情報（編集してください）」の 4 項目（対象プロダクト / UI ライブラリ / 認証方式 / HTML 特性）を記入する。ここが skills の判断（Locator 戦略・認証フロー実装）の入力になる。

### 2-4. baseline の凍結（人間が行う）

**前提**: gate は `src/` の存在を前提とする（cwd ガードで即 fail）ため、`/e2e-bootstrap` で 4 層の骨格（src/ + tsconfig）を生成した**後**に実行する。gate が exit 0 で通る状態を作り上げるところまでが bootstrap の Definition of Done。

bootstrap 後、初回の `npm run gate` は次のように案内する:

```
❌ Rules 常時ロード総量 → 初回セットアップ: 現在の実測値で .claude/rules-baseline を作成して
   凍結してください（人間が実行: echo NNNNN > .claude/rules-baseline。AI エージェントは作成しない）
```

指示どおり人間がファイルを作成すれば完了。この baseline は「常時ロードされる規範の総量はこの値を上限とする」という**ラチェット**で、以後 rules を増やす変更は「同量を削るか、baseline 引き上げの必然性を PR に書くか」の二択を機械的に迫られる。

**なぜ人間が作るのか**: 凍結は「この量を正とする」という意思決定であり、引き上げも含めて必ず人間の diff として残す設計のため。AI エージェントには「実測値を人間に伝えて設定を依頼する」ところまでを任せる（Stop フック経由の gate は baseline 未設定を ⚠️ に留め、エージェントが自己書き換えで脱出する誘因を作らない）。

### 2-5. Stop フックの仕組み

`.claude/settings.json` に登録済みの Stop フックが、**AI のターン終了時**に gate を自動実行する。

- 違反があれば exit 2 で停止をブロックし、エラー内容を AI に差し戻して自己修正させる（人間が違反コードを受け取る前に直る）
- `src/` `.claude/` `scripts/` に変更がないターン（質問への回答だけ等）は gate を回さない
- 依存未インストール（`node_modules` なし）では偽 fail を避けるためスキップする
- 無限ループは `stop_hook_active` フラグで防止

### 2-6. CI への組み込み（推奨）

ローカルの Stop フックは即時フィードバック、CI はバックストップ。例（GitHub Actions）:

```yaml
name: gate
on: [pull_request]
permissions:
  contents: read
jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npm ci
      - run: npm run gate
```

## 3. 運用フロー

### 3-1. フェーズ判定

作業を始める前にフェーズを判定し、対応する skill を読む（`CLAUDE.md` が入口）:

| フェーズ | トリガー | skill |
|---------|---------|-------|
| 環境構築 | 新規セットアップ / 既存プロジェクトの 4 層変換 | `/e2e-bootstrap` |
| テスト作成 | テスト追加 / 手順書・チェックリスト・ユーザーストーリーからの生成 | `/e2e-test-create`（+ `/e2e-locator`） |
| レビュー | PR 確認 / 品質チェック | `/e2e-review`（+ `/e2e-locator`） |

### 3-2. 入力契約 — 「原本」を渡す

テスト作成の入力は**原本** = テストの意図を記述した文書（テスト手順書 / チェックリスト / 受け入れ条件 / ユーザーストーリー）。粒度はまちまちでよい。AI は原本を JSDoc テスト手順書へ**正規化**してから実装し、原本と意図的に変えた点は手順書の「元手順書との意図的差分」欄に集約する。原本が曖昧なら AI は推測補完せず人間に確認する。

### 3-3. gate が守るもの

| 領域 | チェック | 守るもの |
|------|---------|---------|
| コード禁止パターン | 1〜13 | `text=` / XPath / 層境界違反 / `.catch` 隠蔽 / ハードコード / `Date.now()` 一意名 等 |
| 理由コメント規律 | 14〜18 | 未定義タグ / ordinal・`waitForTimeout`・expect 部分一致の理由コメント / describe 内 configure |
| AST 検出 | 19 | verify（`Promise<boolean>`）メソッド内の固定待機 = 判定が待ち時間に賭かる偽陽性の温床 |
| 宣言元の説明 | 20 | `constants.ts` の数値定数に「何の時間か」の宣言行コメント |
| メタ層（規範自体の劣化） | 21〜23 | rules 総量ラチェット / skill 間参照の健全性 / SKILL.md 単体 20KB 上限 |

⚠️ 警告（W1/W4〜W7）は exit code に影響しないが要目視。**自分が触った行に該当があれば解消する**のが運用ルール。

## 4. ウォークスルー — チェックリストからテストができるまで

### 入力（原本）: 人間が用意するもの

たとえばこんなチェックリストをそのまま渡せばよい:

```
【商品検索のスモーク確認】
- 一般ユーザーでログインできること
- キーワード「ノート」で検索すると結果一覧が表示されること
- 結果の 1 件目を開くと商品詳細が表示されること
```

### 実行

```
/e2e-test-create このチェックリストからテストを作って:（上記を貼り付け）
```

### AI が行うこと（SOP に沿った流れ）

1. **原本をテスト単位に分解**し、不明点（対象環境・テストデータの前提など）があれば人間に確認する
2. **JSDoc テスト手順書へ正規化**する — Phase 分割・番号付き手順・検証ポイント・タグを付与:

   ```typescript
   /**
    * TC-01: 商品検索スモーク
    *
    * ■ [Arrange] ログイン
    *   1. 一般ユーザーでログインする
    *
    * ■ [Act] Phase 1: キーワード検索（✅ 結果一覧の表示）
    *   2. キーワード「ノート」で検索する
    *   3. ✅ 結果一覧が表示されることを検証
    *
    * ■ [Act] Phase 2: 詳細表示（✅ 商品詳細の表示）
    *   4. 結果の 1 件目を開く
    *   5. ✅ 商品詳細が表示されることを検証
    *
    * ■ 検証ポイント（expect）
    *   - Phase 1: 結果一覧の表示
    *   - Phase 2: 商品詳細の表示
    *
    * ■ 元手順書との意図的差分
    *   - なし
    */
   ```

   原本と変えた点（検証の厳密化・手順の統合など）があれば「元手順書との意図的差分」欄に理由つきで記録される。原本の書き方とテストの実装が食い違ったとき、意図的な差分なのか実装ミスなのかをここで区別できる
3. **Action カタログと既存資産を確認**し、再利用できる Action（LoginAction 等）を特定。足りない Action と Page Object を 4 層の責務に従って実装する
4. `npx playwright test` で動作確認し、実行時間を手順書に記載する
5. **`npm run gate` で exit 0 を確認**してから PR 化する。ターン終了時には Stop フックも同じ gate を回すため、違反したコードは人間に届く前に差し戻される

### 人間がレビューで見るもの

`/e2e-review` が機械ゲート → 4 層責務 → JSDoc と実装の同期（差分欄の実態一致を含む）の順でチェックリストを流す。gate が機械化済みの項目は目視から外れているので、人間は「テストが原本の意図を検証できているか」に集中できる。

## 5. カスタマイズ指針

| 対象 | 指針 |
|------|------|
| `e2e-locator` の UI ライブラリ別サブファイル（Ant Design 3 本） | **参考例**。自分のスタック（MUI / Radix / 独自）の実戦知見が溜まったら同じ形式でサブファイルを追加し、§9 から参照する |
| `auth0-flow.md` | 外部認証（Auth0）の実装例。別の認証方式ならこれを雛形に書き換える |
| `constants.ts` の拡張 | 複数ファイルで使う値のみ追加（数値定数は宣言行コメント必須 — gate が検出） |
| rules への追記 | baseline ラチェットが発火する。「追加するなら何を削るか」を考える設計（コード例は rules に書かず skills へ — これも gate が検出） |
| skills の追加 | 新しいフェーズ skill は自由に追加してよい（SKILL.md 単体 20KB 上限・skill 間参照ルールだけ守る） |

## 6. テンプレート更新への追随

このキットは **導入先が `gate.sh` を編集しない**設計になっている（baseline は外部ファイル `.claude/rules-baseline`、プロジェクト固有情報は `CLAUDE.md` の記入欄）。テンプレートの新しいバージョンに追随するときは `.claude/rules/` `.claude/skills/` `scripts/` を再コピーすればよい。ただし:

- `.claude/rules-baseline` は上書きされない（キットに含まれない）
- rules / skills を自分で拡張している場合は diff を確認してからマージする
- 再コピー後に `npm run gate` を回し、baseline 超過が出たら差分を確認する（テンプレ側の増分が原因なら、その分の引き上げを検討する）
