# TEST_CREATION_PROTOCOL.md
## Documentation-First Test Authoring (Standard Workflow for Test Creation)

This document serves as the primary guide for **adding E2E tests to an existing Playwright environment**.
For environment setup, refer to **BOOTSTRAP.md**.

---

## Priority of Authorities
- **CLAUDE.md** takes precedence in case of any conflicts
- The 4-layer responsibilities follow **E2ETest_Framework.md** as the standard

---

## ⚠️ CONSTRAINTS: Pre-Code-Generation Checklist

**This section MUST be reviewed. Internalize these rules before referencing existing code.**

### Required Imports
```typescript
// MUST include in all files
import { TIMEOUTS } from '../config/constants';

// MUST include for Page Objects
import { SELECTORS } from '../config/constants';

// MUST include for Actions
import { URL_PATTERNS } from '../config/constants';

// MUST use for Tests (via Fixture)
import { test, expect } from '../fixtures/app.fixture';
// ❌ MUST NOT: import { test, expect } from '@playwright/test';
```

### Page Object Rules
| Rule | ❌ Anti-pattern | ✅ MUST Use |
|------|-----------------|-------------|
| Locator Definition | `get xxx(): Locator { }` | `readonly xxx: Locator;` (Initialize in constructor) |
| Access Modifier | `private readonly` | `public readonly` |

### Action Rules
| Rule | ❌ Anti-pattern | ✅ MUST Use |
|------|-----------------|-------------|
| Timeout Values | `waitForTimeout(1000)` | `waitForTimeout(TIMEOUTS.MODAL_ANIMATION)` |
| URL Waiting | `waitForURL('**/login**')` | `waitForURL(URL_PATTERNS.LOGIN)` |
| Logging | Start/end only | Implement step-by-step logging using `console.log('Step N: [Description]')` |
| LoginAction | No verification | MUST include post-login validation |

### Test Rules
| Rule | ❌ Anti-pattern | ✅ MUST Use |
|------|-----------------|-------------|
| Import Source | `from '@playwright/test'` | `from '../fixtures/app.fixture'` |
| Action Instantiation | `new XxxAction(page)` | Fixture argument `async ({ xxxAction }) =>` |

### Locator Rules
| Rule | ❌ Anti-pattern | ✅ MUST Use |
|------|-----------------|-------------|
| Text Search | `text=ログイン` | `:has-text("ログイン")` or `getByRole` / `getByText` |
| Ambiguous Selection | `.first()` without comment | `.first()` + reason comment |

### waitForTimeout Rules
| Rule | ❌ Anti-pattern | ✅ MUST Use |
|------|-----------------|-------------|
| Numeric Value | `waitForTimeout(2000)` | `waitForTimeout(TIMEOUTS.SPA_RENDERING)` |
| Comment | No comment | MUST include reason comment |

**Example:**
```typescript
// ❌ Anti-pattern
await page.waitForTimeout(1000);

// ✅ Required
// Wait for modal animation to complete
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
```

---

## ⚠️ Caution When Referencing Existing Code

**Existing code MAY violate rules.** Cross-check against the CONSTRAINTS above before copying existing code.

When violations are found:
1. Implement with correct patterns instead of copying
2. Refactor existing code to comply with these rules if feasible

---

## Final Authority for Locators (MUST Follow)
When in doubt about Locators, consult in this order and make the final decision:

1. **Concept** (Philosophy & Priorities)
2. **Universal** (Universal Principles)
3. **Product-Specific (PRODUCT_A)** (PRODUCT_A-specific constraints)

Reference: `./LOCATOR/`

---

## General Principles (For AI)
- **Preservation of existing structure is the highest priority** (no unauthorized major refactoring)
- First explore existing Actions / PageObject / utilities for reuse
- `.first()` and XPath are generally prohibited (if unavoidable, document reason and add TODO)
- Retrieve sensitive information from `.env` / CI environment variables

---

## 4-Layer Architecture Responsibilities (Summary)
- **Test (Scenario)**: Write intent and expected results. MUST NOT write Locators directly
- **Fixture**: Centralized Action instantiation. Tests MUST NOT instantiate Actions directly
- **Actions (Procedures)**: Grouped user behaviors (reusable units)
- **PageObject**: Encapsulation of screen elements and operations (Locators go here)
- **Data / Config**: Test data, environment differences, authentication (env, etc.)

※ For details, refer to **E2ETest_Framework.md**.

---

## AI Work Procedure (SOP)

### 0) Review CONSTRAINTS Checklist
Review the "CONSTRAINTS: Pre-Code-Generation Checklist" above and understand the rules.

### 1) Decompose User Story into Atomic Test Cases
Split the input user story (or Given/When/Then) into atomic, independent test cases.

### 2) Explore Existing Assets (MUST Do)
- Search for existing `Actions`
- Search for existing `PageObject`
- Search for similar `Test`

> Creating new ones when existing ones are available increases **cost**, so reuse first.
> **However, verify that existing code does not violate CONSTRAINTS.**

### 3) Determine Required Changes (Minimize Redundancy)
- If existing is sufficient, add only Test
- Add or extend Actions / PageObject only for missing parts
- **When adding new Actions, MUST register them in the Fixture file as well**
- MUST follow `./LOCATOR` rules for Locators

### 4) Naming and Placement
- Place in file names and directories according to specifications
- Test names MUST clarify "what is being guaranteed"

### 5) Finalization (Execution & Stabilization)
- Avoid flakiness (prioritize auto-waiting of Locator and expect)
- Write readable expect for failures
- Add trace / screenshot if needed (follow project policy)

### 6) Final Verification with CONSTRAINTS
Verify that generated code does not violate CONSTRAINTS.

---

## Reference (Implementation Examples)
- Quick Recipes: `CLAUDE_Selectors.md`
- Troubleshooting: `CLAUDE_FAQ.md`

---

## Instruction Template (Ready to Use)

> Follow TEST_CREATION_PROTOCOL.md and add E2E tests for the following user story.
> **Review the CONSTRAINTS checklist and ensure no rule violations.**
> First explore existing Actions/PageObjects for reuse, and add only missing parts.
> In test files, retrieve Actions via Fixture (MUST NOT import directly from `@playwright/test`).

- Target Feature:
- User Story:
  1.
  2.
  3.
- Constraints:
  - Add-only / Existing modification OK
  - New Actions creation OK / Existing Actions priority
  - PRODUCT_A-specific constraints (if any)

---

**Last Updated**: 2026-02-02
**Maintainer**: Ray Ishida
