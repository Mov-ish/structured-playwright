---
name: e2e-test-create/failure-patterns
description: "A collection of patterns already tried and failed. Reference material on waits, selectors, and navigation — so they are not reinvented."
---

# Patterns Already Tried and Failed (Do Not Reinvent)

## External auth waits

| What was tried | Result | Reason |
|-----------|------|------|
| `waitForLoadState('networkidle')` only | ❌ | The next operation runs before the transition to the external domain |
| `page.waitForURL()` only | ⚠️ Flaky | Detects the URL change but doesn't wait for rendering to finish |
| `waitForURL()` + `waitForTimeout()` | ✅ | Combines URL-transition confirmation + screen stabilization |

## SPA rendering waits

| What was tried | Result | Reason |
|-----------|------|------|
| `networkidle` only | ❌ Flaky | Framework (React etc.) rendering happens after network completion |
| Fixed 5000ms | ❌ Slow | Needlessly slow, and can still fall short across environments |
| `networkidle` + `TIMEOUTS.SPA_RENDERING` | ✅ | Covers both |

## Confirming the change after deletion

| What was tried | Result | Reason |
|-----------|------|------|
| `waitFor({ state: 'hidden' })` | ❌ | The SPA removes the DOM entirely → the reference becomes invalid |
| `waitFor({ state: 'detached' })` | ❌ Flaky | DOM-dependent, varies across environments |
| Confirming the URL transition | ✅ | Indirect but stable |

## Buttons inside modals

| What was tried | Result | Reason |
|-----------|------|------|
| Clicking right after display | ❌ | Not processed during the CSS animation |
| `waitFor` only | ⚠️ Flaky | Can be visible yet still animating |
| `waitFor` + `MODAL_ANIMATION` + `scrollIntoView` + `force:true` | ✅ | The full set of countermeasures |

## Selector choice

| What was tried | Result | Reason |
|-----------|------|------|
| `getByLabel()` on attribute-poor elements | ❌ | A label element may not exist |
| `getByRole('checkbox')` without scoping | ❌ | Cannot be uniquely identified |
| `button[aria-label="more"]` | ❌ | aria-label may not be set |
| `button:has-text("...")` for an ellipsis button | ❌ | The ellipsis is an SVG, not text |
| `getByRole('row', { name })` | ❌ | Some tables have no accessible name set |
| `filter({ hasNot })` to exclude text | ❌ | hasNot checks child elements; hasNotText is what's needed |
| `button:text-is("...")` to target a button | ❌ | UI libraries (antd etc.) wrap labels in a span. `:text-is` evaluates only immediate text → silently 0 matches, then timeout. Use `getByRole` + `name` + `exact: true` |
| Exact text match on a two-CJK-character label (「検索」etc.) | ❌ | antd's autoInsertSpace makes the DOM text 「検 索」. text-is / has-text / role+name+exact all fail. Only an anchored regex `{ name: /^検\s*索$/ }` gets through (without anchors it also hits 「再検索」). Does not trigger on icon buttons or `type="text"`/`"link"` |

→ For details on label/DOM-text divergence (span wrapping, automatic spaces), see `e2e-locator/ant-design-button-label.md`.

## Waiting for navigation completion

| What was tried | Result | Reason |
|-----------|------|------|
| `waitForLoadState('domcontentloaded')` right after click | ❌ | If it has already fired on the current page it **returns immediately**. The subsequent `goto()` runs before the transition completes and triggers `net::ERR_ABORTED` |
| Proceeding to the next step on URL arrival alone | ❌ | During SPA landing-page init (~2s), clicks are **swallowed** by outer handlers (the landing page's click handlers etc.) and don't behave as expected |
| Waiting for a known destination element to be visible | ✅ | UI-element-based waiting is the baseline. E.g. right after logout → wait for an element unique to the next screen to be visible |
| URL wait + wait for the landing page's init-complete indicator to be visible | ✅ | e.g. `waitForURL('**/dashboard**')` → `getByRole('main').getByRole('tablist').waitFor({ state: 'visible' })` |

```typescript
// ❌ domcontentloaded is not a wait for navigation completion
await page.locator(':text-is("Log out")').click();
await page.waitForLoadState('domcontentloaded');  // returns immediately
await page.context().clearCookies();              // → ERR_ABORTED mid-transition

// ✅ Wait reliably via a visible destination element
await page.locator(':text-is("Log out")').click();
await loginPage.usernameInput.waitFor({ state: 'visible', timeout: TIMEOUTS.LONG });
```

```typescript
// ❌ Clicking immediately on URL arrival → swallowed by a parent handler during SPA init
await page.waitForURL('**/dashboard**');
await sideMenu.click();  // doesn't navigate, or does something else

// ✅ Click after the init-complete indicator element is visible
await page.waitForURL('**/dashboard**');
await page.getByRole('main').getByRole('tablist').waitFor({ state: 'visible' });
await sideMenu.click();
```

## Switching to tabs that may be empty (Archived / Deleted / Unread, etc.)

| What was tried | Result | Reason |
|-----------|------|------|
| Calling `getByRole('tab', { name: 'Archived' }).click()` right away | ❌ | When the tab is empty, many UI libraries (Ant Design etc.) set `aria-disabled="true"` on the Tab. `click()` waits for actionability and **hangs until the test timeout** (hang false positive) |
| Pre-guarding with `tab.isEnabled()` before switching | ✅ | Fails the expect immediately when empty → the true cause (the preceding flow didn't take effect, etc.) becomes apparent at once |

→ For details, see `rules/prohibited-patterns.md` "False positives in the form of hangs".

## Honest verification in the Cleanup phase

"Delete all" operations like `permanentDeleteAll()` / `clearAll()` pass straight through even when there is nothing to delete, so **expect the target's existence/disappearance before and after** to prevent no-op passes (false negatives).

| What was tried | Result | Reason |
|-----------|------|------|
| Tab switch → `permanentDeleteAll()` only | ❌ | Passes even when the target list is empty — a false negative |
| Before deletion: `expect(isXxxVisible).toBeTruthy()` that the target exists + after deletion: `expect(isXxxHidden).toBeTruthy()` that it's gone | ✅ | Leaves evidence that the deletion flow actually ran |

```typescript
// ✅ Zero-false-negative cleanup pattern
expect(await action.hasItemsInTab('Archived')).toBeTruthy();   // guard before switching tabs
await navigationAction.switchTab('Archived');
expect(await action.isItemVisible(targetName)).toBeTruthy();     // the target actually exists in Archived
await action.permanentDeleteAll();
expect(await action.isItemHidden(targetName)).toBeTruthy();      // verify it was permanently deleted
```
