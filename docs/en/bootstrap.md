# BOOTSTRAP.md
## Documentation-First Bootstrap (Standard Workflow for Environment Setup)

This document serves as the primary guide for **setting up a Playwright E2E execution environment**.  
For adding tests to an existing environment, refer to **TEST_CREATION_PROTOCOL.md**.

---

## Objectives (Definition of Done)
The following MUST be satisfied:

- `npm test` can be executed (at least 1 smoke test passes)
- Playwright installation and browser dependencies are in place
- Minimal directory structure for 4-layer architecture is prepared
- Authentication and sensitive information are managed via `.env` (or CI environment variables)

---

## Reference Documents (Higher Authority)
- **CLAUDE.md** (Top-level rules. ClaudeCode MUST read this first)
- **E2ETest_Framework.md** (Ideal structure and responsibilities of 4-layer architecture)

---

## Minimal Skeleton for 4-Layer Architecture (Required)

During environment setup, the following minimal directory structure MUST be prepared.
This is the **minimum requirement to establish the 4-layer architecture pattern**.

```
src/
├─ tests/       # Scenarios (write only intent and expected results)
├─ actions/     # User operation flows (Actions)
├─ pages/       # Screen elements and operations (PageObject / Locators go here)
├─ fixtures/    # Fixture definitions (connection between Test and Action layers)
│  └─ app.fixture.ts
└─ config/      # Environment differences, settings, test data
```

## Responsibilities of Each Layer (Summary)
- **tests**: Describe test intent and expected results. MUST NOT write logic or Locators
- **fixtures**: Centralized Action instantiation. Tests MUST import `test`/`expect` from Fixture, NOT from `@playwright/test`
- **actions**: Reusable procedures combining multiple operations
- **pages**: Encapsulate screen structure and operations (Locators MUST be limited to this layer)
- **config**: Environment differences, authentication (via `.env`), fixed data

For detailed responsibility definitions, prohibitions, and impact considerations, refer to `e2e_test_framework.md` as the canonical source.

---

## Procedure (Common for AI/Human)

### 1) Install Dependencies
```bash
npm ci
```
(Use `npm install` for initial setup or when lock file is absent)

### 2) Install Playwright Browsers
```bash
npx playwright install
```
To include system dependencies for CI:
```bash
npx playwright install --with-deps
```

### 3) Prepare Configuration Files
At minimum, verify/generate the following:

- `playwright.config.ts`
- `tsconfig.json`
- `package.json` (MUST include `test` in scripts)
- `.env.example` (MUST NOT contain secrets, only keys)

> For 4-layer architecture directory guidelines, refer to **E2ETest_Framework.md** as canonical.

### 4) Prepare Fixture File
Create a Fixture file to inject Actions into tests.

Example: `src/fixtures/app.fixture.ts`

For details, refer to **E2ETest_Framework.md §10**.

### 5) Prepare 1 Smoke Test
Purpose: Verify that the environment works correctly.

Example: `src/tests/smoke/smoke.spec.ts`

- Import `test`/`expect` from Fixture (direct import from `@playwright/test` is prohibited)
- Access 1 page
- Verify 1 reliable element
- Login if necessary (from env)

### 6) Verify Execution
```bash
npm test
```

---

## Prohibitions (Critical)

- MUST NOT commit authentication credentials, passwords, or tokens to repository
- MUST NOT commit `.env` (`.env.example` is acceptable)
- MUST NOT recreate environment configuration during test creation phase (use TEST_CREATION_PROTOCOL.md instead)

---

## Next Steps
Once the environment is running, proceed to test creation with:

- **TEST_CREATION_PROTOCOL.md**

---

**Last Updated**: 2026-02-02
**Maintainer**: Ray Ishida
