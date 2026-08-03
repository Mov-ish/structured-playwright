# The Ant Design Tabs disabled Trap

## Conclusion

**In Ant Design Tabs, a "tab with empty content" becomes unclickable via `aria-disabled="true"`.**
Calling `tab.click()` without knowing this makes Playwright's `click()` **hang waiting for actionability, up to the full test timeout (e.g., 600s)**, then Fail after the timeout. This is the worst possible feedback loop: "it looks like a correct Fail, but you only find out after a several-minute-to-10-minute hang."

## Background: Observed DOM

```html
<!-- Tab with empty content (e.g., Trash / Archive / Unread, etc.) -->
<div
  role="tab"
  aria-disabled="true"
  aria-selected="false"
  class="ant-tabs-tab-btn"
  id="rc-tabs-N-tab-archive"
>Deleted</div>
```

Playwright's `isEnabled()` interprets `aria-disabled="true"` and returns `false`.
`click()` internally waits for actionability (visible + enabled + stable), so it keeps waiting for an element that never becomes enabled and hangs.

## ❌ Failing Patterns

```typescript
// ❌ Hangs when the tab is empty. Playwright's error log:
//   - waiting for getByRole('tab', { name: 'Deleted' })
//   - locator resolved to <div role="tab" aria-disabled="true" ...>Deleted</div>
//   - attempting click action
//     - element is not enabled
//     - retrying click action
//     - waiting 500ms
//     ...(retries forever until the timeout)
await page.getByRole('tab', { name: 'Deleted' }).click();

// ❌ Wrapping it in the Action layer behaves the same. Even if you chain another
//   operation like deletion right after tab.click, the switch never succeeded,
//   so execution never gets there
await navigationAction.switchTab('Deleted');
await action.permanentDeleteAll();  // Never reached because the line above hangs
```

## ✅ Correct Pattern: Guard on enabled Before Switching

"The tab is empty = there are no items in that area" is domain information — **pre-verify** it before switching.
By failing immediately instead of hanging, you can instantly identify the root cause (the preceding soft-delete flow did not take effect, the data differs from expectations, etc.).

```typescript
// Page Object: tab enabled check
async isTabEnabled(tabName: string): Promise<boolean> {
  const tab = this.page.getByRole('tab', { name: tabName });
  await tab.waitFor({ state: 'visible', timeout: TIMEOUTS.DEFAULT });
  // isEnabled() is a Promise<boolean>. Inside an async function, make return await explicit
  // (improves stack traces and prevents reader misunderstanding)
  return await tab.isEnabled();  // Interprets aria-disabled and returns true/false
}

// Action layer: verify method (returns a boolean; never writes expect)
async hasItemsInTab(tabName: string): Promise<boolean> {
  return this.pageObject.isTabEnabled(tabName);
}

// Test layer: fail-fast with expect *before* switching
expect(await action.hasItemsInTab('Deleted')).toBeTruthy();
await navigationAction.switchTab('Deleted');
expect(await action.isItemVisible(targetName)).toBeTruthy();
await action.permanentDeleteAll();
expect(await action.isItemHidden(targetName)).toBeTruthy(); // Post-verification of permanent deletion
```

## Why the Pre-Guard Is Necessary

| Approach | When hitting an empty tab | False-positive risk | Cause isolation |
|---|---|---|---|
| Call `switchTab` directly | Hangs until test timeout, then Fails | None (it does Fail) | **Hard**: unclear whether the hang is caused by the empty tab or the Locator |
| `hasItemsInTab()` pre-expect | Immediate expect failure | None | **Clear**: instantly reveals "no items in that area = the preceding flow did not take effect" |

## Extending to Other Tabs / Other Screens

This pattern applies to Ant Design Tabs in general. The same trap can occur in any UI where "a tab is disabled when its content is zero" (e.g., "Unread" in a notification list, "Overdue" in a task list, "Archive" in file management, etc.); in those cases apply the same pre-guard procedure.

The generic form of the check is `isTabEnabled(tabName)` above; parameterizing the tab name makes it reusable.

## Similar Patterns in Related UI Libraries

UI that becomes unclickable via `aria-disabled` exists widely regardless of library. Representative examples:

- **MUI Tabs**: `<Tab disabled>` adds `aria-disabled="true"`
- **Headless UI**: the `disabled` prop behaves the same
- **Radix UI Tabs**: additionally adds `data-disabled`

Playwright's `isEnabled()` interprets all of them, so the same guard pattern handles each case.

## Related Topics

- `prohibited-patterns.md`, "False positives in the form of hangs": prohibited under the same philosophy.
- `locator-principles.md` §1 "Future value": `isEnabled()` itself evaluates immediately, which is OK, but inserting a visibility `waitFor({state:'visible'})` first is safer (wait until the element becomes obtainable as a Future value, then judge).
