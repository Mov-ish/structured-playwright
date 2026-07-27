# テストデータ管理（§9 の正本）

> **正本 = 本ファイル**（e2e-test-create §9 から抽出）。テストデータ設計・Setup Action 化の判断・[Arrange] の構造を決めるときに読む。

- 静的テストデータ: `src/config/testdata/` に JSON ファイル配置
- 動的テストデータ: `uniqueId()`（`src/utils/uniqueId.ts`）で一意名を生成。**`Date.now()` 単独は並列ワーカー衝突のため禁止**（`prohibited-patterns.md`「一意テストデータ名は uniqueId() で生成する（Date.now() 単独依存禁止）」参照）。TC 識別子はプレフィックスに含める（`リソース名TC01_${random}`）
- テスト後のクリーンアップ: 作成したデータの削除を Action として実装

### 複数 `test()` 間でデータを共有する場合

**禁止**: module スコープに `const random = uniqueId()` を置いて複数 `test()` が暗黙参照する構造（判定基準・弊害の正本は `prohibited-patterns.md`「テスト間データ依存」）。一意性確保のため `Date.now()` 単独で名前を作るのも禁止（同「一意テストデータ名は uniqueId() で生成する」参照）。

```typescript
// ❌ 禁止の典型形
const random = uniqueId();                       // module スコープ
const RESOURCE_NAME = `リソース名${random}`;

test.describe('TC-XX', () => {
  test('Phase 1: 作成', async () => { /* RESOURCE_NAME でリソース作成 */ });
  test('Phase 2: 利用', async () => { /* RESOURCE_NAME で検索 — Phase 1 に暗黙依存 */ });
});
```

**推奨パターン早見表**（本節が実装パターンの正本。スコープ設計の規範は `architecture.md`「テストデータの共有と再利用」）:

| 状況 | 実装 |
|------|------|
| 単一 `test()` 完結 | `test()` 内で `const random = uniqueId()` |
| 同一 describe 内 Phase 分割 | `test.beforeAll` でデータ準備 + describe スコープ変数で共有 |
| 別 spec / 別 TC から再利用したい | Setup Action + Fixture（後述） |
| TC全体が通しユーザーストーリー | `test()` を分割せず 1つの `test()` 内に収め、`test.step()` で Phase 表現 |

**判断フロー**:
1. 同じ spec 内の別 `test()` から呼ばれうる？ → **Yes なら Action 引数化必須**
2. 別 spec / 別 TC から呼ばれうる？ → **Yes なら Setup Action + Fixture 化**
3. 一意性の確保 → `uniqueId()` で生成（`Date.now()` 単独禁止）。**生成は Action の外（test() 内 or beforeAll）で行い引数で渡す**

> ⚠️ **「Phase = `test()` ブロック」と短絡しないこと。** 手順書（JSDoc）の Phase 表記と `test()` の分割は別物。後段が前段の生成物に依存する連続ストーリー（作成 → 利用 → 完了）は**単一 `test()` + `test.step()`**。Phase ごとに `test()` を割って `describe`/module スコープ変数で状態を渡すと Implicit Test Coupling になる。是正は **「縦に束ねる（Arrange をビルダー化）＋ 単一 `test()`」** であって test() 分割ではない。

#### 通しテストの肥大とベース作成の集約

`create → use → complete` を**単一 `test()` に通すのは「その条件下での完了」自体がテスト対象（subject）のときのみ**。
テスト対象が別（詳細動作・アクセス条件など）でリソース作成が単なる前提なら、**作成を Setup Action に追い出してテスト本体を絞る**。

そのうえで、**ベース作成フロー（設定 → サブ項目追加 → 公開 → 利用者登録）をテストや TC にインライン展開しない**。
共有ビルダー（Setup Action）に集約し、各 TC は構成パラメータだけを渡す。

> **理由（AI 模倣の伝播）**: インライン展開した大きな作成ブロックは「最強の正解」として次の TC にコピーされ、肥大が伝播する。共有ビルダーに移せば、コピーされても伝播するのは「ビルダー呼び出し + きれいな構造」になる。

作成自体が subject の通し TC（＝単一 `test()` を保つもの）には、**荷重コメント**で意図と禁止を明記する:

```typescript
/**
 * TC-XX: ○○リソースの作成（意図的に end-to-end）
 * このテストは「○○リソースの作成 + その条件での完了」が subject のため単一 test() で通す。
 * subject が狭いテスト（詳細動作のみ等）でこの monolithic な形を真似ないこと。
 * ベース作成は ResourceSetupAction（共有ビルダー）経由。
 */
```

**可読性ガード（抽出してよいのは `[Arrange]`/`[Cleanup]` のみ）**: ビルダーに `[Act]`/`[Assert]` を畳まない（主題はインラインに残す）/ 引数は boolean 羅列でなく options + 意図名 / ビルダー名は終状態を語り戻り値で生成名を返す / 似てるだけの双子を分岐で1本化しない。受け入れ基準は「spec を開いた人間がファイルを離れず (a)どんな状態から始まるか (b)何を検証するか を答えられる」。

#### `beforeAll` パターン（同一 describe 内 Phase 分割）

```typescript
test.describe('TC-XX: リソース利用ストーリー', () => {
  let resourceName: string;
  let subItemName: string;

  test.beforeAll(async ({ browser }) => {
    const context = await browser.newContext();
    const page = await context.newPage();
    // セットアップ Action でリソース作成
    const random = uniqueId();
    resourceName = `リソース名${random}`;
    subItemName = `サブ項目名${random}`;
    // ... 実装
    await context.close();
  });

  test('Phase 2: ユーザーがリソースを利用', async ({ resourceUseAction }) => {
    await resourceUseAction.searchAndOpen(resourceName);  // 引数で受け取る
    // ...
  });
});
```

#### Setup Action パターン（別 TC から再利用）

```typescript
// actions/ResourceSetupAction.ts — 「利用可能なリソース一式」を作る共通フロー
export class ResourceSetupAction extends BaseAction {
  async createPublishedResource(opts: {
    random: string;
    ownerName: string;
  }): Promise<{ resourceName: string; subItemName: string }> {
    this.beginAction();
    const resourceName = `リソース名${opts.random}`;
    // ... リソース作成 → サブ項目追加 → 公開
    return { resourceName, subItemName: `サブ項目名${opts.random}` };
  }
}

// fixtures/app.fixture.ts に登録
resourceSetupAction: async ({ page, stepCounter }, use) => {
  await use(new ResourceSetupAction(page, stepCounter));
},
```

```typescript
// 利用側
test('TC-XX: 利用ストーリー', async ({ resourceSetupAction, resourceUseAction }) => {
  const random = uniqueId();
  const { resourceName } = await resourceSetupAction.createPublishedResource({ random, ownerName: 'ユーザー' });
  await resourceUseAction.searchAndOpen(resourceName);
  // ...
});
```

### Action の引数化（再利用に備える）

「再利用される可能性が少しでもある」フロー（リソース利用・完了確認・別画面遷移など）は、**最初から引数化**しておく。後で再利用するときの改修コストの方が大きい。

```typescript
// ❌ Action 内で外部スコープ参照（モジュール定数 RESOURCE_NAME 等）
async openResource(): Promise<void> { await this.searchInput.fill(RESOURCE_NAME); }

// ✅ 引数で受け取る
async openResource(resourceName: string): Promise<void> { await this.searchInput.fill(resourceName); }
```

外部テストツールの Shared Step に対応する粒度（リソース操作・状態確認・後始末等）は、最初から Action 引数化しておくこと。

### verify は観測のみ — 固定待機は操作メソッドへ

verify（boolean 返却）内の `waitForTimeout` は判定の正しさが待ち時間に賭かる偽陽性/偽陰性の温床（判定基準の正本は `prohibited-patterns.md`「verify 内の固定待機」）。

```typescript
// ❌ 禁止: verify 内の固定待機 — 判定の正しさが 2 秒に賭かる
async isItemAbsent(title: string): Promise<boolean> {
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // ← 外部 action の結果を待つ
  const values = await this.collectItemTitles();
  return !values.includes(title);
}

// ✅ 正しい: 待機は操作メソッド側に集約、verify は観測のみ
async deleteItem(): Promise<void> {
  await this.deleteButton.click();
  await this.confirmButton.click();
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // ← 自 action の余波待ち (慣習)
}
async isItemAbsent(title: string): Promise<boolean> {
  const values = await this.collectItemTitles();
  return !values.includes(title);
}
```

**「遷移検証」パターン**: verify が「ある状態であること」を返すなら、呼び出し側で変化前後を両方検証する。「`isAbsent` 単独」では「最初から存在しなかった」のか「削除で消えた」のかを区別できない。

```typescript
// 削除前: 対象が存在する (この前提検証がないと「削除で消えた」と言えず偽陽性)
expect(await resourceAction.isItemPresent(title)).toBeTruthy();
await resourceAction.deleteItem();
// 削除後: 対象が消えた
expect(await resourceAction.isItemAbsent(title)).toBeTruthy();
```

### テスト条件を満たせない場合は Fail（Silent Skip 禁止のコード例）

テスト条件（引数・パラメータで明示）と環境差異吸収の判定基準は `prohibited-patterns.md`「テスト条件の黙殺禁止」が正本。

```typescript
// ❌ 禁止: テスト条件を黙殺
async checkRequired(): Promise<void> {
  try {
    await this.checkbox.waitFor({ state: 'visible', timeout: TIMEOUTS.ELEMENT_CHECK });
  } catch {
    console.log('見つからないのでスキップ');  // ← テスト条件が満たされず Pass する偽陽性
    return;
  }
  await this.checkbox.check();
}

// ✅ 正しい: テスト条件を満たせなければ Fail
async checkRequired(required: boolean): Promise<void> {
  try {
    await this.checkbox.waitFor({ state: 'visible', timeout: TIMEOUTS.ELEMENT_CHECK });
  } catch {
    if (required) {
      throw new Error('必須チェックボックスが見つかりません（required=true）');
    }
    return; // required=false で存在しないのは許容
  }
  if (required) {
    await this.checkbox.check();
  } else {
    await this.checkbox.uncheck();
  }
}
```

### Cleanup フェーズの正直な検証

`permanentDeleteAll()` / `clearAll()` 等の「全件削除」操作は対象が無くても素通りするため、**前後で対象の存在/消失を expect する**ことで空振り（偽陽性）を防ぐ。

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| タブ切替 → `permanentDeleteAll()` のみ | ❌ | 対象が空でも素通りして Pass する偽陽性 |
| 削除前: 対象が存在する `expect(isXxxVisible).toBeTruthy()` + 削除後: 対象が消えた `expect(isXxxHidden).toBeTruthy()` | ✅ | 削除フローが本当に動いた証跡が残る |

```typescript
// ✅ 偽陽性ゼロの cleanup パターン
// isItemHidden は waitFor({state:'hidden'}) 方向の待機 — !isItemVisible では代替不可
expect(await action.hasItemsInTab('アーカイブ')).toBeTruthy();         // タブ切替前ガード
await navigationAction.switchTab('アーカイブ');
expect(await action.isItemVisible(targetName)).toBeTruthy();           // 対象がアーカイブに実在
await action.permanentDeleteAll();
expect(await action.isItemHidden(targetName)).toBeTruthy();            // 完全削除されたことを検証
```

```typescript
// ❌ domcontentloaded は遷移完了待機にならない
await this.page.locator(':text-is("ログアウト")').click();
await this.page.waitForLoadState('domcontentloaded');  // 即 return される
await this.page.context().clearCookies();              // → /logout 遷移中で ERR_ABORTED

// ✅ 遷移先要素 visible で確実に待つ
await this.page.locator(':text-is("ログアウト")').click();
await this.loginPage.usernameInput.waitFor({ state: 'visible', timeout: TIMEOUTS.LONG });
```

```typescript
// ❌ URL 到達で即 click → React init 中の親ハンドラに吸われる
await this.page.waitForURL('**/dashboard**');
await sideMenu.click();  // 遷移しない or 別タブ選択になる

// ✅ init 完了の目印要素 visible 後に click
await this.page.waitForURL('**/dashboard**');
await this.page.getByRole('main').getByRole('tablist').waitFor({ state: 'visible' });
await sideMenu.click();
```

---

