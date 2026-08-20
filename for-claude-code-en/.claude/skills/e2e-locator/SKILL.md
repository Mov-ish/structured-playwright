---
name: e2e-locator
description: "Locator selector implementation pattern collection. Use when creating a new Page Object, when unsure how to write a specific Locator, or when handling UI-library-specific elements. For design philosophy and priorities, see .claude/rules/locator-principles.md."
---

# E2E Locator Implementation Patterns

> Design philosophy, priorities, and decision flow are in rules/locator-principles.md (always loaded).
> This Skill specializes in **concrete syntax and code examples**.

## §1. Semantic Locators (Elements with a Rich Semantic Layer)

```typescript
// data-testid (top priority — when present)
page.locator('[data-testid="login-button"]')

// role + name
page.getByRole('dialog', { name: 'Add text' })
page.getByRole('button', { name: 'Save' })
page.getByRole('button', { name: /Delete|delete/ })

// label
page.getByLabel('Email address')

// placeholder
page.getByPlaceholder('Search')
```

## §2. :has-text() / :text-is()

The 3 engines "look at" different places (the list right below the priority pyramid in `rules/locator-principles.md` is canonical):

| Engine | Match | Evaluated against |
|---|---|---|
| `:text-is("x")` | Exact | The element's **immediate** text nodes only |
| `:text("x")` | Partial | Full subtree text; only the **smallest** element matches |
| `:has-text("x")` | Partial | Full subtree text; **every ancestor** matches (the only engine that pierces nesting) |

```typescript
page.locator('button:has-text("Log in")')       // Partial match (pierces nesting)
page.locator('span:text-is("My Page")')         // Exact match (target an element with immediate text)
```

**text-is's immediate-text constraint**: `:text-is` does not match elements whose label is wrapped in a span etc. (silently 0 matches → timeout).
```typescript
// ❌ Silent on <button><span>Save</span></button> (Ant Design Button etc.)
page.locator('button:text-is("Save")')

// ✅ The default for exact leaf matching — the accessible name is computed from descendants, immune to nesting
page.getByRole('button', { name: 'Save', exact: true })
```
Note: the default for `getByText` / `getByRole`'s `name` is a **partial match**. Make exact matching explicit with `exact: true`.
Note: `getByText(..., { exact: true })` is exact too, but it is evaluated against the **full subtree text**, unlike `:text-is` (immediate only) — so it does get through span wrapping.
Note: for Ant Design Button label pitfalls (span wrapping, automatic space insertion between two CJK characters), see `e2e-locator/ant-design-button-label.md`.

**Danger of has-text**: partial matching hits unintended elements.
```typescript
// ❌ Partial match on "Save" → matches ALL of the following → strict mode violation
//   "Save now", "Save draft", "Saved", "Autosave"
page.locator('button:has-text("Save")')

// ✅ Exact match (role + name + exact)
page.getByRole('button', { name: 'Save', exact: true })

// ✅ If you must use has-text, always narrow with a Local Universe + qualify with an element type
page.locator('[role="dialog"] button:has-text("Save")')
```

**XPath conversion trap**:
```typescript
// ❌ Converting exact match → partial match by accident
page.locator(`span:has-text("Log in")`)  // Also matches "Log in with SSO"!

// ✅ Exact match → exact match
page.locator(`span:text-is("Log in")`)
```

**Change resilience of regular expressions**:
```typescript
// ❌ Fragile: stops matching on minor UI copy changes
.getByRole('button', { name: /Permanently delete this item/ })

// ✅ Robust: broad pattern + exclusion filter
.getByRole('button', { name: /Permanently delete/ }).filter({ hasNotText: 'all' })
```
Note: an unanchored broad pattern is a **deliberate partial match** for copy-change resilience — uniqueness comes from `hasNotText` / a Local Universe. As a **substitute for exact matching**, `^` `$` are mandatory (antd auto-space workaround: `e2e-locator/ant-design-button-label.md`).

## §3. :near() (Elements with a Minimal Semantic Layer)

```typescript
// Checkbox (no label)
page.locator('input[type="checkbox"]:near(:text("I agree"))')

// Radio button
page.locator('input[type="radio"]:near(:text("Yes"))')
```

## §4. data Attributes (UI-Library-Specific)

```typescript
// SVG icon buttons (when a data-icon attribute exists)
page.locator('button:has(svg[data-icon="edit"])')
page.locator('button:has(svg[data-icon="delete"])')
page.locator('button:has(svg[data-icon="ellipsis"])')

// Combining getByRole with filter
page.getByRole('button').filter({ has: page.locator('svg[data-icon="ellipsis"]') })
```

**When introducing to a project**: identify the stable data attributes assigned by the UI library and define them in constants.ts.

## §5. Attribute Selectors

```typescript
page.locator('input[name="username"]')
page.locator('input[name="password"]')
page.locator('input[type="email"]')
```

## §6. Narrowing by Parent Element (Local Universe)

```typescript
// Inside a modal
page.locator('[role="dialog"] button:has-text("Save")')

// Inside a table row
const row = page.locator('tr').filter({ hasText: targetText });
row.locator('button:has(svg[data-icon="edit"])');
```

## §7. Table Row Locators

```typescript
// ❌ Unstable: depends on the accessible name
table.getByRole('row', { name: new RegExp(targetText) })

// ✅ Stable: filter by text
table.locator('tr').filter({ hasText: targetText })
```

## §8. Choosing the Right Filter

```typescript
// ❌ hasNot checks child elements (cannot be used to exclude text)
.filter({ hasNot: page.getByText('Permanently delete all') })

// ✅ hasNotText excludes by text
.filter({ hasNotText: 'all' })

// Application: select "Edit" (excluding "Bulk edit")
page.getByRole('button', { name: /Edit/ }).filter({ hasNotText: 'Bulk' })
```

## §9. UI-Library-Specific Selectors (Add per Project)

Add UI-library-specific selectors here.
Prefer semantic Locators; use library-specific selectors as a supplement.
Beware that class names may change when the library is upgraded.

```typescript
// Example: Ant Design
// page.locator('.ant-modal-content')
// page.locator('.ant-select-item-option').filter({ hasText: optionText })

// Example: MUI (Material-UI)
// page.locator('.MuiDialog-root')
// page.locator('.MuiMenuItem-root').filter({ hasText: optionText })
```

**⚠️ Portal-rendered Select trap**: many UI libraries (Ant Design / MUI / Headless UI, etc.) render the Select / Combobox dropdown into a portal directly under `body`.

- `getByRole('option')` also matches the **hidden original select element** and may not be clickable
- `combobox.fill()` may not trigger the search debounce
- Solution: open the dropdown with a click, then directly click the visible element on the portal side

```typescript
// ❌ option role matches the hidden element
await page.getByRole('option', { name: targetName }).click();
// ❌ fill() may not trigger the search
await combobox.fill(targetName);

// ✅ Expand the dropdown → directly click the visible element on the portal side
await combobox.click();
await page.locator('.ant-select-item-option')   // Library-specific class
  .filter({ hasText: targetName }).first().click();
```

**⚠️ Empty tabs become unclickable via `aria-disabled`**: Ant Design Tabs / MUI Tabs / Radix UI Tabs and others add `aria-disabled="true"` when a tab has zero content. Calling `tab.click()` without knowing this makes Playwright's `click()` **hang until the test timeout** waiting for actionability — the worst possible feedback loop (Fail after several minutes, hard to isolate the cause).
→ See [ant-design-tabs-disabled.md](./ant-design-tabs-disabled.md) for details

```typescript
// ❌ Hangs forever on an empty tab until the test timeout
await page.getByRole('tab', { name: 'Archive' }).click();

// ✅ Guard on enabled before switching (immediate fail-fast)
async isTabEnabled(tabName: string): Promise<boolean> {
  const tab = this.page.getByRole('tab', { name: tabName });
  await tab.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  return tab.isEnabled();  // Interprets aria-disabled
}
// Test layer
expect(await action.hasItemsInTab('Archive')).toBeTruthy();
await navigationAction.switchTab('Archive');
```

**⚠️ Lingering `[role="dialog"]` after modal close (stale dialog)**: with Ant Design Modal and many other UI library modals, elements carrying `[role="dialog"]` can remain in the DOM for a while after closing. In flows that pass through multiple modals, or when the same flow reopens a modal, `getByRole('dialog')` matches multiple elements and clicks fail with a strict mode violation.
→ Absorb this with an `activeDialog()` helper that grabs the "most recently opened dialog".

**Placement guideline**: if used only within a single Page Object, keep it in that Page Object. Before it starts being used by multiple Page Objects, lift it into `BasePage` as `protected activeDialog()` to prevent duplicate definitions.

```typescript
// Within a single Page Object
activeDialog(): Locator {
  // Take the newest modal, which is appended at the end of the DOM
  return this.page.getByRole('dialog').last();
}

// Usage example
await this.activeDialog().getByRole('button', { name: 'Delete' }).click();
```

**When to use `activeDialog()` vs `SELECTORS.MODAL`** (not competing — different roles. Canonical source is `prohibited-patterns.md`, "Active modal idiom"; this table is a skill-layer practical quick reference):

| Purpose | Use |
|------|---------|
| Pick the "most recently opened = active" one among stale dialogs (`.last()` is needed) | `getByRole('dialog').last()` (`activeDialog()`) — getByRole auto-excludes hidden elements, robust against stale dialogs |
| Scope to a single modal and grab elements inside it (no `.last()` needed) | `SELECTORS.MODAL` (`[role="dialog"]`) — the Local Universe universe constant |
| Hybrid `page.locator(SELECTORS.MODAL).last()` | ❌ Prohibited (contradiction: applying the stale-dialog `.last()` to an attribute selector that does not exclude hidden elements. Details in `prohibited-patterns.md`, "Active modal idiom") |

> The `.last()` in `activeDialog()` is a Category B ordinal based on a framework invariant (end of DOM = frontmost). A reason comment is required but no TODO (`prohibited-patterns.md`, "Acceptable boundaries for ordinal selectors").

**Local Universe for card lists**: on screens listing card-style UI items (Ant Design `.ant-card`, MUI `.MuiCard-root`, custom Tailwind card classes, etc.), the same text tends to be duplicated across breadcrumbs / side menu / list. Scoping to the card body stabilizes things.

```typescript
// ❌ page scope → risk of false hits on identically named text in breadcrumbs / side menu
await page.locator(`:text-is("${itemName}")`).click();

// ✅ Wrap in the card body and filter with text-is (strict mode detects multiple matches)
const card = page.locator('.ant-card')  // Library-specific class
  .filter({ has: page.locator(`:text-is("${itemName}")`) });
await card.click();
```

Maintain the detailed per-library patterns in project-specific documentation.

## §10. constants.ts Selector Definition Policy

```typescript
// ❌ Too generic (would require .first())
FIRST_CHECKBOX: 'input[type="checkbox"]',

// ✅ Specific (no .first() needed)
AGREEMENT_CHECKBOX: 'input[type="checkbox"]:near(:text("I agree"))',
```

**Dynamic values belong in the PageObject layer**:
```typescript
// ❌ Do not put dynamic values in constants.ts
USER_ROW: (name) => `tr:has-text("${name}")`,

// ✅ Complement them in the PageObject
async clickUser(name: string) {
  await this.page.locator(`tr:has-text("${name}")`).click();
}
```

## §11. Handling ordinal Selectors (`.first()` / `.last()` / `.nth()`)

Ordinals fall into 3 categories by purpose, each with different requirements (details in `prohibited-patterns.md`, "Acceptable boundaries for ordinal selectors").

### Category A: Stopgap for Ambiguous Matches (`.first()` is typical)
"Multiple matches, so pick by position" = solidifying coincidence. Try to eliminate it in the following order; if you cannot, add a reason comment **+ TODO** (the order corresponds to the "Priority Pyramid" in `locator-principles.md`).

1. **Top priority**: unique identification via name / exact match (`getByRole(..., { name, exact: true })` / `:text-is()`) / Local Universe (semantic)
2. **Next best**: identify via surrounding text with `:near()`
3. **Compromise**: narrow by parent element, then ordinal
4. **Last resort**: ordinal + detailed comment + TODO

> Asking the dev team to add `data-testid` is a valid root fix but a long-term measure. It is fine to note it in a TODO.

```typescript
// ❌ Using A with no comment (the most common violation)
await this.page.locator(`:text-is("${name}")`).first().click();

// ✅ A: first check whether the pyramid can eliminate it → if not, reason + TODO
// The resource name matches 2 elements: the <a> and its inner <span>. Take the leading <a>
// TODO: remove .first() once the resource name element gets data-testid etc.
return this.page.locator(`:text-is("${name}")`).first();

// ✅ Another A example: compromise after confirming structurally there is only one candidate
// This dialog contains only one checkbox (verified YYYY-MM-DD)
// TODO: request adding data-testid="agreement-checkbox"
page.locator('[role="dialog"] input[type="checkbox"]').first()
```

### Category B: Framework Invariants (`.last()` is typical)
When `.last()` encodes a **real invariant** of z-order / DOM append order, such as "most recently opened = frontmost". There is physically no alternative, so do not remove it. **A reason comment is required but no TODO** (permanently correct design).

```typescript
// Explanation of the invariant only (B — no TODO needed)
// The modal library leaves role="dialog" in the DOM after closing. The most recently
// opened one is appended at the end of the DOM, so last() takes the active modal
this.page.getByRole('dialog').last()
```

### Category C: Drain-Loop Iteration (`.first()` is typical)
The pattern of "take the first item, process it, take the first again" repeated until zero items remain (bulk cleanup / janitor processing). All items get consumed regardless of order, so A's solidified coincidence does not occur. **Reason comment required, no TODO** (same as B). The canonical source for the 2 qualifying conditions (① a loop that drains everything down to 0 items, ② order does not affect the result) and the mandatory maxLoops + throw guard is `prohibited-patterns.md`.

> **Outside A/B/C classification** (canonical source: same section of `prohibited-patterns.md`): uses where the ordinal is a **direct expression of intent** rather than ambiguity resolution (an `nth(i)` loop iterator over a count scan, or `nth(param)` with an argument-derived index) are outside this classification — add only a reason comment (e.g., `// Loop iterator (outside A/B: full scan, not position pinning)`).

```typescript
// ✅ C: the caller loops until zero items remain, so the order of first() does not affect the result (no TODO needed)
return this.rowContaining(text).first();
```
