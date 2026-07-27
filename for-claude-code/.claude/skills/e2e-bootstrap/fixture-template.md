# 最小 Fixture 雛形（§3 の正本）

> **正本 = 本ファイル**（e2e-bootstrap §3 から抽出）。Fixture の新規作成・4層変換・新規 Action の Fixture 登録時に読む。

```typescript
import { test as base } from '@playwright/test';
import { StepCounter } from '../actions/StepCounter';
import { LoginAction } from '../actions/LoginAction';

// === Action 一覧 ===
// 実装済み:
//   loginAction  : ログイン
//
// TODO（未実装）:
//   xxxAction    : 説明（対象TCや用途）
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

