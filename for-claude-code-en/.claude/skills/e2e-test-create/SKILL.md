---
name: e2e-test-create
description: "For E2E test creation. Use when adding tests, implementing Actions/Page Objects, or generating tests from user stories. Includes the SOP, Fixture definitions, wait patterns, test data design, and the JSDoc template. See auth0-flow.md for external auth flow examples and failure-patterns.md for failure patterns."
---

# E2E Test Creation Skill

## §6. AI Work Procedure (SOP) — start here

1. Review the MUST checklist (rules/architecture.md "Absolute boundaries between layers" + rules/prohibited-patterns.md)
2. **Receive the source document and decompose it into test units**
   - Source document = a document describing the intent of the tests (test procedure document / checklist / acceptance criteria / user story; granularity may vary)
   - If no source document is provided, or the intent cannot be read from it, **ask a human instead of filling the gaps by guesswork** (unauthorized gap-filling creates "verifications absent from the original", which the differences section later cannot explain)
3. **Write the test procedure document first** (template and tag table in §11; the norm is `architecture.md` "Test layer header comments")
   - Organize Phase splits, step numbers, and verification points in natural language — the step of **normalizing the source document into the §11 template format**
   - Consolidate intentional deviations from the original (merged steps, stricter verification, substituted data, etc.) into the §11 "Intentional differences from the original procedure" section
   - This becomes the design document for the test implementation
4. Check the **Action catalog** in `fixtures/app.fixture.ts`
   - Identify reusable methods from the list of existing Action methods
   - If a needed Action is in the TODO list, a new one must be created
5. Explore existing assets (Actions / Page Objects / similar Tests) → prefer reuse
   > ⚠️ **Existing code may violate the rules.** Before copying, cross-check against the prohibitions in rules/architecture.md and rules/prohibited-patterns.md.
   > If you find a violation, implement with the correct pattern instead of copying.
6. Keep added files to a minimum → new Actions must be **registered in the Fixture as well + the Action catalog updated** (see `architecture.md` "Action catalog conventions")
   - **When implementing or modifying `LoginAction`, read §4 (auth0-flow.md) first**
7. Implement (following the 4-layer responsibilities in rules)
8. Verify with `npx playwright test <file>`
   - **If the test doesn't pass, check the known patterns in §5 (failure-patterns.md)**
9. Record the execution time in the header comment
10. Final check against rules/architecture.md "Absolute boundaries between layers" + rules/prohibited-patterns.md
11. **Run `npm run gate` and confirm exit 0** (mechanical gate — the canonical source is `scripts/gate.sh`; CI runs the same checks)
    - On ❌, fix according to the "→ alternative" in the fail message before creating the PR
    - Resolve ⚠️ warnings that fall on lines you added or changed (existing lines are out of scope)

---

## §1. MUST Checklist (review before generating code)

### Per-layer rules quick reference

| Layer | ❌ Prohibited | ✅ Required |
|---|---|---|
| **Page Object** | `private readonly` | `readonly` (public) + constructor initialization |
| **Page Object** | expect / waitForTimeout | Single-responsibility methods; waitFor + try-catch allowed |
| **Action** | expect() | waitFor(); `this.step()` for every step |
| **Action** | bare `console.log` for step logging | `this.step('name', async () => { ... })` |
| **Action** | forgetting `beginAction()` | `this.beginAction()` at the top of public methods that use `this.step()` |
| **Action** | hardcoded numbers/URLs | TIMEOUTS/URL_PATTERNS constants + reason comment |
| **Test** | `from '@playwright/test'` | `from '../fixtures/app.fixture'` |
| **Test** | `new XxxAction(page)` | Fixture argument `async ({ xxxAction }) =>` |
| **Test** | Locators written directly | Via Action verify methods |
| **Test** | No header comment | Test procedure document as JSDoc (see `architecture.md`) |
| **All layers** | Silently skipping when a test condition cannot be met | Fail when an explicitly required operation fails (see `prohibited-patterns.md`) |

---

## §2. Fixture Definition

**Canonical template = `e2e-bootstrap/fixture-template.md`** (the complete form, including the full `base.extend` structure and the worker-scoped stepCounter). The only delta needed at test creation time is "registering the new Action":

```typescript
// fixtures/app.fixture.ts — these 3 additions are all you write for a new Action
import { XxxAction } from '../actions/XxxAction';            // ① import
type AppFixtures = { /* existing */ xxxAction: XxxAction };     // ② add to the type
// ③ register (inject stepCounter into the constructor)
xxxAction: async ({ page, stepCounter }, use) => { await use(new XxxAction(page, stepCounter)); },
```

**New Action → import + register in the Fixture too (inject stepCounter) → declare as a test argument + update the Action catalog (`architecture.md` "Action Catalog Conventions for fixture.ts")**

---

## §3. Wait Handling Patterns

| Situation | Wait method | Constant |
|------|---------|------|
| After page navigation | `networkidle` + `waitForTimeout` | `TIMEOUTS.SPA_RENDERING` |
| Modal display | `waitFor({state:'visible'})` + `waitForTimeout` | `TIMEOUTS.MODAL_ANIMATION` |
| External auth transition | `waitForURL()` + `waitForTimeout` | `TIMEOUTS.AUTH_STABILIZATION` |
| Redirect | `waitForTimeout` | `TIMEOUTS.REDIRECT` |
| Confirmation dialog | `waitFor({state:'visible'})` | `TIMEOUTS.DEFAULT` |

### Modal interaction pattern
```typescript
await page.locator(SELECTORS.MODAL).waitFor({ state: 'visible', timeout: TIMEOUTS.SHORT });
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION); // wait for CSS animation to complete
const button = page.locator('[role="dialog"] button:has-text("Save")');
await button.scrollIntoViewIfNeeded();
await button.click({ force: true });
```

---

### try-catch boundaries (code examples)

Only "element state-transition timeouts" may be caught (the canonical criteria are in `prohibited-patterns.md` "Allowed vs. Prohibited try-catch Boundaries").

```typescript
// ✅ Catch only the waitFor timeout — return the fact that "it wasn't visible"
async isSectionVisible(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    return true;
  } catch { return false; }
}

// ❌ A textContent failure after a successful waitFor also becomes false, hiding the true cause
async hasValue(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
    const text = await this.section.textContent(); // ← its failure is also caught
    return /\d+/.test(text ?? '');
  } catch { return false; }
}

// ✅ Separate waitFor from value retrieval
async hasValue(): Promise<boolean> {
  try {
    await this.section.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  } catch { return false; }
  const text = await this.section.textContent();
  return /\d+/.test(text ?? '');
}
```

### Optional modal pattern (modals/buttons that may or may not appear)

In flows where a modal or button "appears in some environments and not in others", **put only the waitFor inside try-catch, and move click/fill outside**. If the click sits inside the try, a click failure is concealed as "no modal" (detected by gate W5).

```typescript
// ❌ click inside the try block — a click failure is also treated as "no modal"
try {
  await confirmBtn.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  await confirmBtn.click(); // ← a click failure is also treated as "no modal"
} catch { /* no confirmation modal */ }

// ✅ Only the waitFor goes inside try-catch; the click moves outside
let modalVisible = false;
try {
  await confirmBtn.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  modalVisible = true;
} catch { /* no confirmation modal */ }
if (modalVisible) await confirmBtn.click();
```

The canonical criteria are in `prohibited-patterns.md` "Allowed vs. Prohibited try-catch Boundaries".

---

## §4. External Authentication Flow

→ See **`.claude/skills/e2e-test-create/auth0-flow.md`** (read when implementing or modifying LoginAction)

---

## §5. Patterns Already Tried and Failed

→ See **`.claude/skills/e2e-test-create/failure-patterns.md`** (check when stuck)

---

## §7. Per-Component Patterns

### Form input
```typescript
await this.step('Fill in the form', async () => {
  await inputField.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  await inputField.fill(value);
  await submitButton.click();
  await this.page.waitForLoadState('networkidle');
});
```

### List operations (ellipsis menu)
```typescript
await this.step('Open the menu', async () => {
  const row = this.page.locator('tr').filter({ hasText: targetText });
  await row.locator('button:has(svg[data-icon="ellipsis"])').click();
});
await this.step('Select a menu item', async () => {
  await this.page.locator('li:has-text("Edit")').click();
});
```

### File upload
```typescript
await this.step('Upload the file', async () => {
  await this.page.locator('input[type="file"]').setInputFiles(filePath);
  await this.page.waitForResponse(resp => resp.url().includes('/upload'));
  await this.page.waitForLoadState('networkidle');
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // wait for the post-upload UI update
});
```

---

## §8. Error Handling Patterns

### Saving a screenshot on error
```typescript
// Helper that can be added to BaseAction
protected async executeWithScreenshot(
  fn: () => Promise<void>,
  context: string
): Promise<void> {
  try {
    await fn();
  } catch (error) {
    await this.page.screenshot({ path: `test-results/error-${context}-${Date.now()}.png` });
    throw error;
  }
}
```

### Retry pattern in the Action layer (handling state not yet reflected right after a transition)

For environment variance where "an element is not yet reflected in a list right after page navigation or an operation", **wrap only the single PO method call in try, and reload + retry in the Action layer**.

```typescript
// ✅ Action layer — wrap only the single PO call in try
async processRequest(itemName: string): Promise<void> {
  this.beginAction();
  await this.step('Process the request', async () => {
    try {
      await this.listPage.processItem(itemName); // the single PO call only
    } catch {
      // If the list hasn't been updated, reload and retry (catches the waitFor timeout inside the PO)
      await this.page.reload();
      await this.page.waitForLoadState('networkidle');
      await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
      await this.listPage.processItem(itemName);
    }
  });
}
```

**Points**:
- Only the **single PO call** goes inside the try (not the whole Action)
- If navigation or a `click` inside the PO fails, the throw propagates as-is and never reaches the catch (nothing is concealed)
- The catch only captures the `waitFor` timeout inside the PO (element not yet reflected)
- The PO side only needs to let the throw propagate on `waitFor` timeout (the reload decision is the Action layer's responsibility)

> ⚠️ A retry that wraps `click` directly in try (`try { locator.click() } catch { retry }`) violates W5. The cause of the click failure is concealed. Redesign to confirm existence with `waitFor` before clicking.

---

## §9. Test Data Management (as the number of tests grows)

**Canonical source = `test-data-management.md` (same directory) — always read it when designing test data, deciding whether to extract a Setup Action, or structuring [Arrange].** Covers: scope design (sharing across multiple `test()` blocks / `beforeAll` / the Setup Action pattern), end-to-end test bloat and consolidating base creation, parameterizing Actions, verify observes only, Fail when test conditions cannot be met (no Silent Skip), and honest verification in the Cleanup phase.

## §10. Naming Conventions

| Kind | Pattern | Example |
|------|---------|---|
| Page Object | `{ScreenName}Page.ts` | `LoginPage.ts` |
| Action | `{FeatureName}Action.ts` | `LoginAction.ts` |
| Test | `{test-target}.spec.ts` | `user-journey.spec.ts` |

Make test names specific, written in your team's working language: `'can log in with valid credentials'` ✅

---

## §11. Test Procedure Document (JSDoc) Template

**Canonical source = `jsdoc-template.md` (same directory) — always read it when writing a test procedure document.** Covers: the full template (including the "Intentional differences from the original procedure" section), top-level configure placement, the tag meaning table, and the Cleanup logout principle.
