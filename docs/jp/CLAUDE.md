# CLAUDE.md - E2Eテストプロジェクト ルールブック


## AI 作業フェーズ判定（必須）

本リポジトリにおけるAIの作業は、必ず次のいずれかのフェーズに分類する。

### 1) 環境構築フェーズ（Bootstrap）
- 新規セットアップ／Playwright環境が未整備／初回実行可能な状態を作る

👉 この場合、AIは **`./bootstrap.md`** を最初に参照し、記載された手順に従うこと。

### 2) テスト作成フェーズ（Test Authoring）
- 既存環境へのE2Eテスト追加／ユーザーストーリーに基づくテスト実装／Actions・PageObjectの追加/修正

👉 この場合、AIは **`./test_creation_protocol.md`** を参照し、4層アーキテクチャとLocator Strategyに従って作業すること。

**AIは作業フェーズを誤認してはならない。**  
フェーズが不明な場合は、作業開始前に人間へ確認を求めること。

---

## Locator Strategy（最終判断・正）

Locator の選択・設計に迷ったら、必ず次を参照し、ここを“正”として判断を止める：

1. `./LOCATOR/Concept/`
2. `./LOCATOR/Universal/`
3. `./LOCATOR/productspecific/PRODUCT_A/`

実装例（即効レシピ）は `CLAUDE_Selectors.md`、詰まった場合は `CLAUDE_FAQ.md` を参照する。

**プロジェクト名**: E2E Test Framework  
**対象環境**: Playwright + TypeScript  
**最終更新**: 2025-10-03

---

## 📚 参照ドキュメント

このプロジェクトは**4層アーキテクチャ**に基づいて構築されています。
詳細なアーキテクチャ定義は以下を参照してください：

👉 **[E2ETest_Framework.md](./E2ETest_Framework.md)** - 4層アーキテクチャ技術標準書

---

## 🎯 プロジェクト概要

このプロジェクトは、シナリオE2E検証を行うためのテストフレームワークです。
以下の原則に従ってテストコードを作成・管理します。

### アーキテクチャ構成

```
Layer 4: Config/Env     → 環境設定・環境変数管理
Layer 3: Tests          → 期待結果検証（AAA パターン）
Layer 2: Actions        → ビジネスロジック・複数画面フロー
Layer 1: Page Objects   → UI要素定義・基本操作
```

詳細は `E2ETest_Framework.md` を参照してください。
構造（Test / Actions / PageObject / Config）の判断に迷った場合は、E2ETest_Framework.md を正としてください。

---

## 🎨 このプロジェクトの特性

### HTML構造の特徴

**ルール化の背景**：
- **日付**: 2025-10-01（2026-01-13 更新）
- **発見**: Playwrightの推奨セレクタ（data-testid、セマンティック）が一部使えない
- **原因**: 既存HTMLに`data-testid`、`aria-label`等の属性が不足している要素がある
- **試行錯誤**: フロントエンドチームに属性追加を依頼したが、優先度の問題で対応困難
- **結論**: 要素の特性に応じてセマンティックロケータとCSSセレクタを使い分ける

**このプロジェクトでの制約**：
- ❌ `data-testid`属性がほぼ存在しない
- ⚠️ `aria-label`、`label`要素が不足している要素がある（特にチェックボックス、アイコンボタン）

**セマンティックロケータの使用指針**：
- ✅ **使用可能**: `getByRole('dialog')`, `getByRole('button', { name: '...' })`, `getByPlaceholder()`
- ✅ **使用可能**: モーダル、テキストを持つボタン、placeholder付き入力欄
- ⚠️ **使用不可（意味層が薄い要素）**: ラベルのないチェックボックス、アイコンのみのボタン

**意味層が薄い要素への対応策**：
- ✅ `:near()` セレクタ（周辺テキストで特定）
- ✅ `svg[data-icon]`（アイコンボタン）
- ✅ CSSセレクタ + `:has-text()` / `:text-is()`
- ✅ 親要素で絞り込み（Local Universe）

**詳細**：👉 **[CLAUDE_Selectors.md § 1-2](./CLAUDE_Selectors.md)**, **[locator_strategy.md](./LOCATOR/locator_strategy.md)**

---

### 認証フローの特性

**このプロジェクトの認証**：Auth0による外部認証

```
1. 利用規約ページ（my-app.example.com/login）
   ↓ 利用規約チェック → メールログインボタン
2. Auth0ログインページ（auth.example.com）← 外部ドメイン
   ↓ メール・パスワード入力 → ログインボタン
3. アプリケーション（コース一覧画面など）
```

**重要**：外部ドメインへの遷移があるため、以下が必須：
- Page Objectsの分離（TermsPage / Auth0LoginPage）
- URL遷移の明示的な待機
- 画面安定化の待機

**詳細**：👉 **[CLAUDE_Patterns.md § 1](./CLAUDE_Patterns.md)**

---

### SPA特性

このプロジェクトはReact SPAのため、以下の特性があります：

**問題**：`networkidle`後もレンダリング遅延が発生

**対応**：
```typescript
// networkidle + waitForTimeout の組み合わせ
await page.waitForLoadState('networkidle');
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // 2000ms
```

**詳細**：👉 **[CLAUDE_Patterns.md § 2](./CLAUDE_Patterns.md)**

---

## 🔐 セキュリティ・環境変数ルール

### 必須ルール

#### 1. **認証情報の外部化**
- ❌ **禁止**: ユーザーID、パスワードをコード内にハードコード
- ✅ **必須**: `.env`ファイルから環境変数として読み込む

```typescript
// ❌ 悪い例
const email = 'user@example.com';
const password = 'password123';

// ✅ 良い例
const env = EnvConfig.getTestEnvironment();
const email = env.credentials.email;
const password = env.credentials.password;
```

#### 2. **機密情報の管理**
以下の情報は**必ず環境変数**で管理すること：

- メールアドレス
- パスワード
- 認証トークン
- APIキー
- テスト対象URL（環境ごとに異なる場合）

#### 3. **.envファイルの取り扱い**
- `.env`ファイルは`.gitignore`に含める（既に設定済み）
- `.env.example`をテンプレートとして用意する
- 本番環境の認証情報は絶対に含めない

---

## 🎯 ロケータ戦略ルール

### このプロジェクト固有の制約

このプロジェクトのHTMLには`data-testid`が存在せず、一部の要素では`aria-label`、`label`が不足しています。
**セマンティックロケータは要素の特性に応じて使い分けてください。**

詳細は `CLAUDE_Selectors.md § 1` および `locator_strategy.md` を参照してください。

### ロケータ優先順位（このプロジェクト）

| 優先度 | 方法 | 使用可否 | 備考 |
|--------|------|----------|------|
| ❌ 1 | data-testid | **使用不可** | 属性が存在しない |
| ✅ 2 | セマンティック（getByRole等） | **条件付き使用可** | モーダル、ボタン（テキストあり）、placeholder付き入力欄で有効 |
| ✅ 3 | CSSセレクタ + `:has-text()` / `:text-is()` | **推奨** | 安定して動作 |
| ✅ 4 | `:near()` セレクタ | **推奨** | 意味層の薄い要素（チェックボックス等）に有効 |
| ✅ 5 | `svg[data-icon]` | **推奨** | アイコンボタンに有効 |
| ✅ 6 | 属性セレクタ（name, type） | **推奨** | フォーム要素に有効 |
| ⚠️ 7 | 構造セレクタ（親子関係） | **最終手段** | 変更に弱い、コメント必須 |

### 必須ルール

**❌ 禁止パターン**
```typescript
// text=ロケータ（このプロジェクトで動作しない）
page.locator(`text=${groupName}`)
page.locator('text=ログイン')

// 意味層の薄い要素へのセマンティックロケータ（動作しない）
page.getByLabel('同意する')  // ❌ label要素がない
page.getByRole('checkbox')              // ❌ 一意に特定できない
```

**✅ 推奨パターン**
```typescript
// セマンティックロケータ（意味層がある要素）
page.getByRole('dialog', { name: 'テキストを追加' })  // モーダル
page.getByRole('button', { name: '保存' })            // テキスト付きボタン
page.getByPlaceholder('検索')                         // placeholder付き入力欄

// CSSセレクタ + :has-text() / :text-is()
page.locator('button:has-text("ログイン")')
page.locator('span:text-is("コース一覧")')  // 完全一致

// :near() セレクタ（意味層の薄い要素）
page.locator('input[type="checkbox"]:near(:text("同意する"))')

// svg[data-icon]（アイコンボタン）
page.locator('button:has(svg[data-icon="edit"])')
page.locator('button:has(svg[data-icon="ellipsis"])')

// 属性セレクタ（フォーム要素）
page.locator('input[name="email"]')
page.locator('input[type="password"]')

// 親要素で絞り込み（Local Universe）
page.locator('[role="dialog"] button:has-text("保存")')
```

### エラーバナー検出

```typescript
// ✅ CSSセレクタで検出
await expect(page.locator('[role="alert"]')).toBeVisible();
await expect(page.locator('[role="alert"]')).toContainText('エラーメッセージ');
```

---

## 🚫 禁止事項まとめ

| 禁止事項 | 理由 | 代替手段 | 詳細 |
|---------|------|----------|------|
| 認証情報のハードコード | セキュリティリスク | 環境変数（.env） | §セキュリティ・環境変数ルール |
| タイムアウト値のハードコード | 保守性低下 | TIMEOUTS定数 | E2ETest_Framework.md §6.2 |
| 共通セレクタのハードコード | 一貫性欠如 | SELECTORS定数 | E2ETest_Framework.md §6.2 |
| URLパターンのハードコード | 環境変更時の修正漏れ | URL_PATTERNS定数 | E2ETest_Framework.md §6.2 |
| `private readonly`でロケーター定義 | デバッグ困難 | `readonly`（public） | E2ETest_Framework.md §3.2 |
| Actionの中間ステップログ省略 | 原因特定困難 | 各ステップでconsole.log | E2ETest_Framework.md §4.2 |
| ログイン成功検証の省略 | 後続テスト失敗時の原因不明瞭 | URL検証ロジック | CLAUDE_Patterns.md §1.4.1 |
| `.first()`の安易な使用 | 保守性低下 | 具体的なセレクタ、`:near()` | CLAUDE_Selectors.md §3 |
| `text=`ロケータ | このプロジェクトで動作しない | CSSセレクタ + :has-text() | §ロケータ戦略ルール |
| 意味層の薄い要素へのセマンティックロケータ | 属性が不足 | `:near()`、`svg[data-icon]` | §ロケータ戦略ルール |

---

## ⏱️ 待機処理ルール

### 原則：画面描画を待つ

#### ⚠️ 最小化：固定時間待機

```typescript
// ❌ 禁止：コメントなし・定数未使用
await page.waitForTimeout(5000);

// ✅ 許容：TIMEOUTS定数 + 理由コメント
// SPAのレンダリング完了を待つ（networkidleだけでは不十分）
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
```

`waitForTimeout`は**最小化**を原則とし、使用時は以下を必須とします：
- **TIMEOUTS定数を使用**（数値のハードコード禁止）
- **理由をコメントで明記**

**詳細な使い分け**：👉 **[CLAUDE_Patterns.md § 2](./CLAUDE_Patterns.md)** を参照

#### ✅ 推奨：状態ベースの待機

**URL遷移を待つ**
```typescript
// URL パターンマッチ
await expect(page).toHaveURL(/\/groups\/\w+/);

// 特定のURLパス
await expect(page).toHaveURL(/.*\/dashboard/);
```

**要素の表示を待つ**
```typescript
// 見出しの表示
await expect(page.locator('h1:has-text("学習目標")')).toBeVisible();

// ボタンの有効化
await expect(page.locator('button:has-text("ログイン")')).toBeEnabled();

// ロケータの表示
await loginPage.emailInput.waitFor({ state: 'visible', timeout: 10000 });
```

**ネットワーク待機**
```typescript
// ネットワークアイドル待機
await page.waitForLoadState('networkidle');

// DOM読み込み完了
await page.waitForLoadState('domcontentloaded');
```

#### ✅ 応用：expect.poll の活用

動的な値をポーリングして待機する場合：

```typescript
await expect.poll(async () => {
  const count = await page.locator('.item').count();
  return count;
}, {
  timeout: 10000,
  message: 'アイテム数が期待値に達しませんでした'
}).toBeGreaterThan(0);
```

---

## 🧪 テストコード品質ルール

### 1. **コード生成後の内部テスト必須**

テストコードを生成・修正したら、**必ず実行して動作確認**すること。

```bash
# テスト実行
npm test

# 特定のテストのみ実行
npx playwright test src/tests/scenarios/login.spec.ts

# ヘッドモードで確認
npm run test:headed
```

### 2. **変更時の依存性確認**

テストコードを変更する際は、以下を確認すること：

- ✅ 変更した Page Object を使用している Action の影響
- ✅ 変更した Action を使用している Test の影響
- ✅ 共通モジュール変更時は全テストへの影響

### 3. **結果検証の徹底**

テストは**動作だけでなく結果まで必ず確認**すること。

```typescript
// ❌ 悪い例：動作のみ、結果未確認
await loginAction.execute(email, password);
// テスト終了

// ✅ 良い例：結果を明示的に検証
await loginAction.execute(email, password);
expect(page.url()).not.toContain('/login');
await expect(page.locator('h1:has-text("ダッシュボード")')).toBeVisible();
```

### 4. **データクリーンアップの実施**

テスト終了後、作成したデータは必ずクリーンアップすること。

```typescript
test('新規グループ作成テスト', async ({ page }) => {
  // Arrange
  const groupName = `テストグループ_${Date.now()}`;

  // Act
  await createGroupAction.execute(groupName);

  // Assert
  await expect(page.getByText(groupName)).toBeVisible();

  // Cleanup（重要！）
  await deleteGroupAction.execute(groupName);
});
```

または、`test.afterEach`を活用：

```typescript
test.afterEach(async ({ page }) => {
  // テスト後のクリーンアップ処理
  await cleanupTestData();
});
```

---

## 📁 ディレクトリ構成

```
src/
├── config/          # Layer 4: 環境設定
│   └── env.ts
├── pages/           # Layer 1: Page Objects
│   ├── LoginFormPage.ts
│   ├── TermsPage.ts
│   └── DashboardPage.ts
├── actions/         # Layer 2: Actions
│   └── LoginAction.ts
└── tests/           # Layer 3: Tests
    └── scenarios/
        └── login.spec.ts
```

詳細は `E2ETest_Framework.md` を参照してください。

---

## 🚀 開発コマンド

```bash
# テスト実行
npm test                    # 全テスト実行
npm run test:headed         # ブラウザ表示モード
npm run test:debug          # デバッグモード
npm run test:ui             # Playwright UI モード

# レポート表示
npm run report              # HTML レポート表示
```

---

## ✅ テスト作成チェックリスト

新しいテストを作成する際は、以下を確認してください：

### Page Object 作成時

- [ ] `readonly`でロケーター定義
- [ ] ロケータ優先順位に従う（セマンティック → :has-text() → :near() → data-icon）
- [ ] 意味層の薄い要素には`:near()`や`svg[data-icon]`を使用
- [ ] 単一責任メソッドのみ実装
- [ ] ビジネスロジックを含めない
- [ ] JSDocコメント記述

### Action 作成時

- [ ] 使用するPage Objectsをプライベートフィールドで保持
- [ ] `execute()`メソッドで主要フローを実装
- [ ] 適切な待機処理（`waitForTimeout`は最小化＋コメント必須）
- [ ] コンソールログで進行状況を出力
- [ ] エラーハンドリング実装

### Test 作成時

- [ ] AAA（Arrange-Act-Assert）パターンに従う
- [ ] 環境変数から認証情報を取得
- [ ] ロケータ優先順位に従った検証
- [ ] 結果検証を必ず実施
- [ ] データクリーンアップを実装
- [ ] 実行して動作確認完了

---

## 🔍 コードレビュー観点

プルリクエスト時は以下を確認：

1. **セキュリティ**
   - 認証情報がハードコードされていないか
   - `.env`ファイルが`.gitignore`に含まれているか

2. **ロケータ**
   - `text=`ロケータを使用していないか
   - ロケータ優先順位に従っているか
   - 意味層の薄い要素に`:near()`や`svg[data-icon]`を使用しているか
   - 構造依存セレクタを避けているか

3. **待機処理**
   - `waitForTimeout`を不必要に使用していないか
   - 状態ベースの待機を使用しているか

4. **テスト品質**
   - 結果検証が実装されているか
   - データクリーンアップが実装されているか
   - テストが実行可能か（動作確認済みか）

---

## ⚡ クイックチェックリスト

### Page Object 作成時
- [ ] `import { TIMEOUTS, SELECTORS } from '../config/constants';` を追加
- [ ] `readonly`でロケーター定義（`private readonly`は禁止）
- [ ] ロケータ優先順位に従う（セマンティック → :has-text() → :near() → data-icon）
- [ ] 共通セレクタは`SELECTORS`から読み込み
- [ ] `.first()`は極力避ける（使用時はコメント必須）

### Action 作成時
- [ ] `import { TIMEOUTS, URL_PATTERNS } from '../config/constants';` を追加
- [ ] Page Objectsをプライベートフィールドで保持
- [ ] 状態ベース待機 + waitForTimeout を組み合わせ
- [ ] waitForTimeout使用時は理由をコメント
- [ ] **各ステップでconsole.log出力**（必須）
- [ ] **LoginActionはログイン成功検証を実装**（必須）

### Test 作成時
- [ ] AAAパターンに従う
- [ ] 環境変数から認証情報を取得
- [ ] 結果検証を実施
- [ ] **実行して動作確認完了**（最重要！）

---

## 📝 ルールの追加・更新

### 新しいルールの追加方法

1. **テスト実行で不備を発見**
2. **原因を特定**：曖昧さ？未定義条件？
3. **適切なドキュメントに追記**：
   - セレクタ関連 → `CLAUDE_Selectors.md`
   - パターン関連 → `CLAUDE_Patterns.md`
   - エラー対処 → `CLAUDE_FAQ.md`
4. **ルール化の背景を記録**：
   - 日付、発見内容、原因、試行錯誤、結論

### 汎用化のフロー

定期的（月次または四半期）に棚卸しを実施：

```
1. CLAUDE_xxx.mdをレビュー
   ↓
2. 他プロジェクトでも使えるパターンを特定
   ↓
3. E2ETest_Framework.mdへ移動（具体例として）
   ↓
4. CLAUDE_xxx.mdから削除 or 参照リンクに置き換え
```

---

## 📖 参考リンク

- [E2ETest_Framework.md](./E2ETest_Framework.md) - 4層アーキテクチャ詳細
- [CLAUDE_Selectors.md](./CLAUDE_Selectors.md) - セレクタ戦略・パターン集
- [CLAUDE_Patterns.md](./CLAUDE_Patterns.md) - 実装パターン・成功事例
- [CLAUDE_FAQ.md](./CLAUDE_FAQ.md) - トラブルシューティング
- [Playwright 公式ドキュメント](https://playwright.dev/)
- [Playwright ロケータ戦略](https://playwright.dev/docs/locators)

---

## License

MIT License

---

**最終更新**: 2026-01-13
**管理者**: Ray Ishida