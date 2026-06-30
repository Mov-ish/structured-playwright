---
name: e2e-test-create/failure-patterns
description: "既に試して失敗したパターン集。待機・セレクタ・遷移で「再発明しないため」の参照資料。"
---

# 既に試して失敗したパターン（再発明するな）

## 外部認証の待機

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| `waitForLoadState('networkidle')` のみ | ❌ | 外部ドメイン遷移前に次の操作が走る |
| `page.waitForURL()` のみ | ⚠️ 不安定 | URL変化は検知するが画面描画完了を待たない |
| `waitForURL()` + `waitForTimeout()` | ✅ | URL遷移確認+画面安定化の組み合わせ |

## SPA描画待機

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| `networkidle` のみ | ❌ 不安定 | フレームワーク（React 等）の描画はnetwork完了後に発生 |
| 固定5000ms | ❌ 遅い | 不必要に遅く環境差で不足する場合も |
| `networkidle` + `TIMEOUTS.SPA_RENDERING` | ✅ | 両方カバー |

## 削除後の変化確認

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| `waitFor({ state: 'hidden' })` | ❌ | SPAでDOM完全削除→参照無効 |
| `waitFor({ state: 'detached' })` | ❌ 不安定 | DOM依存で環境差 |
| URL遷移確認 | ✅ | 間接的だが安定 |

## モーダル内ボタン

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| 表示直後クリック | ❌ | CSSアニメーション中は処理されない |
| `waitFor` のみ | ⚠️ 不安定 | visibleでもアニメーション中あり |
| `waitFor` + `MODAL_ANIMATION` + `scrollIntoView` + `force:true` | ✅ | 全対策 |

## セレクタ選択

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| 属性不足要素に `getByLabel()` | ❌ | label要素が存在しない場合がある |
| `getByRole('checkbox')` スコープなし | ❌ | 一意に特定できない |
| `button[aria-label="more"]` | ❌ | aria-label未設定の場合がある |
| `button:has-text("...")` で三点リーダー | ❌ | 三点リーダーはSVGでありテキストではない |
| `getByRole('row', { name })` | ❌ | accessible nameが設定されていないテーブルがある |
| `filter({ hasNot })` でテキスト除外 | ❌ | hasNotは子要素チェック。hasNotTextが必要 |

## Navigation 完了待機

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| click 直後 `waitForLoadState('domcontentloaded')` | ❌ | 現ページで既に発火済みだと**即 return** する。後続 `goto()` が遷移完了前に走り `net::ERR_ABORTED` を起こす |
| URL 到達のみで次ステップ実行 | ❌ | SPA 着地画面 init 中（~2s）の click は外側ハンドラ（着地画面のクリックハンドラ等）に**吸われて**期待動作しない |
| 遷移先の既知要素 visible 待ち | ✅ | UI 要素ベースが基本。例: ログアウト直後 → 次画面の固有要素 visible 待ち |
| URL 待機 + 着地画面の init 完了指標 visible 待ち | ✅ | 例: `waitForURL('**/dashboard**')` → `getByRole('main').getByRole('tablist').waitFor({ state: 'visible' })` |

```typescript
// ❌ domcontentloaded は遷移完了待機にならない
await page.locator(':text-is("ログアウト")').click();
await page.waitForLoadState('domcontentloaded');  // 即 return される
await page.context().clearCookies();              // → 遷移中で ERR_ABORTED

// ✅ 遷移先要素 visible で確実に待つ
await page.locator(':text-is("ログアウト")').click();
await loginPage.usernameInput.waitFor({ state: 'visible', timeout: TIMEOUTS.LONG });
```

```typescript
// ❌ URL 到達で即 click → SPA init 中の親ハンドラに吸われる
await page.waitForURL('**/dashboard**');
await sideMenu.click();  // 遷移しない or 別動作になる

// ✅ init 完了の目印要素 visible 後に click
await page.waitForURL('**/dashboard**');
await page.getByRole('main').getByRole('tablist').waitFor({ state: 'visible' });
await sideMenu.click();
```

## 中身が空のタブ切替（アーカイブ / 削除済み / 未読 等）

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| `getByRole('tab', { name: 'アーカイブ' }).click()` をいきなり呼ぶ | ❌ | 中身が空のとき多くの UI ライブラリ（Ant Design 等）は Tab に `aria-disabled="true"` を付与する。`click()` は actionable 待ちで **test timeout までハング**する（ハング偽陽性） |
| 切替前に `tab.isEnabled()` で事前ガード | ✅ | 空時に即 expect 失敗 → 真因（前段のフローが効いていない 等）が即判明 |

→ 詳細は `rules/prohibited-patterns.md`「ハングという形の偽陽性」参照。

## Cleanup フェーズの正直な検証

`permanentDeleteAll()` / `clearAll()` 等の「全件削除」操作は対象が無くても素通りするため、**前後で対象の存在/消失を expect する**ことで空振り（偽陽性）を防ぐ。

| 試したこと | 結果 | 理由 |
|-----------|------|------|
| タブ切替 → `permanentDeleteAll()` のみ | ❌ | 対象が空でも素通りして Pass する偽陽性 |
| 削除前: 対象が存在する `expect(isXxxVisible).toBeTruthy()` + 削除後: 対象が消えた `expect(isXxxHidden).toBeTruthy()` | ✅ | 削除フローが本当に動いた証跡が残る |

```typescript
// ✅ 偽陽性ゼロの cleanup パターン
expect(await action.hasItemsInTab('アーカイブ')).toBeTruthy();   // タブ切替前ガード
await navigationAction.switchTab('アーカイブ');
expect(await action.isItemVisible(targetName)).toBeTruthy();     // 対象がアーカイブに実在
await action.permanentDeleteAll();
expect(await action.isItemHidden(targetName)).toBeTruthy();      // 完全削除されたことを検証
```
