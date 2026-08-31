# 禁止事項一覧

このファイルのパターンは**いかなるタスクでも**使用してはならない。

> **機械検出**: grep 可能なパターンは `npm run gate`（`scripts/gate.sh`）が exit code で機械判定する。本ファイルの役割は「禁止 → 代替」の生成時誘導と、gate で判定できない項目（ordinal A/B/C・try-catch 境界・Silent Skip 等）の判定基準の提供。

## 用語

**偽陽性（誤検知）= 不具合が無いのに Fail。偽陰性（見逃し）= 不具合があるのに Pass。**
「陽性」はテストが異常を検出した状態（Fail）を指し、Pass ではない。`rules/` `skills/` 全体でこの意味に固定する。

## コード禁止パターン

gate 列: ✓ = `npm run gate` が機械検出（exit 1）/ ⚠️ = gate が警告として可視化（要目視）/ — = 判断系（本ファイルの判定基準で判断）

| 禁止 | 理由 | 代替 | gate |
|------|------|------|:---:|
| `text=ログイン` 記法 | プロジェクトで動作しない | `:has-text("ログイン")` or `getByRole` | ✓ |
| XPath (`//div/span`) | 構造依存・AI誤生成の温床 | CSS + セマンティック | ✓ |
| CSS構造セレクタ (`div > div > button`) | DOM揺れで即破壊 | 意味ベース + 探索スコープ | — |
| ordinal セレクタ（`.first()` / `.last()` / `.nth()`）コメントなし | 偶然の固定化・保守不能（並び替え/要素追加で破壊） | 下記「ordinal セレクタの許容境界」参照（用途で A=コメント+TODO / B・C=理由コメントのみ に分岐） | ✓ |
| `.catch(() => false)` / `.catch(() => true)` | タイムアウト隠蔽・偽陽性/偽陰性 | 下記「try-catch の許容/禁止の境界」参照 | ✓ |
| `private readonly` でLocator定義（Page Object層） | デバッグ困難 | `readonly`（public） | ✓ |
| `import { test } from '@playwright/test'` | Fixture未経由 | `from '../fixtures/app.fixture'` | ✓ |
| `new XxxAction(page)` をTest内で直接 | 依存が明示されない | Fixture引数で受け取る | ✓ |
| Action層で `expect()` | アサーションはTest層の責務 | `waitFor()` ベースの verify メソッド | ✓ |
| Action層 / Test層で Locator 直接記述 | Locator は Page Object 層の責務 | PO に移しメソッド経由 / Action の verify メソッド経由 | ✓ |
| Page Objectで `waitForTimeout()` | 固定待機はAction層で行う | `waitFor()` + try-catch | ⚠️ |
| verify メソッド (boolean) 内の `waitForTimeout()` | 判定の正しさが待ち時間に賭かる + 二重待機（下記参照） | 待機は操作メソッド側に集約、verify は観測のみ（gate が AST で機械検出） | ✓ |
| 意味層の薄い要素にセマンティックLocator | 属性不足で動作しない | `:near()` / `svg[data-icon]` | — |
| `has-text` をスコープなしで使用 | 同じ文言が複数→誤爆 | role+name+exact or 探索スコープで絞る | — |
| モーダルを `page` 全体で探索 | 背景ボタン誤クリック | `[role="dialog"]` で閉じ込め | — |
| `locator(SELECTORS.MODAL).last()` ハイブリッド | hidden を除外しない属性セレクタに stale 対策の `.last()` を貼る最悪の組合せ（下記参照） | アクティブモーダルは `getByRole('dialog').last()` / 単一スコープは `.last()` なしの `SELECTORS.MODAL` | ✓ |
| module スコープ乱数 + 複数 `test()` 暗黙依存 | 部分実行不可・別テスト再利用不可（下記参照） | 引数化 / Setup Action / `beforeAll`（`architecture.md` 参照） | ⚠️ |
| Action 内で module スコープ変数を直接参照 | 別テストから呼ぶと挙動が変わる | 引数で受け取る | — |

## ordinal セレクタの許容境界（`.first()` / `.last()` / `.nth()`）

ordinal は「偶然を排除する」原則（`locator-principles.md`）の対象だが**全面禁止は誤り** — **曖昧さ解消のための ordinal** は用途で3カテゴリに分岐する。意図の直接表現（count 走査の `nth(i)` イテレータ・引数由来 index の `nth(param)`）は本分類の対象外 — 理由コメントのみ必須。

| カテゴリ | 例 | 性質 | 扱い |
|---------|----|------|------|
| **A: 曖昧マッチの応急処置** | 複数マッチ → `.first()` | 偶然の固定化（並び替え・要素追加で破壊） | 最終手段。ピラミッド上位を先に試す + 理由コメント **+ TODO** |
| **B: フレームワークの不変条件** | `getByRole('dialog').last()` = アクティブモーダル | z-order = DOM append 順という実在の不変条件を符号化 | 下記①②を両方満たす場合のみ許容。理由コメント必須・**TODO 不要** |
| **C: ループ消化型イテレーション** | 「先頭1件を処理」を0件まで反復する `.first()` | どの順でも全件消化され順序に意味がない | 下記①②を両方満たす場合のみ許容。理由コメント必須・**TODO 不要** |

**判断基準**: 「たまたま位置で選んでいる（A）」のか「不変条件で位置が意味を持つ（B）」のか「順序が結果に影響しない消化ループ（C）」なのか。

**B 判定条件（両方必須。片方でも欠ければ A 扱い）**:
1. **フレームワーク仕様として検証可能** — UI ライブラリの公開挙動・DOM 構築規則で根拠を言語化できる（「たぶん末尾」という経験則は B でない）
2. **代替実装が物理的に存在しない** — 優先順位ピラミッドの上位手段で一意特定できない（できるなら A = 消す対象）

**C 判定条件（両方必須。片方でも欠ければ A 扱い）**: ①呼び出し元が0件になるまでのループで全件消化する（1回きりの先頭取りは A）②取り出す順序が結果に影響しない。消化の完全性は別ガード（maxLoops + throw、「ハングという形の偽陽性」参照）で担保 — ガードなしは C でも不合格。

> **WHY（条件を明示する理由）**: 条件がないと過剰 B/C 判定で TODO なしコメントが量産される（判定の甘さが偽の正当化を生む）。**迷ったら A** に倒す。

解決手順とコード例（❌ノーコメント / ✅A 理由+TODO / ✅B 不変条件のみ / ✅C 消化ループ）は **`e2e-locator` §11 が正本**。

### アクティブモーダルのイディオム — `activeDialog()` と `SELECTORS.MODAL` の使い分け

`SELECTORS.MODAL`（`[role="dialog"]`）と `activeDialog()`（`getByRole('dialog').last()`）は**競合ではなく役割が違う**。

| 用途 | 使うもの | 理由 |
|------|---------|------|
| **stale dialog が溜まる中から「最後に開いた＝アクティブ」を取る** | `getByRole('dialog').last()` | `getByRole` は hidden を自動除外 → stale 残骸に堅牢 |
| **単一モーダルにスコープして中の要素を取る** | `SELECTORS.MODAL`（`[role="dialog"]`） | 探索スコープの定数。複数ファイルで共通管理 |
| **ハイブリッド `locator(SELECTORS.MODAL).last()`** | ❌ **禁止** | hidden を除外しない属性セレクタに stale 対策の `.last()` を貼る最悪の組合せ |

## 値の禁止パターン

| 禁止 | 理由 | 代替 | gate |
|------|------|------|:---:|
| タイムアウト数値ハードコード (`2000`, `10000`) | 保守性低下 | `TIMEOUTS.SPA_RENDERING` 等の定数 | ✓ |
| URLパターンハードコード (`'**/login**'`) | 環境変更時の修正漏れ | `URL_PATTERNS.LOGIN` 等の定数 | ✓ |
| 共通セレクタハードコード (`'[role="dialog"]'`) | 一貫性欠如 | `SELECTORS.MODAL` 等の定数 | — |
| 認証情報ハードコード | セキュリティリスク | `.env` + `EnvConfig` | — |
| `waitForTimeout` の当該行に理由コメントなし | 意図不明で保守不能 | 当該行に「直前のどの操作の何を待つか」を書く（定数名の言い換えは不可）。定数自体の意味は宣言元（constants.ts）に置く（gate が機械検出） | ✓ |
| `Date.now()` 単独で一意テストデータ名を生成 | 並列ワーカー（別プロセス）が同一 ms で衝突 | `uniqueId()`（下記「一意テストデータ名は uniqueId() で生成する」参照） | ✓ |
| expect の部分一致（`toContain`/`toContainText`/`toMatch`）に理由コメントなし | `'1'`⊂`'10'` 型の偽陰性 = All green のまま検証だけが死ぬ縮退 | 厳密一致（`toBe`/`toEqual`）を既定に。部分一致は「なぜ厳密一致にできないか」の理由コメント必須 | ✓ |

## try-catch の許容/禁止の境界

catch で `false` を返すコード全てが禁止ではない。**catch が何を捕まえているか**で判断する。

| | 待っている条件 | falseの意味 | 判定 |
|---|---|---|---|
| `waitFor({ state: 'visible' })` のタイムアウト | 要素の状態遷移（非表示→表示） | 「その状態にならなかった」 | ✅ 許容 |
| `click()` / `fill()` 等の操作失敗 | 操作の成功 | 「何かが失敗した」（原因不明） | ❌ 禁止 |
| `textContent()` / `inputValue()` 等の取得失敗 | 値の取得 | 「何かが失敗した」（原因不明） | ❌ 禁止 |

**判断基準**: catch ブロックが捕まえるのは「要素の状態遷移のタイムアウト」だけか？ Yes なら許容、No なら禁止（waitFor と値取得は try-catch を分離する）。

コード例（✅許容 / ❌混入 / ✅分離）は **`e2e-test-create` §3「try-catch の境界」が正本**。

## verify 内の固定待機 — 待機は操作メソッドに集約

**boolean を返す検証メソッド (verify) の内部に `waitForTimeout` を置かない。** 同じ Page Object でも「操作メソッド (void) 末尾の固定待機」とは性質が異なる。

| | 操作メソッド (void) | verify メソッド (boolean) |
|---|---|---|
| 例 | `selectItem()` / `deleteItem()` | `isItemVisible()` / `isItemAbsent()` |
| 責務 | DOM を変える action | 現在の状態を観測して真偽を返す |
| 待機対象 | **自メソッド内の action の余波**（click 直後の再描画） | 自メソッドの外で起きた変化（他のメソッドの action 結果） |
| 待ち時間不足の影響 | 後続操作が遅延するだけ | **判定が誤って通る**（偽陰性 / 偽陽性で flaky） |
| 待機所有者 | action の付随処理 | （本来は呼び出し側のフロー制御） |
| 判定 | 既存慣習として許容 | ❌ **禁止** |

**WHY**: verify の責務は「観測して真偽を返す」こと。固定 sleep が混ざると①判定の正しさが待ち時間に賭かる（flaky な偽陰性/偽陽性）②操作メソッド末尾と verify 冒頭が同じ描画安定を二重に待つ（待機所有者の分散 = 層責務の崩れ）③1件でも残ると AI が正解パターンとして模倣・増殖する。

コード例（❌verify 内固定待機 / ✅操作メソッドへ集約）と「遷移検証」パターン（`isPresent → action → isAbsent` の対で偽陰性を排除）は **`e2e-test-create/test-data-management.md`「verify は観測のみ」が正本**。

### 例外

判定対象が「状態遷移のタイムアウト」そのものの場合、`waitFor({state:'visible'/'hidden'})` + try-catch は許可（`architecture.md`「Page Object で許可される待機」参照）。これは「観測そのものに待機戦略が含まれる」ケースで、`waitForTimeout` のような盲目的な固定待機とは別物。

## テスト条件の黙殺禁止（Silent Skip）

テストが明示的に要求した操作が実行できなかった場合、**スキップではなく Fail する**。

| 状況 | 判定 | 理由 |
|------|------|------|
| `required: true` → チェックボックスが見つからない | ❌ Fail必須 | テスト条件が満たされていない |
| `submitAnswer()` → 提出ボタンが見つからない | ❌ Fail必須 | テスト操作が実行されていない |
| 確認モーダルが出る場合と出ない場合がある → 出なかった | ✅ スキップ可 | 環境差異の吸収（テスト条件ではない） |
| ログアウト後のリダイレクト先が環境で異なる | ✅ スキップ可 | 環境差異の吸収 |

**判断基準**: その操作は**テストが明示的に要求したもの**か、**環境差異を吸収するための防御コード**か？

- テスト条件（引数・パラメータで明示）→ **見つからなければ Fail**
- 環境差異の吸収（モーダルの有無・遷移先の違い）→ **スキップ可**

コード例（❌黙殺 / ✅required で throw）は **`e2e-test-create/test-data-management.md`「テスト条件を満たせない場合は Fail」が正本**。

## ハングという形の偽陽性

`waitForTimeout` だけでなく、**disabled な要素に対する click/hover も「ハングという偽陽性」を生む**。Playwright の `click()` は内部で actionable 待ち（visible + enabled + stable）を行うため、`aria-disabled="true"` や `disabled` 属性の要素を待ち続けて test timeout までハングする。「ハング → タイムアウト Fail」は形上は Fail だが、**真因が「データが想定と違う」か「Locator が違う」か切り分けに時間がかかり、フィードバックが遅延する**点で偽陽性に近い害がある。

| 状況 | 判定 | 推奨 |
|------|------|------|
| 中身が空で disabled になるタブ・ボタンを直接 `click()` | ❌ ハング偽陽性 | 事前に `isEnabled()` を検証して即 fail-fast |
| 「対象が存在する前提」の操作（一括削除 / 全件処理 等）を空コンテキストで実行 | ❌ 空振り偽陰性 | 操作前に対象の存在を `expect(...).toBeTruthy()` で検証 |

代表例: **UI ライブラリの Tabs で中身が空のとき `aria-disabled="true"` になる罠**（Ant Design Tabs / MUI Tabs / Radix UI Tabs 等）。
詳細は `.claude/skills/e2e-locator/ant-design-tabs-disabled.md` を参照。

事前ガードのコード例（存在検証 → 切替 → 操作 → 消失検証の遷移検証）は **`e2e-test-create/test-data-management.md`「Cleanup フェーズの正直な検証」が正本**。

## AI生成コードの警戒パターン

- `.catch(() => false)` が5箇所以上 → AIコピペを疑う
- 同じエラーハンドリングパターンの大量重複 → 一箇所でも問題なら全体が問題
- **「動く」≠「正しい」** — テストは失敗することに意味がある

## テスト間データ依存（Implicit Test Coupling）

複数の `test()` が module スコープ変数や、前のテストで作られた状態に**暗黙的に**依存している構造は禁止。

### 何が問題か

アンチパターンの典型形（module スコープの乱数 + 複数 `test()` の暗黙参照）のコード例は **`e2e-test-create/test-data-management.md` が正本**。

| 弊害 | 具体例 |
|------|-------|
| 部分実行不可 | `-g "Phase 2"` で Phase 2 だけ走らせるとリソースが存在せず失敗 |
| 再利用不可 | 別 spec から Phase 2 のフローを呼べない |
| デバッグ困難 | Phase 1 失敗時に Phase 2 がスキップされず、別の理由で失敗して原因が紛らわしい |
| 暗黙結合 | `[Arrange]` と `[Act]` がテスト境界を跨ぎ、テスト独立性が崩れる |

### 判定基準

- module スコープ（`describe` の外）に動的値（`uniqueId()` / `Date.now()` 等）を持つ → ❌
- Action が module スコープ変数を直接参照する → ❌
- `test()` の中だけで完結する一意 ID（`const random = uniqueId()` を `test()` 内で宣言） → ✅（一意性は `uniqueId()` で確保。`Date.now()` 単独は ❌ → 「一意テストデータ名は uniqueId() で生成する」参照）
- `test.beforeAll` でデータ準備し、`describe` スコープ変数 で共有 → ✅
- Setup Action + Fixture でデータ準備 → ✅（推奨、`architecture.md` 参照）

### 例外

「TC全体が1つの長いユーザーストーリーで、最初から最後まで通しで動くことが本質」のテストは、`test()` を分割せず **単一の `test()` 内で全 Phase を実行する** ことで暗黙依存を回避する。Phase 分割が欲しいなら `test.step()` または Action 単位の粒度で表現する。

## 一意テストデータ名は uniqueId() で生成する（Date.now() 単独依存禁止）

テストデータ名の一意性を **`Date.now()` のミリ秒だけに依存してはならない**。

> **スコープ軸とは別問題**: これは上の「テスト間データ依存」（module スコープ vs `test()` 内スコープ）とは**直交する独立論点**。`test()` 内に置いても `Date.now()` 単独なら並列ワーカーで衝突する。両方を満たす必要がある。

### 何が問題か

**WHY**: 並列実行では各ワーカーが別プロセスのため同一 ms に同名データが生成され、`getByText` 等の複数マッチ（strict mode violation）で落ちる。単独実行では顕在化せず、**CI 並列で初めて flaky として現れる**。

| 弊害 | 具体例 |
|------|-------|
| 並列衝突 | Worker A と Worker B が同一 ms に同名リソースを生成 → `getByText` が 2 要素マッチ |
| プレフィックス共通で衝突 | `アイテム名${random}` が別テストでも同プレフィックス → 同 ms なら衝突 |
| `.slice()` で悪化 | `Date.now().toString().slice(-6)` は約1000秒周期で再衝突 |

### 判定基準

| パターン | 判定 |
|---|---|
| `const random = Date.now().toString()` 単独で一意名を作る | ❌ |
| `Date.now().toString().slice(-6)` 等で桁を削る | ❌（衝突確率が桁違いに上がる） |
| `const random = uniqueId()`（ms + ランダム）で生成 | ✅ |

### 正しい実装

**雛形の正本 = `e2e-bootstrap` §4「src/utils/uniqueId.ts」**（ms の36進 + ランダム6桁を `padEnd` で固定長にした一意サフィックス）。

> ※ テストコードでの `Math.random()` / `Date.now()` 利用自体は問題ない（一意**名生成**への単独使用だけが禁止）。
