---
name: e2e-bootstrap
description: "E2E環境構築用。新規セットアップ・Playwright導入・既存プロジェクトの4層アーキテクチャ変換時に使用。Definition of Done・最小骨格・Fixture/constants雛形・コーディング規約・Playwrightデフォルトからの変換手順を含む。"
---

# E2E Bootstrap Skill

> テスト追加が目的なら `/e2e-test-create` を使うこと。

## §1. Definition of Done

- `npm test` が実行できる（smokeが1本通る）
- `npx tsc --noEmit` が通る（型エラー・未使用importがゼロ）
- Playwrightとブラウザ依存が揃っている
- 4層アーキテクチャの最小ディレクトリが存在する
- 認証情報は`.env`/CI環境変数で管理
- Fixtureファイル（app.fixture.ts）が存在しtest/expectをexport

---

## §2. 4層の最小骨格

```
src/
├── tests/           # Layer 3: シナリオ
├── actions/         # Layer 2: ユーザ操作の流れ
├── pages/           # Layer 1: 画面要素と操作（Locatorはここ）
├── fixtures/        # Fixture定義
│   └── app.fixture.ts
└── config/          # Layer 4: 環境差分・設定
    ├── env.ts
    └── constants.ts
```

---

## §3. 最小Fixture

```typescript
import { test as base } from '@playwright/test';
import { StepCounter } from '../actions/StepCounter';
import { LoginAction } from '../actions/LoginAction';

// === Action 一覧 ===
// 実装済み:
//   loginAction  : ログイン
//
// TODO（未実装）:
//   xxxAction    : 説明（対象TC番号）
type AppFixtures = { loginAction: LoginAction; };

// Worker スコープ Fixture — stepCounter は describe 境界で自動リセットするため、
// worker 全体で 1 インスタンス共有する（test スコープだと test() 跨ぎで番号が継続しない）
type WorkerFixtures = { stepCounter: StepCounter; };

export const test = base.extend<AppFixtures, WorkerFixtures>({
  stepCounter: [
    async ({}, use) => { await use(new StepCounter()); },
    { scope: 'worker' },
  ],
  loginAction: async ({ page, stepCounter }, use) => { await use(new LoginAction(page, stepCounter)); },
});
export { expect } from '@playwright/test';
```

**TODO 管理ルール**: 新規 Action を実装したら TODO → 実装済みに昇格。未実装の計画は TODO に追記。詳細は `rules/architecture.md` 参照。

---

## §4. 最小constants.ts

```typescript
export const TIMEOUTS = {
  SHORT: 3000, MEDIUM: 10000, LONG: 30000, DEFAULT: 10000,
  AUTH_STABILIZATION: 2000, MODAL_ANIMATION: 1000,
  SPA_RENDERING: 2000, REDIRECT: 3000,
} as const;

export const SELECTORS = {
  MODAL: '[role="dialog"]',
  SUBMIT_BUTTON: 'button[type="submit"]',
} as const;

export const URL_PATTERNS = {
  LOGIN: '**/login**',
  DASHBOARD: '**/dashboard**',
  LOGIN_PATH: '/login',
  // 例: AUTH_LOGIN: '**/auth.example.com/**',
} as const;
```

---

## §5. playwright.config.ts 必須設定

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './src/tests',
  globalSetup: './src/global-setup.ts',    // crashpad_handler 残存クリーンアップ（macOS arm64 + Chromium）
  timeout: 60000,                          // テスト全体のタイムアウト
  expect: {
    timeout: 10000,                        // 各expectのタイムアウト
  },
  reporter: [
    ['json', { outputFile: 'test-results/report.json' }],  // 構造化レポート
    ['html', { open: 'never' }],                            // HTMLレポート
    ['list'],                                                // ターミナル表示
  ],
  use: {
    trace: 'retain-on-failure',              // 失敗時のみtrace保存（常時ONはheaded実行でクラッシュする）
    screenshot: 'on',                      // 全テストでスクリーンショット保存
    video: 'retain-on-failure',            // 失敗時の動画（容量対策）
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // macOS arm64 + Chromium headed モードで chrome_crashpad_handler が
        // 残存しプロセスがハングする問題の防御的設定。
        // Playwright のレポート機能（trace/screenshot/video/report.json）には影響しない。
        launchOptions: {
          args: ['--disable-crash-reporter'],
        },
      },
    },
  ],
});
```

**なぜこの設定が必須か**:
- `timeout` + `expect.timeout`: 無限に待たせない。偽Passの防止
- `json` reporter: report.jsonにステップ構造が残る。Fail時の追跡に必須
- `trace/video retain-on-failure`: 失敗時のみ保存。trace常時ONは長時間テストのheaded実行でブラウザクラッシュの原因になる。Pass時の証跡はreport.json + screenshotで代替
- `screenshot on`: 全テストでスクリーンショット保存。Pass時の「正しく動作した証拠」として機能
- `html` reporter: 人間がブラウザで結果を確認できる
- `projects`: ブラウザを明示的に指定
- `--disable-crash-reporter`: macOS arm64 + Chromium で crash reporter 残存の防御的設定。これだけでは完全に防げないため `globalSetup` と併用
- `globalSetup`: テスト開始前に前回の残存 `chrome_crashpad_handler` をクリーンアップ（対症療法）

### globalSetup（crashpad_handler クリーンアップ）

macOS arm64 + Chromium for Testing の headed モードで、テスト完了後に `chrome_crashpad_handler` が残存しプロセスがハングする問題の対症療法。テスト開始前に前回の残存プロセスをクリーンアップする。

```typescript
// src/global-setup.ts
import { execSync } from 'child_process';

export default function globalSetup() {
  try {
    execSync("pkill -f 'ms-playwright.*chrome_crashpad_handler' 2>/dev/null", { stdio: 'ignore' });
  } catch {
    // プロセスが存在しない場合は無視
  }
}
```

`playwright.config.ts` に `globalSetup: './src/global-setup.ts'` を追加すること。
`ms-playwright` でパスを絞り込むため、通常の Chrome / VS Code / 他アプリには影響しない。

---

## §6. BaseAction / StepCounter 雛形

全ActionはBaseActionを継承する。`step()`ヘルパーはコンソール（ユーザーストーリー粒度）と`test.step()`（HTMLレポート階層表示）を両方出力する。prefix（`[TC / Phase]`）は `test.info().titlePath` から自動導出される。

### BaseAction.ts

```typescript
// actions/BaseAction.ts
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

### StepCounter.ts

```typescript
// actions/StepCounter.ts
import { test } from '@playwright/test';

/**
 * Action 呼び出し単位のステップ番号管理（describe スコープで継続カウント）
 * - 同一 describe 内では test() を跨いでも番号を継続カウント
 * - 別 describe に入ると番号を 1 にリセット
 */
export class StepCounter {
  private mainNumber = 0;
  private lastDescribeKey: string | null = null;

  nextMain(): number {
    const currentKey = this.getDescribeKey();
    if (currentKey !== this.lastDescribeKey) {
      this.mainNumber = 0;
      this.lastDescribeKey = currentKey;
    }
    this.mainNumber++;
    return this.mainNumber;
  }

  get currentMain(): number {
    return this.mainNumber;
  }

  private getDescribeKey(): string | null {
    try {
      const info = test.info();
      const parts = info.titlePath;
      // file + describes を key に含めることで、別 file で同名 describe が混在しても衝突しない
      const keyParts = parts.slice(0, -1);
      return keyParts.length > 0 ? keyParts.join('|') : null;
    } catch {
      return null;
    }
  }
}
```

**出力例**:
```
[TC-XX / Phase 1] Step 1: LoginAction - ログインページへ遷移
[TC-XX / Phase 1] Step 1: LoginAction - 認証情報入力
[TC-XX / Phase 1] Step 2: NavigationAction - メインメニューを開く
...
[TC-XX / Phase 2] Step 21: LoginAction - ログインページへ遷移   ← describe 内で連番継続
```

---

## §7. .env.example

```
TEST_BASE_URL=
TEST_USER_EMAIL=
TEST_USER_PASSWORD=
```

---

## §8. コーディング規約

### package.json 必須devDependencies
```json
{
  "devDependencies": {
    "@playwright/test": "^1.50.0",
    "dotenv": "^16.4.0",
    "typescript": "^5.9.0",
    "@types/node": "^22.0.0"
  }
}
```

> `typescript` と `@types/node` がないと `npx tsc --noEmit` による型チェックが実行できない。
> §1 Definition of Done の型チェック要件を満たすために必須。

### TypeScript設定（tsconfig.json）
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

### コードフォーマット（Prettier）
```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100
}
```

### 命名規則

| 種類 | 規則 | 例 |
|------|------|---|
| クラス | PascalCase | `LoginPage`, `LoginAction` |
| メソッド | camelCase | `fillEmail()`, `clickButton()` |
| 変数 | camelCase | `emailInput`, `userName` |
| 定数 | UPPER_SNAKE_CASE | `MAX_RETRY`, `DEFAULT_TIMEOUT` |
| インターフェース | PascalCase | `TestEnvironment` |

### JSDocコメント規約
```typescript
/**
 * メソッドの説明
 * @param email - メールアドレス
 * @param password - パスワード
 * @returns ログイン成功の可否
 */
async execute(email: string, password: string): Promise<boolean> {
  // 実装
}
```

---

## §9. Playwrightデフォルト構成から4層への変換手順

Playwrightデフォルト（`tests/`直下にspecファイル）から変換する場合：

1. `src/` 配下に4層ディレクトリ作成（§2参照）
2. `config/constants.ts` と `config/env.ts` を作成（§4, §5参照）
3. specファイル内のLocator → `pages/` のPage Objectに移動
4. specファイル内のフロー操作 → `actions/` のActionに移動
5. Fixture定義を作成（§3参照）し、testのimport元を切り替える
6. specファイルには意図・期待結果のみ残す（Locator・ロジック禁止）
7. ハードコード値 → `constants.ts` に移動
8. 認証情報 → `env.ts` + `.env` に移動
9. `npx playwright test` で全テスト通過を確認

**変換時の注意**:
- 一度に全部変換しない。1テストずつ移行して確認
- 既存のテストが通る状態を常に維持する
- 新規Actionを作ったらFixtureに登録を忘れない

---

## §10. プロジェクト固有設定チェックリスト

新プロジェクトに導入する際、以下を確認してCLAUDE.mdに記入する：

- [ ] 対象プロダクト名
- [ ] UIライブラリ（Ant Design / MUI / 独自 / なし）
- [ ] 認証方式（外部認証 / 独自ログイン / SSO / なし）
- [ ] HTML意味層の状況（data-testid有無 / aria-label整備状況）
- [ ] SPA or MPA
- [ ] CI/CD環境（CircleCI / GitHub Actions等）

---

## §11. トラブルシューティング

### macOS + Chromium headed モードでテスト失敗後にターミナルがハングする

**症状**: `npx playwright test --headed` で失敗した後、ターミナルがコマンドを受け付けない。Ctrl+C も効かないことがある。

**原因**: `chrome_crashpad_handler` プロセスが残存し、親プロセスが解放されない。`globalSetup`（§5）は**次回テスト実行前**に残存をクリーンアップする予防策であって、現在のハング状態は解消しない。

**対処**: 別ターミナルタブから次のコマンドで Playwright の Chromium プロセスのみを kill する。

```bash
pkill -f 'ms-playwright'
```

`ms-playwright` でパスを絞り込むため、通常の Chrome / VS Code / 他アプリには影響しない。kill 後、ハングしていたターミナルが解放される。
