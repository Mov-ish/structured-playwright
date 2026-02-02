# CLAUDE_Patterns.md - 実装パターン・成功事例集

**最終更新**: 2026-02-02

---

## 📘 このドキュメントについて

このドキュメントは、**このプロジェクトで実際に動作した実装パターンと成功事例**を記載しています。

**対象**：
- Claude.code / CodexCLIによるコード生成
- 開発者の実装時の参照
- 新しいパターンの追記

**メインルールブック**：👉 [CLAUDE.md](./CLAUDE.md)

---

## § 1. Auth0外部認証フロー

### 1.1 ルール化の背景

**日付**: 2025-10-05  
**発見**: Auth0ログインで要素が見つからないエラー頻発  
**原因**: 外部ドメイン（auth.example.com）への遷移を待たずに操作  
**試行錯誤**:
1. `waitForLoadState('networkidle')` のみ → 失敗（外部遷移前に次の操作）
2. `page.waitForURL()` 追加 → 改善したが不安定
3. `page.waitForURL()` + `waitForTimeout()` → 成功（test2で安定動作）

**結論**: URL遷移の明示的な待機 + 画面安定化待機が必須

---

### 1.2 認証フロー図

```
1. 利用規約ページ (my-app.example.com/login)
   ↓
   利用規約チェック
   ↓
   「メールアドレスでログイン」ボタンクリック
   ↓
2. Auth0ページ (auth.example.com) ← 外部ドメイン
   ↓
   【重要】URL遷移待機 + 画面安定化待機
   ↓
   メールアドレス入力
   ↓
   パスワード入力
   ↓
   ログインボタンクリック
   ↓
3. アプリケーション (my-app.example.com/courses)
   ↓
   【重要】リダイレクト完了待機
```

---

### 1.3 Page Objectsの分離

**重要**：ドメインが異なるページは、必ず別のPage Objectに分離すること

```typescript
// ✅ 正しい分離
export class TermsPage extends BasePage {
  // my-app.example.com/login
  readonly agreeCheckbox: Locator;
  readonly emailLoginButton: Locator;
}

export class Auth0LoginPage extends BasePage {
  // auth.example.com
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
}

// ❌ 間違い：混在
export class LoginPage {
  // 異なるドメインの要素を同じPage Objectに混在
  readonly agreeCheckbox: Locator;      // my-app.example.com
  readonly emailInput: Locator;         // auth.example.com
}
```

**理由**：
- 変更理由が異なる（自社サイト vs 外部サービス）
- デバッグが容易
- Page Object単体でのテストが可能

---

### 1.4 LoginAction実装パターン（test2で成功）

```typescript
import type { Page } from '@playwright/test';
import { TIMEOUTS } from '../config/constants';
import { TermsPage } from '../pages/TermsPage';
import { Auth0LoginPage } from '../pages/Auth0LoginPage';

export class LoginAction {
  private readonly page: Page;
  private readonly termsPage: TermsPage;
  private readonly auth0LoginPage: Auth0LoginPage;

  constructor(page: Page) {
    this.page = page;
    this.termsPage = new TermsPage(page);
    this.auth0LoginPage = new Auth0LoginPage(page);
  }

  /**
   * ログインフローを実行
   * @param url - ログインページURL
   * @param email - メールアドレス
   * @param password - パスワード
   */
  async execute(url: string, email: string, password: string): Promise<void> {
    console.log('🔐 ログインフロー開始');

    // Step 1: 利用規約ページへ遷移
    console.log('📄 利用規約ページへ遷移');
    await this.termsPage.goto(url);
    await this.termsPage.waitForReady();

    // Step 2: 利用規約に同意
    console.log('✅ 利用規約に同意');
    await this.termsPage.agreeToTerms();

    // Step 3: メールアドレスでログインボタンをクリック
    console.log('📧 メールログインボタンクリック');
    await this.termsPage.clickEmailLogin();

    // Step 4: Auth0ページへの遷移を待つ（重要！）
    console.log('⏳ Auth0ページへの遷移を待機');
    await this.page.waitForURL('**/auth.example.com/**', {
      timeout: TIMEOUTS.DEFAULT
    });
    // Auth0画面の安定化待ち（SPAの初期レンダリング）
    await this.page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);

    // Step 5: Auth0でメールアドレスを入力
    console.log('📧 メールアドレス入力');
    await this.auth0LoginPage.waitForReady();
    await this.auth0LoginPage.fillEmail(email);

    // Step 6: パスワードを入力してログイン
    console.log('🔑 パスワード入力とログイン');
    await this.auth0LoginPage.fillPassword(password);
    await this.auth0LoginPage.clickSubmit();

    // Step 7: ログイン完了を待つ（リダイレクト）
    console.log('⏳ ログイン完了を待機');
    await this.page.waitForTimeout(TIMEOUTS.REDIRECT);

    // Step 8: ログイン成功検証（MUST）
    console.log('🔍 ログイン成功を検証');
    const currentURL = this.page.url();
    if (currentURL.includes('/login')) {
      throw new Error('ログインに失敗しました（ログインページのままです）');
    }
    console.log('✅ ログイン成功を確認');

    console.log('✅ ログインフロー完了');
  }
}
```

**重要なポイント**：
1. **URL遷移の明示的な待機**：`waitForURL()`
2. **画面安定化待機**：`TIMEOUTS.AUTH0_STABILIZATION`
3. **リダイレクト完了待機**：`TIMEOUTS.REDIRECT`
4. **コンソールログで進捗確認**：デバッグに有用
5. **ログイン成功検証**：URLがログインページでないことを確認（MUST）

### 1.4.1 ログイン成功検証ルール（MUST）

**❌ 禁止：検証なしでログイン完了**
```typescript
await this.auth0LoginPage.clickSubmit();
await this.page.waitForURL('**example.com**', { timeout: TIMEOUTS.LONG });
// ← ここで終了、成功検証なし
```

**✅ 必須：ログイン成功を明示的に検証**
```typescript
await this.auth0LoginPage.clickSubmit();
await this.page.waitForURL(URL_PATTERNS.DASHBOARD, { timeout: TIMEOUTS.LONG });

// ログイン成功確認（URLがログインページでないことを確認）
const currentURL = this.page.url();
if (currentURL.includes('/login')) {
  throw new Error('ログインに失敗しました（ログインページのままです）');
}
console.log('ログイン成功を確認');
```

**理由**：ログイン失敗時に後続テストが不明瞭なエラーで失敗することを防ぐ

---

### 1.5 よくあるエラーと対処

#### エラー1: `Target page, context or browser has been closed`

**原因**：URL遷移を待たずに要素操作

```typescript
// ❌ 悪い例
await this.termsPage.clickEmailLogin();
await this.auth0LoginPage.fillEmail(email); // エラー！

// ✅ 良い例
await this.termsPage.clickEmailLogin();
await this.page.waitForURL('**/auth.example.com/**', { timeout: TIMEOUTS.DEFAULT });
await this.page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);
await this.auth0LoginPage.fillEmail(email); // 成功
```

---

## § 2. 待機処理パターン

### 2.1 ルール化の背景

**日付**: 2025-10-10  
**発見**: `networkidle`後も要素が見つからないエラー  
**原因**: React SPAのため、ネットワーク完了後にレンダリング遅延がある  
**試行錯誤**:
1. `waitForLoadState('networkidle')` のみ → 不安定
2. 固定待機時間（5000ms）のみ → 遅すぎる
3. `networkidle` + `waitForTimeout(2000ms)` → 安定（test2-test5で成功）

**結論**: 状態ベース待機 + 固定待機時間を組み合わせる

---

### 2.2 待機処理の種類と使い分け

| 状況 | 待機方法 | タイムアウト | 理由 |
|------|---------|------------|------|
| **ページ遷移後** | `networkidle` + `waitForTimeout` | `TIMEOUTS.SPA_RENDERING` | SPAの初期レンダリング |
| **モーダル表示** | `waitFor({state: 'visible'})` + `waitForTimeout` | `TIMEOUTS.MODAL_ANIMATION` | アニメーション完了 |
| **Auth0遷移** | `waitForURL()` + `waitForTimeout` | `TIMEOUTS.AUTH0_STABILIZATION` | 外部サイトの描画 |
| **リダイレクト** | `waitForTimeout` | `TIMEOUTS.REDIRECT` | 認証完了とリダイレクト |

---

### 2.3 SPA待機パターン

```typescript
// ページ遷移後の待機
async goto(url: string): Promise<void> {
  await this.page.goto(url);
  // ネットワーク完了を待つ
  await this.page.waitForLoadState('networkidle');
  // SPAレンダリング完了を待つ
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
}
```

**コメント例**：
```typescript
// SPAのため、networkidle後もReactのレンダリング遅延がある
await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
```

---

### 2.4 モーダル待機パターン（test5で成功）

```typescript
/**
 * モーダル表示を待ち、ボタンをクリック
 */
async clickModalButton(buttonText: string): Promise<void> {
  // Step 1: モーダルの表示を待つ
  await this.page.locator(SELECTORS.MODAL).waitFor({ 
    state: 'visible', 
    timeout: TIMEOUTS.SHORT 
  });
  
  // Step 2: モーダルのアニメーション完了を待つ
  // 理由: CSSアニメーション中はクリックイベントが正しく処理されない
  await this.page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
  
  // Step 3: ボタンをスクロールして表示
  const button = this.page.locator(`[role="dialog"] button:has-text("${buttonText}")`);
  await button.scrollIntoViewIfNeeded();
  
  // Step 4: ボタンをクリック
  await button.click({ force: true });
}
```

**重要なポイント**：
1. モーダルの表示待機
2. アニメーション完了待機（必須）
3. スクロール処理
4. `force: true` オプション

---

### 2.5 waitForTimeoutのコメント記載例

```typescript
// ✅ 良い例：理由を明記
await this.page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
// 理由: モーダルのCSSアニメーション（1秒）完了を待つ

await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
// 理由: React SPAの初期レンダリング完了を待つ

await this.page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);
// 理由: Auth0（外部サイト）の画面描画完了を待つ

// ❌ 悪い例：理由がない、定数を使用していない
await this.page.waitForTimeout(2000);
```

**新しい定数が必要な場合のパターン**：
```typescript
// Step 1: constants.tsに定数を追加
export const TIMEOUTS = {
  // ... 既存の定数 ...
  KEEP_BROWSER_OPEN: 300000,   // 新規追加：ブラウザを開いたまま待機（5分）
} as const;

// Step 2: 使用箇所でインポートして使用
import { TIMEOUTS } from '../config/constants';

// 手順28: ブラウザを開いたまま待機
await page.waitForTimeout(TIMEOUTS.KEEP_BROWSER_OPEN);
```

---

## § 3. 成功実装パターン集

### 3.1 test2：ログインフロー（成功事例）

**実装日**: 2025-10-05  
**成功要因**:
- Auth0外部認証フローの正しい実装
- URL遷移待機の導入
- 適切な待機時間の設定

**コードパターン**：§ 1.4 参照

---

### 3.2 test：セレクタ定義（成功事例）

**実装日**: 2025-10-20  
**成功要因**:
- `.first()`を14箇所 → 1箇所に削減
- 具体的なセレクタ定義（constants.ts）
- `:near()` セレクタの活用

**詳細**：👉 [CLAUDE_Selectors.md § 2-3](./CLAUDE_Selectors.md)

---

### 3.3 test5：モーダル処理（成功事例）

**実装日**: 2025-10-25  
**成功要因**:
- モーダルアニメーション完了待機
- `scrollIntoViewIfNeeded()`の活用
- `force: true`オプション

**コードパターン**：§ 2.4 参照

---

## § 4. コンポーネント別パターン

### 4.1 フォーム入力パターン

```typescript
/**
 * フォーム入力の基本パターン
 */
export class FormPage extends BasePage {
  async fillForm(data: FormData): Promise<void> {
    // 入力フィールドの準備完了を待つ
    await this.firstInput.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    
    // フィールドに入力
    await this.nameInput.fill(data.name);
    await this.emailInput.fill(data.email);
    
    // ドロップダウンの選択
    await this.categorySelect.selectOption(data.category);
    
    // チェックボックスのチェック
    if (data.agree) {
      await this.agreeCheckbox.check();
    }
    
    // 送信ボタンをクリック
    await this.submitButton.click();
    
    // 送信完了を待つ
    await this.page.waitForLoadState('networkidle');
  }
}
```

---

### 4.2 リスト操作パターン

```typescript
/**
 * リスト内の特定項目を操作
 */
export class ListPage extends BasePage {
  /**
   * リスト項目をクリック
   * @param itemText - 項目のテキスト
   */
  async clickListItem(itemText: string): Promise<void> {
    // リストの読み込み完了を待つ
    await this.page.waitForLoadState('networkidle');
    await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
    
    // 項目をクリック
    await this.page.locator(`li:has-text("${itemText}")`).click();
  }
  
  /**
   * リスト項目の3点リーダーメニューを開く
   * @param itemText - 項目のテキスト
   */
  async openItemMenu(itemText: string): Promise<void> {
    // 項目を特定
    const item = this.page.locator(`li:has-text("${itemText}")`);
    
    // 3点リーダーボタンをクリック
    const moreButton = item
      .getByRole('button')
      .filter({ has: this.page.locator('svg[data-icon="ellipsis"]') });
    
    await moreButton.click();
    
    // メニュー表示を待つ
    await this.page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
  }
}
```

---

### 4.3 ファイルアップロードパターン

```typescript
/**
 * ファイルアップロード
 */
export class UploadPage extends BasePage {
  async uploadFile(filePath: string): Promise<void> {
    // ファイル選択
    await this.fileInput.setInputFiles(filePath);
    
    // アップロード完了を待つ
    await this.page.waitForResponse(resp => 
      resp.url().includes('/api/upload') && resp.status() === 200
    );
    
    // UI更新を待つ
    await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
  }
}
```

---

## § 5. エラーハンドリングパターン

### 5.1 基本的なエラーハンドリング

```typescript
export class BaseAction {
  protected async executeWithErrorHandling(
    actionName: string,
    action: () => Promise<void>
  ): Promise<void> {
    try {
      console.log(`🚀 ${actionName} 開始`);
      await action();
      console.log(`✅ ${actionName} 完了`);
    } catch (error) {
      console.error(`❌ ${actionName} 失敗:`, error);
      
      // スクリーンショット保存
      await this.page.screenshot({ 
        path: `screenshots/error-${Date.now()}.png`,
        fullPage: true 
      });
      
      throw error;
    }
  }
}
```

---

### 5.2 リトライパターン

```typescript
/**
 * 不安定な操作をリトライ
 */
async clickWithRetry(locator: Locator, maxRetries: number = 3): Promise<void> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await locator.click({ timeout: TIMEOUTS.SHORT });
      return; // 成功
    } catch (error) {
      if (i === maxRetries - 1) {
        throw error; // 最後のリトライで失敗
      }
      console.log(`⚠️ クリック失敗、リトライ ${i + 1}/${maxRetries}`);
      await this.page.waitForTimeout(1000);
    }
  }
}
```

---

## § 6. 新パターン追記エリア

### 2026-02-02 - 確認ダイアログの待機パターン

**実装背景**：
削除ボタンクリック後、確認ダイアログが表示される前に「削除する」ボタンを探してタイムアウトが発生した。

**成功要因**：
ボタンクリック後、確認ダイアログ内のボタンが表示されるまで明示的に待機する。

**コード例**：
```typescript
// ❌ 悪い例：ダイアログ表示を待たない
await deleteButton.click();
await this.page.waitForTimeout(TIMEOUTS.UI_RESPONSE);
await this.confirmDeleteButton.click(); // タイムアウトする可能性

// ✅ 良い例：確認ダイアログの表示を待つ
await deleteButton.click();
await this.confirmDeleteButton.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
await this.confirmDeleteButton.click();
```

**注意点**：
- `waitForTimeout`だけでは不安定（ダイアログ表示のタイミングが環境により異なる）
- `waitFor({ state: 'visible' })`で確実に表示を待つ

---

### 2026-02-02 - 削除後のリスト変化確認パターン

**実装背景**：
SPAでリスト項目が削除された後、その変化を確認しようとしたが、要素参照が無効になり失敗した。

**試行錯誤**：
1. `waitFor({ state: 'hidden' })` → ❌ 要素がDOMから削除されるため失敗
2. `waitFor({ state: 'detached' })` → ❌ DOM依存で不安定
3. `expect().toHaveCount(0)` → ❌ 削除済みタブでは動作せず
4. タブ遷移で確認 → ❌ タブ要素取得が不安定
5. **URL遷移確認** → ✅ 安定して動作

**成功要因**：
削除操作後、期待するURLに遷移することを確認する。

**コード例**：
```typescript
// ❌ 不安定：要素の消失を直接確認
await this.confirmDeleteButton.click();
await itemRow.waitFor({ state: 'hidden', timeout: TIMEOUTS.DEFAULT }); // 失敗

// ✅ 安定：URL遷移で削除完了を確認
await this.confirmDeleteButton.click();
await this.page.waitForURL('**/admin/items?tab=archive', { timeout: TIMEOUTS.DEFAULT });
```

**注意点**：
- SPAではリスト項目削除時に要素がDOMから完全に削除される
- 元のLocator参照が無効になるため、`hidden`や`detached`では確認できない
- URL遷移やネットワーク完了で間接的に確認するのが安定

**代替パターン（クリーンアップ時）**：
削除処理自体が目的の場合（クリーンアップ等）、厳密な確認は省略可能：
```typescript
await this.confirmDeleteButton.click();
// 削除処理のレスポンスを待つ（短いタイムアウトで十分）
await this.page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {
  console.log('削除完了: networkidle待機タイムアウト（処理は完了済み）');
});
```

---

## § 7. パターン改善ログ

### 2026-02-02
- 確認ダイアログの待機パターンを追加
- 削除後のリスト変化確認パターンを追加

### 2025-11-06
- 初版作成
- test2, test（セレクタ定義）, test5の成功パターンを記録

---

**最終更新**: 2026-02-02  
**管理者**: Ray Ishida
