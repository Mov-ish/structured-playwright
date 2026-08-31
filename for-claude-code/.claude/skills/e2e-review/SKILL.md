---
name: e2e-review
description: "E2Eコードレビュー用。PR確認・品質チェック時に使用。MUST FIX/SHOULD FIXチェックリスト・エラーメッセージ別対処法・.catch隠蔽問題の検出方法・FAQを含む。禁止事項の詳細は .claude/rules/prohibited-patterns.md を参照。"
---

# E2E Code Review Skill

> 禁止事項・4層責務・Locator原則は rules/（常時読み込み済み）。
> このSkillは**レビュー手順とチェックリスト**に特化。

## §1. レビュー手順

1. **§2.0 機械ゲート（`npm run gate`）を実行し、出力を確認する**（読むだけのチェックより先。機械的に落とせるデブリを最初に潰す）
2. §2のMUST FIXチェックリストを上から確認
3. §3のSHOULD FIX確認
4. **§8 self-interrogation を作成者自身に自己申告させる**（grep で拾えないデブリ — 未使用追加物・PR本文との乖離・新規 `@deprecated`）
5. Locator具体指摘が必要なら `/e2e-locator` Skill参照
6. 指摘は「理由」+「正しい実装例」をセットで

> **なぜコマンドを先に回すのか**: 「読むだけ」のルールは注意の希釈で素通りする（自己レビュー1往復を通過した後でも tsc エラー・Action 直書き Locator・未使用 export が master 直前まで残る事例が起きる）。grep / コマンドで落とせるものは人間の目視に頼らず機械で落とす。

> **再レビュー時のフレッシュスキャン原則**: 複数ラウンドのレビューでは「前ラウンドで指摘した箇所が直っているか」の確認に集中しがちになり、Round 1 で見逃したものはその後も発見されにくい。再レビュー時は前ラウンドのコメントを参照せず、**diff を最初から通読する**。修正コードに混入した新たな問題も「対応内容に問題なし」と素通りしやすいため、変更箇所の周辺コードも含めて新鮮な目でチェックする。

---

## §2. MUST FIX（PR差し戻し基準）

### §2.0 機械ゲート（コマンドで機械的に落とす — 最優先）

> **必ず実行して出力を確認する**。チェックボックスを目視で埋めるのではなく、コマンドの結果で判定する。
> 複数プロジェクトを含むワークスペースでは、対象プロジェクトのディレクトリに `cd` してから実行する。

```bash
npm run gate; echo "exit: $?"
```

検出ロジックの**正本は `scripts/gate.sh`**（CI でも PR ごとに同一判定が走る）。
カバー範囲: tsc 型チェック / Action・Test 層 Locator 直書き / `.catch` 隠蔽 / `text=` / XPath /
`private readonly` / Fixture 未経由 import / Test 内 `new Action` / Action 層 `expect` /
タイムアウト・URL ハードコード / `Date.now()` 一意名 / MODAL ハイブリッド / 未定義タグ /
ordinal・waitForTimeout・expect 部分一致の理由コメントなし / describe 内 configure /
verify 内 waitForTimeout（AST）/ 数値定数の宣言元コメントなし / メタ層（Rules 総量ラチェット・
Skill 間参照・SKILL.md サイズ）+ ⚠️ 警告（Page Object waitForTimeout の目視補完等）。

`npm run gate` がない場合は以下を個別に実行する:

```bash
# 1. 型チェック — exit 0 でなければ差し戻し
#    （未使用変数・未使用 import・未使用パラメータ・型エラーを拾う。tsconfig は noUnusedLocals/noUnusedParameters 有効）
npx tsc --noEmit; echo "exit: $?"

# 2. Action 層への Locator 直書き検出（4層境界違反）— ヒットは全て違反
#    Locator は Page Object 層にだけ存在してよい（rules/architecture.md「pages/ = Locatorはここだけ」）。
#    レシーバを問わず .locator( / .getBy*( を拾う（this.page 限定にすると複数行記法・別レシーバ経由を取りこぼす）。
grep -rnE "\.(locator|getBy[A-Za-z]+)\(" src/actions/

# 3. .catch 隠蔽パターン（詳細は §4）
grep -rn "\.catch(() => false)\|\.catch(() => true)" src/
```

- [ ] `npm run gate` が **exit 0**（❌ が1件でもあれば差し戻し）
  - **新規追加は当然不可**。既存ヒット（負債）も**例外なく違反**として扱う — 「既存だから OK」を許すと AI が既存コードを模倣して同じ違反を再生産するため（AI 先行模倣性）。定数経由（`SELECTORS.MODAL` 等）や `getByRole(...)` のセマンティックなものも、Locator が Action にある時点で違反
  - **grep はレシーバを問わず `.locator(` / `.getBy*(` を拾う形にする**。`this.page.` 限定にすると ①`this.page` と `.locator` が別行の複数行記法、②`modal.locator(...)` のような別レシーバ経由、を取りこぼし実際の違反の一部しか検出できない（= 目視より悪い偽の安心を生む）。PO から受け取った Locator への `.click()`/`.nth()` 等は `.locator(`/`.getBy(` を含まないので誤検出しない
  - 既存負債の一括解消は別途追跡。それまでの間にヒットが残っていても「既存だから残してよい」とは判断しない
- [ ] ⚠️ 警告のうち、**本 PR が追加・変更した行に該当があれば** SHOULD FIX として指摘（既存行の警告は別途追跡で可）

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
- [ ] **Page Object / Action の verify メソッド（boolean を返す状態確認）内に `waitForTimeout` を置いていないか** — 待機は操作メソッド（void）側に集約。verify 内固定待機は判定の正しさが待ち時間に賭かる + 二重待機の温床（`prohibited-patterns.md`「verify 内の固定待機 — 待機は操作メソッドに集約」参照）。**§2.0 の gate が AST で機械検出済み** — 目視は既知の検出漏れ（返り値注釈のない推論依存メソッド・void ヘルパー間接呼び出し内の待機）の補完に絞る
- [ ] Action: 各ステップ`this.step()`でログ記録（`console.log`単体は禁止）、expect未使用、**Locator 直書きなし（§2.0 で grep 検出）**、LoginAction はログイン成功検証あり
- [ ] Fixture: `stepCounter` が worker スコープで定義されている（`scope: 'worker'`）
- [ ] Test: Fixture経由import、Fixture引数でAction取得、Locator直書きなし
- [ ] 新規Action → Fixtureに登録済み、かつ TODO → 実装済みセクションに昇格済み

### エラーハンドリング
- [ ] `.catch(() => false)` パターン未使用（§4参照）

### テスト条件の黙殺
- [ ] テストが明示的に要求した操作（引数・パラメータで指定）が見つからない場合に Fail するか（スキップして Pass は偽陰性）

### テストデータ準備の構造（ベース作成フローの肥大・模倣伝播）
- [ ] **ベース作成フロー（リソース作成→データ追加→公開→利用者登録 等）をテストにインライン展開して重複させていないか** — 共有ビルダー（Setup Action）に集約する。インライン展開は AI 模倣で他テストに肥大伝播する
- [ ] **連続ユーザーストーリーを複数 `test()` に水平分割して `describe`/module スコープ変数で状態共有していないか** — Implicit Test Coupling（`prohibited-patterns.md`「テスト間データ依存」）。是正は **「縦に束ねる（Arrange をビルダー化）＋ 単一 `test()` のまま」** であって test() 分割ではない。「Phase = `test()` ブロック」と短絡した結果がこれ（手順書の Phase 表記と test() 分割は別物 → `architecture.md`）
- [ ] **ビルダー抽出が可読性を壊していないか（可読性ガード）** — 抽出してよいのは `[Arrange]`/`[Cleanup]` のみ。次を確認: (a) `[Act]`/`[Assert]` がインラインに残り「何を検証するか」が spec 本体で読めるか（R1）/ (b) 引数が boolean 羅列でなく options + 意図名か（R2）/ (c) ビルダー名が終状態を語り戻り値で生成名を返すか（R3）/ (d) 似てるだけの双子を分岐で1本化していないか（R4）

### テスト手順書（JSDoc）と実装の同期
- [ ] `.spec.ts` ファイル先頭の JSDoc（テスト手順書）と実装の Arrange/Act/Assert ステップが一致しているか
  - 実装変更時の JSDoc 更新漏れは無条件 NG（仕様変更追随・リファクタ・Action 名統合に伴うステップ表記変化も対象）
  - 既存ファイルの JSDoc に元から乖離が残っている場合も、その PR で実装を触る以上は同期させる
  - 規範は `architecture.md` 「JSDoc と実装の同期 — 無条件 MUST」参照
  - **チェック観点**: ①ステップ番号と実装行の対応（ズレ・抜け）②Action 名変更時の手順書表記③検証ポイントの増減と `✅` マーカーの整合 ④`[Arrange]`/`[Act]`/`[Assert]`/`[Cleanup]` タグの位置が実装コメントと一致 ⑤「元手順書との意図的差分」欄の存在と実態の一致 — 原本にない検証・手順の統合/省略が欄に記載されず手順内コメントに散在していないか（欄の書式は `e2e-test-create/jsdoc-template.md`）

---

## §3. SHOULD FIX

- [ ] ordinal（`.first()` / `.last()` / `.nth()`）の A/B 判定を行う
  - コメントなし → §2.0 の gate ❌ で機械検出済み（レビューに到達する時点で 0 件のはず）。目視の対象は**コメント内容の妥当性**
  - コメントあり・TODO なし → **B 判定条件を両方満たしているか確認する**: ①フレームワーク仕様として検証可能 ②代替手段が物理的に存在しない。片方でも欠ければ A 扱いにして TODO を追加する
  - コメントあり・TODO あり → A（偶然の固定化）として記録済み。理由コメントが実態を正しく説明しているか確認する
  - **迷ったら A**（TODO 追加）
- [ ] `waitForTimeout` の理由コメントが「直前のどの操作の何を待つか」を説明しているか — コメントの**有無**は §2.0 の gate ❌ で機械検出済み。目視の対象は**内容**（定数名の言い換え = `// SPA描画完了待ち` の類は不可）
- [ ] `:has-text()` → 完全一致（`getByRole`+`name`+`exact: true`／直下テキストなら `:text-is()`）を検討したか
- [ ] 探索スコープ（親要素絞り込み）活用
- [ ] AAAパターン、結果検証、データクリーンアップ
- [ ] テスト名が具体的か
- [ ] `.spec.ts` にテスト手順ヘッダーコメントがあるか（Phase・手順番号・検証ポイント）
- [ ] 各 Phase に `[Arrange]` / `[Act]` / `[Cleanup]` タグが付いているか（データ準備とテスト本体の区別）
- [ ] `this.step()` を使う public メソッドに `this.beginAction()` があるか（ステップ番号付与）
- [ ] 通し `test()`（作成→操作→検証を1本）が、その**条件下の振る舞い自体を subject とする**ものに限られているか — subject が別でリソース作成が単なる前提なら、作成を Setup Action に出してテストを絞る（`e2e-test-create/test-data-management.md`）
- [ ] JSDoc の実行時間などメタデータに「未測定」「実機確認時に更新」等の未更新プレースホルダが残っていないか（テスト通過済みなら実測値または確認済みコメントに置き換える）
- [ ] fixture カタログのメソッド description が実装と一致しているか（Action 名変更・引数変更に追随しているか）
- [ ] 実機確認で解決できる TODO がそのまま残っていないか（「解決策が分かっている TODO」は同 PR 内で対処する）

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

### 偽陰性（Pass と誤報告）が起きやすいケース

| 状況 | 何が起きるか | 正しい報告 |
|------|------------|----------|
| ブラウザクラッシュ（exit code 144 等） | 途中まで `✓` 出力されているがサマリーなし | 「結果未確定、再実行が必要」 |
| `report.json` が JSON 不完全 / 切れている | プロセス強制終了で書き込み中断 | 「結果未確定」 |
| Ctrl+C 等で中断 | 途中まで完走しているように見える | 「中断された、結果不明」 |
| timeout で kill | 個別 test は ✓ でも全体は failed | サマリー行を見て判定 |

**ルール**: 上記いずれかが疑われる場合は「Pass」と報告せず、**再実行を提案**する。ユーザーに「全テスト合格」と伝えて良いのは、3 点の確認が揃ったときのみ。

**再レビュー時の数値再測定**: fix コミット後の再レビューでは、サイズ・件数などの数値主張を前回測定値の流用で「一致」とせず**必ず再測定する**（fix コミット自体が数値を変える）。

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
