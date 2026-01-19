# CLAUDE_FAQ.md - トラブルシューティング・Q&A

**最終更新**: 2026-01-13

---

## 📘 このドキュメントについて

このドキュメントは、**このプロジェクトでよく発生する問題と解決策**を記録します。

### 役割
- よくあるエラーと解決策
- エラーメッセージ別対処法
- レビューでよく指摘される問題
- FAQ

### 成長するドキュメント
- 新しいエラーが発生したら、§ 1 または § 2 に追記してください
- 定期的に類似エラーを統合・整理します

---

## § 1. よくあるエラーと解決策

### 1.1 セマンティックロケータで要素が見つからない（意味層の薄い要素）

#### エラーメッセージ
```
Error: locator.check: Target page, context or browser has been closed
Error: locator.click: Timeout 30000ms exceeded
```

#### 曖昧さに起因した問題
**人間の指示**: 「同意チェックボックスをチェックして」
**AIの解釈**: `page.getByRole('checkbox', { name: '同意する' })`
**問題**: チェックボックスに`aria-label`や関連付けられた`label`要素がない（意味層が薄い）

#### 原因
- **意味層の薄い要素**では、`aria-label`、`label`等の属性が不足している
- 特に：ラベルのないチェックボックス、アイコンのみのボタンなど
- **ただし**、モーダル、テキスト付きボタン、placeholder付き入力欄などの**意味層が厚い要素**ではセマンティックロケータが使用可能

#### 解決策
**意味層の薄い要素** → CSSセレクタ + `:near()` または `svg[data-icon]` を使用

```typescript
// ❌ 動作しない（意味層が薄い要素）
page.getByRole('checkbox', { name: '同意する' })
page.getByLabel('同意する')

// ✅ 動作する：:near() セレクタ
page.locator('input[type="checkbox"]:near(:text("同意する"))')

// ✅ 動作する：定数から読み込み
import { SELECTORS } from '../config/constants';
page.locator(SELECTORS.AGREEMENT_CHECKBOX)
```

**意味層が厚い要素** → セマンティックロケータ使用可能

```typescript
// ✅ 動作する：モーダル
page.getByRole('dialog', { name: 'テキストを追加' })

// ✅ 動作する：テキスト付きボタン
page.getByRole('button', { name: '保存' })

// ✅ 動作する：placeholder付き入力欄
page.getByPlaceholder('検索')
```

#### 参考
- [CLAUDE_Selectors.md § 1](./CLAUDE_Selectors.md) - セレクタ戦略
- [locator_strategy.md](./LOCATOR/locator_strategy.md) - 意味層の厚さ判断基準

---

### 1.2 外部認証（Auth0等）ログインで要素が見つからない

#### エラーメッセージ
```
Error: locator.fill: Target closed
Error: locator.fill: Target page, context or browser has been closed
```

#### 曖昧さに起因した問題
**人間の指示**: 「ログインボタンをクリックして、メールアドレスとパスワードを入力」  
**AIの解釈**: `clickEmailLogin()` → すぐに `fillEmail()`  
**問題**: Auth0への遷移を待たずにフォーム入力を試みている

#### 原因
- Auth0への遷移を待たずにフォーム入力を試みている
- 外部ドメインへの遷移は、通常のページ遷移より時間がかかる

#### 解決策
URL遷移を明示的に待つ

```typescript
import { TIMEOUTS } from '../config/constants';

// ❌ 悪い例
await this.termsPage.clickEmailLogin();
await this.auth0LoginPage.fillEmail(email); // エラー！

// ✅ 良い例
await this.termsPage.clickEmailLogin();

// Auth0への遷移を待つ（重要！）
await this.page.waitForURL('**/auth.example.com/**', { 
  timeout: TIMEOUTS.DEFAULT 
});
// 画面安定化を待つ
await this.page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);

// その後フォーム入力
await this.auth0LoginPage.fillEmail(email);
```

#### 参考
- [locator_rules_product_specific_part2.md § 2.4](./LOCATOR/productspecific/PRODUCT_A/locator_rules_product_specific_part2.md) - Auth0外部認証フロー

---

### 1.3 モーダル内のボタンがクリックできない

#### エラーメッセージ
```
Error: locator.click: Element is not visible
Error: locator.click: Element is outside of the viewport
```

#### 曖昧さに起因した問題
**人間の指示**: 「モーダルの保存ボタンをクリック」  
**AIの解釈**: モーダル表示を待って、すぐに `button.click()`  
**問題**: モーダルのアニメーション中にクリックを試みている

#### 原因
- モーダルのフェードインアニメーション中にクリックを試みている
- 要素は存在するが、まだクリック可能な状態ではない

#### 解決策
モーダルの表示を待ち、アニメーション完了を待つ

```typescript
import { TIMEOUTS, SELECTORS } from '../config/constants';

// ❌ 悪い例
const button = page.locator('[role="dialog"] button:has-text("保存")');
await button.click(); // エラー！

// ✅ 良い例
// Step 1: モーダル表示を待つ
await page.locator(SELECTORS.MODAL).waitFor({ 
  state: 'visible', 
  timeout: TIMEOUTS.SHORT 
});

// Step 2: アニメーション完了を待つ
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);

// Step 3: 要素をスクロールしてクリック
const button = page.locator('[role="dialog"] button:has-text("保存")');
await button.scrollIntoViewIfNeeded();
await button.click({ force: true });
```

#### 参考
- [CLAUDE_Selectors.md § 4.3](./CLAUDE_Selectors.md) - モーダル処理パターン

---

### 1.4 ネットワーク完了後も要素が見つからない

#### エラーメッセージ
```
Error: locator.click: Timeout 30000ms exceeded
Error: locator.isVisible: Timeout 30000ms exceeded
```

#### 未定義条件による問題
**人間の指示**: 「ページ遷移後、要素をクリック」  
**AIの解釈**: `waitForLoadState('networkidle')` → すぐに `element.click()`  
**問題**: SPAのレンダリング完了を待っていない

#### 原因
- このプロジェクトはReact SPAで構築されている
- `networkidle`の後にReactのレンダリングがある
- ネットワーク完了 ≠ レンダリング完了

#### 解決策
networkidle + waitForTimeout を組み合わせる

```typescript
import { TIMEOUTS } from '../config/constants';

// ❌ 不十分
await page.waitForLoadState('networkidle');
await element.click(); // 要素がまだ存在しない可能性

// ✅ 良い例
await page.waitForLoadState('networkidle');
// SPAのレンダリング完了を待つ
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
await element.click();
```

#### 参考
- [CLAUDE.md § 待機処理ルール](./CLAUDE.md) - 待機処理パターン

---

### 1.5 .first() が危険だと警告される

#### 質問
`.first()` を使うのは安全？

#### 回答
**いいえ、できるだけ避けるべきです。**

#### 危険な理由
- ❌ 一度テストがPassすると、誰も修正しない（技術的負債化）
- ❌ UI変更時に突然失敗し、デバッグが困難
- ❌ 保守性が著しく低下し、将来の変更コストが増大

#### 推奨対策（優先順位順）
1. **最優先**: 開発チームにdata-testid属性の追加を依頼
2. **次善策**: `:near()` セレクタで周辺要素から特定
3. **妥協策**: 親要素で十分に絞り込んでから`.first()`
4. **最終手段**: `.first()` + 詳細コメント + TODOでリファクタリング計画

```typescript
// ❌ 危険：絞り込みなし
page.locator('input[type="checkbox"]').first()

// ❌ 危険：コメントなし
page.locator('[role="dialog"] input[type="checkbox"]').first()

// ✅ 安全：親要素で絞り込み + コメント
// このダイアログには1つのチェックボックスのみ存在
// TODO: data-testid="terms-checkbox" の追加を依頼（Issue #123）
page.locator('[role="dialog"] input[type="checkbox"]').first()

// ✅ より安全：近接セレクタ（.first()不要）
page.locator('input[type="checkbox"]:near(:text("同意する"))')
```

#### 参考
- [CLAUDE_Selectors.md § 3](./CLAUDE_Selectors.md) - .first() 使用ルール

---

### 1.6 3点リーダーボタン（...）が見つからない

#### エラーメッセージ
```
Error: locator.click: Timeout 30000ms exceeded.
Call log:
  - waiting for locator('button[aria-label="more"]').first()
```

#### 曖昧さに起因した問題
**人間の指示**: 「3点リーダー（...）ボタンをクリック」  
**AIの解釈**: `page.locator('button[aria-label="more"]')`  
**問題**: 3点リーダーボタンには`aria-label`やテキストがない

#### 原因
- 3点リーダーボタンには`aria-label`やテキストがなく、SVGアイコンのみで構成されている
- Ant DesignのSVGアイコンには`data-icon`属性がある

#### 解決策
SVGアイコンの`data-icon`属性を使ってフィルタリング

```typescript
// ❌ 動作しない：aria-labelが存在しない
page.locator('button[aria-label="more"]')

// ❌ 動作しない：テキストがない
page.locator('button:has-text("...")')

// ✅ 動作する：Ellipsisアイコンを含むボタンをフィルタリング
page.getByRole('button').filter({ 
  has: page.locator('svg[data-icon="ellipsis"]') 
})
```

#### 応用：他のアイコンボタン
```typescript
// Editアイコンボタン
page.getByRole('button').filter({ has: page.locator('svg[data-icon="edit"]') })

// Deleteアイコンボタン
page.getByRole('button').filter({ has: page.locator('svg[data-icon="delete"]') })

// Closeアイコンボタン
page.getByRole('button').filter({ has: page.locator('svg[data-icon="close"]') })
```

#### 参考
- [CLAUDE_Selectors.md § 4.2](./CLAUDE_Selectors.md) - SVGアイコンボタンパターン

---

## § 2. エラーメッセージ別対処法

### 2.1 Target closed / Target page, context or browser has been closed

**原因の候補**:
1. Auth0への遷移を待たずにフォーム入力（§ 1.2）
2. 意味層の薄い要素にセマンティックロケータを使用（§ 1.1）
3. ページ遷移中に操作を試みている

**対処法**:
- `waitForURL()` でURL遷移を明示的に待つ
- 意味層の薄い要素には`:near()`や`svg[data-icon]`を使用
- `waitForLoadState('networkidle')` を追加

### 2.2 Timeout exceeded

**原因の候補**:
1. SPAのレンダリング待機不足（§ 1.4）
2. モーダルのアニメーション待機不足（§ 1.3）
3. セレクタが間違っている
4. ネットワークが遅い

**対処法**:
- `networkidle` + `waitForTimeout()` を併用
- タイムアウト値を延長（`TIMEOUTS.LONG`を使用）
- セレクタを確認（`page.pause()`でデバッグ）

### 2.3 Element is not visible / Element is outside of the viewport

**原因の候補**:
1. モーダルのアニメーション中にクリック（§ 1.3）
2. 要素がスクロール範囲外にある
3. 要素が`display: none`または`visibility: hidden`

**対処法**:
- `scrollIntoViewIfNeeded()` を使用
- `click({ force: true })` を使用
- モーダルのアニメーション完了を待つ

### 2.4 strict mode violation

**原因**:
- セレクタが複数要素にマッチしている
- `:has-text()` が部分一致のため、複数マッチしている可能性

**対処法**:
```typescript
// ❌ 部分一致で複数マッチ
page.locator('span:has-text("ログイン")') // "ログイン", "ログインする", "再ログイン"

// ✅ 完全一致
page.locator('span:text-is("ログイン")') // "ログイン"のみ

// ✅ 親要素で絞り込み
page.locator('[role="dialog"] span:has-text("ログイン")')

// ✅ より具体的なセレクタ
page.locator('button:has-text("ログイン")')
```

---

## § 3. レビューでよく指摘される問題

### 3.1 タイムアウト値のハードコード

**違反例**:
```typescript
await page.waitForTimeout(2000);
await element.waitFor({ state: 'visible', timeout: 10000 });
```

**正しい実装**:
```typescript
import { TIMEOUTS } from '../config/constants';
await page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);
await element.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
```

**🚨 特に注意：コード修正・追加時の落とし穴**

**よくある原因**:
- ❌ エラー修正時に「とりあえず動かす」ために数値を直接書いた
- ❌ 新機能追加時に`constants.ts`を確認せずに数値を書いた
- ❌ 既存コードのコピー&ペーストで定数インポートを忘れた

**修正手順**:

1. **constants.tsに該当する定数があるか確認**
   ```typescript
   // src/config/constants.ts を確認
   export const TIMEOUTS = {
     DEFAULT: 10000,
     LONG: 30000,
     SPA_RENDERING: 2000,
     // ...
   }
   ```

2. **なければ定数を追加**
   ```typescript
   // 例: ブラウザを開いたまま待機する定数が必要
   export const TIMEOUTS = {
     // ... 既存の定数 ...
     KEEP_BROWSER_OPEN: 300000,   // 新規追加
   }
   ```

3. **使用箇所でインポートして使用**
   ```typescript
   import { TIMEOUTS } from '../config/constants';

   // ❌ 修正前
   await page.waitForTimeout(300000);

   // ✅ 修正後
   await page.waitForTimeout(TIMEOUTS.KEEP_BROWSER_OPEN);
   ```

**実例（2025-11-06に発見）**:
- **発見場所**: `CreateCourseAction.ts:74` と `courseManagement.spec.ts:65`
- **問題**: `2000` と `300000` がハードコード
- **修正内容**:
  1. `constants.ts`に `KEEP_BROWSER_OPEN: 300000` を追加
  2. 両ファイルで `import { TIMEOUTS }` を追加
  3. `2000` → `TIMEOUTS.SPA_RENDERING`
  4. `300000` → `TIMEOUTS.KEEP_BROWSER_OPEN`

**参考**: [CLAUDE.md § 2.2](./CLAUDE.md) - 定数管理ルール、[E2ETest_Framework.md § 6.2](./E2ETest_Framework.md) - 定数管理

---

### 3.2 認証情報のハードコード

**違反例**:
```typescript
const email = 'test@example.com';
const password = 'password123';
```

**正しい実装**:
```typescript
const env = EnvConfig.getTestEnvironment();
const email = env.credentials.email;
const password = env.credentials.password;
```

**参考**: [CLAUDE.md § 1](./CLAUDE.md) - セキュリティルール

---

### 3.3 共通セレクタのハードコード

**違反例**:
```typescript
const modal = page.locator('[role="dialog"]');
const submitButton = page.locator('button[type="submit"]');
```

**正しい実装**:
```typescript
import { SELECTORS } from '../config/constants';
const modal = page.locator(SELECTORS.MODAL);
const submitButton = page.locator(SELECTORS.SUBMIT_BUTTON);
```

**参考**: [CLAUDE.md § 2](./CLAUDE.md) - 定数管理ルール

---

### 3.4 .first() 使用時のコメント不足

**違反例**:
```typescript
page.locator('input[type="checkbox"]').first(); // コメントなし
```

**正しい実装**:
```typescript
// このダイアログには1つのチェックボックスのみ存在することを確認済み
// TODO: data-testid="confirm-checkbox" の追加を依頼（Issue #123）
page.locator('[role="dialog"] input[type="checkbox"]').first();
```

**参考**: [CLAUDE_Selectors.md § 3](./CLAUDE_Selectors.md) - .first() 使用ルール

---

### 3.5 waitForTimeout 使用時のコメント不足

**違反例**:
```typescript
await page.waitForTimeout(2000); // コメントなし、定数未使用
```

**正しい実装**:
```typescript
import { TIMEOUTS } from '../config/constants';
// Auth0画面の描画完了を待つ（networkidleだけでは不十分）
await page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);
```

**参考**: [CLAUDE.md § 待機処理ルール](./CLAUDE.md) - 待機処理パターン

---

### 3.6 セマンティックロケータの使用（意味層に応じて判断）

**セマンティックロケータは「意味層の厚さ」に応じて使い分けます。**

#### 意味層が薄い要素（❌ セマンティックロケータ不可）

**違反例**:
```typescript
// ❌ ラベルのないチェックボックス
page.getByRole('checkbox', { name: '同意する' });
page.getByLabel('同意する');

// ❌ アイコンのみのボタン
page.getByRole('button', { name: '編集' });
```

**正しい実装**:
```typescript
// ✅ :near() セレクタ
page.locator('input[type="checkbox"]:near(:text("同意する"))');

// ✅ svg[data-icon] でアイコンボタン
page.locator('button:has(svg[data-icon="edit"])');

// ✅ 定数から読み込み
import { SELECTORS } from '../config/constants';
page.locator(SELECTORS.AGREEMENT_CHECKBOX);
```

#### 意味層が厚い要素（✅ セマンティックロケータ使用可能）

```typescript
// ✅ モーダル
page.getByRole('dialog', { name: 'テキストを追加' });

// ✅ テキスト付きボタン
page.getByRole('button', { name: '保存' });

// ✅ placeholder付き入力欄
page.getByPlaceholder('検索');
```

**参考**: [CLAUDE_Selectors.md § 1](./CLAUDE_Selectors.md) - セレクタ戦略、[locator_strategy.md](./LOCATOR/locator_strategy.md)

---

## § 4. FAQ（よくある質問）

### Q1: E2ETest_Framework.mdとCLAUDE.mdの違いは？

**A**: 
- **E2ETest_Framework.md**: 全プロジェクト共通の理想的なベストプラクティス
- **CLAUDE.md**: このプロジェクト固有の実装パターンと調整事項

矛盾する場合は、CLAUDE.mdを優先します。

---

### Q2: data-testid属性がない場合はどうすれば？

**A**: 
CSSセレクタ + `:has-text()` または `:near()` を使用してください。  
CLAUDE.mdに明記することで、AIが正しいコードを生成できます。

**参考**: [CLAUDE_Selectors.md § 1](./CLAUDE_Selectors.md)

---

### Q3: waitForTimeoutは使用してはいけない？

**A**: 
いいえ。SPAのアニメーション待機や外部認証の画面描画待機では必要です。  
ただし、必ずコメントで理由を明記し、`TIMEOUTS`定数を使用してください。

**参考**: [CLAUDE.md § 待機処理ルール](./CLAUDE.md)

---

### Q4: 外部認証（Auth0など）のテストはどう書く？

**A**: 
Page Objectsを分離し、URL遷移待機を明示的に行ってください。

**参考**: [locator_rules_product_specific_part2.md § 2.4](./LOCATOR/productspecific/PRODUCT_A/locator_rules_product_specific_part2.md)

---

### Q5: .first()の使用は危険？

**A**: 
はい、できるだけ避けるべきです。

**理由**:
- 一度テストがPassすると、誰も修正しない（技術的負債化）
- UI変更時に突然失敗し、原因特定が困難
- 保守性が著しく低下

**推奨対応**: § 1.5 を参照

---

### Q6: 複数のドキュメントがあって混乱する

**A**:
以下の順番で参照してください：

1. **CLAUDE.md** - まずはここを読む（プロジェクト概要と必須ルール）
2. **CLAUDE_Selectors.md** - セレクタで困ったとき
3. **CLAUDE_FAQ.md（このファイル）** - エラーで困ったとき
4. **E2ETest_Framework.md** - アーキテクチャの詳細を知りたいとき
5. **LOCATOR/** - Locator戦略の詳細ドキュメント

---

### Q7: 「意味層の厚さ」とは？ {#semantic-layer-thickness}

**A**:
HTML要素がセマンティック情報（意味的な識別子）をどの程度持っているかを示す概念です。

#### 意味層が厚い要素（セマンティックロケータ使用可能）

| 要素タイプ | 理由 | 使用するLocator |
|-----------|------|-----------------|
| モーダル/ダイアログ | `role="dialog"` + タイトルで一意に特定可能 | `getByRole('dialog', { name: '...' })` |
| テキスト付きボタン | ボタンテキストで一意に特定可能 | `getByRole('button', { name: '...' })` |
| placeholder付き入力欄 | placeholderで一意に特定可能 | `getByPlaceholder('...')` |

#### 意味層が薄い要素（セマンティックロケータ使用不可）

| 要素タイプ | 理由 | 代替Locator |
|-----------|------|------------|
| ラベルのないチェックボックス | `aria-label`/`label`要素がない | `:near()` セレクタ |
| アイコンのみのボタン | テキストがない、`aria-label`がない | `svg[data-icon]` |
| 汎用的なclass名のみの要素 | 意味的なアンカーがない | 親要素で絞り込み |

**このプロジェクトでは**:
- `data-testid` がほぼ存在しない
- 一部の要素で `aria-label`、`label` が不足
- **要素ごとに意味層の厚さを判断して適切なLocatorを選択する**

**対処法**:
1. **意味層が厚い要素** → セマンティックロケータを優先使用
2. **意味層が薄い要素** → `:near()` セレクタや `svg[data-icon]` を使用
3. **両方の場合** → 親要素でスコープを絞る（Local Universe）

**参考**: [CLAUDE_Selectors.md § 1](./CLAUDE_Selectors.md)、[locator_strategy.md](./LOCATOR/locator_strategy.md)

---

## § 5. 新エラー追記エリア

**使い方**:
1. 新しいエラーが発生したら、ここに追記してください
2. 以下の形式で記録してください：
   - 日付
   - エラーメッセージ
   - 発生状況
   - 原因分析
   - 解決策

### 📝 テンプレート

```markdown
### 新エラーX: [エラー概要]

**日付**: YYYY-MM-DD

**エラーメッセージ**:
```
[エラーメッセージ]
```

**発生状況**: [どのような状況で発生したか]
**原因分析**: [原因は何か]
**解決策**: [どう解決したか]

**コード例**:
```typescript
// 解決策のコード
```
```

---

### 新エラー追記欄（ここから下に追記）

<!-- 新しいエラーをここに追記してください -->

---

## 📊 定期的な整理（月次/四半期）

### 整理ログ

#### 2025-11 棚卸し
**追加されたエラー**:
- （初版のため追加なし）

**統合したエラー**:
- （初版のため統合なし）

**削除したエラー**:
- （初版のため削除なし）

**ファイルサイズ**: 300行

---

## License

MIT License

---

**最終更新**: 2026-01-13  
**管理者**: QA Team
