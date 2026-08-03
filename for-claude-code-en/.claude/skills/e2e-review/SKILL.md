---
name: e2e-review
description: "For E2E code review. Use when reviewing PRs or checking quality. Includes MUST FIX/SHOULD FIX checklists, remedies by error message, how to detect the .catch concealment problem, and an FAQ. For details on prohibited patterns, see .claude/rules/prohibited-patterns.md."
---

# E2E Code Review Skill

> Prohibited patterns, 4-layer responsibilities, and Locator principles live in rules/ (always loaded).
> This Skill focuses on **review procedure and checklists**.

## §1. Review Procedure

1. **Run the §2.0 mechanical gate (`npm run gate`) and inspect its output** (before any read-only checks — mechanically eliminate detectable debris first)
2. Work through the §2 MUST FIX checklist from the top
3. Check §3 SHOULD FIX
4. **Have the author self-report the §8 self-interrogation** (debris grep cannot catch — unused additions, divergence from the PR description, newly added `@deprecated`)
5. If concrete Locator feedback is needed, refer to the `/e2e-locator` Skill
6. Every finding must pair a "reason" with a "correct implementation example"

> **Why run the commands first**: rules that are merely "read" slip through due to attention dilution (there have been cases where tsc errors, Locators written directly in Actions, and unused exports survived all the way to just before master, even after a full round of self-review). Anything grep / commands can catch should be caught by the machine, not by human eyes.

> **Fresh-scan principle on re-review**: in multi-round reviews, attention tends to narrow to "were the previous round's findings fixed", so anything missed in Round 1 stays undiscovered afterward. On re-review, do not consult the previous round's comments — **read the diff from the beginning**. New problems introduced in fix code also slip through as "the fix looks fine", so check the code surrounding the changes with fresh eyes as well.

---

## §2. MUST FIX (PR send-back criteria)

### §2.0 Mechanical gate (fail mechanically via commands — top priority)

> **Always run it and inspect the output.** Judge by command results, not by visually ticking checkboxes.
> In a workspace containing multiple projects, `cd` into the target project's directory before running.

```bash
npm run gate; echo "exit: $?"
```

The **canonical source of the detection logic is `scripts/gate.sh`** (CI runs the same checks on every PR).
Coverage: tsc type check / Locators written directly in the Action and Test layers / `.catch` concealment / `text=` / XPath /
`private readonly` / imports bypassing the Fixture / `new Action` inside Tests / `expect` in the Action layer /
hardcoded timeouts and URLs / `Date.now()` unique names / MODAL hybrid / undefined tags /
ordinal, waitForTimeout, and partial-match expect without reason comments / configure inside describe /
waitForTimeout inside verify (AST) / numeric constants without a declaration-source comment / meta layer (Rules total-size ratchet,
cross-Skill references, SKILL.md size) + ⚠️ warnings (visual follow-up for Page Object waitForTimeout, etc.).

If `npm run gate` is unavailable, run the following individually:

```bash
# 1. Type check — send back unless exit 0
#    (catches unused variables, unused imports, unused parameters, and type errors. tsconfig has noUnusedLocals/noUnusedParameters enabled)
npx tsc --noEmit; echo "exit: $?"

# 2. Detect Locators written directly in the Action layer (4-layer boundary violation) — every hit is a violation
#    Locators may exist only in the Page Object layer (rules/architecture.md layer structure: "Locators live here and only here").
#    Catch .locator( / .getBy*( regardless of receiver (restricting to this.page misses multi-line notation and other receivers).
grep -rnE "\.(locator|getBy[A-Za-z]+)\(" src/actions/

# 3. .catch concealment pattern (details in §4)
grep -rn "\.catch(() => false)\|\.catch(() => true)" src/
```

- [ ] `npm run gate` exits **0** (a single ❌ means send-back)
  - **New additions are obviously not allowed.** Existing hits (debt) are also treated as violations **without exception** — allowing "it's existing, so OK" leads AI to imitate existing code and reproduce the same violations (AI imitates precedent first). Even constant-based usage (`SELECTORS.MODAL` etc.) or semantic `getByRole(...)` is a violation the moment a Locator lives in an Action
  - **The grep must catch `.locator(` / `.getBy*(` regardless of receiver.** Restricting to `this.page.` misses (1) multi-line notation where `this.page` and `.locator` are on separate lines, and (2) other receivers such as `modal.locator(...)`, detecting only a fraction of real violations (= false reassurance worse than eyeballing). `.click()`/`.nth()` etc. on Locators received from a PO contain no `.locator(`/`.getBy(` and therefore don't false-positive
  - Bulk cleanup of existing debt is tracked separately. Until then, remaining hits are never judged "existing, so they may stay"
- [ ] Among ⚠️ warnings, flag as SHOULD FIX **any that fall on lines added or changed by this PR** (warnings on existing lines may be tracked separately)

> Unused **exports** (methods or PO classes called by no test) are not caught by tsc (`noUnusedLocals` only covers local variables/imports). These are self-reported by the author via §8 self-interrogation.

### Security
- [ ] No hardcoded credentials
- [ ] `.env` is included in `.gitignore`

### Constants management
- [ ] `TIMEOUTS`, `SELECTORS`, and `URL_PATTERNS` are imported from constants.ts
- [ ] No hardcoded timeout values, URL patterns, or shared selectors

### Locator
- [ ] No `text=` locators used
- [ ] The priority order is followed (see rules)
- [ ] Structure-dependent selectors are avoided
- [ ] data-testid is used on elements that have it
- [ ] `:near()` / `svg[data-icon]` is used for elements with a thin semantic layer

### 4-layer responsibilities
- [ ] Page Object: `readonly` (`private readonly` prohibited), no expect
- [ ] **No `waitForTimeout` inside Page Object / Action verify methods (boolean-returning state checks)** — consolidate waits in operation methods (void). A fixed wait inside verify gambles the correctness of the check on the wait time and breeds double waits (see `prohibited-patterns.md` "Fixed waits inside verify — consolidate waits in operation methods"). **The §2.0 gate already detects this mechanically via AST** — limit eyeballing to compensating for the known detection gaps (inference-dependent methods without return type annotations; waits inside indirectly called void helpers)
- [ ] Action: every step logged via `this.step()` (bare `console.log` prohibited), no expect, **no direct Locators (grep-detected in §2.0)**, LoginAction verifies login success
- [ ] Fixture: `stepCounter` is defined at worker scope (`scope: 'worker'`)
- [ ] Test: imports via Fixture, obtains Actions through Fixture arguments, no direct Locators
- [ ] New Action → registered in the Fixture, and promoted from TODO to the implemented section

### Error handling
- [ ] No `.catch(() => false)` pattern (see §4)

### Silent skipping of test conditions
- [ ] Does the test Fail when an operation it explicitly requires (specified via arguments/parameters) cannot be found (skipping and passing is a false positive)

### Structure of test data preparation (base-creation flow bloat / imitation propagation)
- [ ] **Is a base-creation flow (create resource → add data → publish → register users, etc.) inline-expanded and duplicated inside tests?** — consolidate it into a shared builder (Setup Action). Inline expansion propagates bloat to other tests through AI imitation
- [ ] **Is a continuous user story horizontally split into multiple `test()` blocks sharing state via `describe`/module-scope variables?** — Implicit Test Coupling (`prohibited-patterns.md` "Inter-Test Data Dependencies (Implicit Test Coupling)"). The fix is **"bundle vertically (turn Arrange into a builder) + keep a single `test()`"**, not test() splitting. This is what happens when "Phase = `test()` block" is short-circuited (Phase notation in the procedure document and test() splitting are different things → `architecture.md`)
- [ ] **Does builder extraction break readability (readability guard)?** — only `[Arrange]`/`[Cleanup]` may be extracted. Check: (a) `[Act]`/`[Assert]` remain inline so "what is being verified" is readable in the spec body (R1) / (b) arguments are options + intent-revealing names, not a row of booleans (R2) / (c) the builder name states the end state and the return value provides the generated names (R3) / (d) merely-similar twins are not unified into one branching builder (R4)

### Sync between the test procedure document (JSDoc) and the implementation
- [ ] Do the JSDoc (test procedure document) at the top of the `.spec.ts` file and the Arrange/Act/Assert steps in the implementation match?
  - Forgetting to update the JSDoc when the implementation changes is unconditionally NG (including step-notation changes caused by spec updates, refactoring, or Action-name consolidation)
  - Even if pre-existing divergence remains in an existing file's JSDoc, syncing is required once the PR touches that implementation
  - The norm is `architecture.md` "JSDoc-implementation sync — unconditional MUST"
  - **Check points**: (1) correspondence between step numbers and implementation lines (drift, gaps) (2) procedure-document notation after Action renames (3) consistency between changes in verification points and the `✅` markers (4) `[Arrange]`/`[Act]`/`[Assert]`/`[Cleanup]` tag positions match the implementation comments (5) presence and accuracy of the "Intentional differences from the original procedure" section — verifications absent from the original, or merged/omitted steps, must be recorded in that section rather than scattered as inline comments in the steps (section format in `e2e-test-create/jsdoc-template.md`)

---

## §3. SHOULD FIX

- [ ] Perform the A/B judgment for ordinals (`.first()` / `.last()` / `.nth()`)
  - No comment → already mechanically detected as ❌ by the §2.0 gate (should be zero by the time it reaches review). Eyeballing targets the **validity of the comment content**
  - Comment present, no TODO → **confirm both B-judgment conditions are met**: (1) verifiable as framework behavior (2) no alternative physically exists. If either fails, treat it as A and add a TODO
  - Comment present, TODO present → recorded as A (accidental pinning). Confirm the reason comment accurately describes reality
  - **When in doubt, choose A** (add a TODO)
- [ ] Does each `waitForTimeout` reason comment explain "which preceding operation is being waited on, and for what" — the **presence** of the comment is already gate-detected ❌ in §2.0. Eyeballing targets the **content** (a paraphrase of the constant name, e.g. `// wait for SPA rendering to complete`, is not acceptable)
- [ ] Was `:has-text()` → `:text-is()` (exact match) considered?
- [ ] Local Universe (parent-element scoping) is used
- [ ] AAA pattern, result verification, data cleanup
- [ ] Test names are specific
- [ ] The `.spec.ts` has a test-procedure header comment (Phases, step numbers, verification points)
- [ ] Each Phase carries `[Arrange]` / `[Act]` / `[Cleanup]` tags (separating data preparation from the test body)
- [ ] Public methods that use `this.step()` call `this.beginAction()` (step numbering)
- [ ] End-to-end `test()` blocks (create → operate → verify in one) are limited to those whose **subject is the behavior under that condition itself** — if the subject is something else and resource creation is a mere prerequisite, move the creation into a Setup Action and narrow the test (`e2e-test-create/test-data-management.md`)
- [ ] No stale placeholders such as "not yet measured" / "update after verifying on a real run" remain in JSDoc metadata like execution time (once the test passes, replace them with measured values or a confirmed note)
- [ ] Method descriptions in the fixture catalog match the implementation (tracking Action renames and argument changes)
- [ ] No TODOs remain that could be resolved by verifying on a real run ("TODOs whose solution is known" are handled within the same PR)

---

## §4. Detecting and fixing `.catch(() => false)`

**Detection**:
```bash
grep -rn ".catch(() => false)" src/
grep -rn ".catch(() => true)" src/
```
5 or more hits → strongly suspect AI copy-paste.

**Fix**:
```typescript
// ❌
const isVisible = await element.isVisible({ timeout: 5000 }).catch(() => false);

// ✅
try {
  await expect(element).toBeVisible({ timeout: TIMEOUTS.CHECK });
  await element.click();
} catch {
  // Optional element, skip
}
```

---

## §5. Remedies by error message

### `Target page, context or browser has been closed`
**Cause**: URL transition not awaited (frequent during external auth transitions)
```typescript
await this.page.waitForURL(URL_PATTERNS.AUTH_LOGIN, { timeout: TIMEOUTS.DEFAULT });
await this.page.waitForTimeout(TIMEOUTS.AUTH_STABILIZATION);
```

### `Timeout exceeded`
**Cause**: insufficient SPA rendering wait / modal animation / wrong selector
```typescript
await page.waitForLoadState('networkidle');
await page.waitForTimeout(TIMEOUTS.SPA_RENDERING);
```

### `Element is not visible / outside of the viewport`
```typescript
await page.waitForTimeout(TIMEOUTS.MODAL_ANIMATION);
await button.scrollIntoViewIfNeeded();
await button.click({ force: true });
```

### `strict mode violation`
**Cause**: multiple matches from `:has-text()` partial matching
```typescript
page.locator('span:text-is("Login")')                    // exact match
page.locator('[role="dialog"] span:has-text("Login")')    // scoped down
```

---

## §6. FAQ

**Q: Can waitFor() be used in the Action layer?**
Yes. waitFor() is a wait operation, not an assertion. Only expect() is prohibited.

**Q: What is semantic-layer thickness?**
The richness of an element's semantic information. Thick (has data-testid, labeled form fields, text buttons) → semantic Locators work. Thin (unlabeled checkboxes, icon-only buttons) → `:near()`/data attributes. Assess the semantic-layer thickness of the entire UI when onboarding a project.

**Q: Is waitForTimeout allowed?**
Yes. It is necessary for SPAs, external auth, and modals. Conditions: a TIMEOUTS constant + a reason comment.

**Q: Is `.first()` always bad?**
Avoid it as much as possible. When used: scope by a parent element + reason comment + TODO.

**Q: What if existing code violates the rules?**
Don't copy it; implement with the correct pattern. Fix the existing code too if feasible.

---

## §7. Test result reporting protocol (validating Pass claims)

Before reporting a test result as "Pass", always confirm that the test runner **terminated normally**. Even if `✓` marks appear in mid-run logs, the result is **inconclusive** unless the runner exited normally.

### Three things to confirm

1. **Process exit code**: check with `npx playwright test ...; echo $?`. Anything other than `0` (e.g. `1`, `144`) means failure or abnormal termination
2. **Final summary line**: the `N passed (Mm)` summary appears at the end of stdout
3. **report.json integrity**: `test-results/report.json` exists, `stats.unexpected === 0`, and the JSON is complete

```bash
# ✅ Example of confirming normal termination
npx playwright test ... 2>&1 | tail -3
# →  1 passed (1.9m)        ← the summary is present

cat test-results/report.json | jq '.stats'
# → { "expected": N, "unexpected": 0, ... }
```

### Cases prone to false positives (misreporting as Pass)

| Situation | What happens | Correct report |
|------|------------|----------|
| Browser crash (exit code 144 etc.) | `✓` printed partway through, but no summary | "Result inconclusive, rerun required" |
| `report.json` is incomplete / truncated JSON | Write interrupted by forced process termination | "Result inconclusive" |
| Interrupted by Ctrl+C etc. | Looks like it ran most of the way through | "Interrupted, result unknown" |
| Killed by timeout | Individual tests show ✓ but the whole run failed | Judge by the summary line |

**Rule**: if any of the above is suspected, do not report "Pass" — **propose a rerun**. Telling the user "all tests passed" is allowed only when all three confirmations are in place.

**Re-measure numbers on re-review**: in a re-review after fix commits, never declare numeric claims (sizes, counts, etc.) "consistent" by reusing the previous measurements — **always re-measure** (the fix commit itself changes the numbers).

---

## §8. self-interrogation (pre-PR self-report — debris grep cannot catch)

The §2.0 commands mechanically eliminate syntactic/boundary debris. But **"additions that nothing calls", "divergence between the PR description and the diff", and "unneeded compatibility code" cannot be caught by grep**. Have the author (including AI) **explicitly self-report** the following before creating the PR. Don't settle for "none" — enumerate the items and attach a reason to each.

### Q1. Enumerate every unused addition and state the "reason to keep" for each

List everything **added** by this PR, among the following, that is **called by no test**. For each, decide whether it is "planned for a future test (name which test)" or "should be deleted now".

- Added public methods (Action / Page Object)
- Added Page Object classes/files
- Added env keys / constants entries
- Added function arguments/options

> If keeping something "because it might be used later", write **which test will use it and when**. Anything you cannot write down is dead code — delete it.

```bash
# Helper: example of checking whether an added export name is referenced elsewhere in src/
#   If it's 0 hits excluding the definition line, suspect it's unused
grep -rn "SomeMethodName\|SomePageClass" src/   # ← count hits excluding the defining file
```

### Q2. Cross-check the PR description against `git diff --name-only` and call out discrepancies

```bash
git diff --name-only main...HEAD
```

- Do the changes the PR description mentions ("added XX", etc.) **actually exist in the diff**?
- Are there changes in the diff that the description does not explain?
- **Are nonexistent tests or features being claimed?**

### Q3. Confirm no `@deprecated` was newly added by this PR

```bash
git diff main...HEAD | grep -n "@deprecated"
```

- `@deprecated` is a compatibility marker for things that "cannot be removed because existing consumers exist".
- **If code newly added by this PR carries `@deprecated`, that is a contradiction** (new = there are no existing consumers to stay compatible with) → the code was unnecessary from the start, so delete it.
- `@deprecated` on existing code (added in earlier PRs) is exempt.
