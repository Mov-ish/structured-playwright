# Constants Management & Security Rules

## Required Imports (All Files)

Import `test`/`expect` via `fixtures/app.fixture`, not from `@playwright/test`. Import constants (TIMEOUTS / SELECTORS / URL_PATTERNS) from `../config/constants`. The canonical source for the constants format is `e2e-bootstrap` §4; for the Fixture format, `e2e-bootstrap/fixture-template.md`.

## Minimum Required Structure of Constants

**Canonical source of the template = `e2e-bootstrap` §4** (the complete form of TIMEOUTS / SELECTORS / URL_PATTERNS that must be included at environment setup + project-specific extension examples. A declaration-line comment is required for numeric constants — the gate detects this mechanically). The rules hold no code. `SELECTORS.MODAL` is the universe constant scoped to a single modal (no `.last()` — see "When to Use Which" below).

## What Goes Into constants.ts / What Does Not

| Include | Exclude |
|--------|---------|
| Selectors, URLs, and timeouts **shared across multiple files** | Locators **used only on a specific screen** |
| Static values only | Dynamic values (ones that vary by argument) → handle inside the Page Object |

Locators specific to one screen are correctly defined inside the Page Object's constructor.

### When to Use `SELECTORS.MODAL` vs. `activeDialog()`

`SELECTORS.MODAL` (`[role="dialog"]`) is used **exclusively for scoping to a single modal, without `.last()`**. To avoid duplicated content, the details of active-modal disambiguation (`activeDialog()`) and the hybrid prohibition are covered by their canonical source: **see "Active Modal Idiom — When to Use `activeDialog()` vs. `SELECTORS.MODAL`" in `prohibited-patterns.md`** (the usage table there is canonical. This section only explains the purpose of `SELECTORS.MODAL` = scope restriction, and does not cover active-modal disambiguation).

## When a New Constant Is Needed

1. Ask: "Will it be used in multiple files?"
2. Yes → add it to `constants.ts` and import it
3. No → define it inside the Page Object / Action
4. **Never hard-code** (timeout values, URL patterns, shared selectors)

## Security

- Credentials (email, password, tokens, API keys) are **retrieved from `.env`**
- Include `.env` in `.gitignore`
- Provide `.env.example` as a template
- Never include production credentials
- Hard-coding in code is strictly prohibited (always retrieve via `.env` + `EnvConfig.getTestEnvironment()`)
