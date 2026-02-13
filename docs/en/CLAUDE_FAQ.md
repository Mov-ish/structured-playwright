# CLAUDE_FAQ.md - Troubleshooting & Q&A

**Last Updated**: 2026-01-13

---

## 📘 About This Document

This document records **common problems and solutions in this project**.

### Role
- Common errors and solutions
- Error message-specific troubleshooting
- Frequently identified issues in reviews
- FAQ

### Growing Document
- When new errors occur, add to § 1 or § 2
- Periodically consolidate and organize similar errors

---

## § 1. Common Errors and Solutions

### 1.1 Element Not Found with Semantic Locators (Elements with Minimal Semantic Layer)

#### Error Messages
```
Error: locator.check: Target page, context or browser has been closed
Error: locator.click: Timeout 30000ms exceeded
```

#### Problem from Ambiguity
**Human Instruction**: "Check the agreement checkbox"
**AI Interpretation**: `page.getByRole('checkbox', { name: '同意する' })`
**Problem**: Checkbox lacks `aria-label` or associated `label` element (minimal semantic layer)

#### Cause
- **Elements with minimal semantic layer** lack attributes like `aria-label`, `label`
- Especially: checkboxes without labels, icon-only buttons
- **However**, **elements with rich semantic layer** like modals, buttons with text, input fields with placeholder CAN use semantic locators

#### Solution
**Elements with minimal semantic layer** → Use CSS selector + `:near()` or `svg[data-icon]`

```typescript
// ❌ Does not work (element with minimal semantic layer)
page.getByRole('checkbox', { name: '同意する' })
page.getByLabel('同意する')

// ✅ Works: :near() selector
page.locator('input[type="checkbox"]:near(:text("同意する"))')

// ✅ Works: Load from constants
import { SELECTORS } from '../config/constants';
page.locator(SELECTORS.AGREEMENT_CHECKBOX)
```

**Elements with rich semantic layer** → Semantic locators available

```typescript
// ✅ Works: Modal
page.getByRole('dialog', { name: 'テキストを追加' })

// ✅ Works: Button with text
page.getByRole('button', { name: '保存' })

// ✅ Works: Input field with placeholder
page.getByPlaceholder('検索')
```

#### Reference
- [CLAUDE_Selectors.md § 1](./CLAUDE_Selectors.md) - Selector Strategy
- [locator_strategy.md](./LOCATOR/locator_strategy.md) - Semantic Layer Thickness Criteria

---

### 1.2 Element Not Found in External Authentication (Auth0, etc.) Login

#### Error Messages
```
Error: locator.fill: Target closed
Error: locator.fill: Target page, context or browser has been closed
```

#### Problem from Ambiguity
**Human Instruction**: "Click login button and enter email and password"  
**AI Interpretation**: `clickEmailLogin()` → immediately `fillEmail()`  
**Problem**: Attempting form input without waiting for Auth0 transition

#### Cause
- Attempting form input without waiting for Auth0 transition
- External domain transitions take longer than normal page transitions

#### Solution
Explicitly wait for URL transition

```typescript
import { TIMEOUTS } from '../config/constants';

// ❌ Bad example
await this.termsPage.clickEmailLogin();
await this.auth0LoginPage.fillEmail(email); // Error!

// ✅ Good example
await this.termsPage.clickEmailLogin();

// Wait for Auth0 transition (Critical!)
await this.page.waitForURL('**/auth.example.com/**', { 
  timeout: TIMEOUTS.DEFAULT 
});
// Wait for screen stabilization
await this.page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);

// Then form input
await this.auth0LoginPage.fillEmail(email);
```

#### Reference
- [locator_rules_product_specific_part2.md § 2.4](./LOCATOR/productspecific/PRODUCT_A/locator_rules_product_specific_part2.md) - Auth0 External Authentication Flow

---

### 1.3 Cannot Click Button in Modal

#### Error Messages
```
Error: locator.click: Element is not visible
Error: locator.click: Element is outside of the viewport
```

#### Problem from Ambiguity
**Human Instruction**: "Click save button in modal"  
**AI Interpretation**: Wait for modal display, immediately `button.click()`  
**Problem**: Attempting click during modal animation

#### Cause
- Attempting click during modal fade-in animation
- Element exists but not yet clickable

#### Solution
Wait for modal display and animation completion

```typescript
import { TIMEOUTS, SELECTORS } from '../config/constants';

// ❌ Bad example
const button = page.locator('[role="dialog"] button:has-text("保存")');
await button.click(); // Error!

// ✅ Good example
// Step 1: Wait for modal display
await page.locator(SELECTORS.MODAL).waitFor({ 
  state: 'visible', 
  timeout: TIMEOUTS.SHORT 
});

// Step 2: Wait for animation completion
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);

// Step 3: Scroll element into view and click
const button = page.locator('[role="dialog"] button:has-text("保存")');
await button.scrollIntoViewIfNeeded();
await button.click({ force: true });
```

#### Reference
- [CLAUDE_Selectors.md § 4.3](./CLAUDE_Selectors.md) - Modal Processing Pattern

---

### 1.4 Element Not Found Even After Network Completion

#### Error Messages
```
Error: locator.click: Timeout 30000ms exceeded
Error: locator.isVisible: Timeout 30000ms exceeded
```

#### Problem from Undefined Condition
**Human Instruction**: "After page transition, click element"  
**AI Interpretation**: `waitForLoadState('networkidle')` → immediately `element.click()`  
**Problem**: Not waiting for SPA rendering completion

#### Cause
- This project is built with React SPA
- React rendering occurs after `networkidle`
- Network completion ≠ Rendering completion

#### Solution
Combine networkidle + waitForTimeout

```typescript
import { TIMEOUTS } from '../config/constants';

// ❌ Insufficient
await page.waitForLoadState('networkidle');
await element.click(); // Element may not exist yet

// ✅ Good example
await page.waitForLoadState('networkidle');
// Wait for SPA rendering completion
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
await element.click();
```

#### Reference
- [CLAUDE.md § Waiting Logic Rules](./CLAUDE.md) - Waiting Patterns

---

### 1.5 Warning About `.first()` Being Dangerous

#### Question
Is using `.first()` safe?

#### Answer
**No, SHOULD be avoided whenever possible.**

#### Dangerous Reasons
- ❌ Once test passes, no one fixes it (becomes technical debt)
- ❌ Suddenly fails on UI changes, difficult to debug
- ❌ Maintainability significantly declines, future change costs increase

#### Recommended Countermeasures (Priority Order)
1. **Highest Priority**: Request development team to add data-testid attribute
2. **Next Best**: Use `:near()` selector to identify from surrounding elements
3. **Compromise**: Filter sufficiently by parent element before `.first()`
4. **Last Resort**: `.first()` + detailed comment + TODO for refactoring plan

```typescript
// ❌ Dangerous: No filtering
page.locator('input[type="checkbox"]').first()

// ❌ Dangerous: No comment
page.locator('[role="dialog"] input[type="checkbox"]').first()

// ✅ Safe: Filter by parent + comment
// This dialog has only one checkbox
// TODO: Request addition of data-testid="terms-checkbox" (Issue #123)
page.locator('[role="dialog"] input[type="checkbox"]').first()

// ✅ Safer: Proximity selector (no .first() needed)
page.locator('input[type="checkbox"]:near(:text("同意する"))')
```

#### Reference
- [CLAUDE_Selectors.md § 3](./CLAUDE_Selectors.md) - .first() Usage Rules

---

### 1.6 Three-Dot Button (...) Not Found

#### Error Message
```
Error: locator.click: Timeout 30000ms exceeded.
Call log:
  - waiting for locator('button[aria-label="more"]').first()
```

#### Problem from Ambiguity
**Human Instruction**: "Click three-dot (...) button"  
**AI Interpretation**: `page.locator('button[aria-label="more"]')`  
**Problem**: Three-dot button has no `aria-label` or text

#### Cause
- Three-dot button consists only of SVG icon without `aria-label` or text
- Ant Design SVG icons have `data-icon` attribute

#### Solution
Filter using SVG icon's `data-icon` attribute

```typescript
// ❌ Does not work: aria-label does not exist
page.locator('button[aria-label="more"]')

// ❌ Does not work: No text
page.locator('button:has-text("...")')

// ✅ Works: Filter button containing Ellipsis icon
page.getByRole('button').filter({ 
  has: page.locator('svg[data-icon="ellipsis"]') 
})
```

#### Application: Other Icon Buttons
```typescript
// Edit icon button
page.getByRole('button').filter({ has: page.locator('svg[data-icon="edit"]') })

// Delete icon button
page.getByRole('button').filter({ has: page.locator('svg[data-icon="delete"]') })

// Close icon button
page.getByRole('button').filter({ has: page.locator('svg[data-icon="close"]') })
```

#### Reference
- [CLAUDE_Selectors.md § 4.2](./CLAUDE_Selectors.md) - SVG Icon Button Pattern

---

## § 2. Error Message-Specific Troubleshooting

### 2.1 Target closed / Target page, context or browser has been closed

**Possible Causes**:
1. Form input without waiting for Auth0 transition (§ 1.2)
2. Using semantic locators for elements with minimal semantic layer (§ 1.1)
3. Attempting operation during page transition

**Solutions**:
- Explicitly wait for URL transition with `waitForURL()`
- Use `:near()` or `svg[data-icon]` for elements with minimal semantic layer
- Add `waitForLoadState('networkidle')`

### 2.2 Timeout exceeded

**Possible Causes**:
1. Insufficient SPA rendering wait (§ 1.4)
2. Insufficient modal animation wait (§ 1.3)
3. Incorrect selector
4. Slow network

**Solutions**:
- Combine `networkidle` + `waitForTimeout()`
- Extend timeout value (use `TIMEOUTS.LONG`)
- Check selector (debug with `page.pause()`)

### 2.3 Element is not visible / Element is outside of the viewport

**Possible Causes**:
1. Click during modal animation (§ 1.3)
2. Element outside scroll range
3. Element is `display: none` or `visibility: hidden`

**Solutions**:
- Use `scrollIntoViewIfNeeded()`
- Use `click({ force: true })`
- Wait for modal animation completion

### 2.4 strict mode violation

**Cause**:
- Selector matches multiple elements
- `:has-text()` is partial match, may match multiple

**Solutions**:
```typescript
// ❌ Partial match matches multiple
page.locator('span:has-text("ログイン")') // "ログイン", "ログインする", "再ログイン"

// ✅ Exact match
page.locator('span:text-is("ログイン")') // "ログイン" only

// ✅ Filter by parent element
page.locator('[role="dialog"] span:has-text("ログイン")')

// ✅ More specific selector
page.locator('button:has-text("ログイン")')
```

---

## § 3. Frequently Identified Issues in Reviews

### 3.1 Hard-coded Timeout Values

**Violation**:
```typescript
await page.waitForTimeout(2000);
await element.waitFor({ state: 'visible', timeout: 10000 });
```

**Correct Implementation**:
```typescript
import { TIMEOUTS } from '../config/constants';
await page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);
await element.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
```

**🚨 Special Attention: Pitfalls When Modifying/Adding Code**

**Common Causes**:
- ❌ Wrote values directly to "just make it work" during error fixing
- ❌ Wrote values without checking `constants.ts` during new feature addition
- ❌ Forgot constant import when copy-pasting existing code

**Correction Steps**:

1. **Check if constants exist in constants.ts**
   ```typescript
   // Check src/config/constants.ts
   export const TIMEOUTS = {
     DEFAULT: 10000,
     LONG: 30000,
     SPA_RENDERING: 2000,
     // ...
   }
   ```

2. **Add constant if not exists**
   ```typescript
   // Example: Need constant for keeping browser open
   export const TIMEOUTS = {
     // ... existing constants ...
     KEEP_BROWSER_OPEN: 300000,   // New addition
   }
   ```

3. **Import and use at usage location**
   ```typescript
   import { TIMEOUTS } from '../config/constants';

   // ❌ Before correction
   await page.waitForTimeout(300000);

   // ✅ After correction
   await page.waitForTimeout(TIMEOUTS.KEEP_BROWSER_OPEN);
   ```

**Real Example (Discovered 2025-11-06)**:
- **Discovery Location**: `CreateCourseAction.ts:74` and `courseManagement.spec.ts:65`
- **Problem**: `2000` and `300000` hard-coded
- **Correction**:
  1. Added `KEEP_BROWSER_OPEN: 300000` to `constants.ts`
  2. Added `import { TIMEOUTS }` to both files
  3. `2000` → `TIMEOUTS.SPA_RENDERING`
  4. `300000` → `TIMEOUTS.KEEP_BROWSER_OPEN`

**Reference**: [CLAUDE.md § 2.2](./CLAUDE.md) - Constants Management Rules, [E2ETest_Framework.md § 6.2](./E2ETest_Framework.md) - Constants Management

---

### 3.2 Hard-coded Authentication Information

**Violation**:
```typescript
const email = 'test@example.com';
const password = 'password123';
```

**Correct Implementation**:
```typescript
const env = EnvConfig.getTestEnvironment();
const email = env.credentials.email;
const password = env.credentials.password;
```

**Reference**: [CLAUDE.md § 1](./CLAUDE.md) - Security Rules

---

### 3.3 Hard-coded Common Selectors

**Violation**:
```typescript
const modal = page.locator('[role="dialog"]');
const submitButton = page.locator('button[type="submit"]');
```

**Correct Implementation**:
```typescript
import { SELECTORS } from '../config/constants';
const modal = page.locator(SELECTORS.MODAL);
const submitButton = page.locator(SELECTORS.SUBMIT_BUTTON);
```

**Reference**: [CLAUDE.md § 2](./CLAUDE.md) - Constants Management Rules

---

### 3.4 Insufficient Comments When Using .first()

**Violation**:
```typescript
page.locator('input[type="checkbox"]').first(); // No comment
```

**Correct Implementation**:
```typescript
// Confirmed this dialog has only one checkbox
// TODO: Request addition of data-testid="confirm-checkbox" (Issue #123)
page.locator('[role="dialog"] input[type="checkbox"]').first();
```

**Reference**: [CLAUDE_Selectors.md § 3](./CLAUDE_Selectors.md) - .first() Usage Rules

---

### 3.5 Insufficient Comments When Using waitForTimeout

**Violation**:
```typescript
await page.waitForTimeout(2000); // No comment, no constants
```

**Correct Implementation**:
```typescript
import { TIMEOUTS } from '../config/constants';
// Wait for Auth0 screen rendering completion (networkidle alone insufficient)
await page.waitForTimeout(TIMEOUTS.AUTH0_STABILIZATION);
```

**Reference**: [CLAUDE.md § Waiting Logic Rules](./CLAUDE.md) - Waiting Patterns

---

### 3.6 Using Semantic Locators (Judge by Semantic Layer)

**Semantic locators MUST be used based on "semantic layer thickness".**

#### Elements with Minimal Semantic Layer (❌ Semantic Locators Unavailable)

**Violation**:
```typescript
// ❌ Checkbox without label
page.getByRole('checkbox', { name: '同意する' });
page.getByLabel('同意する');

// ❌ Icon-only button
page.getByRole('button', { name: '編集' });
```

**Correct Implementation**:
```typescript
// ✅ :near() selector
page.locator('input[type="checkbox"]:near(:text("同意する"))');

// ✅ svg[data-icon] for icon button
page.locator('button:has(svg[data-icon="edit"])');

// ✅ Load from constants
import { SELECTORS } from '../config/constants';
page.locator(SELECTORS.AGREEMENT_CHECKBOX);
```

#### Elements with Thick Semantic Layer (✅ Semantic Locators Available)

```typescript
// ✅ Modal
page.getByRole('dialog', { name: 'テキストを追加' });

// ✅ Button with text
page.getByRole('button', { name: '保存' });

// ✅ Input field with placeholder
page.getByPlaceholder('検索');
```

**Reference**: [CLAUDE_Selectors.md § 1](./CLAUDE_Selectors.md) - Selector Strategy, [locator_strategy.md](./LOCATOR/locator_strategy.md)

---

## § 4. FAQ (Frequently Asked Questions)

### Q1: What's the difference between E2ETest_Framework.md and CLAUDE.md?

**A**: 
- **E2ETest_Framework.md**: Ideal best practices common to all projects
- **CLAUDE.md**: Implementation patterns and adjustments specific to this project

In case of conflicts, CLAUDE.md takes precedence.

---

### Q2: What if data-testid attribute does not exist?

**A**: 
Use CSS selector + `:has-text()` or `:near()`.  
By documenting in CLAUDE.md, AI can generate correct code.

**Reference**: [CLAUDE_Selectors.md § 1](./CLAUDE_Selectors.md)

---

### Q3: Should waitForTimeout not be used?

**A**: 
No. It's necessary for SPA animation waits and external authentication screen rendering waits.  
However, MUST document reason in comments and use `TIMEOUTS` constants.

**Reference**: [CLAUDE.md § Waiting Logic Rules](./CLAUDE.md)

---

### Q4: How to write tests for external authentication (Auth0, etc.)?

**A**: 
Separate Page Objects and explicitly wait for URL transitions.

**Reference**: [locator_rules_product_specific_part2.md § 2.4](./LOCATOR/productspecific/PRODUCT_A/locator_rules_product_specific_part2.md)

---

### Q5: Is using .first() dangerous?

**A**: 
Yes, SHOULD be avoided whenever possible.

**Reasons**:
- Once test passes, no one fixes it (becomes technical debt)
- Suddenly fails on UI changes, difficult cause identification
- Maintainability significantly declines

**Recommended Response**: Refer to § 1.5

---

### Q6: Confused by multiple documents?

**A**:
Refer in this order:

1. **CLAUDE.md** - Read this first (project overview and required rules)
2. **CLAUDE_Selectors.md** - When stuck with selectors
3. **CLAUDE_FAQ.md (this file)** - When stuck with errors
4. **E2ETest_Framework.md** - When wanting architecture details
5. **LOCATOR/** - Detailed Locator strategy documents

---

### Q7: What is "semantic layer thickness"? {#semantic-layer-thickness}

**A**:
Concept indicating how much semantic information (meaningful identifiers) HTML elements possess.

#### Elements with Thick Semantic Layer (Semantic Locators Available)

| Element Type | Reason | Locator to Use |
|-------------|--------|----------------|
| Modal/Dialog | Uniquely identifiable with `role="dialog"` + title | `getByRole('dialog', { name: '...' })` |
| Button with text | Uniquely identifiable by button text | `getByRole('button', { name: '...' })` |
| Input field with placeholder | Uniquely identifiable by placeholder | `getByPlaceholder('...')` |

#### Elements with Minimal Semantic Layer (Semantic Locators Unavailable)

| Element Type | Reason | Alternative Locator |
|-------------|--------|-------------------|
| Checkbox without label | No `aria-label`/`label` element | `:near()` selector |
| Icon-only button | No text, no `aria-label` | `svg[data-icon]` |
| Element with only generic class name | No semantic anchor | Filter by parent element |

**In This Project**:
- `data-testid` almost non-existent
- Some elements lack `aria-label`, `label`
- **Judge semantic layer thickness for each element and select appropriate Locator**

**Solutions**:
1. **Elements with rich semantic layer** → Prioritize semantic locators
2. **Elements with minimal semantic layer** → Use `:near()` selector or `svg[data-icon]`
3. **Both cases** → Narrow scope with parent element (Local Universe)

**Reference**: [CLAUDE_Selectors.md § 1](./CLAUDE_Selectors.md), [locator_strategy.md](./LOCATOR/locator_strategy.md)

---

## § 5. New Error Addition Area

**How to Use**:
1. When new errors occur, add here
2. Record in the following format:
   - Date
   - Error message
   - Occurrence situation
   - Cause analysis
   - Solution

### 📝 Template

```markdown
### New Error X: [Error Summary]

**Date**: YYYY-MM-DD

**Error Message**:
```
[Error message]
```

**Occurrence Situation**: [Under what circumstances]
**Cause Analysis**: [What was the cause]
**Solution**: [How it was resolved]

**Code Example**:
```typescript
// Solution code
```
```

---

### New Error Addition Section (Add below)

<!-- Add new errors here -->

---

## 📊 Periodic Organization (Monthly/Quarterly)

### Organization Log

#### 2025-11 Review
**Added Errors**:
- (No additions as initial version)

**Consolidated Errors**:
- (No consolidation as initial version)

**Deleted Errors**:
- (No deletions as initial version)

**File Size**: 300 lines

---

## License

MIT License

---

**Last Updated**: 2026-01-13  
**Maintainer**: Ray Ishida
