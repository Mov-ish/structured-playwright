# Test Data Management (canonical source for §9)

> **Canonical source = this file** (extracted from e2e-test-create §9). Read when designing test data, deciding whether to extract a Setup Action, or structuring [Arrange].

- Static test data: place JSON files in `src/config/testdata/`
- Dynamic test data: generate unique names with `uniqueId()` (`src/utils/uniqueId.ts`). **Bare `Date.now()` is prohibited because of parallel-worker collisions** (see `prohibited-patterns.md` "Generate unique test data names with uniqueId() (No Reliance on Date.now() Alone)"). Include the TC identifier in the prefix (`ResourceTC01_${random}`)
- Post-test cleanup: implement deletion of created data as an Action

### Sharing data across multiple `test()` blocks

**Prohibited**: a structure where `const random = uniqueId()` sits at module scope and multiple `test()` blocks reference it implicitly (the canonical criteria and harms are in `prohibited-patterns.md` "Inter-Test Data Dependencies (Implicit Test Coupling)"). Building names with bare `Date.now()` for uniqueness is also prohibited (see "Generate unique test data names with uniqueId()" there).

```typescript
// ❌ The typical prohibited form
const random = uniqueId();                       // module scope
const RESOURCE_NAME = `Resource${random}`;

test.describe('TC-XX', () => {
  test('Phase 1: create', async () => { /* create a resource named RESOURCE_NAME */ });
  test('Phase 2: use', async () => { /* search for RESOURCE_NAME — implicitly depends on Phase 1 */ });
});
```

**Recommended pattern quick reference** (this section is the canonical source for implementation patterns; the norm for scope design is `architecture.md` "Sharing and reusing test data"):

| Situation | Implementation |
|------|------|
| Self-contained in a single `test()` | `const random = uniqueId()` inside the `test()` |
| Phase split within the same describe | Prepare data in `test.beforeAll` + share via describe-scope variables |
| Reused from another spec / another TC | Setup Action + Fixture (below) |
| The whole TC is an end-to-end user story | Don't split `test()`; keep it in one `test()` and express Phases with `test.step()` |

**Decision flow**:
1. Could it be called from another `test()` in the same spec? → **If yes, Action parameterization is mandatory**
2. Could it be called from another spec / another TC? → **If yes, extract a Setup Action + Fixture**
3. Ensuring uniqueness → generate with `uniqueId()` (bare `Date.now()` prohibited). **Generate outside the Action (inside the test() or in beforeAll) and pass via arguments**

> ⚠️ **Do not short-circuit into "Phase = `test()` block".** Phase notation in the procedure document (JSDoc) and `test()` splitting are different things. A continuous story where later stages depend on earlier artifacts (create → use → complete) is a **single `test()` + `test.step()`**. Splitting `test()` per Phase and passing state via `describe`/module-scope variables creates Implicit Test Coupling. The fix is **"bundle vertically (turn Arrange into a builder) + a single `test()`"**, not test() splitting.

#### End-to-end test bloat and consolidating base creation

Running `create → use → complete` **in a single `test()` is only for when "completion under that condition" is itself the test subject**.
If the test subject is something else (detailed behavior, access conditions, etc.) and resource creation is a mere prerequisite, **push the creation out into a Setup Action and narrow the test body**.

On top of that, **do not inline-expand the base-creation flow (configure → add sub-items → publish → register users) into tests or TCs**.
Consolidate it into a shared builder (Setup Action); each TC passes only its configuration parameters.

> **Reason (propagation via AI imitation)**: a large inlined creation block gets copied into the next TC as "the strongest known-good answer", and the bloat propagates. Moved into a shared builder, what propagates when copied is "a builder call + clean structure".

For end-to-end TCs where creation itself is the subject (= those that keep a single `test()`), state the intent and the prohibition in a **load-bearing comment**:

```typescript
/**
 * TC-XX: Creating an XX resource (intentionally end-to-end)
 * This test keeps a single test() because "creating the XX resource + completion under that condition" is the subject.
 * Do not imitate this monolithic shape in tests with a narrower subject (detailed behavior only, etc.).
 * Base creation goes through ResourceSetupAction (the shared builder).
 */
```

**Readability guard (only `[Arrange]`/`[Cleanup]` may be extracted)**: don't fold `[Act]`/`[Assert]` into builders (keep the subject inline) / arguments are options + intent-revealing names, not a row of booleans / the builder name states the end state and the return value provides the generated names / don't unify merely-similar twins into one branching builder. Acceptance criterion: "a human opening the spec can answer, without leaving the file, (a) what state it starts from and (b) what it verifies".

#### The `beforeAll` pattern (Phase split within the same describe)

```typescript
test.describe('TC-XX: resource usage story', () => {
  let resourceName: string;
  let subItemName: string;

  test.beforeAll(async ({ browser }) => {
    const context = await browser.newContext();
    const page = await context.newPage();
    // Create the resource with a setup Action
    const random = uniqueId();
    resourceName = `Resource${random}`;
    subItemName = `SubItem${random}`;
    // ... implementation
    await context.close();
  });

  test('Phase 2: the user uses the resource', async ({ resourceUseAction }) => {
    await resourceUseAction.searchAndOpen(resourceName);  // received via argument
    // ...
  });
});
```

#### The Setup Action pattern (reuse from other TCs)

```typescript
// actions/ResourceSetupAction.ts — the shared flow that builds "a ready-to-use resource set"
export class ResourceSetupAction extends BaseAction {
  async createPublishedResource(opts: {
    random: string;
    ownerName: string;
  }): Promise<{ resourceName: string; subItemName: string }> {
    this.beginAction();
    const resourceName = `Resource${opts.random}`;
    // ... create the resource → add sub-items → publish
    return { resourceName, subItemName: `SubItem${opts.random}` };
  }
}

// Register in fixtures/app.fixture.ts
resourceSetupAction: async ({ page, stepCounter }, use) => {
  await use(new ResourceSetupAction(page, stepCounter));
},
```

```typescript
// Consumer side
test('TC-XX: usage story', async ({ resourceSetupAction, resourceUseAction }) => {
  const random = uniqueId();
  const { resourceName } = await resourceSetupAction.createPublishedResource({ random, ownerName: 'User' });
  await resourceUseAction.searchAndOpen(resourceName);
  // ...
});
```

### Parameterizing Actions (preparing for reuse)

Any flow with **even a slight chance of being reused** (using a resource, confirming completion, navigating to another screen, etc.) should be **parameterized from the start**. The rework cost of retrofitting it for reuse later is greater.

```typescript
// ❌ Referencing outer scope inside the Action (module constant RESOURCE_NAME etc.)
async openResource(): Promise<void> { await this.searchInput.fill(RESOURCE_NAME); }

// ✅ Receive it via an argument
async openResource(resourceName: string): Promise<void> { await this.searchInput.fill(resourceName); }
```

Anything at the granularity of a Shared Step in external test tools (resource operations, state checks, teardown, etc.) should be Action-parameterized from the start.

### verify observes only — fixed waits go into operation methods

A `waitForTimeout` inside a verify (boolean-returning) method gambles the correctness of the check on the wait time — a breeding ground for false positives/negatives (the canonical criteria are in `prohibited-patterns.md` "Fixed waits inside verify").

```typescript
// ❌ Prohibited: a fixed wait inside verify — correctness of the check hinges on 2 seconds
async isItemAbsent(title: string): Promise<boolean> {
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // ← waiting for another action's result
  const values = await this.collectItemTitles();
  return !values.includes(title);
}

// ✅ Correct: consolidate waits in the operation method; verify observes only
async deleteItem(): Promise<void> {
  await this.deleteButton.click();
  await this.confirmButton.click();
  await this.page.waitForTimeout(TIMEOUTS.SPA_RENDERING); // ← waiting out this action's own aftermath (convention)
}
async isItemAbsent(title: string): Promise<boolean> {
  const values = await this.collectItemTitles();
  return !values.includes(title);
}
```

**The "transition verification" pattern**: when verify returns "being in a certain state", the caller verifies both before and after the change. `isAbsent` alone cannot distinguish "never existed in the first place" from "removed by the deletion".

```typescript
// Before deletion: the target exists (without this precondition check you can't claim "the deletion removed it" — false positive)
expect(await resourceAction.isItemPresent(title)).toBeTruthy();
await resourceAction.deleteItem();
// After deletion: the target is gone
expect(await resourceAction.isItemAbsent(title)).toBeTruthy();
```

### Fail when test conditions cannot be met (code example of the Silent Skip prohibition)

The canonical criteria for test conditions (explicit via arguments/parameters) vs. absorbing environment variance are in `prohibited-patterns.md` "No silent skipping of test conditions".

```typescript
// ❌ Prohibited: silently swallowing the test condition
async checkRequired(): Promise<void> {
  try {
    await this.checkbox.waitFor({ state: 'visible', timeout: TIMEOUTS.ELEMENT_CHECK });
  } catch {
    console.log('Not found, skipping');  // ← passes without the test condition being met — a false positive
    return;
  }
  await this.checkbox.check();
}

// ✅ Correct: Fail when the test condition cannot be met
async checkRequired(required: boolean): Promise<void> {
  try {
    await this.checkbox.waitFor({ state: 'visible', timeout: TIMEOUTS.ELEMENT_CHECK });
  } catch {
    if (required) {
      throw new Error('Required checkbox not found (required=true)');
    }
    return; // absence is acceptable when required=false
  }
  if (required) {
    await this.checkbox.check();
  } else {
    await this.checkbox.uncheck();
  }
}
```

### Honest verification in the Cleanup phase

"Delete all" operations like `permanentDeleteAll()` / `clearAll()` pass straight through even when there is nothing to delete, so **expect the target's existence/disappearance before and after** to prevent no-op passes (false positives).

| What was tried | Result | Reason |
|-----------|------|------|
| Tab switch → `permanentDeleteAll()` only | ❌ | Passes even when the target list is empty — a false positive |
| Before deletion: `expect(isXxxVisible).toBeTruthy()` that the target exists + after deletion: `expect(isXxxHidden).toBeTruthy()` that it's gone | ✅ | Leaves evidence that the deletion flow actually ran |

```typescript
// ✅ Zero-false-positive cleanup pattern
// isItemHidden waits in the waitFor({state:'hidden'}) direction — !isItemVisible is not a substitute
expect(await action.hasItemsInTab('Archived')).toBeTruthy();         // guard before switching tabs
await navigationAction.switchTab('Archived');
expect(await action.isItemVisible(targetName)).toBeTruthy();           // the target actually exists in Archived
await action.permanentDeleteAll();
expect(await action.isItemHidden(targetName)).toBeTruthy();            // verify it was permanently deleted
```

```typescript
// ❌ domcontentloaded is not a wait for navigation completion
await this.page.locator(':text-is("Log out")').click();
await this.page.waitForLoadState('domcontentloaded');  // returns immediately
await this.page.context().clearCookies();              // → ERR_ABORTED during the /logout transition

// ✅ Wait reliably via a visible destination element
await this.page.locator(':text-is("Log out")').click();
await this.loginPage.usernameInput.waitFor({ state: 'visible', timeout: TIMEOUTS.LONG });
```

```typescript
// ❌ Clicking immediately on URL arrival → swallowed by a parent handler during React init
await this.page.waitForURL('**/dashboard**');
await sideMenu.click();  // doesn't navigate, or selects a different tab

// ✅ Click after the init-complete indicator element is visible
await this.page.waitForURL('**/dashboard**');
await this.page.getByRole('main').getByRole('tablist').waitFor({ state: 'visible' });
await sideMenu.click();
```

---
