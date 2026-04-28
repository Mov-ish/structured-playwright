# 禁止事項一覧

このファイルのパターンは**いかなるタスクでも**使用してはならない。

## コード禁止パターン

| 禁止 | 理由 | 代替 |
|------|------|------|
| `text=ログイン` 記法 | プロジェクトで動作しない | `:has-text("ログイン")` or `getByRole` |
| XPath (`//div/span`) | 構造依存・AI誤生成の温床 | CSS + セマンティック |
| CSS構造セレクタ (`div > div > button`) | DOM揺れで即破壊 | 意味ベース + Local Universe |
| `.first()` コメントなし | 偶然の固定化、保守不能 | `:near()` / 具体セレクタ / コメント+TODO付き |
| `.catch(() => false)` / `.catch(() => true)` | タイムアウト隠蔽・false positive | 下記「try-catch の許容/禁止の境界」参照 |
| `private readonly` でLocator定義（Page Object層） | デバッグ困難 | `readonly`（public） |
| `import { test } from '@playwright/test'` | Fixture未経由 | `from '../fixtures/app.fixture'` |
| `new XxxAction(page)` をTest内で直接 | 依存が明示されない | Fixture引数で受け取る |
| Action層で `expect()` | アサーションはTest層の責務 | `waitFor()` ベースの verify メソッド |
| Test層で Locator 直接記述 | UIは Page Object層の責務 | Action の verify メソッド経由 |
| Page Objectで `waitForTimeout()` | 固定待機はAction層で行う | `waitFor()` + try-catch |
| 意味層の薄い要素にセマンティックLocator | 属性不足で動作しない | `:near()` / `svg[data-icon]` |
| `has-text` をスコープなしで使用 | 同じ文言が複数→誤爆 | `text-is` or Local Universe で絞る |
| モーダルを `page` 全体で探索 | 背景ボタン誤クリック | `[role="dialog"]` で閉じ込め |
| module スコープ乱数 + 複数 `test()` 暗黙依存 | 部分実行不可・別TC再利用不可（下記参照） | 引数化 / Setup Action / `beforeAll`（`architecture.md` 参照） |
| Action 内で module スコープ変数を直接参照 | 別 TC から呼ぶと挙動が変わる | 引数で受け取る |

## 値の禁止パターン

| 禁止 | 理由 | 代替 |
|------|------|------|
| タイムアウト数値ハードコード (`2000`, `10000`) | 保守性低下 | `TIMEOUTS.SPA_RENDERING` 等の定数 |
| URLパターンハードコード (`'**/login**'`) | 環境変更時の修正漏れ | `URL_PATTERNS.LOGIN` 等の定数 |
| 共通セレクタハードコード (`'[role="dialog"]'`) | 一貫性欠如 | `SELECTORS.MODAL` 等の定数 |
| 認証情報ハードコード | セキュリティリスク | `.env` + `EnvConfig` |
| `waitForTimeout` に理由コメントなし | 意図不明で保守不能 | TIMEOUTS定数 + 理由コメント必須 |

## try-catch の許容/禁止の境界

catch で `false` を返すコード全てが禁止ではない。**catch が何を捕まえているか**で判断する。

| | 待っている条件 | falseの意味 | 判定 |
|---|---|---|---|
| `waitFor({ state: 'visible' })` のタイムアウト | 要素の状態遷移（非表示→表示） | 「その状態にならなかった」 | ✅ 許容 |
| `click()` / `fill()` 等の操作失敗 | 操作の成功 | 「何かが失敗した」（原因不明） | ❌ 禁止 |
| `textContent()` / `inputValue()` 等の取得失敗 | 値の取得 | 「何かが失敗した」（原因不明） | ❌ 禁止 |

**許容パターン**（`architecture.md`「Test層とAction層の検証の両立」参照）:
```typescript
// ✅ waitFor のタイムアウトのみを catch — 「見えなかった」という事実を返す
async isSectionVisible(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    return true;
  } catch { return false; }
}
```

**禁止パターン**: waitFor 以外の操作を同じ try-catch に入れる
```typescript
// ❌ waitFor 成功後の textContent 失敗も false になり、真の原因が隠れる
async hasValue(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    const text = await this.section.textContent(); // ← これの失敗も catch される
    return /\d+/.test(text ?? '');
  } catch { return false; }
}
```

```typescript
// ✅ waitFor と値取得を分離する
async hasValue(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  } catch { return false; }
  const text = await this.section.textContent();
  return /\d+/.test(text ?? '');
}
```

**判断基準**: catch ブロックが捕まえるのは「要素の状態遷移のタイムアウト」だけか？ Yes なら許容、No なら禁止。

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

## AI生成コードの警戒パターン

- `.catch(() => false)` が5箇所以上 → AIコピペを疑う
- 同じエラーハンドリングパターンの大量重複 → 一箇所でも問題なら全体が問題
- **「動く」≠「正しい」** — テストは失敗することに意味がある

## テスト間データ依存（Implicit Test Coupling）

複数の `test()` が module スコープ変数や、前のテストで作られた状態に**暗黙的に**依存している構造は禁止。

### 何が問題か

```typescript
// ❌ 禁止
const random = Date.now().toString();
const RESOURCE_NAME = `リソース名${random}`;

test.describe('TC-XX', () => {
  test('Phase 1: 作成', async () => { /* RESOURCE_NAME でリソース作成 */ });
  test('Phase 2: 利用', async () => { /* RESOURCE_NAME で検索 — Phase 1 に暗黙依存 */ });
});
```

| 弊害 | 具体例 |
|------|-------|
| 部分実行不可 | `-g "Phase 2"` で Phase 2 だけ走らせるとリソースが存在せず失敗 |
| 再利用不可 | 別 spec から Phase 2 のフローを呼べない |
| デバッグ困難 | Phase 1 失敗時に Phase 2 がスキップされず、別の理由で失敗して原因が紛らわしい |
| 暗黙結合 | `[Arrange]` と `[Act]` がテスト境界を跨ぎ、テスト独立性が崩れる |

### 判定基準

- module スコープ（`describe` の外）に `Date.now()` などの動的値を持つ → ❌
- Action が module スコープ変数を直接参照する → ❌
- `test()` の中だけで完結する乱数（`const random = Date.now()` を `test()` 内で宣言） → ✅
- `test.beforeAll` でデータ準備し、`describe` スコープ変数 で共有 → ✅
- Setup Action + Fixture でデータ準備 → ✅（推奨、`architecture.md` 参照）

### 例外

「TC全体が1つの長いユーザーストーリーで、最初から最後まで通しで動くことが本質」のテストは、`test()` を分割せず **単一の `test()` 内で全 Phase を実行する** ことで暗黙依存を回避する。Phase 分割が欲しいなら `test.step()` または Action 単位の粒度で表現する。
