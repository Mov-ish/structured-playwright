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

> **注意**: このパターンは `prohibited-patterns.md` の `.catch(() => false)` 禁止とは異なる。
> catch が捕まえるのは「要素の状態遷移のタイムアウト」のみ。
> waitFor 以外の操作（textContent, click 等）を同じ try-catch に入れてはならない。
> 詳細は `prohibited-patterns.md`「try-catch の許容/禁止の境界」を参照。

```typescript
// Action層 — waitFor() は許可
async isRegistrationComplete(): Promise<boolean> {
  try {
    await this.completionMessage.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    return true;
  } catch { return false; }
}
```

**Test層**: verify メソッドの戻り値を expect() で検証
```typescript
// Test層 — Locator直接書かない
expect(await memberAction.isRegistrationComplete()).toBeTruthy();
```

## Page Objectのアクセス修飾子

```typescript
// ❌ 禁止: private readonly
private readonly emailInput: Locator;

// ✅ 必須: readonly（publicアクセス可能）
readonly emailInput: Locator;
```

理由: デバッグ時にテストから要素に直接アクセスできる。一貫性のある設計パターン。

## Page Objectで許可される待機

`waitFor()` + try-catch で boolean を返す状態確認メソッドは許可。
`expect()` によるアサーション、`waitForTimeout()` による固定待機は禁止。

## Action層のステップログ

Action層の各ステップは `this.step()` ヘルパーで記録する（`console.log`単体は禁止）。
`this.step()` はコンソール出力（ユーザーストーリー粒度）と `test.step()`（HTMLレポート上の階層表示）を同時に行う。
Fail時にどのステップで落ちたか即特定できる。

### 責務分離

| 表示先 | 粒度 | 目的 |
|--------|------|------|
| **コンソール** | `Step N: ActionName - 詳細`（ユーザーストーリー粒度） | リアルタイム進捗把握・CI ログでの位置特定 |
| **HTML レポート** | `test.step()` のネストで Action 内部詳細を階層表示 | Fail 時の詳細デバッグ |

### BaseActionの必須ヘルパー

```typescript
// BaseAction に必ず実装する
import { Page, test } from '@playwright/test';
import { StepCounter } from './StepCounter';

export class BaseAction {
  protected readonly page: Page;
  protected readonly actionName: string;
  protected readonly stepCounter?: StepCounter;

  constructor(page: Page, actionName: string, stepCounter?: StepCounter) {
    this.page = page;
    this.actionName = actionName;
    this.stepCounter = stepCounter;
  }

  /** Action の public メソッド先頭で呼ぶ。メイン番号をインクリメント */
  protected beginAction(): void {
    this.stepCounter?.nextMain();
  }

  /**
   * ステップ記録ヘルパー
   * コンソール: [TC / Phase] Step N: ActionName - 詳細
   * HTMLレポート: test.step() ネストで Action 内部詳細を階層表示
   *
   * 重要: fn() 実行中のエラーは catch せずそのまま伝播させる。
   *       catch するのはテストコンテキスト判定のみ。偽陽性（flaky pass）を防止する。
   */
  protected async step(name: string, fn: () => Promise<void>): Promise<void> {
    const { prefix, hasTestContext } = this.resolveTestContext();
    const mainNo = this.stepCounter?.currentMain ?? 0;
    // stepCounter が注入されているのに mainNo === 0 = beginAction() 呼び忘れ。
    // silent 通過させず即 throw（設計違反の早期検知 / 偽陽性防止）
    if (this.stepCounter && mainNo === 0) {
      throw new Error(
        `[${this.actionName}] beginAction() が呼ばれていません。public メソッドの先頭で必ず this.beginAction() を呼んでください`
      );
    }
    const stepLabel = mainNo > 0 ? `Step ${mainNo}` : 'Step';
    console.log(`${prefix}${stepLabel}: ${this.actionName} - ${name}`);

    if (hasTestContext) {
      await test.step(name, fn); // HTMLレポートでは詳細名のみ（ネストで可視化）
    } else {
      await fn();                // テストコンテキスト外のみフォールバック
    }
  }

  /** test.info().titlePath から prefix を組み立て（describe/test 名の `:` 前半を抽出） */
  private resolveTestContext(): { prefix: string; hasTestContext: boolean } {
    try {
      const info = test.info();
      const parts = info.titlePath.slice(1); // file 名を除外
      if (parts.length === 0) return { prefix: '', hasTestContext: true };
      const labels = parts.map((p) => this.shortenLabel(p));
      return { prefix: `[${labels.join(' / ')}] `, hasTestContext: true };
    } catch {
      return { prefix: '', hasTestContext: false };
    }
  }

  private shortenLabel(title: string): string {
    // ASCII `:` と全角 `：` の両対応（最初に現れる方で分割）
    const candidates = [title.indexOf(':'), title.indexOf('：')].filter((i) => i !== -1);
    if (candidates.length === 0) return title;
    const colonIdx = Math.min(...candidates);
    return title.slice(0, colonIdx).trim();
  }
}
```

### StepCounter の必須ヘルパー

StepCounter はメイン番号のみを管理する（サブ番号は廃止）。`describe` 境界で自動リセットし、同一 `describe` 内の複数 `test()` は連番継続する。

```typescript
import { test } from '@playwright/test';

export class StepCounter {
  private mainNumber = 0;
  private lastDescribeKey: string | null = null;

  /** Action の public メソッド開始時に呼ぶ。describe 境界でリセットしてから +1 */
  nextMain(): number {
    const currentKey = this.getDescribeKey();
    if (currentKey !== this.lastDescribeKey) {
      this.mainNumber = 0;
      this.lastDescribeKey = currentKey;
    }
    this.mainNumber++;
    return this.mainNumber;
  }

  /** 現在のメイン番号（インクリメントせず参照のみ。step() 表示用） */
  get currentMain(): number {
    return this.mainNumber;
  }

  private getDescribeKey(): string | null {
    try {
      const info = test.info();
      const parts = info.titlePath;
      // titlePath: [file, ...describes, test]
      // key = file + describes（末尾の test 名を除く）。
      // file を常に含めることで、別 file で同名 describe が混在しても衝突しない
      const keyParts = parts.slice(0, -1);
      return keyParts.length > 0 ? keyParts.join('|') : null;
    } catch {
      return null;
    }
  }
}
```

### ステップ番号の仕組み

メイン番号 = Action の public メソッド呼び出し単位。Action 内部の複数 `this.step()` は同じメイン番号を共有する（Action の内部詳細は HTML レポートの `test.step()` ネストで表現される）。

Fixture で `StepCounter` を **worker スコープ**で生成し、全 Action に共有注入する（test スコープだと `test()` 跨ぎで番号が継続しないため）。

**番号の意味**: 番号は「同一 describe 内の Action 呼び出し順」を示す。並列 workers が複数のテストを同時実行する場合、**各 worker はそれぞれ独立した StepCounter を持つ**ため、異なる describe の番号同士は比較できない。「TC-A の Step 5 は TC-B の Step 7 より先に実行された」といったグローバル順序は読み取れない。

**prefix の構成**:
- `test.info().titlePath` から自動導出（ `[file, describe, test]` の順）
- describe / test 名の `:` 前半をラベルとして採用（例: `'TC-XX: メインフロー...'` → `'TC-XX'`）
- `:` が無ければ名前全体を使用
- ASCII `:` と全角 `：` の両方に対応（先に現れる方で分割）

**出力例** （TC-XX 想定）:
```
コンソール:
[TC-XX / Phase 1] Step 1: LoginAction - ログインページへ遷移
[TC-XX / Phase 1] Step 1: LoginAction - 認証情報入力
[TC-XX / Phase 1] Step 1: LoginAction - ログインボタンクリック
[TC-XX / Phase 1] Step 2: NavigationAction - メインメニューを開く
[TC-XX / Phase 1] Step 3: ResourceAction - リソース作成モーダルを開く
...
[TC-XX / Phase 1] Step 20: LogoutAction - 管理画面からログアウト
[TC-XX / Phase 2] Step 21: LoginAction - ログインページへ遷移   ← 連番継続
[TC-XX / Phase 2] Step 22: NavigationAction - 別ロールに切替
...

HTMLレポート（test.step() ネスト）:
  ログインページへ遷移
  認証情報入力
  ログインボタンクリック
  ...
```

### 使い方
```typescript
// Action内 — beginAction() を public メソッドの先頭に必ず置く
async execute(url: string, email: string, password: string): Promise<void> {
  this.beginAction();
  await this.step('ログインページへ遷移', async () => {
    await this.loginPage.goto(url);
  });
  await this.step('認証情報入力', async () => {
    await this.authPage.fillCredentials(email, password);
  });
}
```

### beginAction() のルール

| 対象 | beginAction() |
|------|--------------|
| `this.step()` を使う public メソッド | **必須** |
| 検証メソッド（`isXxx()` → boolean 等） | 不要（step() を使わない） |
| private / protected メソッド | 不要 |

`beginAction()` を呼び忘れた状態で `this.step()` が呼ばれると、`BaseAction.step()` が即 **throw** する（silent 通過させない）。これは「設計違反の早期検知」と本テンプレートの偽陽性防止思想に沿った挙動。

### ネスト防止ルール

**Test層では `test.step()` で包まない。** ステップの粒度はAction層が管理する。
Test層で `test.step()` を使うと HTML レポートのネストが二重になり可読性が下がる。

## Test層のヘッダーコメント（テスト手順書）

すべての `.spec.ts` ファイルには、ヘッダーの JSDoc コメントにテスト手順を自然言語で記載する。

**必須項目**:
- テストケース番号と概要
- Phase ごとの手順（番号付き）
- 各 Phase に `[Arrange]` `[Act]` `[Assert]` `[Cleanup]` タグ
- 検証ポイント（expect で何を確認するか）

**テンプレート**:
```typescript
/**
 * TC-XX: テストケース名
 *
 * 実行時間: 約X.X分
 *
 * ■ [Arrange] データ準備（約X分）
 *   1. ○○する
 *   2. △△する
 *
 * ■ [Act] Phase 1: フェーズ名（約X分）
 *   3. ○○する
 *   4. △△する → ✅ □□を検証
 *
 * ■ [Assert] Phase 2: フェーズ名（約X分）
 *   5. ✅ □□を検証
 *
 * ■ [Cleanup] クリーンアップ（約X分）
 *   6. データ削除・ログアウト
 *
 * ■ 検証ポイント（expect）
 *   - Phase 1: ○○の検証（N箇所）
 *   - Phase 2: △△の検証
 */
```

**タグの意味**:

| タグ | 意味 | テストの目的との関係 |
|------|------|-------------------|
| `[Arrange]` | テストに必要なデータ・状態の準備 | テスト対象ではない。ここが失敗してもテスト対象の不具合ではない |
| `[Act]` | テスト対象の操作 | ここが本題。ユーザーストーリーで検証したい操作 |
| `[Assert]` | 期待結果の検証 | `[Act]` と同じ Phase 内でインラインに書いてもよい |
| `[Cleanup]` | テストデータの削除・環境の復元 | テスト対象ではない。省略可（データが残っても問題ない場合） |

**ルール**:
- テスト作成時に必ず記載する
- Phase 分割はテスト内の `test()` ブロックに対応させる
- 各 Phase に `[Arrange]` / `[Act]` / `[Assert]` / `[Cleanup]` のいずれかを付与する
- `[Act]` と `[Assert]` は同一 Phase にまとめてよい（`[Act]` タグで統一）
- 検証ポイントは `✅` マークでインライン表示 + 末尾にサマリー
- 実行時間は初回実行後に記載（未実行時は省略可）
- テストコード内のコメントにも同じタグを使用する（例: `// [Arrange] データ準備`）

## テストデータの共有と再利用

複数 `test()` 間でデータを共有する場合、または Phase 2/3 など後段フローを別 TC から再利用したい場合の設計指針。

### アンチパターン: module スコープ乱数による再利用阻害

```typescript
// ❌ 再利用不能
const random = Date.now().toString();          // module スコープ
const RESOURCE_NAME = `リソース名${random}`;

test.describe('TC-XX', () => {
  test('Phase 1: 作成', async ({ ... }) => { /* RESOURCE_NAME でリソース作成 */ });
  test('Phase 2: 利用', async ({ ... }) => { /* RESOURCE_NAME に暗黙依存 */ });
});
```

**弊害**:
- `-g "Phase 2"` での部分実行不可（Phase 1 が走らないとリソースが存在しない）
- 別 spec から Phase 2 のフローを再利用不可
- module スコープ乱数は spec 再読み込みのたびに変わるため、前回データを引き継げない
- `[Arrange]` と `[Act]` がテスト境界を跨いで暗黙結合する

### 推奨パターン

| 状況 | 推奨アプローチ |
|------|--------------|
| 単一 `test()` で完結 | `const random = Date.now()` を test() 内で持つ |
| 同一 describe 内で Phase 分割 | `test.beforeAll` でデータ準備、結果を describe スコープ変数で共有 |
| 別 spec / 別 TC から再利用したい | **Setup Action + Fixture** に切り出し、データ名は引数/戻り値で受け渡し |

### Setup Action パターン

`[Arrange]` 相当のデータ準備フロー（リソース作成・公開・権限付与など）が **複数 TC から呼ばれる可能性がある** 場合、専用の Setup Action として切り出す。

```typescript
// actions/ResourceSetupAction.ts
export class ResourceSetupAction extends BaseAction {
  /** 利用可能なリソース一式を作成。生成された名前を返す */
  async createPublishedResource(opts: {
    random: string;
    ownerName: string;
  }): Promise<{ resourceName: string; subItemName: string }> {
    this.beginAction();
    const resourceName = `リソース名${opts.random}`;
    // ... リソース作成・サブ項目追加・公開フロー
    return { resourceName, subItemName: `サブ項目${opts.random}` };
  }
}

// Fixture 登録
resourceSetupAction: async ({ page, stepCounter }, use) => {
  await use(new ResourceSetupAction(page, stepCounter));
},
```

### Action は最初から引数で受け取る

「再利用される可能性が少しでもある」フロー（リソース利用・完了確認・別画面遷移など）は、テストデータ（リソース名・項目名・乱数）を **必ず引数で受け取る** 設計にする。

```typescript
// ❌ Action 内で外部スコープ変数を直接参照
async openResource(): Promise<void> {
  await this.searchInput.fill(RESOURCE_NAME);    // module スコープに暗黙依存
}

// ✅ 引数で受け取る — 別 TC からも呼べる
async openResource(resourceName: string): Promise<void> {
  await this.searchInput.fill(resourceName);
}
```

引数化のコストは小さく、後で再利用するときの改修コストは大きい。**Action 内で module スコープ変数を直接参照しない** ことを原則とする。

### 判断フロー

1. 同じ spec 内の別 `test()` から呼ばれうる？ → **Yes なら Action 引数化必須**
2. 別 spec / 別 TC から呼ばれうる？ → **Yes なら Setup Action + Fixture 化**
3. 乱数で一意性を確保する？ → **乱数は Action の外（test() 内 or beforeAll）で生成して引数で渡す**

外部テストツール（MagicPod 等）の Shared Step に相当する粒度のフロー（リソース操作、完了確認、後始末など）は、最初から引数化・Action 化しておくこと。

## Fixture

```typescript
import { test as base } from '@playwright/test';
import { StepCounter } from '../actions/StepCounter';
import { LoginAction } from '../actions/LoginAction';

type AppFixtures = {
  loginAction: LoginAction;
};

// Worker スコープ Fixture — stepCounter は describe 境界で自動リセットするため、
// worker 全体で 1 インスタンス共有する（test スコープだと test() 跨ぎで番号が継続しない）
type WorkerFixtures = {
  stepCounter: StepCounter;
};

export const test = base.extend<AppFixtures, WorkerFixtures>({
  stepCounter: [
    async ({}, use) => { await use(new StepCounter()); },
    { scope: 'worker' },
  ],
  loginAction: async ({ page, stepCounter }, use) => {
    await use(new LoginAction(page, stepCounter));
  },
});
export { expect } from '@playwright/test';
```

新規Action追加時 → Fixtureにも登録必須（`stepCounter` を constructor に注入）。

## fixture.ts の Action カタログ規約

fixture.ts の `AppFixtures` 型定義の直前に、**Action カタログ**を維持する。
人間が fixture.ts を開くだけで「どんな Action があり、何ができるか」を把握できる状態にする。

### 書式

```typescript
// === Action カタログ ===
//
// ■ loginAction (LoginAction)
//   - execute(url, email, password)    ログイン
//
// ■ logoutAction (LogoutAction)
//   - execute()                        ログアウト
//
// ■ navigationAction (NavigationAction)
//   - selectWorkspace(wsName)          ワークスペース切替
//   - switchRole(role)                 ロール切替
//
// ■ resourceAction (ResourceAction)
//   - createResource(type, name)       リソース新規作成
//   - editResource(name, opts)         リソース編集
//   - publishResource()                リソースを公開
//   - isPublished() → boolean          「公開中」ステータス確認
//   ...
//
// === TODO（未実装） ===
//   yyyAction  : 説明（対象TC番号）
//
type AppFixtures = { ... };
```

### ルール
- **Action 名 + クラス名**: `■ xxxAction (XxxAction)` で始める
- **メソッド一覧**: `- メソッド名(主要パラメータ)  説明` を1行で。全 public メソッドを記載
- **戻り値が boolean/string のメソッド**: `→ 型` を明記（検証メソッドの識別）
- **省略記法**: メソッドが多い場合は主要なものを記載し `...` で省略可
- **注意事項**: UI の制約があれば `※` で補足
- 新規 Action を実装したら TODO → カタログに昇格
- 今後実装予定の Action は TODO に追加
