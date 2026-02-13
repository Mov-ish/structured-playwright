# CLAUDE_Selectors.md - Selector Strategy & Pattern Collection

**Last Updated**: 2026-02-12

---

## 📘 About This Document

This document describes **project-specific selector strategies and patterns**.

**Target Audience**:
- Code generation by Claude.code / CodexCLI
- Criteria for AI review
- Reference during developer implementation

**Main Rulebook**: 👉 [CLAUDE.md](./CLAUDE.md)
**Detailed Locator Design Philosophy**: 👉 [locator_strategy.md](./LOCATOR/locator_strategy.md)

---

## § 1. This Project's Selector Strategy

### 1.1 Background of Rule Formalization

**Date**: 2025-10-01 (Updated 2026-01-13)
**Discovery**: Playwright-recommended selectors (data-testid, semantic) don't work for some elements
**Cause**: Some existing HTML elements lack:
- `data-testid` attributes (generally lacking)
- `aria-label` attributes (lacking for checkboxes, icon buttons, etc.)
- Proper `label` elements (lacking for form elements)

**Trial and Error**: Requested frontend team to add attributes → Difficult due to priority issues
**Conclusion**: Use semantic locators vs CSS selectors based on element's "semantic layer thickness"

---

### 1.2 Selector Priority in This Project

| Priority | Selector Type | Availability | Reason/Use |
|----------|--------------|--------------|------------|
| ❌ 1 | data-testid | **Unavailable** | Does not exist in HTML |
| ✅ 2 | Semantic (getByRole, etc.) | **Conditionally Available** | Effective for modals, buttons with text, input fields with placeholder |
| ✅ 3 | CSS Selector + :has-text() / :text-is() | **Recommended** | Identify elements by text |
| ✅ 4 | :near() Selector | **Recommended** | Optimal for elements with minimal semantic layer (checkboxes, etc.) |
| ✅ 5 | svg[data-icon] | **Recommended** | Effective for icon buttons |
| ✅ 6 | Attribute Selector (name, type) | **Recommended** | Effective for form elements |
| ✅ 7 | Parent Element Filtering (Local Universe) | **Recommended** | Effective for elements inside modals, rows |
| ⚠️ 8 | Structural Selector | **Last Resort** | Weak to changes, comment required |

### 1.3 Criteria by Semantic Layer Thickness

| Semantic Layer | Element Examples | Recommended Locator |
|----------------|------------------|---------------------|
| **Thick** | Modals, buttons with text | `getByRole('dialog')`, `getByRole('button', { name: '...' })` |
| **Medium** | Text links, input fields | `:has-text()`, `:text-is()`, `getByPlaceholder()` |
| **Minimal** | Checkboxes, radios | `:near()` selector |
| **None** | Icon buttons | `svg[data-icon]` |

---

### 1.4 Basic Selector Patterns

#### ✅ Recommended Pattern 1: Semantic Locators (Elements with Thick Semantic Layer)

```typescript
// Modal
page.getByRole('dialog', { name: 'テキストを追加' })
page.getByRole('dialog')  // Can omit name

// Button with text
page.getByRole('button', { name: '保存' })
page.getByRole('button', { name: /削除|delete/ })

// Input field with placeholder
page.getByPlaceholder('検索')
page.getByPlaceholder('メールアドレスを入力')
```

**Use**: Elements with thick semantic layer (role, name, placeholder set)

#### ✅ Recommended Pattern 2: :has-text() / :text-is()

```typescript
// Partial match (:has-text)
page.locator('button:has-text("ログイン")')
page.locator('a:has-text("マイページ")')

// Exact match (:text-is) - avoid multiple matches
page.locator('span:text-is("マイページ")')
page.locator('button:text-is("保存")')
```

**Note**: `:has-text()` is partial match, may match multiple elements. Recommend `:text-is()` for exact match.

#### ✅ Recommended Pattern 3: :near() Selector (Elements with Minimal Semantic Layer)

```typescript
// Checkbox (without label)
page.locator('input[type="checkbox"]:near(:text("同意する"))')
page.locator('input[type="checkbox"]:near(:text("通知を受け取る"))')

// Radio button
page.locator('input[type="radio"]:near(:text("はい"))')
```

**Use**: Elements with minimal semantic layer (no label, aria-label). Identify by surrounding text.

#### ✅ Recommended Pattern 4: svg[data-icon] (Icon Buttons)

```typescript
// Icon buttons
page.locator('button:has(svg[data-icon="edit"])')
page.locator('button:has(svg[data-icon="delete"])')
page.locator('button:has(svg[data-icon="ellipsis"])')  // Three dots
page.locator('button:has(svg[data-icon="close"])')
```

**Use**: Icon buttons without text. Utilize UI library internal attributes.

#### ✅ Recommended Pattern 5: Attribute Selectors

```typescript
// name attribute (Auth0 forms, etc.)
page.locator('input[name="username"]')
page.locator('input[name="password"]')

// type attribute
page.locator('input[type="email"]')
page.locator('input[type="checkbox"]')
```

#### ✅ Recommended Pattern 6: Filter by Parent Element (Local Universe)

```typescript
// Button in modal
page.locator('[role="dialog"] button:has-text("保存")')
page.locator('[role="dialog"] input[type="checkbox"]')

// Element in table row
const row = page.locator('tr:has-text("TypeScript入門")');
row.locator('button:has(svg[data-icon="edit"])');
```

**Use**: When same text exists multiple times. Limit scope with parent element.

---

### 1.5 XPath → CSS Conversion Notes

**Critical**: `text()='...'` and `:has-text()` behave differently!

```typescript
// ❌ Wrong: Exact match → Partial match
page.locator(`//span[text()='ログイン']`)
→ page.locator(`span:has-text("ログイン")`) // Also matches "ログインする", "再ログイン"!

// ✅ Correct: Exact match → Exact match
page.locator(`//span[text()='ログイン']`)
→ page.locator(`span:text-is("ログイン")`) // Only matches "ログイン"
```

---

## § 2. constants.ts Selector Definition Collection

### 2.1 Selector Definition Policy

**Principle**: Define static selectors specifically to uniquely identify, reducing `.first()` usage

#### ❌ Not Recommended: Too Generic Definition

```typescript
// Old approach (not recommended)
export const SELECTORS = {
  FIRST_CHECKBOX: 'input[type="checkbox"]',  // Requires .first()
  FIRST_TEXT_INPUT: 'input[type="text"]',    // Requires .first()
}
```

#### ✅ Recommended: Specific Definition

```typescript
// New approach (recommended)
export const SELECTORS = {
  // Common elements like modals
  MODAL: '[role="dialog"]',
  SUBMIT_BUTTON: 'button[type="submit"]',
  
  // Specific definition per page (no .first() needed)
  AGREEMENT_CHECKBOX: 'input[type="checkbox"]:near(:text("同意する"))',
  AUTH0_EMAIL_INPUT: 'input[name="username"]',
  AUTH0_PASSWORD_INPUT: 'input[name="password"]',
  AUTH0_SUBMIT_BUTTON: 'button[type="submit"], button:has-text("続ける"), button:has-text("ログイン")',
  
  CONFIRM_CHECKBOX: '[role="dialog"] input[type="checkbox"]:near(:text("下記事項を確認"))',
  NOMINATED_COURSE_BUTTON: '[role="dialog"] button:has-text("指名コース")',
} as const;
```

### 2.2 Currently Defined Selectors

#### Common Elements

```typescript
export const SELECTORS = {
  // Modal
  MODAL: '[role="dialog"]',
  
  // Button
  SUBMIT_BUTTON: 'button[type="submit"]',
  
  // Other common elements
  // ...
} as const;
```

#### Auth0 Related

```typescript
// Auth0 login page
AUTH0_EMAIL_INPUT: 'input[name="username"]',
AUTH0_PASSWORD_INPUT: 'input[name="password"]',
AUTH0_SUBMIT_BUTTON: 'button[type="submit"], button:has-text("続ける"), button:has-text("ログイン")',
```

#### Agreement Checkbox Related

```typescript
// Agreement checkbox (identified from surrounding text with :near())
AGREEMENT_CHECKBOX: 'input[type="checkbox"]:near(:text("同意する"))',
```

#### Modal Internal Elements

```typescript
// Confirmation checkbox
CONFIRM_CHECKBOX: '[role="dialog"] input[type="checkbox"]:near(:text("下記事項を確認"))',

// Nominated course button
NOMINATED_COURSE_BUTTON: '[role="dialog"] button:has-text("指名コース")',
```

---

### 2.3 Guidelines for Adding New Selectors

When adding new selector patterns, record them in the following format:

```markdown
### [Date Added] - [Element Name]

**Discovery Context**:
- Which test required it
- Why this selector was needed

**Trial and Error**:
- First attempted selector → Reason for failure
- Next attempted selector → Reason for failure
- Finally adopted selector → Reason for success

**Selector Definition**:
```typescript
ELEMENT_NAME: 'selector',
```

**Usage Example**:
```typescript
page.locator(SELECTORS.ELEMENT_NAME)
```
```

---

## § 3. `.first()` Usage Rules

### 3.1 Basic Policy: Avoid Whenever Possible

**Dangers of `.first()`**:
- ❌ Once test passes, no one fixes it (becomes technical debt)
- ❌ Suddenly fails on UI changes, difficult to identify cause
- ❌ Maintainability significantly declines, future change costs increase

---

### 3.2 Recommended Responses (Priority Order)

#### 1. **Highest Priority**: Request data-testid Attribute Addition

```markdown
Request to frontend team:
"Please add data-testid="terms-checkbox" (Issue #123)"
```

#### 2. **Next Best**: Use `:near()` Selector to Identify from Surrounding Elements

```typescript
// ✅ Uniquely identify from surrounding text
page.locator('input[type="checkbox"]:near(:text("同意する"))')
```

#### 3. **Compromise**: Filter Sufficiently by Parent Element Before `.first()`

```typescript
// ✅ Filter to modal before .first()
page.locator('[role="dialog"] input[type="checkbox"]').first()
```

#### 4. **Last Resort**: `.first()` + Detailed Comment + TODO

```typescript
// ✅ Detailed comment REQUIRED when unavoidable
this.agreeCheckbox = page
  .locator('[role="dialog"] input[type="checkbox"]')
  .first();
// TODO: Request addition of data-testid="agreement-checkbox" (Issue #123)
// Reason: Multiple checkboxes exist in modal, but
//        confirmed first element is always agreement checkbox (2025-10-15)
```

---

### 3.3 `.first()` Reduction Example

| Item | Before Improvement | After Improvement |
|------|-------------------|-------------------|
| **Total Selectors** | 20 | 6 |
| **`.first()` Usage** | 14 locations | 1 location (dynamic value) |
| **Maintainability** | Low | High |

**Improvement Approach**:
- Generic selectors → Specific selectors
- Utilize `:near()` selector
- Filter by parent element

---

## § 4. Selector Pattern Collection

### 4.1 Form Elements

#### Checkboxes

```typescript
// ✅ Recommended: Identify by surrounding text
page.locator('input[type="checkbox"]:near(:text("同意する"))')

// ⚠️ Acceptable: Filter by parent element
page.locator('[role="dialog"] input[type="checkbox"]').first()
// TODO: Replace with more specific selector
```

#### Text Input

```typescript
// ✅ Recommended: Identify by name attribute
page.locator('input[name="username"]')
page.locator('input[name="password"]')

// ⚠️ Acceptable: placeholder + parent element
page.locator('[role="dialog"] input[placeholder*="メール"]')
```

#### Buttons

```typescript
// ✅ Recommended: Text + type attribute
page.locator('button[type="submit"]:has-text("ログイン")')

// ✅ Recommended: Filter by parent element
page.locator('[role="dialog"] button:has-text("保存")')

// ✅ Acceptable: Specify multiple candidates
page.locator('button[type="submit"], button:has-text("続ける"), button:has-text("ログイン")')
```

---

### 4.2 Icon Buttons (SVG)

**Problem**: Icon buttons like three-dot (...) have no text or aria-label

**Solution**: Filter by SVG icon's `data-icon` attribute

```typescript
// ✅ Button containing Ellipsis icon
page.getByRole('button').filter({ has: page.locator('svg[data-icon="ellipsis"]') })

// ✅ Edit icon button
page.getByRole('button').filter({ has: page.locator('svg[data-icon="edit"]') })

// ✅ Delete icon button
page.getByRole('button').filter({ has: page.locator('svg[data-icon="delete"]') })

// ✅ Close icon button
page.getByRole('button').filter({ has: page.locator('svg[data-icon="close"]') })
```

---

### 4.3 Elements Inside Modals

```typescript
// Wait for modal display
await page.locator(SELECTORS.MODAL).waitFor({ state: 'visible', timeout: TIMEOUTS.SHORT });
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION); // Animation completion

// Operate element inside modal
await page.locator('[role="dialog"] button:has-text("保存")').click();
```

---

### 4.4 Elements with Dynamic Values

**Principle**: Dynamic values (determined at runtime) are handled within Page Object, `.first()` usage unavoidable

```typescript
/**
 * Click course name (dynamic value)
 * @param courseName - Course name to click
 */
async clickCourseName(courseName: string): Promise<void> {
  // Note: .first() usage unavoidable due to dynamic value
  // Ideally should identify by course ID or data-testid attribute
  await this.page.locator(`a:has-text("${courseName}")`).first().click();
  // TODO: Consider identifying by data-testid="course-{courseId}" (Issue #XXX)
}
```

---

## § 5. AI Review Checklist

Claude.code, CodexCLI, Cursor, etc. MUST verify the following during code review.

### 5.1 MUST FIX (Required Fixes)

#### Security
- [ ] Authentication information not hard-coded
- [ ] `.env` file included in `.gitignore`

#### Constants Management
- [ ] **Import TIMEOUTS, SELECTORS, URL_PATTERNS from constants.ts**
- [ ] Timeout values not directly written (`2000`, `10000`, etc.)
- [ ] Common selectors not directly written (`'button[type="submit"]'`, etc.)
- [ ] URL patterns not directly written (`'**/login**'`, etc.)

#### Locators
- [ ] Not using `text=` locators
- [ ] Following locator priority (Semantic → :has-text() → :near() → data-icon)
- [ ] Using `:near()` or `svg[data-icon]` for elements with minimal semantic layer
- [ ] Avoiding structure-dependent selectors
- [ ] Loading common selectors from `SELECTORS`

#### Page Objects
- [ ] Defining locators with `readonly` (`private readonly` prohibited)

#### Actions
- [ ] console.log output at each step
- [ ] LoginAction implements login success verification

### 5.2 SHOULD FIX (Recommended Fixes)

#### Code Quality
- [ ] **Comment present when using `.first()`**
  - Explain why first element is acceptable
  - Document refactoring plan with TODO

- [ ] **Comment present when using waitForTimeout**
  - Explain why necessary
  - Use TIMEOUTS constants

- [ ] Select locators based on semantic layer thickness
- [ ] Use specific selectors rather than overly generic ones
- [ ] Utilize Local Universe (filter by parent element)

#### Test Quality
- [ ] Follow AAA pattern
- [ ] Result verification implemented
- [ ] Data cleanup implemented (when necessary)

### 5.3 INFO (Information)

- [ ] **Referencing success patterns?**
  - test2 (Login flow)
  - test (Selector definition)
  - test5 (Modal processing)
- [ ] Referencing implementation patterns from CLAUDE_Patterns.md?

---

## § 6. New Pattern Addition Area

### 2026-02-02 - Filter Usage (hasNot vs hasNotText)

**Discovery Background**:
Needed to distinguish "Delete" button from "Bulk Delete" button in E2E test.
Used `hasNot` filter but "Bulk Delete" button was clicked by mistake.

**Trial and Error**:
1. `filter({ hasNot: page.getByText('一括削除') })` → Failed (not excluded as intended)
2. `filter({ hasNotText: '一括' })` → Success

**Cause**:
- `hasNot`: Checks for **not having child elements**
- `hasNotText`: Checks for **not containing text**

When excluding by button's own text, MUST use `hasNotText`.

**Selector Definition**:
```typescript
// ❌ Wrong: hasNot checks child elements
const deleteButton = page
  .getByRole('button', { name: /削除/ })
  .filter({ hasNot: page.getByText('一括削除') });

// ✅ Correct: hasNotText excludes by text
const deleteButton = page
  .getByRole('button', { name: /削除/ })
  .filter({ hasNotText: '一括' });
```

**Usage Examples**:
```typescript
// Select "Edit" button (excluding "Bulk Edit")
const editButton = page
  .getByRole('button', { name: /編集/ })
  .filter({ hasNotText: '一括' });

// Select "Save" button (excluding "Save All")
const saveButton = page
  .getByRole('button', { name: /保存/ })
  .filter({ hasNotText: 'すべて' });
```

---

### 2026-02-02 - Regex Change Resistance

**Discovery Context**:
Used regex `/削除する/` to match "削除する" (Delete), but didn't match when UI showed only "削除".

**Trial and Error**:
1. `/削除する/` → Doesn't match "削除"
2. `/削除/` + `hasNotText` → Handles both cases

**Conclusion**:
- Overly strict regex is fragile against UI text changes
- Broader pattern + exclusion filter is stable

**Selector Definition**:
```typescript
// ❌ Fragile: Too strict regex
.getByRole('button', { name: /削除する/ })

// ✅ Robust: Broad pattern + exclusion filter
.getByRole('button', { name: /削除/ })
.filter({ hasNotText: '一括' })
```

---

### 2026-02-02 - Table Row Locator Strategy

**Discovery Background**:
Needed to click ellipsis button in specific row of data table in test case.
Tried `getByRole('row', { name: ... })` but failed because row's accessible name not set as expected.

**Trial and Error**:
1. `getByRole('row', { name: new RegExp(name) })` → Failed (accessible name doesn't match)
2. `locator('tr').filter({ hasText: name })` → Success

**Cause**:
- `getByRole('row', { name: ... })` depends on row's accessible name
- Many tables don't set accessible name on row itself even if cells have text
- `filter({ hasText })` can reliably filter by text content

**Selector Definition**:
```typescript
// ❌ Unstable: Depends on accessible name
table.getByRole('row', { name: new RegExp(targetText) })

// ✅ Stable: Filter by text content
table.locator('tr').filter({ hasText: targetText })
```

**Usage Example (Table Row + Meatball Menu Pattern)**:
```typescript
// Find specific row in user table and click its menu button
const table = page.locator('table').last();
const row = table.locator('tr').filter({ hasText: userName });
const menuButton = row.getByRole('button', { name: 'ellipsis' });
await menuButton.click();
```

**Applicable Scenarios**:
- Click operation buttons within table rows (edit, delete, etc.)
- Select specific rows (checkbox operations, etc.)
- Data validation at row level

---

### 2026-02-02 - Ant Design Components

**Discovery Background**:
Applications using Ant Design UI library have elements that cannot be handled with standard semantic locators.

**Ant Design-Specific Selectors**:
```typescript
// Modal
page.locator('.ant-modal-content')

// Select (dropdown) options
page.locator('.ant-select-item-option')
page.locator('.ant-select-item-option').filter({ hasText: optionText })

// Dropdown container
page.locator('.ant-select-dropdown')

// Table
page.locator('.ant-table')
page.locator('.ant-table-row')

// Message/Toast
page.locator('.ant-message')
page.locator('.ant-notification')
```

**Constants Example (constants.ts)**:
```typescript
export const SELECTORS = {
  // Ant Design components
  ANT_MODAL_CONTENT: '.ant-modal-content',
  ANT_SELECT_OPTION: '.ant-select-item-option',
  ANT_SELECT_DROPDOWN: '.ant-select-dropdown',
} as const;
```

**Ant Design Modal Operation Pattern**:
```typescript
// Wait for modal to appear
const modal = page.locator(SELECTORS.ANT_MODAL_CONTENT);
await modal.waitFor({ state: 'visible', timeout: TIMEOUTS.SHORT });

// Input field inside modal (Local Universe)
const input = modal.locator('input[type="text"]').first();
await input.fill(value);

// Button inside modal (Local Universe)
const submitButton = modal.getByRole('button', { name: '作成する' });
await submitButton.click();

// Wait for modal to close
await modal.waitFor({ state: 'hidden', timeout: TIMEOUTS.DEFAULT });
```

**Ant Design Dropdown Operation Pattern**:
```typescript
// Open dropdown
await page.getByRole('combobox').click();

// Wait for options to appear
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);

// Click option
const option = page.locator(SELECTORS.ANT_SELECT_OPTION).filter({ hasText: targetName }).first();
await option.click();

// Close dropdown (Escape key)
await page.keyboard.press('Escape');
await page.waitForTimeout(TIMEOUTS.DROPDOWN_ANIMATION);
```

**Notes**:
- Ant Design class names may change with version updates
- Prioritize semantic locators whenever possible, use Ant Design-specific selectors as auxiliary

---

## License

MIT License

---

**Last Updated**: 2026-02-12
**Maintainer**: Ray Ishida
