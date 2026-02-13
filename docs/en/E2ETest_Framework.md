# E2E Test Framework - 4-Layer Architecture Technical Standard

**Document Version**: 1.0

**Created**: September 30, 2025

**Audience**: Developers, QA Engineers

## Document Positioning (4th)

This document defines the **structural canon of 4-layer architecture** in Playwright E2E.

- Refer to `bootstrap.md` for environment setup procedures
- Refer to `test_creation_protocol.md` for test creation workflow
- This document is used to determine "what to write in which layer" and "where not to write"

This document is **not intended for regular reading**.  
Referenced as final judgment when confused about structure, responsibilities, or placement.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Directory Structure](#2-directory-structure)
3. [Layer 1: Page Objects](#3-layer-1-page-objects)
4. [Layer 2: Actions](#4-layer-2-actions)
5. [Layer 3: Tests](#5-layer-3-tests)
6. [Layer 4: Config/Env](#6-layer-4-configenv)
7. [Naming Conventions](#7-naming-conventions)
8. [Coding Standards](#8-coding-standards)
9. [Error Handling](#9-error-handling)
10. [Fixture Definition](#10-fixture-definition)
11. [Test Data Management](#11-test-data-management)

---

## 1. Architecture Overview

### 1.1 4-Layer Structure

```
┌─────────────────────────────────────┐
│ Layer 4: Config/Env                 │  ← Environment configuration
├─────────────────────────────────────┤
│ Layer 3: Tests                      │  ← Expected result verification
├─────────────────────────────────────┤
│ Layer 2: Actions                    │  ← Business logic
├─────────────────────────────────────┤
│ Layer 1: Page Objects               │  ← UI element management
└─────────────────────────────────────┘
```

### 1.2 Separation of Responsibilities Principle

| Layer | Responsibility | Reason for Change |
| --- | --- | --- |
| **Page Objects** | UI element definition and basic operations | HTML structure changes |
| **Actions** | Business flows, multi-page control | Business procedure changes |
| **Tests** | Expected result definition and verification | Test perspective changes |
| **Config/Env** | Environment-dependent configuration values | Environment changes |

### 1.3 Design Principles

**Single Responsibility Principle (SRP)**

- Each class has only one responsibility
- Only one reason to change

**Open-Closed Principle (OCP)**

- Open for extension
- Closed for modification

**Dependency Inversion Principle (DIP)**

- Upper layers depend on lower layers
- Lower layers do not depend on upper layers

---

## 2. Directory Structure

### 2.1 Standard Directory Structure

```
e2e-tests/
├── .circleci/
│   └── config.yml                    # CI/CD configuration
├── src/
│   ├── config/                       # Layer 4: Configuration
│   │   ├── env.ts                   # Environment variable management
│   │   └── constants.ts             # Constant definitions
│   ├── pages/                       # Layer 1: Page Objects
│   │   ├── BasePage.ts              # Base class
│   │   ├── LoginPage.ts
│   │   ├── CoursePage.ts
│   │   └── DashboardPage.ts
│   ├── actions/                     # Layer 2: Actions
│   │   ├── BaseAction.ts            # Base class
│   │   ├── LoginAction.ts
│   │   ├── CourseEnrollmentAction.ts
│   │   └── UserProfileAction.ts
│   ├── tests/                       # Layer 3: Tests
│   │   ├── scenarios/               # Scenario tests
│   │   │   ├── user-journey.spec.ts
│   │   │   └── course-management.spec.ts
│   │   ├── smoke/                   # Smoke tests
│   │   │   └── login-smoke.spec.ts
│   │   └── regression/              # Regression tests
│   │       └── critical-path.spec.ts
│   ├── fixtures/                    # Playwright Fixture definitions + test data
│   │   ├── app.fixture.ts          # Fixture definition (Action injection)
│   │   ├── users.json
│   │   └── courses.json
│   └── utils/                       # Utilities
│       ├── logger.ts
│       └── helpers.ts
├── screenshots/                     # Screenshot storage
├── test-results/                    # Test results
├── playwright-report/               # HTML report
├── .env.example                     # Environment variable template
├── .gitignore
├── package.json
├── tsconfig.json
├── playwright.config.ts
└── README.md
```

### 2.2 File Naming Conventions

| Type | Pattern | Example |
| --- | --- | --- |
| **Page Object** | `{ScreenName}Page.ts` | `LoginPage.ts` |
| **Action** | `{FunctionName}Action.ts` | `LoginAction.ts` |
| **Test** | `{TestTarget}.spec.ts` | `user-journey.spec.ts` |
| **Config** | `{ConfigType}.ts` | `env.ts` |
| **Fixture Definition** | `{ScopeName}.fixture.ts` | `app.fixture.ts` |
| **Fixture Data** | `{DataType}.json` | `users.json` |

---

## 3. Layer 1: Page Objects

### 3.1 Basic Structure

```typescript
import { Page, Locator } from '@playwright/test';

/**
 * [Screen Name] Page Object class
 *
 * Responsibilities:
 * - UI element (locator) definition
 * - Basic operation methods for single elements
 * - Page-specific state check methods
 *
 * Reason for Change: UI structure (HTML/CSS/selector) changes
 */
export class XxxPage {
  readonly page: Page;

  // UI element definition (readonly for immutability)
  readonly element1: Locator;
  readonly element2: Locator;

  constructor(page: Page) {
    this.page = page;

    // Selector definition
    // Prioritize data-testid attribute
    this.element1 = page.locator('[data-testid="element1"]');
    this.element2 = page.getByRole('button', { name: 'Button Name' });
  }

  /**
   * Basic operation method
   * Single responsibility, one operation for one element
   */
  async fillSomething(value: string): Promise<void> {
    await this.element1.fill(value);
  }

  async clickSomething(): Promise<void> {
    await this.element2.click();
  }

  /**
   * State check method
   */
  async isVisible(): Promise<boolean> {
    return await this.element1.isVisible();
  }

  async getText(): Promise<string> {
    return await this.element1.textContent() || '';
  }
}
```

### 3.2 Page Object Creation Guidelines

### Locator Principles
- Locators MAY ONLY exist in this layer
- Locator judgment criteria MUST follow Strategy under locator/
- MUST NOT place Locators whose stability reason cannot be explained

**Required**

- ✅ All locators defined with `readonly` (**`private readonly` PROHIBITED**)
- ✅ Prioritize `data-testid` attribute for selectors
- ✅ Methods have single responsibility (1 method = 1 operation)
- ✅ Do not include complex logic
- ✅ Write JSDoc comments

**Locator Definition Rules (MUST)**

```typescript
// ❌ Prohibited: private readonly
export class Auth0LoginPage extends BasePage {
  private readonly emailInput: Locator;  // ← Prohibited
  private readonly passwordInput: Locator;
}

// ✅ Required: readonly (publicly accessible)
export class Auth0LoginPage extends BasePage {
  readonly emailInput: Locator;  // ← Correct
  readonly passwordInput: Locator;
}
```

**Reasons**:
- Page Objects are interfaces for testing, not internal implementation
- Convenient to directly access elements from tests during debugging
- Maintain consistent design pattern

**Prohibitions**

- ❌ Define locators with `private readonly`
- ❌ Include business logic
- ❌ Operations spanning multiple pages
- ❌ Expected result verification (expect)
- ❌ Wait time determination (done in Action layer)
- ❌ Hold environment-dependent values

### 3.3 Selector Priority

```typescript
// Priority 1: data-testid attribute (most stable)
page.locator('[data-testid="login-button"]')

// Priority 2: role + name (semantic)
page.getByRole('button', { name: 'Login' })

// Priority 3: label (form elements)
page.getByLabel('Email Address')

// Priority 4: placeholder
page.getByPlaceholder('Enter Email Address')

// Priority 5: CSS class/ID (last resort)
page.locator('.login-button')
```

### 3.4 Managing Complex Elements

```typescript
export class CoursePage {
  // Manage by grouping
  readonly search = {
    input: this.page.locator('[data-testid="search-input"]'),
    button: this.page.locator('[data-testid="search-button"]'),
    suggestions: this.page.locator('[data-testid="suggestions"]')
  };

  readonly filters = {
    category: this.page.locator('[data-testid="filter-category"]'),
    price: this.page.locator('[data-testid="filter-price"]'),
    apply: this.page.locator('[data-testid="apply-filters"]')
  };
}
```

---

## 4. Layer 2: Actions

### Design Guidelines
- Actions SHOULD be divided at "granularity where user intent is readable"
- MUST NOT include test-specific expect or assertions
- SHOULD NOT promote processes not reused by multiple tests to Actions

### 4.1 Basic Structure

```typescript
import { Page } from '@playwright/test';
import { BaseAction } from './BaseAction';
import { XxxPage } from '../pages/XxxPage';
import { TIMEOUTS } from '../config/constants';  // ← Required import

/**
 * [Function Name] Action class
 *
 * Responsibilities:
 * - Business flow implementation
 * - Multi-page operations
 * - Error handling and waiting logic
 * - Combination of Page Objects
 *
 * Reason for Change: Business procedure/flow changes
 */
export class XxxAction extends BaseAction {
  private xxxPage: XxxPage;
  private yyyPage: YyyPage;

  // NOTE: Instantiated from Fixture, so only page as argument
  constructor(page: Page) {
    super(page, 'Action Name (Japanese)');
    this.xxxPage = new XxxPage(page);
    this.yyyPage = new YyyPage(page);
  }

  /**
   * Main execution method
   * Implement complete business flow
   */
  async execute(...args: any[]): Promise<void> {
    console.log('Step 1: XXX');
    await this.xxxPage.doSomething();
    await this.page.waitForLoadState('networkidle');

    console.log('Step 2: YYY');
    await this.yyyPage.doSomethingElse();
    // Wait for SPA rendering completion (reason comment required)
    await this.page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);  // ← Use constants

    console.log('Step 3: Completion check');
    // ...
  }

  /**
   * Variation method
   * Handle different patterns
   */
  async executeWithOptions(options: Options): Promise<void> {
    // ...
  }
}
```

### 4.2 Action Creation Guidelines

**Required**

- ✅ Inherit `BaseAction`
- ✅ Hold Page Objects used as private fields
- ✅ Implement main flow in `execute()` method
- ✅ **Output console log at each step** (MUST)
- ✅ Include appropriate waiting logic
- ✅ Implement error handling

**Log Output Rules (MUST)**

```typescript
// ❌ Prohibited: Only start/end logs
async execute(url: string, email: string, password: string): Promise<void> {
  console.log('=== Login Started ===');
  // ... processing ...
  console.log('=== Login Completed ===');
}

// ✅ Required: Log output at each step
async execute(url: string, email: string, password: string): Promise<void> {
  console.log('=== Login Process Started ===');

  console.log(`Step 1: Page transition - ${url}`);
  await this.termsPage.goto(url);

  console.log('Step 2: Agree to terms');
  await this.termsPage.agreeToTerms();

  console.log('Step 3: Click email login button');
  await this.termsPage.clickEmailLogin();

  console.log('Step 4: Wait for Auth0 page transition');
  await this.page.waitForURL(URL_PATTERNS.AUTH0_LOGIN, { timeout: TIMEOUTS.DEFAULT });

  // ... continue similarly ...

  console.log('=== Login Process Completed ===');
}
```

**Log Output Format**:
- Start: `'=== {Action Name} Process Started ==='`
- Each step: `'Step {number}: {operation content}'`
- Complete: `'=== {Action Name} Process Completed ==='`
- Error: `console.error('{Action Name} error occurred:', error)`

**Reason**: Easy to identify cause when failed in CI/CD environment

**Prohibitions**

- ❌ Directly use UI element selectors
- ❌ Expected result verification (expect)
- ❌ Direct reference to environment configuration values
- ❌ Omit intermediate step logs

### 4.3 Waiting Logic Best Practices

```typescript
// ✅ Good: Explicit waiting
await this.page.waitForLoadState('networkidle');
await this.loginPage.emailInput.waitFor({ state: 'visible', timeout: 5000 });

// ✅ Good: Conditional waiting
await this.page.waitForFunction(() => {
  return document.querySelectorAll('.course-item').length > 0;
});

// ⚠️ Avoid: Fixed-time waiting (last resort, constants + comment required)
// Wait for modal animation to complete
await this.page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
```

### 4.4 Error Handling

```typescript
async execute(email: string, password: string): Promise<void> {
  try {
    // Terms of use screen (optional)
    await this.loginPage.termsCheckbox.waitFor({
      state: 'visible',
      timeout: 5000
    });
    await this.loginPage.acceptTerms();
  } catch (error) {
    console.log('Terms of use screen skipped (already agreed)');
  }

  // Main process
  await this.loginPage.fillEmail(email);
  await this.loginPage.fillPassword(password);
  await this.loginPage.clickLogin();
}
```

---

## 5. Layer 3: Tests

### 5.1 Basic Structure

```typescript
// ✅ Required: Import test/expect from Fixture file
import { test, expect } from '../fixtures/app.fixture';
import { EnvConfig } from '../config/env';

test.describe('Test Suite Name', () => {

  // ✅ Required: Receive only Actions used via Fixture
  test('Test Case Name (Specific)', async ({ xxxAction, page }) => {
    // Arrange
    const env = EnvConfig.getTestEnvironment();

    // Act
    await xxxAction.execute(param1, param2);

    // Assert
    expect(await xxxAction.isSuccess()).toBeTruthy();
    expect(page.url()).toContain('/success');
  });

});
```

**Fixture Rules (MUST)**
- ❌ `import { test, expect } from '@playwright/test'` is **PROHIBITED** (go through Fixture)
- ❌ `const action = new XxxAction(page)` is **PROHIBITED** (receive via Fixture)
- ✅ `import { test, expect } from '../fixtures/app.fixture'` is **REQUIRED**
- ✅ Declare only Actions needed in test function arguments

### 5.2 Test Creation Guidelines

**Required**

- ✅ Follow AAA (Arrange-Act-Assert) pattern
- ✅ 1 test case = 1 verification perspective
- ✅ Test names in Japanese, specific
- ✅ Maintain independence (do not depend on other tests)
- ✅ Clear verification with expect()

**Prohibitions**

- ❌ Complex logic (move to Action layer)
- ❌ Direct UI element operations
- ❌ Hard-coded environment-dependent values
- ❌ Dependency on other test cases
- ❌ MUST NOT directly write Locators
- ❌ MUST NOT write logic depending on page structure or DOM
- ❌ MUST NOT have business logic with conditional branching

### 5.3 Structuring Tests

```typescript
test.describe('Login Functionality', () => {

  test.describe('Normal Cases', () => {
    test('Can login with valid credentials', async ({ page }) => {
      // ...
    });

    test('Redirected to dashboard after login', async ({ page }) => {
      // ...
    });
  });

  test.describe('Error Cases', () => {
    test('Error message displayed with invalid email', async ({ page }) => {
      // ...
    });

    test('Error message displayed with empty password', async ({ page }) => {
      // ...
    });
  });

});
```

### 5.4 Validation Best Practices

```typescript
// ✅ Good example: Clear validations
expect(await loginPage.isLoggedIn()).toBeTruthy();
expect(page.url()).toContain('/dashboard');
expect(await dashboardPage.getWelcomeMessage()).toBe('おかえりなさい');

// ✅ Good example: Multiple item validation
const courseCount = await coursePage.getCourseCount();
expect(courseCount).toBeGreaterThan(0);
expect(courseCount).toBeLessThanOrEqual(50);

// ❌ Anti-pattern: Ambiguous validation
expect(true).toBeTruthy(); // What is being validated is unclear
```

---

## 6. Layer 4: Config/Env

### Handling Environment Dependencies
- Authentication information, URLs, environment differences MUST be obtained from `.env` or CI environment variables
- MUST NOT directly embed environment-dependent values in PageObject or Actions

### 6.1 Environment Variable Management

```typescript
// config/env.ts
import * as dotenv from 'dotenv';

dotenv.config();

export interface TestEnvironment {
  baseUrl: string;
  credentials: {
    email: string;
    password: string;
  };
  timeout: {
    default: number;
    long: number;
  };
}

export class EnvConfig {
  static getTestEnvironment(): TestEnvironment {
    return {
      baseUrl: process.env.TEST_BASE_URL || '',
      credentials: {
        email: process.env.TEST_USER_EMAIL || '',
        password: process.env.TEST_USER_PASSWORD || '',
      },
      timeout: {
        default: 10000,
        long: 30000,
      },
    };
  }

  static validateEnvironment(): void {
    const required = [
      'TEST_BASE_URL',
      'TEST_USER_EMAIL',
      'TEST_USER_PASSWORD'
    ];

    const missing = required.filter(key => !process.env[key]);

    if (missing.length > 0) {
      throw new Error(`Required environment variables not set: ${missing.join(', ')}`);
    }
  }
}
```

### 6.2 Constants Management

#### Required Rules (MUST)

**❌ Prohibited: Hard-coded Numbers/URL Patterns**
```typescript
// ❌ Hard-coded timeout values (prohibited)
await page.waitForTimeout(2000);

// ❌ Hard-coded URL patterns (prohibited)
await this.page.waitForURL('**/u/login**', { timeout: 10000 });
```

**✅ Required: Import from constants.ts**
```typescript
import { TIMEOUTS, URL_PATTERNS } from '../config/constants';

// ✅ Correct implementation
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
await this.page.waitForURL(URL_PATTERNS.AUTH0_LOGIN, { timeout: TIMEOUTS.REDIRECT });
```

#### Standard Constants Definition Structure

```typescript
// config/constants.ts

export const TIMEOUTS = {
  SHORT: 3000,
  MEDIUM: 10000,
  LONG: 30000,
  DEFAULT: 10000,              // Default timeout
  AUTH0_STABILIZATION: 2000,   // Auth0 screen stabilization wait
  MODAL_ANIMATION: 1000,       // Modal animation completion wait
  SPA_RENDERING: 2000,         // SPA rendering completion wait
  REDIRECT: 3000,              // Redirect completion wait
} as const;

export const SELECTORS = {
  COMMON: {
    LOADING: '[data-testid="loading"]',
    ERROR: '[data-testid="error"]',
    MODAL: '[role="dialog"]',
    SUBMIT_BUTTON: 'button[type="submit"]',
  },
} as const;

export const URL_PATTERNS = {
  AUTH0_LOGIN: '**/auth.example.com/**',
  DASHBOARD: '**/dashboard**',
  LOGIN: '**/login**',
  // Add project-specific URL patterns
} as const;

export const TEST_DATA = {
  VALID_EMAIL: 'test@example.com',
  INVALID_EMAIL: 'invalid-email',
} as const;
```

#### When New Constants Needed

1. First add constant to `constants.ts`
2. Then reference at usage location as `TIMEOUTS.XXX` / `URL_PATTERNS.XXX`
3. **NEVER hard-code**

---

## 7. Naming Conventions

### 7.1 TypeScript Naming Conventions

| Type | Convention | Examples |
| --- | --- | --- |
| **Classes** | PascalCase | `LoginPage`, `LoginAction` |
| **Methods** | camelCase | `fillEmail()`, `clickButton()` |
| **Variables** | camelCase | `emailInput`, `userName` |
| **Constants** | UPPER_SNAKE_CASE | `MAX_RETRY`, `DEFAULT_TIMEOUT` |
| **Interfaces** | PascalCase | `TestEnvironment`, `UserData` |
| **Type Aliases** | PascalCase | `PageOptions`, `ActionResult` |

### 7.2 Test Name Naming Conventions

```typescript
// ✅ Good example: Specific and understandable
test('Can login with valid credentials', async ({ page }) => {});
test('Error message displayed with invalid email address', async ({ page }) => {});
test('Course search displays 10 results', async ({ page }) => {});

// ❌ Anti-pattern: Abstract and unclear
test('Login test', async ({ page }) => {});
test('Error check', async ({ page }) => {});
test('test1', async ({ page }) => {});
```

---

## 8. Coding Conventions

### 8.1 TypeScript Configuration

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

### 8.2 Code Formatting

**Prettier Configuration**

```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100
}
```

### 8.3 Comment Conventions

```typescript
/**
 * Method description
 *
 * @param email - Email address
 * @param password - Password
 * @returns Whether login succeeded
 *
 * @example
 * ```typescript
 * const result = await loginAction.execute('user@example.com', 'password');
 * ```
 */
async execute(email: string, password: string): Promise<boolean> {
  // Implementation
}
```

---

## 9. Error Handling

### 9.1 Error Handling Principles

```typescript
// ✅ Good example: Specific error message
throw new Error(`Login failed. Email: ${email}`);

// ❌ Anti-pattern: Unclear error
throw new Error('An error occurred');
```

### 9.2 Retry Logic

```typescript
async executeWithRetry(maxRetries: number = 3): Promise<void> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await this.execute();
      return;
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      console.log(`Retry ${i + 1}/${maxRetries}`);
      // Wait before retry
      await this.page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
    }
  }
}
```

---

## 10. Fixture Definition

### 10.1 Fixture Role

Fixture is a mechanism to **centrally manage connections** between Test layer and Action layer.
Uses Playwright's `test.extend()` to consolidate Action instantiation in Fixture.

Fixture positioning in 4-layer architecture:
```
Layer 3: Tests ─── Import test/expect from Fixture, receive Action as argument
                    │
              [Fixture Definition] ← Centrally manage Action instantiation
                    │
Layer 2: Actions ── Operate receiving page (unaware of Fixture existence)
```

Fixture is not a new layer but functions as **Test layer infrastructure** (import/instantiation mechanism).

### 10.2 Basic Fixture Definition Structure

```typescript
// fixtures/app.fixture.ts
import { test as base } from '@playwright/test';
import { LoginAction } from '../actions/LoginAction';
import { XxxAction } from '../actions/XxxAction';
import { YyyAction } from '../actions/YyyAction';

// Type definition for Actions provided by Fixture
type AppFixtures = {
  loginAction: LoginAction;
  xxxAction: XxxAction;
  yyyAction: YyyAction;
};

// Register Actions with test.extend()
export const test = base.extend<AppFixtures>({
  loginAction: async ({ page }, use) => {
    await use(new LoginAction(page));
  },
  xxxAction: async ({ page }, use) => {
    await use(new XxxAction(page));
  },
  yyyAction: async ({ page }, use) => {
    await use(new YyyAction(page));
  },
});

export { expect } from '@playwright/test';
```

### 10.3 Fixture Creation Guidelines

**Required**
- ✅ Register all Action classes in Fixture
- ✅ MUST include `export { expect } from '@playwright/test'`
- ✅ Specify Actions provided with type definition (`AppFixtures`)
- ✅ Action constructor takes only `page` as argument

**Prohibitions**
- ❌ Do not include business logic in Fixture
- ❌ Do not call Action methods in Fixture (instantiation only)
- ❌ Do not directly import `test` from `@playwright/test` in test files

**Steps When Adding New Action**
1. Create Action class in `actions/`
2. Add import and registration to Fixture definition file
3. Declare as argument in test file and use

---

## 11. Test Data Management

### 11.1 Using Fixture Data

```typescript
// fixtures/users.json
{
  "validUser": {
    "email": "valid@example.com",
    "password": "ValidPass123"
  },
  "invalidUser": {
    "email": "invalid@example.com",
    "password": "wrong"
  }
}

// Usage in tests
import { test, expect } from '../fixtures/app.fixture';
import users from '../fixtures/users.json';

test('Login with valid user', async ({ loginAction }) => {
  await loginAction.execute(users.validUser.email, users.validUser.password);
});
```

### 11.2 Test Data Generation

```typescript
// utils/testDataGenerator.ts
export class TestDataGenerator {
  static generateEmail(): string {
    return `test-${Date.now()}@example.com`;
  }

  static generatePassword(): string {
    return `Pass${Math.random().toString(36).substring(7)}123`;
  }
}
```

---

## Appendix

### A. Checklist

**When Creating Page Objects**

- [ ] Define locators with `readonly`
- [ ] Prioritize `data-testid` for selector definition
- [ ] Single-responsibility methods only
- [ ] Write JSDoc comments

**When Creating Actions**

- [ ] Inherit `BaseAction`
- [ ] Use Page Objects
- [ ] Appropriate waiting logic
- [ ] Implement error handling

**When Creating Tests**

- [ ] AAA pattern
- [ ] Ensure independence
- [ ] Clear validations
- [ ] Meaningful test names

### B. Common Mistakes

| Mistake | Correct Approach |
| --- | --- |
| Business logic in Page Object | Move to Action |
| Complex logic in Test | Move to Action |
| Excessive fixed wait times | Use explicit waiting |
| Hard-coded selectors | Manage in Page Object |

---

## License

MIT License

---

**Document Management Information**

- Document ID: TECH-STD-E2E-001
- Category: Technical Standard
- Last Updated: 2026-02-02
- Manager: Ray Ishida
