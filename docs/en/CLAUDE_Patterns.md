# CLAUDE_Patterns.md - Implementation Patterns & Success Cases

**Last Updated**: 2026-02-02

---

## 📘 About This Document

This document records **implementation patterns and success cases that actually worked in this project**.

**Target Audience**:
- Code generation by Claude.code / CodexCLI
- Reference during developer implementation
- Addition of new patterns

**Main Rulebook**: 👉 [CLAUDE.md](./CLAUDE.md)

---

## § 1. Auth0 External Authentication Flow

### 1.1 Background of Rule Formalization

**Date**: 2025-10-05  
**Discovery**: Frequent "element not found" errors in Auth0 login  
**Cause**: Operating without waiting for transition to external domain (auth.example.com)  
**Trial and Error**:
1. Only `waitForLoadState('networkidle')` → Failed (next operation before external transition)
2. Added `page.waitForURL()` → Improved but unstable
3. `page.waitForURL()` + `waitForTimeout()` → Success (stable operation in test2)

**Conclusion**: Explicit waiting for URL transition + screen stabilization wait is REQUIRED

---

### 1.2 Authentication Flow Diagram

```
1. Terms of Use Page (my-app.example.com/login)
   ↓
   Check terms of use
   ↓
   Click "Login with Email" button
   ↓
2. Auth0 Page (auth.example.com) ← External domain
   ↓
   [CRITICAL] Wait for URL transition + Wait for screen stabilization
   ↓
   Enter email address
   ↓
   Enter password
   ↓
   Click login button
   ↓
3. Application (my-app.example.com/courses)
   ↓
   [CRITICAL] Wait for redirect completion
```

---

### 1.3 Separation of Page Objects

**Critical**: Pages with different domains MUST be separated into different Page Objects

```typescript
// ✅ Correct separation
export class TermsPage extends BasePage {
  // my-app.example.com/login
  readonly agreeCheckbox: Locator;
  readonly emailLoginButton: Locator;
}

export class Auth0LoginPage extends BasePage {
  // auth.example.com
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
}

// ❌ Wrong: Mixed
export class LoginPage {
  // Elements from different domains in same Page Object
  readonly agreeCheckbox: Locator;      // my-app.example.com
  readonly emailInput: Locator;         // auth.example.com
}
```

**Reasons**:
- Different reasons for change (own site vs external service)
- Easier debugging
- Individual Page Object testing possible

---

### 1.4 LoginAction Implementation Pattern (Successful in test2)

```typescript
import type { Page } from '@playwright/test';
import { TIMEOUTS } from '../config/constants';
import { TermsPage } from '../pages/TermsPage';
import { Auth0LoginPage } from '../pages/Auth0LoginPage';

export class LoginAction {
  private readonly page: Page;
  private readonly termsPage: TermsPage;
  private readonly auth0LoginPage: Auth0LoginPage;

  constructor(page: Page) {
    this.page = page;
    this.termsPage = new TermsPage(page);
    this.auth0LoginPage = new Auth0LoginPage(page);
  }

  /**
   * Execute login flow
   * @param url - Login page URL
   * @param email - Email address
   * @param password - Password
   */
  async execute(url: string, email: string, password: string): Promise<void> {
    console.log('🔐 Login flow started');

    // Step 1: Navigate to terms page
    console.log('📄 Navigating to terms page');
    await this.termsPage.goto(url);
    await this.termsPage.waitForReady();

    // Step 2: Agree to terms
    console.log('✅ Agreeing to terms');
    await this.termsPage.agreeToTerms();

    // Step 3: Click email login button
    console.log('📧 Clicking email login button');
    await this.termsPage.clickEmailLogin();

    // Step 4: Wait for Auth0 page transition (Critical!)
    console.log('⏳ Waiting for Auth0 page transition');
    await this.page.waitForURL('**/auth.example.com/**', {
      timeout: TIMEOUTS.DEFAULT
    });
    // Wait for Auth0 screen stabilization (SPA initial rendering)
    await this.page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);

    // Step 5: Enter email in Auth0
    console.log('📧 Entering email address');
    await this.auth0LoginPage.waitForReady();
    await this.auth0LoginPage.fillEmail(email);

    // Step 6: Enter password and login
    console.log('🔑 Entering password and logging in');
    await this.auth0LoginPage.fillPassword(password);
    await this.auth0LoginPage.clickSubmit();

    // Step 7: Wait for login completion (redirect)
    console.log('⏳ Waiting for login completion');
    await this.page.waitForTimeout(TIMEOUTS.REDIRECT);

    // Step 8: Verify login success (MUST)
    console.log('🔍 Verifying login success');
    const currentURL = this.page.url();
    if (currentURL.includes('/login')) {
      throw new Error('Login failed (still on login page)');
    }
    console.log('✅ Login success confirmed');

    console.log('✅ Login flow completed');
  }
}
```

**Critical Points**:
1. **Explicit URL transition wait**: `waitForURL()`
2. **Screen stabilization wait**: `TIMEOUTS.AUTH0_STABILIZATION`
3. **Redirect completion wait**: `TIMEOUTS.REDIRECT`
4. **Progress confirmation with console logs**: Useful for debugging
5. **Login success verification**: Confirm URL is not login page (MUST)

### 1.4.1 Login Success Verification Rule (MUST)

**❌ Prohibited: Complete login without verification**
```typescript
await this.auth0LoginPage.clickSubmit();
await this.page.waitForURL('**example.com**', { timeout: TIMEOUTS.LONG });
// ← Ends here, no success verification
```

**✅ Required: Explicitly verify login success**
```typescript
await this.auth0LoginPage.clickSubmit();
await this.page.waitForURL(URL_PATTERNS.DASHBOARD, { timeout: TIMEOUTS.LONG });

// Confirm login success (verify URL is not login page)
const currentURL = this.page.url();
if (currentURL.includes('/login')) {
  throw new Error('Login failed (still on login page)');
}
console.log('Login success confirmed');
```

**Reason**: Prevent subsequent tests from failing with unclear errors when login fails

---

### 1.5 Common Errors and Solutions

#### Error 1: `Target page, context or browser has been closed`

**Cause**: Element operation without waiting for URL transition

```typescript
// ❌ Bad example
await this.termsPage.clickEmailLogin();
await this.auth0LoginPage.fillEmail(email); // Error!

// ✅ Good example
await this.termsPage.clickEmailLogin();
await this.page.waitForURL('**/auth.example.com/**', { timeout: TIMEOUTS.DEFAULT });
await this.page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);
await this.auth0LoginPage.fillEmail(email); // Success
```

---

## § 2. Waiting Logic Patterns

### 2.1 Background of Rule Formalization

**Date**: 2025-10-10  
**Discovery**: Element not found errors even after `networkidle`  
**Cause**: React SPA has rendering delays after network completion  
**Trial and Error**:
1. Only `waitForLoadState('networkidle')` → Unstable
2. Only fixed wait time (5000ms) → Too slow
3. `networkidle` + `waitForTimeout(2000ms)` → Stable (successful in test2-test5)

**Conclusion**: Combine state-based waiting + fixed wait time

---

### 2.2 Types of Waiting Logic and Usage

| Situation | Waiting Method | Timeout | Reason |
|-----------|---------------|---------|--------|
| **After page transition** | `networkidle` + `waitForTimeout` | `TIMEOUTS.SPA_RENDERING` | SPA initial rendering |
| **Modal display** | `waitFor({state: 'visible'})` + `waitForTimeout` | `TIMEOUTS.MODAL_ANIMATION` | Animation completion |
| **Auth0 transition** | `waitForURL()` + `waitForTimeout` | `TIMEOUTS.AUTH0_STABILIZATION` | External site rendering |
| **Redirect** | `waitForTimeout` | `TIMEOUTS.REDIRECT` | Authentication completion and redirect |

---

### 2.3 SPA Waiting Pattern

```typescript
// Wait after page transition
async goto(url: string): Promise<void> {
  await this.page.goto(url);
  // Wait for network completion
  await this.page.waitForLoadState('networkidle');
  // Wait for SPA rendering completion
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
}
```

**Comment Example**:
```typescript
// For SPA, React rendering delays exist even after networkidle
await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
```

---

### 2.4 Modal Waiting Pattern (Successful in test5)

```typescript
/**
 * Wait for modal display and click button
 */
async clickModalButton(buttonText: string): Promise<void> {
  // Step 1: Wait for modal display
  await this.page.locator(SELECTORS.MODAL).waitFor({ 
    state: 'visible', 
    timeout: TIMEOUTS.SHORT 
  });
  
  // Step 2: Wait for modal animation completion
  // Reason: Click events are not processed correctly during CSS animation
  await this.page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
  
  // Step 3: Scroll button into view
  const button = this.page.locator(`[role="dialog"] button:has-text("${buttonText}")`);
  await button.scrollIntoViewIfNeeded();
  
  // Step 4: Click button
  await button.click({ force: true });
}
```

**Critical Points**:
1. Wait for modal display
2. Wait for animation completion (required)
3. Scroll processing
4. `force: true` option

---

### 2.5 waitForTimeout Comment Examples

```typescript
// ✅ Good example: Document reason
await this.page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
// Reason: Wait for modal CSS animation (1 second) completion

await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
// Reason: Wait for React SPA initial rendering completion

await this.page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);
// Reason: Wait for Auth0 (external site) screen rendering completion

// ❌ Bad example: No reason, not using constants
await this.page.waitForTimeout(2000);
```

**Pattern When New Constant Is Needed**:
```typescript
// Step 1: Add constant to constants.ts
export const TIMEOUTS = {
  // ... existing constants ...
  KEEP_BROWSER_OPEN: 300000,   // New addition: Keep browser open (5 minutes)
} as const;

// Step 2: Import and use at usage location
import { TIMEOUTS } from '../config/constants';

// Step 28: Keep browser open
await page.waitForTimeout(TIMEOUTS.KEEP_BROWSER_OPEN);
```

---

## § 3. Successful Implementation Pattern Collection

### 3.1 test2: Login Flow (Success Case)

**Implementation Date**: 2025-10-05  
**Success Factors**:
- Correct implementation of Auth0 external authentication flow
- Introduction of URL transition waiting
- Appropriate waiting time configuration

**Code Pattern**: Refer to § 1.4

---

### 3.2 test: Selector Definition (Success Case)

**Implementation Date**: 2025-10-20  
**Success Factors**:
- Reduced `.first()` from 14 locations to 1
- Specific selector definition (constants.ts)
- Utilization of `:near()` selector

**Details**: 👉 [CLAUDE_Selectors.md § 2-3](./CLAUDE_Selectors.md)

---

### 3.3 test5: Modal Processing (Success Case)

**Implementation Date**: 2025-10-25  
**Success Factors**:
- Wait for modal animation completion
- Utilization of `scrollIntoViewIfNeeded()`
- `force: true` option

**Code Pattern**: Refer to § 2.4

---

## § 4. Component-Specific Patterns

### 4.1 Form Input Pattern

```typescript
/**
 * Basic pattern for form input
 */
export class FormPage extends BasePage {
  async fillForm(data: FormData): Promise<void> {
    // Wait for input field readiness
    await this.firstInput.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    
    // Fill fields
    await this.nameInput.fill(data.name);
    await this.emailInput.fill(data.email);
    
    // Dropdown selection
    await this.categorySelect.selectOption(data.category);
    
    // Checkbox check
    if (data.agree) {
      await this.agreeCheckbox.check();
    }
    
    // Click submit button
    await this.submitButton.click();
    
    // Wait for submission completion
    await this.page.waitForLoadState('networkidle');
  }
}
```

---

### 4.2 List Operation Pattern

```typescript
/**
 * Operate specific item in list
 */
export class ListPage extends BasePage {
  /**
   * Click list item
   * @param itemText - Item text
   */
  async clickListItem(itemText: string): Promise<void> {
    // Wait for list loading completion
    await this.page.waitForLoadState('networkidle');
    await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
    
    // Click item
    await this.page.locator(`li:has-text("${itemText}")`).click();
  }
  
  /**
   * Open item three-dot menu
   * @param itemText - Item text
   */
  async openItemMenu(itemText: string): Promise<void> {
    // Identify item
    const item = this.page.locator(`li:has-text("${itemText}")`);
    
    // Click three-dot button
    const moreButton = item
      .getByRole('button')
      .filter({ has: this.page.locator('svg[data-icon="ellipsis"]') });
    
    await moreButton.click();
    
    // Wait for menu display
    await this.page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
  }
}
```

---

### 4.3 File Upload Pattern

```typescript
/**
 * File upload
 */
export class UploadPage extends BasePage {
  async uploadFile(filePath: string): Promise<void> {
    // Select file
    await this.fileInput.setInputFiles(filePath);
    
    // Wait for upload completion
    await this.page.waitForResponse(resp => 
      resp.url().includes('/api/upload') && resp.status() === 200
    );
    
    // Wait for UI update
    await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
  }
}
```

---

## § 5. Error Handling Patterns

### 5.1 Basic Error Handling

```typescript
export class BaseAction {
  protected async executeWithErrorHandling(
    actionName: string,
    action: () => Promise<void>
  ): Promise<void> {
    try {
      console.log(`🚀 ${actionName} started`);
      await action();
      console.log(`✅ ${actionName} completed`);
    } catch (error) {
      console.error(`❌ ${actionName} failed:`, error);
      
      // Save screenshot
      await this.page.screenshot({ 
        path: `screenshots/error-${Date.now()}.png`,
        fullPage: true 
      });
      
      throw error;
    }
  }
}
```

---

### 5.2 Retry Pattern

```typescript
/**
 * Retry unstable operation
 */
async clickWithRetry(locator: Locator, maxRetries: number = 3): Promise<void> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await locator.click({ timeout: TIMEOUTS.SHORT });
      return; // Success
    } catch (error) {
      if (i === maxRetries - 1) {
        throw error; // Failed on last retry
      }
      console.log(`⚠️ Click failed, retry ${i + 1}/${maxRetries}`);
      await this.page.waitForTimeout(1000);
    }
  }
}
```

---

### 5.3 AI Coding Tool Precautions - Dangers of Timeout Error Concealment Pattern

**Background of Rule Formalization**:
- **Date**: 2026-02-16
- **Discovery**: Large number of `.catch(() => false)` patterns existed in Playwright tests
- **Cause**: AI Coding Tools tend to suggest easy solutions to "eliminate errors"
- **Problem**: Timeout errors are concealed, causing tests to report false positives (incorrect success)
- **Conclusion**: `.catch(() => false)` is **absolutely prohibited**; use Playwright native assertions

#### 5.3.1 Problematic Pattern (Common in AI-Generated Code)

```typescript
// ❌ Dangerous: Conceals timeout errors
const isVisible = await element.isVisible({ timeout: 5000 }).catch(() => false);
if (isVisible) {
  await element.click();
}

// What's the problem:
// 1. Returns false on timeout → error is concealed
// 2. Screen closed on timeout but misinterpreted as "test completed"
// 3. True problem (selector error, rendering delay) becomes invisible
// 4. Debugging becomes difficult
```

**Why AI Coding Tools Easily Generate This Pattern**:
1. Error disappears and code "works"
2. Syntactically correct, TypeScript types pass
3. Immediate results
4. Tends to prioritize implementation (operation) over test essence (validation)

#### 5.3.2 Correct Patterns

**Pattern A: Optional Element Check**
```typescript
// ✅ Correct: Playwright native assertion
const { expect } = await import('@playwright/test');
try {
  await expect(element).toBeVisible({ timeout: TIMEOUTS.CHECK });
  await element.click();
} catch {
  // Optional element, skip if not present
  // Consider why timeout occurred:
  // - Is the selector wrong?
  // - Is rendering slow?
  // - Element conditionally displayed?
}
```

**Pattern B: Boolean Validation Method**
```typescript
// ✅ Correct: Pattern in validation method
async isElementVisible(): Promise<boolean> {
  const { expect } = await import('@playwright/test');
  try {
    await expect(element).toBeVisible({ timeout: TIMEOUTS.CHECK });
    return true;
  } catch {
    // Return false if element not found
    // However, timeout is logged
    return false;
  }
}
```

**Pattern C: Nested Conditional Check (Fallback)**
```typescript
// ✅ Correct: Fallback pattern for multiple elements
try {
  await expect(primaryElement).toBeVisible({ timeout: TIMEOUTS.SHORT });
  await primaryElement.click();
} catch {
  try {
    await expect(secondaryElement).toBeVisible({ timeout: TIMEOUTS.SHORT });
    await secondaryElement.click();
  } catch {
    // Both elements not found - this is the real issue
    throw new Error('Primary and secondary elements not found');
  }
}
```

#### 5.3.3 AI Coding Tool Usage Checklist

**❌ Danger Signs (Requires Careful Review of AI Code)**

1. **Large number of same error handling pattern**
   ```bash
   # Detect suspicious patterns
   git diff | grep -n "\.catch(() => false)"
   git diff | grep -n "\.catch(() => true)"
   ```

2. **Excessive use of `.catch(() => ...)`**
   - 5+ instances of same pattern → High likelihood of AI copy-paste

3. **Boolean type but true state unknown**
   ```typescript
   // ❌ Cannot distinguish between timeout and non-existence
   const isVisible = await element.isVisible().catch(() => false);

   // ✅ Can distinguish between timeout and non-existence
   try {
     await expect(element).toBeVisible();
     return true;
   } catch (error) {
     console.log(`Element not visible: ${error.message}`);
     return false;
   }
   ```

**✅ Code Review Checkpoints**

1. **Always suspect when finding `.catch(() => false/true)`**
   - Is it really okay to conceal the error?
   - Can you distinguish between timeout and non-existence?

2. **Be cautious of large copy-paste of same pattern**
   - High likelihood of AI generation
   - If one place has problem, entire code has problem

3. **Be aware that "works" ≠ "correct"**
   - Tests have meaning in failing
   - Verify error messages are informative

4. **Prioritize Playwright best practices**
   - Understand why `expect().toBeVisible()` is recommended
   - Respect framework design philosophy

#### 5.3.4 Implementation Example and Effects

**Problematic Code Before Fix**:
```typescript
// Modal handling example
if (await modal.isVisible({ timeout: TIMEOUTS.CHECK }).catch(() => false)) {
  await button.click();
}
```

**Correct Code After Fix**:
```typescript
const { expect } = await import('@playwright/test');
try {
  await expect(modal).toBeVisible({ timeout: TIMEOUTS.CHECK });
  await button.click();
  await expect(modal).not.toBeVisible({ timeout: TIMEOUTS.SHORT });
} catch {
  // Modal not present, skip
}
```

**Effects**:
1. ✅ Timeouts properly detected as errors
2. ✅ Debugging becomes easier (clear error messages)
3. ✅ False positives reduced
4. ✅ Code consistency maintained

---

## § 6. New Pattern Addition Area

### 2026-02-02 - Confirmation Dialog Waiting Pattern

**Implementation Background**:
After clicking delete button, timeout occurred while searching for "Delete" button before confirmation dialog appeared.

**Success Factors**:
After button click, explicitly wait for button in confirmation dialog to appear.

**Code Example**:
```typescript
// ❌ Bad example: Don't wait for dialog display
await deleteButton.click();
await this.page.waitForTimeout(TIMEOUTS.UI_RESPONSE);
await this.confirmDeleteButton.click(); // May timeout

// ✅ Good example: Wait for confirmation dialog display
await deleteButton.click();
await this.confirmDeleteButton.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
await this.confirmDeleteButton.click();
```

**Notes**:
- `waitForTimeout` alone is unstable (dialog display timing varies by environment)
- `waitFor({ state: 'visible' })` reliably waits for display

---

### 2026-02-02 - List Change Verification Pattern After Deletion

**Implementation Background**:
After deleting list item in SPA, attempting to verify the change failed because element reference became invalid.

**Trial and Error**:
1. `waitFor({ state: 'hidden' })` → ❌ Failed because element is removed from DOM
2. `waitFor({ state: 'detached' })` → ❌ DOM-dependent, unstable
3. `expect().toHaveCount(0)` → ❌ Does not work in deleted tab
4. Verification by tab transition → ❌ Tab element retrieval unstable
5. **URL transition verification** → ✅ Works stably

**Success Factors**:
After deletion operation, verify transition to expected URL.

**Code Example**:
```typescript
// ❌ Unstable: Directly verify element disappearance
await this.confirmDeleteButton.click();
await itemRow.waitFor({ state: 'hidden', timeout: TIMEOUTS.DEFAULT }); // Fails

// ✅ Stable: Verify deletion completion with URL transition
await this.confirmDeleteButton.click();
await this.page.waitForURL('**/admin/items?tab=archive', { timeout: TIMEOUTS.DEFAULT });
```

**Notes**:
- In SPA, list item is completely removed from DOM when deleted
- Original Locator reference becomes invalid, cannot verify with `hidden` or `detached`
- Indirect verification with URL transition or network completion is stable

**Alternative Pattern (During Cleanup)**:
When deletion itself is the purpose (cleanup, etc.), strict verification can be omitted:
```typescript
await this.confirmDeleteButton.click();
// Wait for deletion response (short timeout sufficient)
await this.page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {
  console.log('Deletion complete: networkidle wait timeout (processing already complete)');
});
```

---

## § 7. Pattern Improvement Log

### 2026-02-02
- Added confirmation dialog waiting pattern
- Added list change verification pattern after deletion

### 2025-11-06
- Created initial version
- Recorded success patterns of test2, test (selector definition), test5

---

**Last Updated**: 2026-02-02  
**Maintainer**: Ray Ishida
