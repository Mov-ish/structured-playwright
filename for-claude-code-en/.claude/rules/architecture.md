# 4-Layer Architecture Responsibilities and Boundaries

## Layer Structure

```
Layer 4: Config/Env     → Environment settings, constants (constants.ts / env.ts)
Layer 3: Tests          → Expected result validation (AAA pattern)
Layer 2: Actions        → Business flows, multi-screen control
Layer 1: Page Objects   → UI element definitions, basic operations
```

```
src/
├── config/      # Layer 4
├── pages/       # Layer 1 (Locators live here and only here)
├── actions/     # Layer 2
├── fixtures/    # Test layer infrastructure (app.fixture.ts)
└── tests/       # Layer 3
```

## Absolute Boundaries Between Layers

| Rule | Reason |
|--------|------|
| **No Locators in the Test layer** | Tests express intent and expected results. They have no need to know UI structure |
| **No expect() in the Action layer** | expect is a test-specific assertion. Actions are reusable flows |
| **No business logic in Page Objects** | POs contain only UI elements and single-responsibility methods. Flows belong to the Action layer |
| **No direct imports from `@playwright/test`** | Import `test`/`expect` via the Fixture |
| **Do not manually `new` Actions** | Receive them via Fixture arguments (makes dependencies explicit) |

## Reconciling Verification Between the Test and Action Layers

Locators cannot be written in the Test layer, and expect cannot be written in the Action layer. The pattern that satisfies both at once:

**Action layer**: implement `waitFor()`-based verify methods (waitFor is a waiting operation, not an assertion)

> The only thing that may be caught is "a timeout of an element state transition" (do not put operations other than waitFor inside the same try-catch). The canonical source for the boundary criteria and prohibited examples is "Allowed vs. Prohibited try-catch Boundaries" in `prohibited-patterns.md`; the canonical source for code examples is `e2e-test-create` §3 "try-catch boundaries".

**Test layer**: verify the return value of verify methods with expect() (never write Locators directly).

## Page Object Access Modifiers

Defining Locators with `private readonly` is prohibited. Use `readonly` (public). See "Prohibited Code Patterns" in `prohibited-patterns.md` for details.

Reason: allows direct element access from tests during debugging. Consistent design pattern.

## Waits Permitted in Page Objects

State-check methods that return a boolean via `waitFor()` + try-catch are permitted.
Assertions via `expect()` are prohibited. `waitForTimeout()` is prohibited inside verify methods (boolean) (the gate detects this mechanically via AST); at the end of operation methods (void) it is tolerated as an existing convention (canonical source: `prohibited-patterns.md`).

**Do not place fixed waits inside verify methods (boolean-returning state checks).**
Consolidate fixed waits on the operation-method (void) side; verify methods do **observation only**.
`waitForTimeout` inside verify is a breeding ground for false positives / false negatives — "the correctness of the judgment hinges on the wait duration" and "wait ownership gets duplicated". See "Fixed Waits Inside verify — Consolidate Waits in Operation Methods" in `prohibited-patterns.md` for details.

## Action Layer Step Logging

Each step in the Action layer is recorded via the `this.step()` helper (bare `console.log` is prohibited).
`this.step()` performs console output (user-story granularity) and `test.step()` (hierarchical display in the HTML report) simultaneously.
On failure, the failing step can be identified immediately.

### Separation of Responsibilities

| Output target | Granularity | Purpose |
|--------|------|------|
| **Console** | `Step N: ActionName - details` (user-story granularity) | Real-time progress tracking, locating position in CI logs |
| **HTML report** | Hierarchical display of Action internals via nested `test.step()` | Detailed debugging on failure |

### BaseAction / StepCounter Contract

**Canonical source of the template (copy origin) = `e2e-bootstrap` §6; canonical source of the implementation = `src/actions/`.**
The rules do not hold implementation code (copy drift leads to the accident of "trusting an outdated template as correct").
This contract alone guarantees that a correct Action can be written without opening the actual files.

- `protected beginAction(): void` — required at the top of every public method of an Action (see the "beginAction() Rules" table below for which methods are covered)
- `protected async step(name: string, fn: () => Promise<void>): Promise<void>` — records each step. Performs console output (`[Suite / Phase] Step N: ActionName - details`) and `test.step()` (HTML report hierarchy) simultaneously
- `step()` **does not catch errors thrown while fn() runs; it lets them propagate** (catching them breeds false Pass = flaky pass)
- **If `step()` is called while `beginAction()` was forgotten, it throws immediately** (no silent pass-through. If you hit this error, the cause is a forgotten call)
- Main number = per **public method call of the Action** (multiple `step()` calls inside an Action share the same number; internal details are expressed via nesting in the HTML report)
- Each worker has its **own independent StepCounter** — numbers from different describes cannot be compared with each other
- Create the StepCounter as a **worker-scoped Fixture** and inject it shared into all Actions (with test scope, numbering would not continue across test() calls). Automatically resets at describe boundaries; within the same describe, numbering continues sequentially across test() calls
- New Actions take `(page, stepCounter?)` in the constructor and call `super(page, 'XxxAction', stepCounter)` (BaseAction's constructor is `(page, actionName, stepCounter?)`. The second argument actionName is the log display name; `stepCounter` is optional)

For implementation details such as automatic prefix derivation (titlePath, splitting on `:`) and output examples, see `e2e-bootstrap` §6.

### Usage

The canonical source for code and output examples is `e2e-bootstrap` §6.

### beginAction() Rules

| Target | beginAction() |
|------|--------------|
| Public methods that use `this.step()` | **Required** |
| Verification methods (`isXxx()` → boolean, etc.) | Not needed (they do not use step()) |
| private / protected methods | Not needed |

If `this.step()` is called while `beginAction()` was forgotten, `BaseAction.step()` **throws** immediately (no silent pass-through). This behavior aligns with "early detection of design violations" and this template's false-positive prevention philosophy.

### Anti-Nesting Rule

**In the Test layer, do not wrap Action calls 1:1 in `test.step()`.** The Action's `this.step()` already issues `test.step()`, so this creates double nesting and degrades HTML report readability.
Phase-level grouping (wrapping multiple Action calls together in a single `test.step('[Act] Phase N: ...')`) is the standard form of "Express Phase divisions with `test.step()` as a rule" under "Test Layer Header Comments" below, and is **not covered by this prohibition**. The judgment is based on the meaning of the `test.step()` name, not the number of Action calls — a name that merely echoes the Action name (e.g., `'createResourceAction'`) is prohibited; a Phase heading (e.g., `'[Act] Phase 1: ...'`) is acceptable even if it contains only one Action call.

## Test Layer Header Comments (Test Procedure)

Every `.spec.ts` file describes the test procedure in natural language in a header JSDoc comment.

**Required items**:
- Test case number and summary
- Steps per Phase (numbered)
- `[Arrange]` `[Act]` `[Assert]` `[Cleanup]` tags on each Phase
- Verification points (what each expect confirms)
- Intentional deviations from the source procedure (write "None" if none — field format and example targets: `e2e-test-create/jsdoc-template.md`)

**The canonical source for the full template and the meaning table of the tags ([Arrange]/[Act]/[Assert]/[Cleanup]) is `e2e-test-create/jsdoc-template.md`** (loaded at writing time).

**Rules**:
- Always write it when creating a test
- **Express Phase divisions with `test.step()` as a rule. Split into multiple `test()` blocks only for independent Phases with no data dependencies** — a single continuous user story (a flow such as create → use → complete, where later stages depend on artifacts of earlier stages) goes into a **single `test()`**, with Phases shown via `test.step()`. Splitting into multiple `test()` blocks and sharing state via `describe`/module-scope variables is Implicit Test Coupling and prohibited (see "Inter-Test Data Dependencies" in `prohibited-patterns.md`).
  - ⚠️ Do not shortcut to "Phase = `test()` block". Phase notation (headings in the procedure) and `test()` splitting are **separate things**. Even if the procedure says Phase 1/2/3, the implementation may be a single `test()` + `test.step()`.
- Assign one of `[Arrange]` / `[Act]` / `[Assert]` / `[Cleanup]` to each Phase
- `[Act]` and `[Assert]` may be combined into a single Phase (unified under the `[Act]` tag)
- Show verification points inline with `✅` marks + a summary at the end
- Record execution time after the first run (may be omitted if not yet run)
- Use the same tags in comments inside the test code (e.g., `// [Arrange] Prepare data`)

### JSDoc-Implementation Sync — Unconditional MUST

**When you change the implementation, you MUST update the JSDoc in sync within the same PR.** This covers everything, including step-notation changes caused by spec changes, refactoring, or Action name consolidation.

**WHY**: The JSDoc is the source of truth for the test procedure. Once they diverge, a "this might be stale" reading habit takes hold (broken windows), and the AI replicates the stale notation into the next test.

**Judgment**: Does this PR leave the JSDoc and implementation inconsistent? Existing divergence must also be synced in any PR that touches the implementation (no exceptions). Check points: step numbers, Action name notation, `✅` consistency, tag placement.

## Sharing and Reusing Test Data

Standards for scope design (where data is generated and who receives it). Orthogonal to and independent from uniqueness of generation (`uniqueId()`) (see "Generate Unique Test Data Names with uniqueId()" in `prohibited-patterns.md`).

- **Module-scope dynamic values + implicit sharing across multiple `test()` blocks is prohibited** (Implicit Test Coupling: no partial execution, no reuse, implicit coupling) — the canonical source for judgment criteria and harms is "Inter-Test Data Dependencies" in `prohibited-patterns.md`
- **Actions receive test data (resource names, random values, etc.) as arguments** — never reference module-scope variables directly (the cost of parameterizing is small; the cost of retrofitting for later reuse is large)
- Reused `[Arrange]` flows (resource creation, publishing, permission granting, etc.) are extracted into **Setup Actions + Fixtures**
- The canonical source for implementation patterns is **`e2e-test-create/test-data-management.md`** (recommendation quick-reference, beforeAll, Setup Action code, decision flow)

## Fixture

**Canonical source of the template = `e2e-bootstrap/fixture-template.md`** (the rules hold no code). Contract:

- Do not import directly from `@playwright/test` — **import `test` / `expect` via the Fixture**
- Define the StepCounter with **worker scope** (`{ scope: 'worker' }`) (one instance shared worker-wide, with automatic reset at describe boundaries)
- When adding a new Action → **registration in the Fixture is required** (inject `stepCounter` into the constructor) + update the Action catalog (next section)

## Action Catalog Conventions for fixture.ts

Maintain an **Action catalog** immediately before the `AppFixtures` type definition in fixture.ts.
Keep it in a state where a human can grasp "what Actions exist and what they can do" just by opening fixture.ts.

### Format

The canonical source for the format and code examples is `e2e-bootstrap/fixture-template.md` (Action catalog).

### Rules
- **Action name + class name**: start with `■ xxxAction (XxxAction)`
- **Method list**: one line per method as `- methodName(key params)  description`. List all public methods
- **Methods returning boolean/string**: annotate `→ type` (identifies verification methods)
- **Abbreviation**: if there are many methods, list the main ones and abbreviate with `...`
- **Caveats**: note UI constraints with `※` as needed
- When a new Action is implemented, promote it from TODO → catalog
- Add Actions planned for future implementation to TODO
