# Locator Design Philosophy and Priority

## The Essence of Locators (return here when you encounter an unknown pattern)

**Premise: a Locator is not an ElementHandle** (a common misconception for those with Selenium / WebDriver experience).
A Locator only holds a CSS query (a function); it holds no element reference. At the moment of each action
(`.click()` / `.hover()` / `.fill()`, etc.), it **re-queries the DOM fresh every time**.
Therefore:
- `const x = page.locator(...); await x.hover(); await x.click()` → re-queried at each action
- Writing `page.locator(...).hover()` and `page.locator(...).click()` separately → same thing, re-queried every time
- The two forms above are **functionally equivalent**. The "stale element reference" problem that occurs in Selenium
  cannot occur in principle with Playwright Locators.
- Whether to store it in a variable is a judgment about **DRY / readability / preventing missed updates during maintenance**,
  not about avoiding "the risk of grabbing a different element after a DOM re-render."

The three principles below are the philosophy for designing Locators on top of this premise.

**1. A Locator is a Future value**
A Locator does not require the element to exist in the DOM right now. It is a "condition that will hold in the future," with lazy evaluation, auto-waiting, and auto-retry built in.
→ `waitFor()` (future-value evaluation) is often more appropriate than `isVisible()` (immediate evaluation).

**2. It should be operated in the semantic space**
Capture elements by meaning (role, name, label, text), not structure (nested divs). The meaning of a UI rarely changes, but its structure changes frequently.
→ CSS structural selectors and XPath are prohibited as a rule.

**3. Search within a Local Universe**
The whole page is too large as a search space. Scoping to a semantic unit — modal, row, card, etc. — improves uniqueness, resilience to DOM changes, and clarity of intent.
→ Prefer `modal.locator()` or `row.locator()` over unscoped `page.locator()`.

## The 4 Universal Principles — What Each Prevents

| Principle | What it prevents |
|------|---------|
| **Capture meaning (Semantic Priority)** | Locator collapse on UI changes. Meaning is the layer least likely to change |
| **Limit the universe (Local Universe)** | Mis-hits on identical text. The case where "Save" exists twice: in the background and in a modal |
| **Eliminate coincidence (Deterministic)** | Sudden breakage from ordinal selectors (`.first()`/`.last()`/`.nth()`) when the UI is reordered or elements are added |
| **Do not depend on structure (Anti-XPath)** | All Locators collapsing just because the UI library added one div |

## Priority Pyramid (always consider in this order)

```
  1. Semantic                      getByRole / getByLabel / text-is
  2. Local Universe                dialog / row / card / section
  3. Proximity (near)              :near(:text("..."))
  4. data attributes (UI library)  data-testid / data-icon etc.
  5. Last resort: structural       comment + TODO required
```

**The 3 text engines "look at" different places** (always keep this in mind when choosing):
- `:text-is("x")` — exact match. Evaluated against the element's **immediate** text nodes only (does not match labels wrapped in a span etc.)
- `:text("x")` — partial match. Considers the full subtree text, but only the **smallest** qualifying element matches
- `:has-text("x")` — partial match. Matches **every ancestor** containing the text (the only engine that pierces nesting)

Whether a visible label is an immediate text node is up to the UI library (span wrapping, automatic space insertion, etc.).
**The default for exact leaf matching is `getByRole` + `name` + `exact: true`** (the accessible name is computed from descendants, so it is immune to nesting). `text-is` is for elements that carry immediate text (span / td / li etc.).
Note that the default for `getByText` / `getByRole`'s `name` is a **partial match** — make exact matching explicit with `exact: true`.
Code examples and UI-library-specific pitfalls: `e2e-locator` §2 is the canonical source.

## Decision Flowchart

```
① Does the UI have a clear role / label / data-testid?
   └ Yes → semantic Locator / data-testid
   └ No →
        ② Is the UI text unique?
           └ Yes → text-is (exact match)
           └ No →
                ③ Are the text and the target element adjacent?
                   └ Yes → near()
                   └ No →
                        ④ Inside a modal?
                           └ Yes → role="dialog" + scope
                           └ No →
                                ⑤ An icon?
                                   └ Yes → svg[data-icon]
                                   └ No → structural + comment required
```

## Handling UIs with a Minimal Semantic Layer — a "Structural Necessity," Not an "Exception"

In UIs with a minimal semantic layer (no data-testid, missing aria-label, meaningless class names), the universal principles alone are insufficient.
The root cause is that **the structural layer fluctuates wildly**: the UI library generates masses of divs, nesting differs per screen, and the same text appears in multiple places.

| Specific rule | Why it is a necessity |
|-----------|-----------|
| `near()` as the main weapon | The element itself has no identifier. Nearby text is the only stable anchor |
| Confine modals with `role="dialog"` | Class names are meaningless. role is the only semantic anchor |
| `svg[data-icon]` as the icon anchor | No text, no aria-label. data-icon is the only stable thing |
| Rows as the Universe | Tables are one of the few semantic units in a semantically thin UI |

| Priority | Method | UIs with a minimal semantic layer |
|--------|------|--------|
| ❌ 1 | data-testid | Unavailable (does not exist) |
| ✅ 2 | Semantic | Conditional (only elements with a rich semantic layer) |
| ✅ 3 | `:has-text()` / `:text-is()` | Recommended |
| ✅ 4 | `:near()` | Recommended (best for semantically thin elements) |
| ✅ 5 | `svg[data-icon]` | Recommended (icons) |
| ✅ 6 | Attribute selectors (name, type) | Recommended |
| ✅ 7 | Narrowing by parent element | Recommended |
| ⚠️ 8 | Structural selectors | Last resort (comment + TODO required) |

**Checks when onboarding a project**:
1. Does `data-testid` exist? → if so, use it as the top priority
2. What is the state of `aria-label` / `label` coverage? → decide fallback strategies for the gaps
3. Which UI library is used? → identify the library's own stable attributes
4. How much duplication of identical UI text is there? → decide the Local Universe design policy

## Code of Conduct for AI Generation

1. **Do not casually propose ordinal selectors (`.first()` / `.last()` / `.nth()`)** — first try to solve with `:near()` / Local Universe / specific selectors. When an ordinal is needed, distinguish between "freezing a coincidence (a stopgap)" and "encoding a framework invariant," and attach a reason comment in either case (the former also requires a TODO)
2. **Never propose XPath** — the rejection of structure dependence is a principle at the level of philosophy
3. **Follow the priority pyramid step by step** — confirm that upper levels cannot solve it before moving down. Do not jump straight to structural selectors
4. **Attach a comment explaining the selection rationale to every Locator** — e.g., `// No role set and text is duplicated, so identified via near()`

## When You Encounter an Unknown Pattern

1. Try the decision flowchart
2. It does not apply → **return to the 4 principles**
3. Ask in order: "What is the meaning?" "What is the Universe?" "Is it unique?"
4. Still impossible → structure-dependent (comment + TODO required)
5. **Before inventing a new pattern yourself, ask the human for confirmation**
