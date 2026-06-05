---
name: e2e-review
description: "E2Eコードレビュー用。PR確認・品質チェック時に使用。MUST FIX/SHOULD FIXチェックリスト・エラーメッセージ別対処法・.catch隠蔽問題の検出方法・FAQを含む。禁止事項の詳細は .claude/rules/prohibited-patterns.md を参照。"
---

# E2E Code Review Skill

> 禁止事項・4層責務・Locator原則は rules/（常時読み込み済み）。
> このSkillは**レビュー手順とチェックリスト**に特化。

## §1. レビュー手順

1. **§2.0 構文ゲートのコマンドを実行し、出力を確認する**（読むだけのチェックより先。機械的に落とせるデブリを最初に潰す）
2. §2のMUST FIXチェックリストを上から確認
3. §3のSHOULD FIX確認
4. **§8 self-interrogation を作成者自身に自己申告させる**（grep で拾えないデブリ — 未使用追加物・PR本文との乖離・新規 `@deprecated`）
5. Locator具体指摘が必要なら `/e2e-locator` Skill参照
6. 指摘は「理由」+「正しい実装例」をセットで

> **なぜコマンドを先に回すのか**: 「読むだけ」のルールは注意の希釈で素通りする（自己レビュー1往復を通過した後でも tsc エラー・Action 直書き Locator・未使用 export が master 直前まで残る事例が起きる）。grep / コマンドで落とせるものは人間の目視に頼らず機械で落とす。

---

## §2. MUST FIX（PR差し戻し基準）

### §2.0 構文ゲート（コマンドで機械的に落とす — 最優先）

> 以下は**必ず実行して出力を確認する**。チェックボックスを目視で埋めるのではなく、コマンドの結果で判定する。
> 複数プロジェクトを含むワークスペースでは、対象プロジェクトのディレクトリに `cd` してから実行する。

```bash
# 1. 型チェック — exit 0 でなければ差し戻し
#    （未使用変数・未使用 import・未使用パラメータ・型エラーを拾う。tsconfig は noUnusedLocals/noUnusedParameters 有効）
npx tsc --noEmit; echo "exit: $?"

# 2. Action 層への Locator 直書き検出（4層境界違反）— ヒットは全て違反
#    Locator は Page Object 層にだけ存在してよい（rules/architecture.md「pages/ = Locatorはここだけ」）。
#    レシーバを問わず .locator( / .getBy*( を拾う（this.page 限定にすると複数行記法・別レシーバ経由を取りこぼす）。
grep -rnE "\.(locator|getByRole|getByText|getByLabel|getByPlaceholder|getByTestId|getByTitle|getByAltText)\(" src/actions/

# 3. .catch 隠蔽パターン（詳細は §4）
grep -rn "\.catch(() => false)\|\.catch(() => true)" src/
```

- [ ] `npx tsc --noEmit` が **exit 0**（未使用 import/変数/パラメータ・型エラー ゼロ。tsc は bootstrap の DoD だけでなくレビューでも回す — テストが green でも tsc が落ちることがある）
- [ ] Action 層に Locator 直書きが **0 件**（ヒットしたら Page Object に移し、Action はメソッド経由で呼ぶ）
  - **新規追加は当然不可**。既存ヒット（負債）も**例外なく違反**として扱う — 「既存だから OK」を許すと AI が既存コードを模倣して同じ違反を再生産するため（AI 先行模倣性）。定数経由（`SELECTORS.MODAL` 等）や `getByRole(...)` のセマンティックなものも、Locator が Action にある時点で違反
  - **grep はレシーバを問わず `.locator(` / `.getBy*(` を拾う形にする**。`this.page.` 限定にすると ①`this.page` と `.locator` が別行の複数行記法、②`modal.locator(...)` のような別レシーバ経由、を取りこぼし実際の違反の一部しか検出できない（= 目視より悪い偽の安心を生む）。PO から受け取った Locator への `.click()`/`.nth()` 等は `.locator(`/`.getBy(` を含まないので誤検出しない
  - 既存負債の一括解消は別途追跡。それまでの間にヒットが残っていても「既存だから残してよい」とは判断しない
- [ ] `.catch(() => false)` / `.catch(() => true)` が 5 箇所以上ないか（§4参照）

> 未使用 **export**（どのテストからも呼ばれないメソッド・PO クラス）は tsc では拾えない（`noUnusedLocals` はローカル変数/import まで）。これは §8 self-interrogation で作成者に自己申告させる。

### セキュリティ
- [ ] 認証情報がハードコードされていない
- [ ] `.env`が`.gitignore`に含まれている

### 定数管理
- [ ] `TIMEOUTS`・`SELECTORS`・`URL_PATTERNS`をconstants.tsからインポート
- [ ] タイムアウト数値・URLパターン・共通セレクタが直書きされていない

### Locator
- [ ] `text=` ロケータ未使用
- [ ] 優先順位に従っている（rules参照）
- [ ] 構造依存セレクタを避けている
- [ ] data-testidがある要素ではdata-testidを使用している
- [ ] 意味層の薄い要素に `:near()` / `svg[data-icon]` を使用

### 4層責務
- [ ] Page Object: `readonly`（`private readonly`禁止）、expect 未使用
- [ ] **Page Object verify メソッド（boolean を返す状態確認）内に `waitForTimeout` を置いていないか** — 待機は操作メソッド（void）側に集約。verify 内固定待機は判定の正しさが待ち時間に賭かる + 二重待機の温床（`prohibited-patterns.md`「verify 内の固定待機 — 待機は操作メソッドに集約」参照）
- [ ] Action: 各ステップ`this.step()`でログ記録（`console.log`単体は禁止）、expect未使用、**Locator 直書きなし（§2.0 で grep 検出）**、LoginAction はログイン成功検証あり
- [ ] Fixture: `stepCounter` が worker スコープで定義されている（`scope: 'worker'`）
- [ ] Test: Fixture経由import、Fixture引数でAction取得、Locator直書きなし
- [ ] 新規Action → Fixtureに登録済み、かつ TODO → 実装済みセクションに昇格済み

### エラーハンドリング
- [ ] `.catch(() => false)` パターン未使用（§4参照）

### テスト条件の黙殺
- [ ] テストが明示的に要求した操作（引数・パラメータで指定）が見つからない場合に Fail するか（スキップして Pass は偽陽性）

---

## §3. SHOULD FIX

- [ ] `.first()` にコメント + TODO
- [ ] `waitForTimeout` に理由コメント + TIMEOUTS定数
- [ ] `:has-text()` → `:text-is()`（完全一致）を検討したか
- [ ] Local Universe（親要素絞り込み）活用
- [ ] AAAパターン、結果検証、データクリーンアップ
- [ ] テスト名が具体的か
- [ ] `.spec.ts` にテスト手順ヘッダーコメントがあるか（Phase・手順番号・検証ポイント）
- [ ] 各 Phase に `[Arrange]` / `[Act]` / `[Cleanup]` タグが付いているか（データ準備とテスト本体の区別）
- [ ] `this.step()` を使う public メソッドに `this.beginAction()` があるか（ステップ番号付与）

---

## §4. `.catch(() => false)` 検出と修正

**検出**:
```bash
grep -rn ".catch(() => false)" src/
grep -rn ".catch(() => true)" src/
```
5箇所以上 → AIコピペを強く疑う。

**修正**:
```typescript
// ❌
const isVisible = await element.isVisible({ timeout: 5000 }).catch(() => false);

// ✅
try {
  await expect(element).toBeVisible({ timeout: TIMEOUTS.CHECK });
  await element.click();
} catch {
  // Optional element, skip
}
```

---

## §5. エラーメッセージ別対処

### `Target page, context or browser has been closed`
**原因**: URL遷移未待機（外部認証遷移時に多発）
```typescript
await this.page.waitForURL(URL_PATTERNS.AUTH_LOGIN, { timeout: TIMEOUTS.DEFAULT });
await this.page.waitForTimeout(TIMEOUTS.AUTH_STABILIZATION);
```

### `Timeout exceeded`
**原因**: SPA描画待機不足 / モーダルアニメーション / セレクタ誤り
```typescript
await page.waitForLoadState('networkidle');
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
```

### `Element is not visible / outside of the viewport`
```typescript
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
await button.scrollIntoViewIfNeeded();
await button.click({ force: true });
```

### `strict mode violation`
**原因**: `:has-text()`部分一致で複数マッチ
```typescript
page.locator('span:text-is("ログイン")')                    // 完全一致
page.locator('[role="dialog"] span:has-text("ログイン")')    // スコープ絞り
```

---

## §6. FAQ

**Q: Action層でwaitFor()は使える？**
はい。waitFor()は待機操作でアサーションではない。禁止はexpect()のみ。

**Q: 意味層の厚さとは？**
要素のセマンティック情報の充実度。厚い（data-testidあり、ラベル付きフォーム、テキストボタン）→セマンティックLocator可。薄い（ラベルなしチェックボックス、アイコンのみボタン）→`:near()`/data属性。プロジェクト導入時にUI全体の意味層の厚さを評価すること。

**Q: waitForTimeoutは使っていい？**
はい。SPA/外部認証/モーダルでは必要。TIMEOUTS定数+理由コメントが条件。

**Q: `.first()`は常にダメ？**
できる限り避ける。使う場合: 親要素で絞り込み + 理由コメント + TODO。

**Q: 既存コードがルール違反していたら？**
コピーせず正しいパターンで実装。可能なら既存も修正。

---

## §7. テスト結果報告プロトコル（Pass 判定の検証）

テスト結果を「Pass」と報告する前に、テストランナーが**正常終了したこと**を必ず確認する。途中ログに `✓` が出ていても、ランナーが正常終了していなければ結果は **未確定**。

### 確認すべき 3 点

1. **プロセスの終了コード**: `npx playwright test ...; echo $?` で確認。`0` 以外（例: `1`, `144`）は失敗または異常終了
2. **最終サマリー行**: 標準出力の末尾に `N passed (Mm)` のサマリーが出力されていること
3. **report.json の完全性**: `test-results/report.json` が存在し、`stats.unexpected === 0` かつ JSON として完結していること

```bash
# ✅ 正常終了の確認例
npx playwright test ... 2>&1 | tail -3
# →  1 passed (1.9m)        ← サマリーが出ている

cat test-results/report.json | jq '.stats'
# → { "expected": N, "unexpected": 0, ... }
```

### 偽陽性（Pass と誤報告）が起きやすいケース

| 状況 | 何が起きるか | 正しい報告 |
|------|------------|----------|
| ブラウザクラッシュ（exit code 144 等） | 途中まで `✓` 出力されているがサマリーなし | 「結果未確定、再実行が必要」 |
| `report.json` が JSON 不完全 / 切れている | プロセス強制終了で書き込み中断 | 「結果未確定」 |
| Ctrl+C 等で中断 | 途中まで完走しているように見える | 「中断された、結果不明」 |
| timeout で kill | 個別 test は ✓ でも全体は failed | サマリー行を見て判定 |

**ルール**: 上記いずれかが疑われる場合は「Pass」と報告せず、**再実行を提案**する。ユーザーに「全テスト合格」と伝えて良いのは、3 点の確認が揃ったときのみ。

---

## §8. self-interrogation（PR 化前の自己申告 — grep で拾えないデブリ）

§2.0 のコマンドは構文・境界デブリを機械的に落とす。だが **「呼ばれない追加物」「PR本文と diff の乖離」「不要な互換コード」は grep では拾えない**。作成者自身（AI 含む）に PR 化前に以下を**明文で自己申告**させる。「無い」で済ませず、列挙して各々に理由を添える。

### Q1. 未使用の追加物を全列挙し、各々の「残す理由」を述べよ

本 PR で**追加**した次のうち、**どのテストからも呼ばれていないもの**を全て列挙する。各々について「将来のテストで使う予定（どのテストか明記）」か「今すぐ削除すべき」かを判断する。

- 追加した public メソッド（Action / Page Object）
- 追加した Page Object クラス・ファイル
- 追加した env キー・constants の定数
- 追加した関数引数・オプション

> 「将来使うかも」で残すなら **どのテストでいつ使うか**を書く。書けないものは dead code として削除する。

```bash
# 補助: 追加した export 名が src/ 内で他から参照されているか確認する例
#   定義行を除いて 0 件なら未使用の疑い
grep -rn "SomeMethodName\|SomePageClass" src/   # ← 定義ファイルのヒットは除いて数える
```

### Q2. PR本文と `git diff --name-only` を突き合わせ、食い違いを指摘せよ

```bash
git diff --name-only main...HEAD
```

- PR本文が言及している変更（「○○を追加」等）が **実際に diff に存在するか**
- diff にあるのに本文で説明されていない変更がないか
- **存在しないテスト・機能を主張していないか**

### Q3. 本 PR で新規追加した `@deprecated` がないか確認せよ

```bash
git diff main...HEAD | grep -n "@deprecated"
```

- `@deprecated` は「既存の利用者がいるから消せない」ものに付ける互換マーカー。
- **本 PR で新規に追加したコードに `@deprecated` が付いていたら矛盾**（新規＝互換対象となる既存利用者がいない）→ そのコードは最初から不要なので削除する。
- 既存コードの `@deprecated`（前の PR で付いたもの）はこの限りではない。
