# Claude Code Setup Guide — the for-claude-code Operations Kit

A detailed guide to adopting `for-claude-code-en/` in your own project and continuously producing highly maintainable Playwright tests from test procedures and checklists. For the quick start, see [for-claude-code-en/README.md](../../for-claude-code-en/README.md).

---

## 1. Prerequisites

| Requirement | Details |
|------|------|
| Claude Code | Either the CLI or the IDE extension. Required, because the kit uses skills and the Stop hook |
| Node.js | A version Playwright supports (LTS recommended) |
| bash | The gate and the Stop hook are bash scripts (they run on macOS / Linux / WSL) |
| TypeScript | **5.x required.** The gate's fixed-wait check inside verify methods uses the TypeScript 5.x JS compiler API. The 7.x line does not expose the compiler API, so the check fails with an error instead of silently passing. The `"typescript": "^5.9.0"` semver range prevents `npm update` from promoting it to a new major |

## 2. Setup Steps (detailed)

### 2-1. Copy

Copy **exactly 3 things — `.claude/`, `scripts/`, and `CLAUDE.md`** — from under `for-claude-code-en/` to your project root. Why the root: the gate's meta-layer checks read `.claude/` relative to the cwd, and Claude Code automatically picks up `CLAUDE.md` and `.claude/` at the project root.

### 2-2. package.json

```json
{
  "scripts": {
    "gate": "bash scripts/gate.sh"
  },
  "devDependencies": {
    "@playwright/test": "^1.50.0",
    "dotenv": "^16.4.0",
    "typescript": "^5.9.0",
    "@types/node": "^22.0.0"
  }
}
```

Once that is in place, run `npm install`. If you run the gate before installing, the AST check (which resolves `typescript`) and the trailing `tsc` will falsely fail.

### 2-3. The project-specific information section of CLAUDE.md

Fill in the 4 items under "Project-Specific Information (please edit)": target product, UI library, authentication method, and HTML characteristics. These are the inputs to the judgments the skills make (Locator strategy, authentication flow implementation).

### 2-4. Freezing the baseline (done by a human)

**Prerequisite**: the gate assumes `src/` exists (its cwd guard fails immediately otherwise), so run it **after** generating the 4-layer skeleton (`src/` + tsconfig) with `/e2e-bootstrap`. Bringing the project to a state where the gate exits 0 is part of the bootstrap's Definition of Done.

After bootstrap, the first `npm run gate` guides you like this:

```
❌ Total always-loaded rules volume → initial setup: create .claude/rules-baseline with the
   current measured value and freeze it (run as a human: echo NNNNN > .claude/rules-baseline.
   AI agents must not create it — see the ★ comments in gate.sh)
```

Once a human creates the file as instructed, you are done. This baseline is a **ratchet** meaning "the total volume of always-loaded standards is capped at this value." From then on, any change that grows the rules is mechanically forced into a choice: delete an equivalent amount, or justify in the PR why raising the baseline is unavoidable.

**Why a human creates it**: freezing is the decision "this volume is the correct one," and the design deliberately leaves that decision — raises included — as a human's diff. An AI agent is trusted only up to "report the measured value and ask the human to configure it" (via the Stop hook, the gate keeps an unset baseline at ⚠️, so the agent is never given an incentive to escape by rewriting the setting itself).

### 2-5. How the Stop hook works

The Stop hook already registered in `.claude/settings.json` runs the gate automatically **at the end of the AI's turn**.

- On a violation it blocks the stop with exit 2 and feeds the error back to the AI for self-correction (the fix lands before a human ever receives the offending code)
- Turns with no changes under `src/`, `.claude/`, or `scripts/` (e.g. just answering a question) do not run the gate
- When dependencies are not installed (no `node_modules`), it skips, to avoid false failures
- Infinite loops are prevented by the `stop_hook_active` flag

### 2-6. Wiring it into CI (recommended)

The local Stop hook gives immediate feedback; CI is the backstop. Example (GitHub Actions):

```yaml
name: gate
on: [pull_request]
permissions:
  contents: read
jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npm ci
      - run: npm run gate
```

## 3. Operational Flow

### 3-1. Phase identification

Before starting work, identify the phase and read the corresponding skill (`CLAUDE.md` is the entry point):

| Phase | Trigger | Skill |
|---------|---------|-------|
| Environment setup | New setup / converting an existing project to the 4 layers | `/e2e-bootstrap` |
| Test creation | Adding tests / generating tests from procedures, checklists, or user stories | `/e2e-test-create` (+ `/e2e-locator`) |
| Review | PR checks / quality checks | `/e2e-review` (+ `/e2e-locator`) |

### 3-2. Input contract — hand over the "source document"

The input to test creation is the **source document** = a document describing the intent of the tests (test procedure / checklist / acceptance criteria / user story). Granularity may vary. The AI **normalizes** the source document into a JSDoc test procedure document before implementing, and consolidates every point where it intentionally deviated from the source into the procedure document's "Intentional differences from the original procedure" section. If the source document is ambiguous, the AI asks the human instead of filling the gaps by guesswork.

### 3-3. What the gate protects

| Area | Checks | What it protects |
|------|---------|---------|
| Prohibited code patterns | 1–13 | `text=` / XPath / layer boundary violations / `.catch` concealment / hardcoded values / `Date.now()` unique names, etc. |
| Reason-comment discipline | 14–18 | Undefined tags / reason comments for ordinals, `waitForTimeout`, and partial-match expect / configure inside a describe |
| AST detection | 19 | Fixed waits inside verify (`Promise<boolean>`) methods = a breeding ground for false positives where the verdict rides on wait time |
| Explaining the declaration source | 20 | Declaration-line comments on numeric constants in `constants.ts` stating "what time this is" |
| Meta layer (degradation of the standards themselves) | 21–23 | Rules total-volume ratchet / health of cross-skill references / 20KB cap on a single SKILL.md |

⚠️ Warnings (W1 / W4–W7) do not affect the exit code but do require visual inspection. The operational rule is: **if one falls on a line you touched, resolve it**.

## 4. Walkthrough — from a checklist to a finished test

### Input (source document): what the human prepares

A checklist like this can be handed over as-is:

```
[Product search smoke check]
- A general user can log in
- Searching for the keyword "notebook" displays a result list
- Opening the first result displays the product detail page
```

### Running it

```
/e2e-test-create Create a test from this checklist: (paste the above)
```

### What the AI does (the flow prescribed by the SOP)

1. **Decompose the source document into test units** and ask the human about anything unclear (target environment, test data assumptions, and so on)
2. **Normalize it into a JSDoc test procedure document** — adding Phase splits, numbered steps, verification points, and tags:

   ```typescript
   /**
    * TC-01: Product search smoke
    *
    * ■ [Arrange] Login
    *   1. Log in as a general user
    *
    * ■ [Act] Phase 1: Keyword search (✅ result list displayed)
    *   2. Search for the keyword "notebook"
    *   3. ✅ Verify the result list is displayed
    *
    * ■ [Act] Phase 2: Detail display (✅ product detail displayed)
    *   4. Open the first result
    *   5. ✅ Verify the product detail page is displayed
    *
    * ■ Verification points (expect)
    *   - Phase 1: result list displayed
    *   - Phase 2: product detail displayed
    *
    * ■ Intentional differences from the original procedure
    *   - None
    */
   ```

   Anything changed from the source document (stricter verification, merged steps, etc.) is recorded with its reason in the "Intentional differences from the original procedure" section. When the wording of the source document and the test implementation disagree, this is where you can tell an intentional difference from an implementation mistake
3. **Check the Action catalog and existing assets** and identify reusable Actions (`LoginAction`, etc.). Implement the missing Actions and Page Objects according to the responsibilities of the 4 layers
4. Verify with `npx playwright test` and record the execution time in the procedure document
5. **Confirm `npm run gate` exits 0** before opening the PR. The Stop hook runs the same gate at the end of the turn, so violating code is sent back before it reaches a human

### What the human looks at in review

`/e2e-review` walks its checklist in this order: mechanical gate → 4-layer responsibilities → JSDoc-implementation sync (including whether the differences section matches reality). Items the gate has already mechanized are off the visual-inspection list, so the human can concentrate on "does this test verify the intent of the source document?"

## 5. Customization Guidance

| Target | Guidance |
|------|------|
| The per-UI-library sub-files of `e2e-locator` (2 for Ant Design) | **Reference examples.** Once you have accumulated field knowledge for your own stack (MUI / Radix / in-house), add a sub-file in the same format and reference it from §9 |
| `auth0-flow.md` | An implementation example for external authentication (Auth0). For a different authentication method, rewrite it using this as a template |
| Extending `constants.ts` | Add only values used across multiple files (numeric constants require a declaration-line comment — the gate detects this) |
| Adding to rules | The baseline ratchet fires. The design makes you ask "if I add this, what do I delete?" (do not put code examples in rules — put them in skills; the gate detects this too) |
| Adding skills | Feel free to add new phase skills (just respect the 20KB cap on a single SKILL.md and the cross-skill reference rules) |

## 6. Keeping Up with Template Updates

This kit is designed so that **adopters never edit `gate.sh`** (the baseline lives in the external file `.claude/rules-baseline`, and project-specific information lives in the fill-in section of `CLAUDE.md`). To move up to a new version of the template, just re-copy `.claude/rules/`, `.claude/skills/`, and `scripts/`. However:

- `.claude/rules-baseline` is not overwritten (it is not part of the kit)
- If you have extended rules / skills yourself, review the diff before merging
- Run `npm run gate` after re-copying, and if the baseline is exceeded, review the diff (if the growth came from the template side, consider raising the baseline by that amount)
