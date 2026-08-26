# Prohibited Patterns

The patterns in this file must not be used **in any task whatsoever**.

> **Machine detection**: grep-able patterns are mechanically judged via exit codes by `npm run gate` (`scripts/gate.sh`). This file's role is generation-time guidance ("prohibited → alternative") and providing judgment criteria for items the gate cannot decide (ordinal A/B/C, try-catch boundaries, Silent Skip, etc.).

## Prohibited Code Patterns

gate column: ✓ = detected mechanically by `npm run gate` (exit 1) / ⚠️ = surfaced by the gate as a warning (requires visual inspection) / — = judgment-based (decide using the criteria in this file)

| Prohibited | Reason | Alternative | gate |
|------|------|------|:---:|
| `text=Login` notation | Does not work in this project | `:has-text("Login")` or `getByRole` | ✓ |
| XPath (`//div/span`) | Structure-dependent, breeding ground for AI mis-generation | CSS + semantic | ✓ |
| CSS structural selectors (`div > div > button`) | Break instantly when the DOM shifts | Meaning-based + search scope | — |
| Ordinal selectors (`.first()` / `.last()` / `.nth()`) without a comment | Freezes a coincidence, unmaintainable (breaks on reorder / element addition) | See "Acceptable Boundaries for Ordinal Selectors" below (branches by use: A = comment + TODO / B & C = reason comment only) | ✓ |
| `.catch(() => false)` / `.catch(() => true)` | Hides timeouts, false positives | See "Allowed vs. Prohibited try-catch Boundaries" below | ✓ |
| Defining Locators with `private readonly` (Page Object layer) | Difficult debugging | `readonly` (public) | ✓ |
| `import { test } from '@playwright/test'` | Bypasses the Fixture | `from '../fixtures/app.fixture'` | ✓ |
| Direct `new XxxAction(page)` inside a Test | Dependencies not made explicit | Receive via Fixture arguments | ✓ |
| `expect()` in the Action layer | Assertions are the Test layer's responsibility | `waitFor()`-based verify methods | ✓ |
| Writing Locators directly in the Action / Test layer | Locators are the Page Object layer's responsibility | Move to the PO and go through its methods / go through the Action's verify methods | ✓ |
| `waitForTimeout()` in a Page Object | Fixed waits belong to the Action layer | `waitFor()` + try-catch | ⚠️ |
| `waitForTimeout()` inside a verify method (boolean) | The correctness of the judgment hinges on the wait duration + double waiting (see below) | Consolidate waits on the operation-method side; verify observes only (the gate detects this mechanically via AST) | ✓ |
| Semantic Locators on elements with a minimal semantic layer | Do not work due to missing attributes | `:near()` / `svg[data-icon]` | — |
| Using `has-text` without a scope | Same text appears multiple times → mis-hits | Narrow with role+name+exact or a search scope | — |
| Searching for a modal across the whole `page` | Accidental clicks on background buttons | Confine with `[role="dialog"]` | — |
| The `locator(SELECTORS.MODAL).last()` hybrid | The worst combination: slapping the stale-workaround `.last()` onto an attribute selector that does not exclude hidden elements (see below) | Active modal: `getByRole('dialog').last()` / single-modal scoping: `SELECTORS.MODAL` without `.last()` | ✓ |
| Module-scope random value + implicit dependency across multiple `test()` blocks | No partial execution, no reuse in other tests (see below) | Parameterize / Setup Action / `beforeAll` (see `architecture.md`) | ⚠️ |
| Action directly referencing a module-scope variable | Behavior changes when called from another test | Receive as an argument | — |

## Acceptable Boundaries for Ordinal Selectors (`.first()` / `.last()` / `.nth()`)

Ordinals fall under the "eliminate coincidence" principle (`locator-principles.md`), but **a blanket ban is wrong** — **ordinals used for disambiguation** branch into 3 categories by use. Direct expressions of intent (an `nth(i)` iterator over a counted scan, or `nth(param)` with an argument-derived index) are outside this classification — a reason comment alone is required.

| Category | Example | Nature | Treatment |
|---------|----|------|------|
| **A: Stopgap for an ambiguous match** | Multiple matches → `.first()` | Freezes a coincidence (breaks on reorder / element addition) | Last resort. Try the upper pyramid levels first + reason comment **+ TODO** |
| **B: Framework invariant** | `getByRole('dialog').last()` = active modal | Encodes a real invariant: z-order = DOM append order | Allowed only when both ① and ② below hold. Reason comment required, **no TODO needed** |
| **C: Drain-loop iteration** | A `.first()` that repeats "process the first item" until 0 remain | All items get consumed in any order; order carries no meaning | Allowed only when both ① and ② below hold. Reason comment required, **no TODO needed** |

**Judgment criterion**: is it "selecting by position by happenstance (A)," "a position that carries meaning through an invariant (B)," or "a drain loop where order does not affect the result (C)"?

**B qualification conditions (both required; missing either one makes it A)**:
1. **Verifiable as framework behavior** — the rationale can be articulated from the UI library's documented behavior or DOM construction rules ("probably the last one" as a rule of thumb is not B)
2. **No alternative implementation physically exists** — the upper levels of the priority pyramid cannot uniquely identify the element (if they can, it is A = something to remove)

**C qualification conditions (both required; missing either one makes it A)**: ① the caller drains all items in a loop until 0 remain (a one-off "take the first" is A) ② the extraction order does not affect the result. Completeness of the drain is guaranteed by a separate guard (maxLoops + throw; see "False Positives in the Form of Hangs") — without the guard, even C fails.

> **WHY (why the conditions are spelled out)**: without them, over-generous B/C classification mass-produces TODO-less comments (lax judgment breeds false justification). **When in doubt, classify as A.**

The canonical source for the resolution procedure and code examples (❌ no comment / ✅ A reason + TODO / ✅ B invariant only / ✅ C drain loop) is **`e2e-locator` §11**.

### Active Modal Idiom — When to Use `activeDialog()` vs. `SELECTORS.MODAL`

`SELECTORS.MODAL` (`[role="dialog"]`) and `activeDialog()` (`getByRole('dialog').last()`) are **not competitors; they have different roles**.

| Use case | What to use | Reason |
|------|---------|------|
| **Picking the "last opened = active" modal out of accumulating stale dialogs** | `getByRole('dialog').last()` | `getByRole` automatically excludes hidden elements → robust against stale leftovers |
| **Scoping to a single modal to grab elements inside it** | `SELECTORS.MODAL` (`[role="dialog"]`) | The search-scope constant. Managed in one place across files |
| **The hybrid `locator(SELECTORS.MODAL).last()`** | ❌ **Prohibited** | The worst combination: slapping the stale-workaround `.last()` onto an attribute selector that does not exclude hidden elements |

## Prohibited Value Patterns

| Prohibited | Reason | Alternative | gate |
|------|------|------|:---:|
| Hard-coded timeout values (`2000`, `10000`) | Reduced maintainability | Constants such as `TIMEOUTS.SPA_RENDERING` | ✓ |
| Hard-coded URL patterns (`'**/login**'`) | Missed fixes when environments change | Constants such as `URL_PATTERNS.LOGIN` | ✓ |
| Hard-coded shared selectors (`'[role="dialog"]'`) | Lack of consistency | Constants such as `SELECTORS.MODAL` | — |
| Hard-coded credentials | Security risk | `.env` + `EnvConfig` | — |
| `waitForTimeout` without a reason comment on that line | Intent unclear, unmaintainable | On that line, state "which preceding operation this waits on, and for what" (paraphrasing the constant name does not count). The constant's own meaning lives at its declaration site (constants.ts) (the gate detects this mechanically) | ✓ |
| Generating a unique test data name with `Date.now()` alone | Parallel workers (separate processes) collide within the same ms | `uniqueId()` (see "Generate Unique Test Data Names with uniqueId()" below) | ✓ |
| Partial-match expect (`toContain`/`toContainText`/`toMatch`) without a reason comment | `'1'` ⊂ `'10'`-style false positives = a degradation where everything stays green while only the verification dies | Default to exact matching (`toBe`/`toEqual`). Partial matching requires a comment explaining why exact matching is impossible | ✓ |

## Allowed vs. Prohibited try-catch Boundaries

Not all code that returns `false` in a catch is prohibited. Judge by **what the catch is catching**.

| | Condition being awaited | Meaning of false | Verdict |
|---|---|---|---|
| Timeout of `waitFor({ state: 'visible' })` | An element state transition (hidden → visible) | "It never reached that state" | ✅ Allowed |
| Failure of an operation such as `click()` / `fill()` | Success of the operation | "Something failed" (cause unknown) | ❌ Prohibited |
| Failure of a retrieval such as `textContent()` / `inputValue()` | Retrieval of a value | "Something failed" (cause unknown) | ❌ Prohibited |

**Judgment criterion**: does the catch block catch *only* "a timeout of an element state transition"? If yes, allowed; if no, prohibited (separate waitFor and value retrieval into distinct try-catches).

The canonical source for code examples (✅ allowed / ❌ mixed-in / ✅ separated) is **`e2e-test-create` §3 "try-catch boundaries"**.

## Fixed Waits Inside verify — Consolidate Waits in Operation Methods

**Do not put `waitForTimeout` inside verification methods (verify) that return a boolean.** Even within the same Page Object, this differs in nature from "a fixed wait at the end of an operation method (void)."

| | Operation method (void) | verify method (boolean) |
|---|---|---|
| Examples | `selectItem()` / `deleteItem()` | `isItemVisible()` / `isItemAbsent()` |
| Responsibility | An action that changes the DOM | Observing the current state and returning true/false |
| What is being waited on | **The aftermath of the action inside the same method** (re-render right after a click) | Changes that happened outside the method (results of other methods' actions) |
| Impact of an insufficient wait | Subsequent operations are merely delayed | **The judgment passes incorrectly** (flaky via false negatives / false positives) |
| Wait owner | An adjunct of the action | (Properly, the caller's flow control) |
| Verdict | Tolerated as an existing convention | ❌ **Prohibited** |

**WHY**: verify's responsibility is "observe and return true/false." Once a fixed sleep gets mixed in: ① the correctness of the judgment hinges on the wait duration (flaky false negatives / false positives); ② the end of the operation method and the start of the verify wait for the same render to settle twice (dispersed wait ownership = collapse of layer responsibilities); ③ even one remaining instance gets imitated and multiplied by the AI as a "correct pattern."

The canonical source for code examples (❌ fixed wait inside verify / ✅ consolidated into the operation method) and the "transition verification" pattern (the `isPresent → action → isAbsent` pair that eliminates false positives) is **"verify observes only" in `e2e-test-create/test-data-management.md`**.

### Exception

When the subject of the judgment is itself "a timeout of a state transition," `waitFor({state:'visible'/'hidden'})` + try-catch is allowed (see "Waits Permitted in Page Objects" in `architecture.md`). This is the case where "the observation itself includes a waiting strategy," which is different in kind from a blind fixed wait like `waitForTimeout`.

## No Silent Skipping of Test Conditions (Silent Skip)

If an operation the test explicitly requested cannot be performed, **Fail rather than skip**.

| Situation | Verdict | Reason |
|------|------|------|
| `required: true` → checkbox not found | ❌ Must Fail | The test condition is not satisfied |
| `submitAnswer()` → submit button not found | ❌ Must Fail | The test operation was not performed |
| A confirmation modal sometimes appears and sometimes doesn't → it didn't | ✅ Skip allowed | Absorbing environment differences (not a test condition) |
| The post-logout redirect destination differs by environment | ✅ Skip allowed | Absorbing environment differences |

**Judgment criterion**: is the operation **something the test explicitly requested**, or **defensive code to absorb environment differences**?

- Test conditions (made explicit via arguments/parameters) → **Fail if not found**
- Absorbing environment differences (presence of a modal, differing destinations) → **skip allowed**

The canonical source for code examples (❌ silent skip / ✅ throw on required) is **"Fail when a test condition cannot be met" in `e2e-test-create/test-data-management.md`**.

## False Positives in the Form of Hangs

Beyond `waitForTimeout`, **click/hover on a disabled element also produces "false positives in the form of a hang."** Playwright's `click()` internally waits for actionability (visible + enabled + stable), so it keeps waiting on an element with `aria-disabled="true"` or the `disabled` attribute and hangs until the test timeout. "Hang → timeout Fail" is formally a Fail, but it has harm close to a false positive in that **it takes time to disentangle whether the root cause is "the data differs from expectations" or "the Locator is wrong," delaying feedback**.

| Situation | Verdict | Recommendation |
|------|------|------|
| Directly `click()`-ing a tab/button that becomes disabled when empty | ❌ Hang false positive | Verify with `isEnabled()` beforehand and fail fast |
| Running an operation that "assumes targets exist" (bulk delete / process-all, etc.) in an empty context | ❌ Empty-swing false positive | Verify target existence with `expect(...).toBeTruthy()` before operating |

Representative example: **the trap where a UI library's Tabs become `aria-disabled="true"` when their content is empty** (Ant Design Tabs / MUI Tabs / Radix UI Tabs, etc.).
See `.claude/skills/e2e-locator/ant-design-tabs-disabled.md` for details.

The canonical source for pre-guard code examples (the transition verification of existence check → switch → operate → absence check) is **"Honest verification in the Cleanup phase" in `e2e-test-create/test-data-management.md`**.

## Warning Patterns in AI-Generated Code

- 5 or more occurrences of `.catch(() => false)` → suspect AI copy-paste
- Mass duplication of the same error-handling pattern → if one instance is a problem, the whole is a problem
- **"It runs" ≠ "it is correct"** — a test's value lies in its ability to fail

## Inter-Test Data Dependencies (Implicit Test Coupling)

A structure where multiple `test()` blocks **implicitly** depend on module-scope variables or on state created by a previous test is prohibited.

### What Is the Problem

The canonical source for code examples of the typical anti-pattern (module-scope random value + implicit references from multiple `test()` blocks) is **`e2e-test-create/test-data-management.md`**.

| Harm | Concrete example |
|------|-------|
| No partial execution | Running only Phase 2 via `-g "Phase 2"` fails because the resource does not exist |
| No reuse | The Phase 2 flow cannot be invoked from another spec |
| Hard to debug | When Phase 1 fails, Phase 2 is not skipped and fails for a different reason, muddying the cause |
| Implicit coupling | `[Arrange]` and `[Act]` straddle test boundaries, breaking test independence |

### Judgment Criteria

- Dynamic values (`uniqueId()` / `Date.now()`, etc.) at module scope (outside `describe`) → ❌
- An Action directly referencing a module-scope variable → ❌
- A unique ID fully contained within a `test()` (`const random = uniqueId()` declared inside the `test()`) → ✅ (uniqueness is ensured by `uniqueId()`. `Date.now()` alone is ❌ → see "Generate Unique Test Data Names with uniqueId()")
- Preparing data in `test.beforeAll` and sharing via a `describe`-scope variable → ✅
- Preparing data via a Setup Action + Fixture → ✅ (recommended; see `architecture.md`)

### Exception

For tests where "the entire TC is one long user story and running end-to-end is the essence," avoid implicit dependencies by **running all Phases inside a single `test()`** rather than splitting `test()`. If you want Phase divisions, express them at the granularity of `test.step()` or individual Actions.

## Generate Unique Test Data Names with uniqueId() (No Reliance on Date.now() Alone)

The uniqueness of test data names **must not rely solely on the milliseconds of `Date.now()`**.

> **A separate issue from the scope axis**: this is an **orthogonal, independent concern** from "Inter-Test Data Dependencies" above (module scope vs. `test()`-internal scope). Even inside a `test()`, `Date.now()` alone collides across parallel workers. Both requirements must be satisfied.

### What Is the Problem

**WHY**: in parallel execution, each worker is a separate process, so identically named data gets generated within the same ms, and things fall over on multiple matches (strict mode violation) in `getByText` and the like. It does not surface in solo runs and **first appears as flakiness in parallel CI**.

| Harm | Concrete example |
|------|-------|
| Parallel collision | Worker A and Worker B generate identically named resources in the same ms → `getByText` matches 2 elements |
| Collision via shared prefix | `itemName${random}` shares its prefix with another test → collides if in the same ms |
| Made worse by `.slice()` | `Date.now().toString().slice(-6)` re-collides on a cycle of roughly 1000 seconds |

### Judgment Criteria

| Pattern | Verdict |
|---|---|
| Building a unique name from `const random = Date.now().toString()` alone | ❌ |
| Trimming digits, e.g. `Date.now().toString().slice(-6)` | ❌ (raises the collision probability by orders of magnitude) |
| Generating with `const random = uniqueId()` (ms + random) | ✅ |

### Correct Implementation

**Canonical source of the template = `e2e-bootstrap` §4 "src/utils/uniqueId.ts"** (a unique suffix of base-36 ms + 6 random characters, padded to fixed length with `padEnd`).

> ※ Using `Math.random()` / `Date.now()` in test code is fine in itself (only their sole use for unique **name generation** is prohibited).
