---
name: e2e-bootstrap
description: "For E2E environment setup. Use for new setup, Playwright installation, or converting an existing project to the 4-layer architecture. Includes Definition of Done, minimal skeleton, Fixture/constants templates, coding conventions, and conversion steps from the Playwright default layout."
---

# E2E Bootstrap Skill

> If your goal is adding tests, use `/e2e-test-create` instead.

## §1. Definition of Done

- `npm test` runs (one smoke test passes)
- `npx tsc --noEmit` passes (zero type errors and zero unused imports)
- `npm run gate` exits 0 (machine gate — canonical source is `scripts/gate.sh`)
- Playwright and browser dependencies are installed
- The minimal 4-layer architecture directories exist
- Credentials are managed via `.env` / CI environment variables
- The fixture file (app.fixture.ts) exists and exports test/expect

---

## §2. Minimal 4-Layer Skeleton

```
src/
├── tests/           # Layer 3: scenarios
├── actions/         # Layer 2: user operation flows
├── pages/           # Layer 1: screen elements and operations (Locators live here)
├── fixtures/        # Fixture definitions
│   └── app.fixture.ts
├── utils/           # uniqueId.ts / formatDate.ts etc. (see §4)
└── config/          # Layer 4: environment differences / configuration
    ├── env.ts
    └── constants.ts
```

---

## §3. Minimal Fixture

**Canonical source = `fixture-template.md` (same directory) — always read it when creating a new Fixture, converting to the 4-layer architecture, or registering a new Action.** Contains: the full `base.extend` structure (complete form including the worker-scoped stepCounter).

## §4. Minimal constants.ts

```typescript
export const TIMEOUTS = {
  // Numeric constants require a declaration-line comment (machine-detected by the gate; write one key per line with a trailing comment)
  SHORT: 3000,   // Upper bound for short appearance checks / stabilization (probing optional elements etc.; give up quickly on absence)
  MEDIUM: 10000, // Upper bound for medium element-appearance waits
  LONG: 30000,   // Upper bound for long transitions (cross-origin redirect completion, first page load, etc.)
  DEFAULT: 10000, // Standard upper bound for element appearance / URL transition waits
  AUTH_STABILIZATION: 2000, // Wait for session establishment after external auth redirect
  MODAL_ANIMATION: 1000, // Modal open/close animation
  SPA_RENDERING: 2000, // Wait for SPA re-render / state propagation
  REDIRECT: 3000, // Wait for URL settlement / initialization after page transition
} as const;

export const SELECTORS = {
  MODAL: '[role="dialog"]',          // Constant for scoping to a single modal (no .last())
  SUBMIT_BUTTON: 'button[type="submit"]',
} as const;

export const URL_PATTERNS = {
  LOGIN: '**/login**',
  DASHBOARD: '**/dashboard**',
  LOGIN_PATH: '/login',
  // Example: AUTH_LOGIN: '**/auth.example.com/**',
} as const;
```

**Extension examples (add as project-specific elements grow)**:

```typescript
// TIMEOUTS extension example
ELEMENT_VISIBLE: 5000, // Wait for a specific element to appear (state the purpose — declaration-line comments are machine-detected by the gate)

// SELECTORS extension examples (only selectors shared across multiple screens)
AGREEMENT_CHECKBOX: 'input[type="checkbox"]:near(:text("I agree"))',
AUTH_EMAIL_INPUT: 'input[name="username"]',
AUTH_PASSWORD_INPUT: 'input[name="password"]',
```

### Create alongside it: src/utils/uniqueId.ts (unique test data names)

Required to guarantee uniqueness of test data names (`Date.now()` alone collides across parallel workers — the criteria are in `prohibited-patterns.md`, "Generate unique test data names with uniqueId()").

```typescript
// src/utils/uniqueId.ts
/**
 * Generates a unique suffix that does not collide even across parallel workers.
 * Use it to guarantee uniqueness of test data names (resource names, entry names, etc.).
 *
 * If uniqueness relies solely on the milliseconds of `Date.now()`, parallel runs with
 * `workers > 1` can have workers in different processes generate within the same millisecond
 * and collide (identically named data piles up in the test environment and `getByText` etc.
 * fail with multiple matches). Avoided via base-36 ms + 6 random characters.
 * See `.claude/rules/prohibited-patterns.md`, "Generate unique test data names with uniqueId()", for details.
 */
export function uniqueId(): string {
  // slice(2, 8) can yield fewer than 6 characters depending on Math.random(), so padEnd fixes it at 6
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8).padEnd(6, '0')}`;
}
```

---

## §5. Required playwright.config.ts Settings

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './src/tests',
  globalSetup: './src/global-setup.ts',    // Cleanup of leftover crashpad_handler (macOS arm64 + Chromium)
  timeout: 60000,                          // Overall test timeout
  expect: {
    timeout: 10000,                        // Timeout for each expect
  },
  reporter: [
    ['json', { outputFile: 'test-results/report.json' }],  // Structured report
    ['html', { open: 'never' }],                            // HTML report
    ['list'],                                                // Terminal display
  ],
  use: {
    trace: 'retain-on-failure',              // Save trace only on failure (always-on crashes headed runs)
    screenshot: 'on',                      // Save screenshots for all tests
    video: 'retain-on-failure',            // Video on failure (disk usage measure)
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // Defensive setting for the issue where chrome_crashpad_handler lingers and
        // the process hangs in macOS arm64 + Chromium headed mode.
        // Does not affect Playwright reporting features (trace/screenshot/video/report.json).
        launchOptions: {
          args: ['--disable-crash-reporter'],
        },
      },
    },
  ],
});
```

**Why these settings are required**:
- `timeout` + `expect.timeout`: never wait forever. Prevents false Passes
- `json` reporter: report.json retains the step structure. Essential for tracing failures
- `trace/video retain-on-failure`: saved only on failure. Always-on trace causes browser crashes in headed runs of long tests. Pass-time evidence is covered by report.json + screenshots instead
- `screenshot on`: screenshots saved for all tests. Serves as "evidence of correct behavior" on Pass
- `html` reporter: lets humans review results in a browser
- `projects`: specify browsers explicitly
- `--disable-crash-reporter`: defensive setting against leftover crash reporters on macOS arm64 + Chromium. Not sufficient alone, so combine with `globalSetup`
- `globalSetup`: cleans up any leftover `chrome_crashpad_handler` from the previous run before tests start (symptomatic treatment)

### globalSetup (crashpad_handler cleanup)

Symptomatic treatment for the issue where, in headed mode with macOS arm64 + Chromium for Testing, `chrome_crashpad_handler` lingers after tests finish and the process hangs. Cleans up leftover processes from the previous run before tests start.

```typescript
// src/global-setup.ts
import { execSync } from 'child_process';

export default function globalSetup() {
  try {
    execSync("pkill -f 'ms-playwright.*chrome_crashpad_handler' 2>/dev/null", { stdio: 'ignore' });
  } catch {
    // Ignore if the process does not exist
  }
}
```

Add `globalSetup: './src/global-setup.ts'` to `playwright.config.ts`.
Since the path is narrowed by `ms-playwright`, regular Chrome / VS Code / other apps are unaffected.

---

## §6. BaseAction / StepCounter Templates

All Actions inherit from BaseAction. The `step()` helper outputs to both the console (user-story granularity) and `test.step()` (hierarchical display in the HTML report). The prefix (`[Suite / Phase]`) is derived automatically from `test.info().titlePath`.

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

  /** Call at the start of every public Action method. Increments the main number */
  protected beginAction(): void {
    this.stepCounter?.nextMain();
  }

  /**
   * Step recording helper
   * Console: [Suite / Phase] Step N: ActionName - details
   * HTML report: test.step() nesting shows Action internals hierarchically
   *
   * Important: errors during fn() execution are NOT caught and propagate as-is.
   *            Only the test-context detection is caught. Prevents false negatives (flaky passes).
   */
  protected async step(name: string, fn: () => Promise<void>): Promise<void> {
    const { prefix, hasTestContext } = this.resolveTestContext();
    const mainNo = this.stepCounter?.currentMain ?? 0;
    // stepCounter injected but mainNo === 0 = beginAction() was forgotten.
    // Do not let it pass silently — throw immediately (early detection of design violations / false-negative prevention)
    if (this.stepCounter && mainNo === 0) {
      throw new Error(
        `[${this.actionName}] beginAction() was not called. Always call this.beginAction() at the start of every public method`
      );
    }
    const stepLabel = mainNo > 0 ? `Step ${mainNo}` : 'Step';
    console.log(`${prefix}${stepLabel}: ${this.actionName} - ${name}`);

    if (hasTestContext) {
      await test.step(name, fn); // HTML report shows only the detail name (visualized via nesting)
    } else {
      await fn();                // Fallback only outside a test context
    }
  }

  /** Build the prefix from test.info().titlePath (extract the part before `:` in describe/test names) */
  private resolveTestContext(): { prefix: string; hasTestContext: boolean } {
    try {
      const info = test.info();
      const parts = info.titlePath.slice(1); // Exclude the file name
      if (parts.length === 0) return { prefix: '', hasTestContext: true };
      const labels = parts.map((p) => this.shortenLabel(p));
      return { prefix: `[${labels.join(' / ')}] `, hasTestContext: true };
    } catch {
      return { prefix: '', hasTestContext: false };
    }
  }

  private shortenLabel(title: string): string {
    // Supports both ASCII `:` and full-width `：` (split on whichever appears first)
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
 * Step number management per Action invocation (continuous counting within describe scope)
 * - Within the same describe, numbering continues across test() boundaries
 * - Entering a different describe resets the number to 1
 */
export class StepCounter {
  private mainNumber = 0;
  private lastDescribeKey: string | null = null;

  /** Call at the start of every public Action method. Resets at describe boundaries, then +1 */
  nextMain(): number {
    const currentKey = this.getDescribeKey();
    if (currentKey !== this.lastDescribeKey) {
      this.mainNumber = 0;
      this.lastDescribeKey = currentKey;
    }
    this.mainNumber++;
    return this.mainNumber;
  }

  /** Current main number (read-only, no increment; for step() display) */
  get currentMain(): number {
    return this.mainNumber;
  }

  private getDescribeKey(): string | null {
    try {
      const info = test.info();
      const parts = info.titlePath;
      // titlePath: [file, ...describes, test]
      // key = file + describes (excluding the trailing test name).
      // Always including the file prevents collisions even when identically named describes exist in different files
      const keyParts = parts.slice(0, -1);
      return keyParts.length > 0 ? keyParts.join('|') : null;
    } catch {
      return null;
    }
  }
}
```

**Prefix composition**:
- Derived automatically from `test.info().titlePath` (in `[file, describe, test]` order)
- The part of the describe / test name before `:` is used as the label (e.g., `'Suite-A: flow name...'` → `'Suite-A'`)
- If there is no `:`, the full name is used
- Supports both ASCII `:` and full-width `：` (splits on whichever appears first)

**Output example**:
```
Console:
[Suite-A / Phase 1] Step 1: LoginAction - Navigate to login page
[Suite-A / Phase 1] Step 1: LoginAction - Enter credentials
[Suite-A / Phase 1] Step 2: NavigationAction - Open main menu
...
[Suite-A / Phase 2] Step 21: LoginAction - Navigate to login page   ← numbering continues within the describe

HTML report (test.step() nesting — Action internals are shown hierarchically here):
  Navigate to login page
  Enter credentials
  Click submit button
  ...
```

> **Meaning of the numbers**: the number is the "Action invocation order within the same describe". With parallel workers, **each worker has its own independent StepCounter**, so numbers from different describes cannot be compared with each other (global ordering cannot be inferred).

---

## §7. .env.example

```
TEST_BASE_URL=
TEST_USER_EMAIL=
TEST_USER_PASSWORD=
```

---

## §8. Coding Conventions

### Required package.json devDependencies / scripts
```json
{
  "scripts": {
    "gate": "bash scripts/gate.sh"
  },
  "devDependencies": {
    "@playwright/test": "^1.50.0",
    "dotenv": "^16.4.0",
    "typescript": "^5.9.0",
    "@types/node": "^22.0.0"
  }
}
```

Keep typescript on the **5.x line** (the fixed-wait check inside the gate's verify uses the TypeScript 5.x JS compiler API; the 7.x line does not expose that API, so the check errors out).

> Without `typescript` and `@types/node`, type checking via `npx tsc --noEmit` cannot run.
> Required to satisfy the type-check requirement of the §1 Definition of Done.
>
> **The `gate` script is required** (machine gate). If you run the gate in CI, add the project's directory to `.github/workflows/gate.yml` or equivalent.

### TypeScript configuration (tsconfig.json)
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

### Code formatting (Prettier)
```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100
}
```

### Naming conventions

| Kind | Convention | Example |
|------|------|---|
| Class | PascalCase | `LoginPage`, `LoginAction` |
| Method | camelCase | `fillEmail()`, `clickButton()` |
| Variable | camelCase | `emailInput`, `userName` |
| Constant | UPPER_SNAKE_CASE | `MAX_RETRY`, `DEFAULT_TIMEOUT` |
| Interface | PascalCase | `TestEnvironment` |

### JSDoc comment conventions
```typescript
/**
 * Description of the method
 * @param email - Email address
 * @param password - Password
 * @returns Whether login succeeded
 */
async execute(email: string, password: string): Promise<boolean> {
  // Implementation
}
```

---

## §9. Converting from the Playwright Default Layout to the 4 Layers

When converting from the Playwright default (spec files directly under `tests/`):

1. Create the 4-layer directories under `src/` (see §2)
2. Create `config/constants.ts` and `config/env.ts` (see §4, §5)
3. Move Locators in spec files → Page Objects in `pages/`
4. Move flow operations in spec files → Actions in `actions/`
5. Create the Fixture definition (see §3) and switch the import source of test
6. Leave only intent and expected results in spec files (Locators and logic prohibited)
7. Move hard-coded values → `constants.ts`
8. Move credentials → `env.ts` + `.env`
9. Confirm all tests pass with `npx playwright test`

**Conversion cautions**:
- Do not convert everything at once. Migrate one test at a time and verify
- Always keep existing tests in a passing state
- Do not forget to register new Actions in the Fixture

---

## §10. Project-Specific Configuration Checklist

When introducing this to a new project, confirm the following and record them in CLAUDE.md:

- [ ] Target product name
- [ ] UI library (Ant Design / MUI / in-house / none)
- [ ] Authentication method (external auth / custom login / SSO / none)
- [ ] State of the HTML semantic layer (presence of data-testid / state of aria-label coverage)
- [ ] SPA or MPA
- [ ] CI/CD environment (CircleCI / GitHub Actions, etc.)
- [ ] **Freezing the Rules total-volume baseline (performed by a human)**: create `.claude/rules-baseline` with the measured value reported by `npm run gate`. **AI agents do not create or modify this file** (their responsibility ends at reporting the measured value to a human and requesting the setting. Freezing or raising it is a human decision that "this volume is correct" — canonical source: the ★ comment on check 21 in `scripts/gate.sh`)

---

## §11. Troubleshooting

### Terminal hangs after a test failure in macOS + Chromium headed mode

**Symptom**: after a failure with `npx playwright test --headed`, the terminal stops accepting commands. Ctrl+C may not work either.

**Cause**: a `chrome_crashpad_handler` process lingers and the parent process is not released. `globalSetup` (§5) is a preventive measure that cleans up leftovers **before the next test run** — it does not resolve the current hang.

**Fix**: from another terminal tab, kill only Playwright's Chromium processes with the following command.

```bash
pkill -f 'ms-playwright'
```

Since the path is narrowed by `ms-playwright`, regular Chrome / VS Code / other apps are unaffected. After the kill, the hung terminal is released.
