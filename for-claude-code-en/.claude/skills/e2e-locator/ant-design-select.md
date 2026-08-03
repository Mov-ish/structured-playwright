# The Select Component Portal Problem (Common Across UI Libraries)

## Background: Two-Layer Structure

Many UI libraries (Ant Design / MUI / Headless UI, etc.) render the Select / Combobox dropdown in a **two-layer structure**:

| Layer | Element | Visibility | Purpose |
|----|------|--------|------|
| listbox layer | `<div role="option">` | **Hidden** (outside the viewport) | Accessibility (for screen readers) |
| portal layer | Library-specific class (e.g., Ant Design `.ant-select-item-option`) | **Visible** | The actual UI. Rendered into the root DOM outside the dialog |

Because the portal layer is rendered outside the dialog (directly under `body`, etc.), it cannot be found when searching within the modal scope.

## ❌ Failing Patterns

```typescript
// ❌ The option role is hidden → waitFor('visible') times out
await page.getByRole('option', { name: targetName }).click();

// ❌ Even with force:true, "Element is outside of the viewport" error
await page.getByRole('option', { name: targetName }).click({ force: true });

// ❌ fill() does not correctly trigger the search API debounce, and loading persists forever
await combobox.fill(targetName);
await page.locator('.ant-select-item-option').filter({ hasText: targetName }).click();
```

## ✅ Correct Pattern

```typescript
// Open the combobox and directly click the visible element on the portal side
const modal = page.getByRole('dialog');
const combobox = modal.getByRole('combobox');
await combobox.click();
// The portal renders outside the dialog, so grab it with page scope
const option = page.locator('.ant-select-item-option')  // Example: Ant Design
  .filter({ hasText: targetName }).first();
await option.click();
// Close the dropdown
await page.keyboard.press('Escape');
```

**Key points**:
- Do not use `fill()` — open the combobox with a click, then directly select the displayed option
- The option Locator uses `page.locator()` (whole page, not the modal scope) — because the portal renders outside the dialog
- Adding `.first()` is a stopgap for ambiguous matches (Category A). First check whether **exact matching** can remove the ambiguity
  - `filter({ has: page.getByText(name, { exact: true }) })` — literal matching, safe against metacharacters (avoid `new RegExp(...)`; if the name contains `[` `]` `.` `(` `)` etc., they are interpreted as regex metacharacters and exact matching breaks)
  - If exact matching cannot remove it and `.first()` remains, a **reason comment + TODO** is required (`prohibited-patterns.md`, "Acceptable boundaries for ordinal selectors" / `e2e-locator` §11)

## When Search Is Needed

If there are many options and scrolling would be required, try `pressSequentially`:

```typescript
await combobox.click();
await combobox.pressSequentially(targetName, { delay: 100 });
// Wait for the debounce to complete
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
// Grab it via the library-specific option class (example: Ant Design)
const option = page.locator('.ant-select-item-option')
  .filter({ hasText: targetName }).first();
await option.click();
```

## Test Data Caution

- Long target names get **truncated in the UI** (`text-overflow: ellipsis`) → `:text-is()` will not match
- Using **short names** for test data keeps things stable

## Option Classes per Library

When introducing this to a project, check the portal class of the UI library in use and replace the class name portion of the patterns above.

| Library | Example portal option class |
|------------|------------------------------|
| Ant Design | `.ant-select-item-option` |
| MUI (Material-UI) | `.MuiMenuItem-root` |
| Headless UI | `[role="option"]` (the one shown after the portal expands) |
