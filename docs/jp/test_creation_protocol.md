# TEST_CREATION_PROTOCOL.md
## Doc-first Test Authoring（テスト作成フェーズの入口）

この文書は **「既存のPlaywright環境にE2Eテストを追加する」** ための入口です。
環境構築が目的なら **BOOTSTRAP.md** を参照してください。

---

## 最上位ルール
- **CLAUDE.md** が最上位（矛盾があれば CLAUDE.md を優先）
- 4層の責務は **E2ETest_Framework.md** を基準にする

---

## ⚠️ MUST: コード生成前の必須チェックリスト

**このセクションは必ず確認すること。既存コードを参照する前に、以下のルールを頭に入れておくこと。**

### インポート必須
```typescript
// 全ファイルで必須
import { TIMEOUTS } from '../config/constants';

// Page Object では追加で
import { SELECTORS } from '../config/constants';

// Action では追加で
import { URL_PATTERNS } from '../config/constants';

// Test では必須（Fixture経由）
import { test, expect } from '../fixtures/app.fixture';
// ❌ 禁止: import { test, expect } from '@playwright/test';
```

### Page Object のルール
| ルール | ❌ 禁止 | ✅ 必須 |
|--------|--------|--------|
| ロケータ定義 | `get xxx(): Locator { }` | `readonly xxx: Locator;` + constructor初期化 |
| アクセス修飾子 | `private readonly` | `readonly`（public） |

### Action のルール
| ルール | ❌ 禁止 | ✅ 必須 |
|--------|--------|--------|
| タイムアウト | `waitForTimeout(1000)` | `waitForTimeout(TIMEOUTS.MODAL_ANIMATION)` |
| URL待機 | `waitForURL('**/login**')` | `waitForURL(URL_PATTERNS.LOGIN)` |
| ログ出力 | 開始・終了のみ | 各ステップで `console.log('Step N: ...')` |
| LoginAction | 検証なし | ログイン成功検証を実装 |

### Test のルール
| ルール | ❌ 禁止 | ✅ 必須 |
|--------|--------|--------|
| import元 | `from '@playwright/test'` | `from '../fixtures/app.fixture'` |
| Action取得 | `new XxxAction(page)` | Fixture引数 `async ({ xxxAction }) =>` |

### ロケータのルール
| ルール | ❌ 禁止 | ✅ 必須 |
|--------|--------|--------|
| テキスト検索 | `text=ログイン` | `:has-text("ログイン")` または `getByRole` |
| 曖昧な取得 | `.first()` コメントなし | `.first()` + 理由コメント |

### waitForTimeout のルール
| ルール | ❌ 禁止 | ✅ 必須 |
|--------|--------|--------|
| 数値 | `waitForTimeout(2000)` | `waitForTimeout(TIMEOUTS.SPA_RENDERING)` |
| コメント | コメントなし | 理由コメント必須 |

**例:**
```typescript
// ❌ 禁止
await page.waitForTimeout(1000);

// ✅ 必須
// モーダルアニメーション完了を待つ
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
```

---

## ⚠️ 既存コード参照時の注意

**既存コードがルール違反している可能性がある。** 既存コードをコピーする前に、上記MUSTリストと照合すること。

違反パターンを見つけた場合：
1. コピーせず、正しいパターンで実装する
2. 可能であれば既存コードも修正する

---

## Locator の最終判断（必須）
Locator に迷ったら、必ず以下の順で参照し、判断を止める：

1. **Concept**（思想・優先順位）
2. **Universal**（普遍原則）
3. **Product-Specific（PRODUCT_A）**（PRODUCT_Aの製品固有の制約）

参照先：`./LOCATOR/`

---

## 作業の基本原則（AI向け）
- "既存構造を壊さずに追加する" が最優先（勝手に大改修しない）
- 既存の Actions / PageObject / ユーティリティをまず探索して再利用する
- `.first()` と XPath は原則禁止（やむを得ない場合は理由と TODO を明記）
- 機密情報は `.env` / CI 環境変数から取得する

---

## 4層アーキテクチャの責務（簡約）
- **Test（Scenario）**：意図・期待結果を書く。Locatorを直接書かない
- **Fixture**：Actionのインスタンス化を一元管理。TestがActionを直接newしない
- **Actions（手順）**：ユーザ行動のまとまり（再利用単位）
- **PageObject**：画面要素・操作のカプセル化（Locatorはここ）
- **Data / Config**：テストデータ・環境差分・認証情報（envなど）

※詳細は **E2ETest_Framework.md** を参照。

---

## AIの作業手順（SOP）

### 0) MUSTチェックリストを確認 ← 新規追加
上記「MUST: コード生成前の必須チェックリスト」を確認し、ルールを把握する。

### 1) ストーリーをテスト単位に分解
入力のユーザーストーリー（またはGiven/When/Then）を、テストケースへ分割する。

### 2) 既存資産の探索（必須）
- 既存の `Actions` を探す
- 既存の `PageObject` を探す
- 類似の `Test` を探す

> 既存があるのに新規作成するのは **コスト増** なので、まず再利用。
> **ただし、既存コードがMUSTルールに違反していないか確認すること。**

### 3) 追加ファイルを決める（最小追加）
- 既存で足りるなら Test だけ追加
- 足りない部分のみ Actions / PageObject を追加 or 拡張
- **新規Actionを追加した場合はFixtureファイルにも登録する**
- Locator は `./LOCATOR` のルールに従う

### 4) 命名と配置
- 仕様に沿ったファイル名・ディレクトリへ配置
- テスト名は「何を保証するか」が分かる名称

### 5) 仕上げ（実行・安定化）
- flake を避ける（待機は Locator と expect の自動待機を優先）
- 失敗時に読みやすい expect を書く
- 必要なら trace / screenshot を付与（プロジェクト方針に従う）

### 6) MUSTチェックリストで最終確認 ← 新規追加
生成したコードがMUSTルールに違反していないか最終確認する。

---

## 参考（実装例）
- 即効レシピ：`CLAUDE_Selectors.md`
- 詰まったら：`CLAUDE_FAQ.md`

---

## 指示テンプレ（そのまま使える）

> TEST_CREATION_PROTOCOL.md に従って、以下のユーザーストーリーでE2Eテストを追加して。
> **MUSTチェックリストを確認し、ルール違反がないことを確認すること。**
> 既存のActions/PageObjectをまず探して再利用し、足りない部分だけ追加して。
> テストファイルではFixture経由でActionを取得すること（`@playwright/test`から直接importしない）。

- 対象機能：
- ユーザーストーリー：
  1.
  2.
  3.
- 制約：
  - 追加のみ／既存修正OK
  - 新規Actions作成OK／既存Actions優先
  - PRODUCT_A固有の制約（あれば）

---

**最終更新**: 2026-02-02
**管理者**: Ray Ishida
