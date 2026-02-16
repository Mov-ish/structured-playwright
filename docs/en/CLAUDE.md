# CLAUDE.md - E2E Test Project Rulebook


## AI Work Phase Identification (Required)

AI work in this repository MUST be classified into one of the following phases.

### 1) Environment Setup Phase (Bootstrap)
- New setup / Playwright environment is not yet configured / Creating initial executable state

👉 In this case, AI MUST first reference **`./bootstrap.md`** and follow the procedures described.

### 2) Test Creation Phase (Test Authoring)
- Adding E2E tests to existing environment / Implementing tests based on user stories / Adding/modifying Actions and PageObjects

👉 In this case, AI MUST reference **`./test_creation_protocol.md`** and work according to the 4-layer architecture and Locator Strategy.

**AI MUST NOT misidentify the work phase.**  
If the phase is unclear, AI MUST ask the human for confirmation before starting work.

---

## Locator Strategy (Final Authority)

When in doubt about Locator selection or design, MUST consult the following and stop judgment here as canonical:

1. `./LOCATOR/Concept/`
2. `./LOCATOR/Universal/`
3. `./LOCATOR/productspecific/PRODUCT_A/`

For implementation examples (quick recipes), refer to `CLAUDE_Selectors.md`; when stuck, refer to `CLAUDE_FAQ.md`.

**Project Name**: E2E Test Framework  
**Target Environment**: Playwright + TypeScript  
**Last Updated**: 2025-10-03

---

## 📚 Reference Documents

This project is built on a **4-layer architecture**.
For detailed architecture definitions, refer to:

👉 **[E2ETest_Framework.md](./E2ETest_Framework.md)** - 4-Layer Architecture Technical Standard

---

## 🎯 Project Overview

This project is a test framework for scenario E2E validation.
Test code MUST be created and managed according to the following principles.

### Architecture Structure

```
Layer 4: Config/Env     → Environment settings, environment variable management
Layer 3: Tests          → Expected result validation (AAA pattern)
Layer 2: Actions        → Business logic, multi-screen flows
Layer 1: Page Objects   → UI element definitions, basic operations
```

For details, refer to `E2ETest_Framework.md`.
When in doubt about structure (Test / Actions / PageObject / Config), use E2ETest_Framework.md as canonical.

---

## 🎨 Project-Specific Characteristics

### HTML Structure Features

**Background of Rule Formalization**:
- **Date**: 2025-10-01 (Updated 2026-01-13)
- **Discovery**: Playwright's recommended selectors (data-testid, semantic) are partially unusable
- **Cause**: Some elements in existing HTML lack `data-testid`, `aria-label`, and other attributes
- **Trial and Error**: Requested attribute additions from frontend team, but difficult due to priority issues
- **Conclusion**: Use semantic locators and CSS selectors based on element characteristics

**Constraints in This Project**:
- ❌ `data-testid` attributes are almost non-existent
- ⚠️ Some elements lack `aria-label` and `label` elements (especially checkboxes, icon buttons)

**Semantic Locator Usage Guidelines**:
- ✅ **Available**: `getByRole('dialog')`, `getByRole('button', { name: '...' })`, `getByPlaceholder()`
- ✅ **Available**: Modals, buttons with text, input fields with placeholder
- ⚠️ **Unavailable (elements with minimal semantic layer)**: Checkboxes without labels, icon-only buttons

**Strategies for Elements with Minimal Semantic Layer**:
- ✅ `:near()` selector (identify by surrounding text)
- ✅ `svg[data-icon]` (icon buttons)
- ✅ CSS selectors + `:has-text()` / `:text-is()`
- ✅ Filter by parent element (Local Universe)

**Details**: 👉 **[CLAUDE_Selectors.md § 1-2](./CLAUDE_Selectors.md)**, **[locator_strategy.md](./LOCATOR/locator_strategy.md)**

---

### Authentication Flow Characteristics

**Authentication in This Project**: External authentication via Auth0

```
1. Terms of Use page (my-app.example.com/login)
   ↓ Check terms → Email login button
2. Auth0 login page (auth.example.com) ← External domain
   ↓ Enter email/password → Login button
3. Application (course list screen, etc.)
```

**Critical**: Due to external domain transitions, the following are required:
- Separate Page Objects (TermsPage / Auth0LoginPage)
- Explicit waiting for URL transitions
- Waiting for screen stabilization

**Details**: 👉 **[CLAUDE_Patterns.md § 1](./CLAUDE_Patterns.md)**

---

### SPA Characteristics

This project is a React SPA with the following characteristics:

**Problem**: Rendering delays occur even after `networkidle`

**Solution**:
```typescript
// Combination of networkidle + waitForTimeout
await page.waitForLoadState('networkidle');
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // 2000ms
```

**Details**: 👉 **[CLAUDE_Patterns.md § 2](./CLAUDE_Patterns.md)**

---

## 🔐 Security & Environment Variable Rules

### Required Rules

#### 1. **Externalization of Authentication Information**
- ❌ **Prohibited**: Hard-coding user IDs and passwords in code
- ✅ **Required**: Load from `.env` file as environment variables

```typescript
// ❌ Anti-pattern
const email = 'user@example.com';
const password = 'password123';

// ✅ Required
const env = EnvConfig.getTestEnvironment();
const email = env.credentials.email;
const password = env.credentials.password;
```

#### 2. **Management of Sensitive Information**
The following information MUST be managed as **environment variables**:

- Email addresses
- Passwords
- Authentication tokens
- API keys
- Test target URLs (if they differ by environment)

#### 3. **.env File Handling**
- `.env` file MUST be included in `.gitignore` (already configured)
- Prepare `.env.example` as a template
- MUST NOT include production environment credentials

---

## 🎯 Locator Strategy Rules

### Project-Specific Constraints

This project's HTML does not have `data-testid`, and some elements lack `aria-label` and `label`.
**Semantic locators MUST be used based on element characteristics.**

For details, refer to `CLAUDE_Selectors.md § 1` and `locator_strategy.md`.

### Locator Priority (This Project)

| Priority | Method | Usability | Notes |
|----------|--------|-----------|-------|
| ❌ 1 | data-testid | **Unavailable** | Attributes do not exist |
| ✅ 2 | Semantic (getByRole, etc.) | **Conditionally Available** | Effective for modals, buttons (with text), input fields with placeholder |
| ✅ 3 | CSS selector + `:has-text()` / `:text-is()` | **Recommended** | Works stably |
| ✅ 4 | `:near()` selector | **Recommended** | Effective for elements with minimal semantic layer (checkboxes, etc.) |
| ✅ 5 | `svg[data-icon]` | **Recommended** | Effective for icon buttons |
| ✅ 6 | Attribute selectors (name, type) | **Recommended** | Effective for form elements |
| ⚠️ 7 | Structural selectors (parent-child) | **Last Resort** | Fragile to changes, comment required |

### Required Rules

**❌ Anti-patterns**
```typescript
// text= locator (does not work in this project)
page.locator(`text=${groupName}`)
page.locator('text=ログイン')

// Semantic locator for elements with minimal semantic layer (does not work)
page.getByLabel('同意する')  // ❌ No label element
page.getByRole('checkbox')              // ❌ Cannot uniquely identify
```

**✅ Recommended Patterns**
```typescript
// Semantic locators (elements with semantic layer)
page.getByRole('dialog', { name: 'テキストを追加' })  // Modal
page.getByRole('button', { name: '保存' })            // Button with text
page.getByPlaceholder('検索')                         // Input field with placeholder

// CSS selector + :has-text() / :text-is()
page.locator('button:has-text("ログイン")')
page.locator('span:text-is("コース一覧")')  // Exact match

// :near() selector (elements with minimal semantic layer)
page.locator('input[type="checkbox"]:near(:text("同意する"))')

// svg[data-icon] (icon buttons)
page.locator('button:has(svg[data-icon="edit"])')
page.locator('button:has(svg[data-icon="ellipsis"])')

// Attribute selectors (form elements)
page.locator('input[name="email"]')
page.locator('input[type="password"]')

// Filter by parent element (Local Universe)
page.locator('[role="dialog"] button:has-text("保存")')
```

### Error Banner Detection

```typescript
// ✅ Detect with CSS selector
await expect(page.locator('[role="alert"]')).toBeVisible();
await expect(page.locator('[role="alert"]')).toContainText('エラーメッセージ');
```

---

## 🚫 Prohibition Summary

| Prohibition | Reason | Alternative | Details |
|-------------|--------|-------------|---------|
| Hard-coding authentication info | Security risk | Environment variables (.env) | §Security & Environment Variable Rules |
| Hard-coding timeout values | Reduced maintainability | TIMEOUTS constants | E2ETest_Framework.md §6.2 |
| Hard-coding common selectors | Lack of consistency | SELECTORS constants | E2ETest_Framework.md §6.2 |
| Hard-coding URL patterns | Missing fixes during environment changes | URL_PATTERNS constants | E2ETest_Framework.md §6.2 |
| Defining locators with `private readonly` | Difficult debugging | `readonly` (public) | E2ETest_Framework.md §3.2 |
| Omitting intermediate step logs in Actions | Difficult cause identification | console.log at each step | E2ETest_Framework.md §4.2 |
| Omitting login success validation | Unclear cause when subsequent tests fail | URL verification logic | CLAUDE_Patterns.md §1.4.1 |
| Casual use of `.first()` | Reduced maintainability | Specific selectors, `:near()` | CLAUDE_Selectors.md §3 |
| `text=` locator | Does not work in this project | CSS selector + :has-text() | §Locator Strategy Rules |
| Semantic locators for elements with minimal semantic layer | Insufficient attributes | `:near()`, `svg[data-icon]` | §Locator Strategy Rules |
| Importing `test` directly from `@playwright/test` | High coupling without Fixture | Import from Fixture file | E2ETest_Framework.md §10 |
| Manually `new`ing Actions | Dependencies not explicit | Receive via Fixture arguments | E2ETest_Framework.md §10 |
| **`.catch(() => false)` pattern** | **Timeout error concealment, false positives** | **`expect().toBeVisible()` + try-catch** | **CLAUDE_Patterns.md §5.3** |

---

## ⏱️ Waiting Logic Rules

### Principle: Wait for Screen Rendering

#### ⚠️ Minimize: Fixed-Time Waiting

```typescript
// ❌ Prohibited: No comment, no constants
await page.waitForTimeout(5000);

// ✅ Acceptable: TIMEOUTS constant + reason comment
// Wait for SPA rendering to complete (networkidle alone is insufficient)
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
```

`waitForTimeout` MUST be **minimized**, and when used, the following are required:
- **Use TIMEOUTS constants** (numeric hard-coding prohibited)
- **Document reason in comments**

**Detailed Usage**: 👉 Refer to **[CLAUDE_Patterns.md § 2](./CLAUDE_Patterns.md)**

#### ✅ Recommended: State-Based Waiting

**Wait for URL Transition**
```typescript
// URL pattern match
await expect(page).toHaveURL(/\/groups\/\w+/);

// Specific URL path
await expect(page).toHaveURL(/.*\/dashboard/);
```

**Wait for Element Visibility**
```typescript
// Heading visibility
await expect(page.locator('h1:has-text("学習目標")')).toBeVisible();

// Button enablement
await expect(page.locator('button:has-text("ログイン")')).toBeEnabled();

// Locator visibility
await loginPage.emailInput.waitFor({ state: 'visible', timeout: 10000 });
```

**Network Waiting**
```typescript
// Network idle wait
await page.waitForLoadState('networkidle');

// DOM content loaded
await page.waitForLoadState('domcontentloaded');
```

#### ✅ Advanced: Utilizing expect.poll

When polling for dynamic values:

```typescript
await expect.poll(async () => {
  const count = await page.locator('.item').count();
  return count;
}, {
  timeout: 10000,
  message: 'Item count did not reach expected value'
}).toBeGreaterThan(0);
```

---

## 🧪 Test Code Quality Rules

### 1. **Internal Testing Required After Code Generation**

After generating or modifying test code, **MUST execute and verify functionality**.

```bash
# Run tests
npm test

# Run specific test only
npx playwright test src/tests/scenarios/login.spec.ts

# Run in headed mode
npm run test:headed
```

### 2. **Dependency Verification on Changes**

When modifying test code, verify the following:

- ✅ Impact on Actions using modified Page Objects
- ✅ Impact on Tests using modified Actions
- ✅ Impact on all tests when modifying common modules

### 3. **Thorough Result Validation**

Tests MUST **verify not only behavior but also results**.

```typescript
// ❌ Anti-pattern: Only behavior, no result verification
await loginAction.execute(email, password);
// Test ends

// ✅ Required: Explicitly verify results
await loginAction.execute(email, password);
expect(page.url()).not.toContain('/login');
await expect(page.locator('h1:has-text("ダッシュボード")')).toBeVisible();
```

### 4. **Data Cleanup Implementation**

After test completion, created data MUST be cleaned up.

```typescript
// ✅ Receive Actions via Fixture
// Note: Test names and test data are in Japanese because the target application has a Japanese UI
test('新規グループ作成テスト', async ({ createGroupAction, deleteGroupAction, page }) => {
  // Arrange
  const groupName = `テストグループ_${Date.now()}`;

  // Act
  await createGroupAction.execute(groupName);

  // Assert
  await expect(page.getByText(groupName)).toBeVisible();

  // Cleanup (Critical!)
  await deleteGroupAction.execute(groupName);
});
```

Or utilize `test.afterEach`:

```typescript
test.afterEach(async ({ cleanupAction }) => {
  // Post-test cleanup
  await cleanupAction.execute();
});
```

---

## 📁 Directory Structure

```
src/
├── config/          # Layer 4: Environment settings
│   └── env.ts
├── pages/           # Layer 1: Page Objects
│   ├── LoginFormPage.ts
│   ├── TermsPage.ts
│   └── DashboardPage.ts
├── actions/         # Layer 2: Actions
│   └── LoginAction.ts
├── fixtures/        # Fixture definitions (Test layer infrastructure)
│   └── app.fixture.ts
└── tests/           # Layer 3: Tests
    └── scenarios/
        └── login.spec.ts
```

For details, refer to `E2ETest_Framework.md`.

---

## 🚀 Development Commands

```bash
# Run tests
npm test                    # Run all tests
npm run test:headed         # Browser display mode
npm run test:debug          # Debug mode
npm run test:ui             # Playwright UI mode

# Display reports
npm run report              # Display HTML report
```

---

## ✅ Test Creation Checklist

When creating new tests, verify the following:

### When Creating Page Objects

- [ ] Define locators with `readonly`
- [ ] Follow locator priority (semantic → :has-text() → :near() → data-icon)
- [ ] Use `:near()` and `svg[data-icon]` for elements with minimal semantic layer
- [ ] Implement only single-responsibility methods
- [ ] Do not include business logic
- [ ] Write JSDoc comments

### When Creating Actions

- [ ] Hold used Page Objects as private fields
- [ ] Implement main flow in `execute()` method
- [ ] Appropriate waiting logic (`waitForTimeout` minimized + comment required)
- [ ] Output progress with console logs
- [ ] Implement error handling
- [ ] **For new Actions, register in Fixture file**

### When Creating Tests

- [ ] Import `test`/`expect` from Fixture file (direct import from `@playwright/test` prohibited)
- [ ] Do not manually `new` Actions, receive via Fixture arguments
- [ ] Follow AAA (Arrange-Act-Assert) pattern
- [ ] Retrieve authentication info from environment variables
- [ ] Validation following locator priority
- [ ] MUST implement result validation
- [ ] Implement data cleanup
- [ ] Execute and verify functionality

---

## 🔍 Code Review Perspectives

When submitting pull requests, verify the following:

1. **Security**
   - Authentication info not hard-coded
   - `.env` file included in `.gitignore`

2. **Locators**
   - Not using `text=` locator
   - Following locator priority
   - Using `:near()` and `svg[data-icon]` for elements with minimal semantic layer
   - Avoiding structure-dependent selectors

3. **Waiting Logic**
   - Not unnecessarily using `waitForTimeout`
   - Using state-based waiting

4. **Test Quality**
   - Importing `test`/`expect` from Fixture file (direct import from `@playwright/test` prohibited)
   - Receiving Actions via Fixture arguments, not manually `new`ing
   - Result validation implemented
   - Data cleanup implemented
   - Tests are executable (functionality verified)

---

## ⚡ Quick Checklist

### When Creating Page Objects
- [ ] Add `import { TIMEOUTS, SELECTORS } from '../config/constants';`
- [ ] Define locators with `readonly` (`private readonly` prohibited)
- [ ] Follow locator priority (semantic → :has-text() → :near() → data-icon)
- [ ] Load common selectors from `SELECTORS`
- [ ] Avoid `.first()` as much as possible (comment required when used)

### When Creating Actions
- [ ] Add `import { TIMEOUTS, URL_PATTERNS } from '../config/constants';`
- [ ] Hold Page Objects as private fields
- [ ] Combine state-based waiting + waitForTimeout
- [ ] Document reason in comments when using waitForTimeout
- [ ] **console.log output at each step** (required)
- [ ] **LoginAction MUST implement login success validation** (required)

### When Creating Tests
- [ ] **Import `test`/`expect` from Fixture file** (required)
- [ ] **Receive Actions via Fixture arguments, not manually `new`ing** (required)
- [ ] Follow AAA pattern
- [ ] Retrieve authentication info from environment variables
- [ ] Implement result validation
- [ ] **Execute and verify functionality** (most critical!)

---

## 📝 Adding & Updating Rules

### How to Add New Rules

1. **Discover deficiency through test execution**
2. **Identify cause**: Ambiguity? Undefined conditions?
3. **Add to appropriate document**:
   - Selector-related → `CLAUDE_Selectors.md`
   - Pattern-related → `CLAUDE_Patterns.md`
   - Error handling → `CLAUDE_FAQ.md`
4. **Record background of rule formalization**:
   - Date, discovery, cause, trial and error, conclusion

### Generalization Flow

Conduct periodic (monthly or quarterly) reviews:

```
1. Review CLAUDE_xxx.md
   ↓
2. Identify patterns usable in other projects
   ↓
3. Move to E2ETest_Framework.md (as concrete examples)
   ↓
4. Delete from CLAUDE_xxx.md or replace with reference link
```

---

## 📖 Reference Links

- [E2ETest_Framework.md](./E2ETest_Framework.md) - 4-Layer Architecture Details
- [CLAUDE_Selectors.md](./CLAUDE_Selectors.md) - Selector Strategy & Pattern Collection
- [CLAUDE_Patterns.md](./CLAUDE_Patterns.md) - Implementation Patterns & Success Cases
- [CLAUDE_FAQ.md](./CLAUDE_FAQ.md) - Troubleshooting
- [Playwright Official Documentation](https://playwright.dev/)
- [Playwright Locator Strategy](https://playwright.dev/docs/locators)

---

## License

MIT License

---

**Last Updated**: 2026-01-13
**Maintainer**: Ray Ishida
