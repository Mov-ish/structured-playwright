# 4層アーキテクチャの責務と境界

## 層構造

```
Layer 4: Config/Env     → 環境設定・定数（constants.ts / env.ts）
Layer 3: Tests          → 期待結果検証（AAAパターン）
Layer 2: Actions        → ビジネスフロー・複数画面制御
Layer 1: Page Objects   → UI要素定義・基本操作
```

```
src/
├── config/      # Layer 4
├── pages/       # Layer 1（Locatorはここだけ）
├── actions/     # Layer 2
├── fixtures/    # Test層のインフラ（app.fixture.ts）
└── tests/       # Layer 3
```

## 層間の絶対境界

| ルール | 理由 |
|--------|------|
| **Test層にLocatorを書かない** | テストは意図と期待結果の表現。UI構造を知る必要がない |
| **Action層にexpect()を書かない** | expectはテスト固有のアサーション。Actionは再利用可能なフロー |
| **Page Objectにビジネスロジックを書かない** | PO はUI要素と単一責務のみ。フローはAction層 |
| **`@playwright/test`から直接importしない** | Fixture経由で`test`/`expect`をインポートする |
| **Actionを手動`new`しない** | Fixture引数で受け取る（依存の明示化） |

## Test層とAction層の検証の両立

Test層でLocatorが書けず、Action層でexpectが書けない。この2つを同時に満たすパターン：

**Action層**: `waitFor()`ベースの verify メソッドを実装（waitForは待機操作でありアサーションではない）

> catch してよいのは「要素の状態遷移のタイムアウト」のみ（waitFor 以外の操作を同じ try-catch に入れない）。境界の判定基準・禁止例は `prohibited-patterns.md`「try-catch の許容/禁止の境界」が正本、コード例は `e2e-test-create` §3「try-catch の境界」が正本。

**Test層**: verify メソッドの戻り値を expect() で検証する（Locator は直接書かない）。

## Page Objectのアクセス修飾子

`private readonly` でLocatorを定義するのは禁止。`readonly`（public）を使う。詳細は `prohibited-patterns.md`「コード禁止パターン」参照。

理由: デバッグ時にテストから要素に直接アクセスできる。一貫性のある設計パターン。

## Page Objectで許可される待機

`waitFor()` + try-catch で boolean を返す状態確認メソッドは許可。
`expect()` によるアサーションは禁止。`waitForTimeout()` は verify メソッド (boolean) 内は禁止（gate が AST で機械検出）、操作メソッド (void) 末尾は既存慣習として許容（正本: `prohibited-patterns.md`）。

**verify メソッド（boolean を返す状態確認）には固定待機を置かない。**
固定待機は操作メソッド（void）側に集約し、verify は **観測のみ** にする。
verify 内の `waitForTimeout` は「判定の正しさが待ち時間に賭かる」「待機所有者が二重化する」
偽陽性 / 偽陰性の温床。詳細は `prohibited-patterns.md`「verify 内の固定待機 — 待機は操作メソッドに集約」参照。

## Action層のステップログ

Action層の各ステップは `this.step()` ヘルパーで記録する（`console.log`単体は禁止）。
`this.step()` はコンソール出力（ユーザーストーリー粒度）と `test.step()`（HTMLレポート上の階層表示）を同時に行う。
Fail時にどのステップで落ちたか即特定できる。

### 責務分離

| 表示先 | 粒度 | 目的 |
|--------|------|------|
| **コンソール** | `Step N: ActionName - 詳細`（ユーザーストーリー粒度） | リアルタイム進捗把握・CI ログでの位置特定 |
| **HTML レポート** | `test.step()` のネストで Action 内部詳細を階層表示 | Fail 時の詳細デバッグ |

### BaseAction / StepCounter の契約

**雛形（コピー元）の正本 = `e2e-bootstrap` §6、実装の正本 = `src/actions/`。**
rules は実装コードを持たない（コピーのドリフトが「古い雛形を正と信じる」事故を生むため）。
以下の契約だけで、実物を開かずに正しい Action が書けることを保証する。

- `protected beginAction(): void` — Action の public メソッド先頭で必須（対象の詳細は下の「beginAction() のルール」表）
- `protected async step(name: string, fn: () => Promise<void>): Promise<void>` — 各ステップの記録。コンソール出力（`[Suite / Phase] Step N: ActionName - 詳細`）と `test.step()`（HTML レポート階層表示）を同時に行う
- `step()` は **fn() 実行中のエラーを catch せず伝播させる**（catch すると偽 Pass = flaky pass の温床）
- **`beginAction()` 忘れの状態で `step()` が呼ばれると即 throw**（silent 通過させない。このエラーに遭遇したら原因は呼び忘れ）
- メイン番号 = Action の **public メソッド呼び出し単位**（Action 内部の複数 `step()` は同番号を共有し、内部詳細は HTML レポートのネストで表現）
- 各 worker は**独立した StepCounter** を持つ — 異なる describe の番号同士は比較できない
- StepCounter は **worker スコープ Fixture** で生成し全 Action に共有注入する（test スコープだと test() 跨ぎで番号が継続しない）。describe 境界で自動リセット・同一 describe 内は test() を跨いで連番継続
- 新規 Action は constructor で `(page, stepCounter?)` を受け取り、`super(page, 'XxxAction', stepCounter)` を呼ぶ（BaseAction の constructor は `(page, actionName, stepCounter?)`。第2引数 actionName はログ表示名、`stepCounter` は optional）

prefix の自動導出（titlePath・`:` 分割）や出力例などの実装詳細は `e2e-bootstrap` §6 を参照。

### 使い方

コード例・出力例の正本は `e2e-bootstrap` §6。

### beginAction() のルール

| 対象 | beginAction() |
|------|--------------|
| `this.step()` を使う public メソッド | **必須** |
| 検証メソッド（`isXxx()` → boolean 等） | 不要（step() を使わない） |
| private / protected メソッド | 不要 |

`beginAction()` を呼び忘れた状態で `this.step()` が呼ばれると、`BaseAction.step()` が即 **throw** する（silent 通過させない）。これは「設計違反の早期検知」と本テンプレートの偽陽性防止思想に沿った挙動。

### ネスト防止ルール

**Test層で Action 呼び出しを 1:1 で `test.step()` に包まない。** Action の `this.step()` が既に `test.step()` を発行するため、二重ネストになり HTML レポートの可読性が下がる。
Phase 単位のグルーピング（複数の Action 呼び出しをまとめて 1 つの `test.step('[Act] Phase N: ...')` で囲む）は、後述「Test層のヘッダーコメント」の「Phase 分割は原則 `test.step()` で表現する」の標準形であり、**本ルールの禁止対象ではない**。判定は Action 呼び出し数ではなく `test.step()` の名前の意味で行う — Action 名をそのままなぞる名前（例: `'createResourceAction'`）は禁止対象、Phase 見出し（例: `'[Act] Phase 1: ...'`）は中の Action 呼び出しが1件でも許容対象。

## Test層のヘッダーコメント（テスト手順書）

すべての `.spec.ts` ファイルには、ヘッダーの JSDoc コメントにテスト手順を自然言語で記載する。

**必須項目**:
- テストケース番号と概要
- Phase ごとの手順（番号付き）
- 各 Phase に `[Arrange]` `[Act]` `[Assert]` `[Cleanup]` タグ
- 検証ポイント（expect で何を確認するか）

**テンプレート全文とタグ（[Arrange]/[Act]/[Assert]/[Cleanup]）の意味表は `e2e-test-create` §11 が正本**（書く局面でロードされる）。

**ルール**:
- テスト作成時に必ず記載する
- **Phase 分割は原則 `test.step()` で表現する。`test()` を分割するのはデータ依存のない独立 Phase のときだけ** — 1 つの連続したユーザーストーリー（作成 → 利用 → 完了 のように後段が前段の生成物に依存する流れ）は**単一 `test()`** に収め、Phase は `test.step()` で見せる。`test()` を複数に割って `describe`/module スコープ変数で状態を共有するのは Implicit Test Coupling であり禁止（`prohibited-patterns.md`「テスト間データ依存」参照）。
  - ⚠️ 「Phase = `test()` ブロック」と短絡しないこと。Phase 表記（手順書の見出し）と `test()` の分割は**別物**。手順書上は Phase 1/2/3 と書いても、実装は単一 `test()` + `test.step()` でよい。
- 各 Phase に `[Arrange]` / `[Act]` / `[Assert]` / `[Cleanup]` のいずれかを付与する
- `[Act]` と `[Assert]` は同一 Phase にまとめてよい（`[Act]` タグで統一）
- 検証ポイントは `✅` マークでインライン表示 + 末尾にサマリー
- 実行時間は初回実行後に記載（未実行時は省略可）
- テストコード内のコメントにも同じタグを使用する（例: `// [Arrange] データ準備`）

### JSDoc と実装の同期 — 無条件 MUST

**実装を変更したら、同一 PR 内で JSDoc も必ず同期更新する。** 仕様変更・リファクタリング・Action 名統合に伴うステップ表記の変化も全て対象。

**WHY**: JSDoc は手順書のソース・オブ・トゥルース。乖離すると「古いかも」前提の読み方が定着し（broken windows）、AI が古い表記を次のテストへ複製する。

**判定**: 本 PR で JSDoc と実装が不一致になっていないか。既存の乖離もその PR で実装を触る以上は同期させる（例外なし）。チェック観点: ステップ番号・Action 名表記・`✅` 整合・タグ位置。

## テストデータの共有と再利用

スコープ設計（どこで生成し誰に渡すか）の規範。生成方法の一意性（`uniqueId()`）とは直交する独立論点（`prohibited-patterns.md`「一意テストデータ名は uniqueId() で生成する」参照）。

- **module スコープの動的値 + 複数 `test()` の暗黙共有は禁止**（Implicit Test Coupling。部分実行不可・再利用不可・暗黙結合）— 判定基準・弊害の正本は `prohibited-patterns.md`「テスト間データ依存」
- **Action はテストデータ（リソース名・乱数等）を引数で受け取る** — module スコープ変数を直接参照しない（引数化のコストは小さく、後で再利用するときの改修コストは大きい）
- 再利用される `[Arrange]` フロー（リソース作成・公開・権限付与等）は **Setup Action + Fixture** に切り出す
- 実装パターンの正本は **`e2e-test-create/test-data-management.md`**（推奨早見表・beforeAll・Setup Action コード・判断フロー）

## Fixture

**雛形の正本 = `e2e-bootstrap/fixture-template.md`**（rules はコードを持たない）。契約:

- `@playwright/test` から直接 import しない — **Fixture 経由で `test` / `expect` を import** する
- StepCounter は **worker スコープ**（`{ scope: 'worker' }`）で定義する（describe 境界の自動リセットを worker 全体で 1 インスタンス共有）
- 新規 Action 追加時 → **Fixture にも登録必須**（`stepCounter` を constructor に注入）+ Action カタログ更新（次節）

## fixture.ts の Action カタログ規約

fixture.ts の `AppFixtures` 型定義の直前に、**Action カタログ**を維持する。
人間が fixture.ts を開くだけで「どんな Action があり、何ができるか」を把握できる状態にする。

### 書式

書式の正本・コード例は `e2e-bootstrap/fixture-template.md`（Action カタログ）参照。

### ルール
- **Action 名 + クラス名**: `■ xxxAction (XxxAction)` で始める
- **メソッド一覧**: `- メソッド名(主要パラメータ)  説明` を1行で。全 public メソッドを記載
- **戻り値が boolean/string のメソッド**: `→ 型` を明記（検証メソッドの識別）
- **省略記法**: メソッドが多い場合は主要なものを記載し `...` で省略可
- **注意事項**: UI の制約があれば `※` で補足
- 新規 Action を実装したら TODO → カタログに昇格
- 今後実装予定の Action は TODO に追加
