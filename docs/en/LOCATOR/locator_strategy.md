# Locator Strategy
### — Locator Design Philosophy / Universal Rules / Product-Specific Rules —

This document holds **the complete system of Locator strategy** for Playwright E2E testing.
It is organized from three perspectives:

1. **Concept (design philosophy)**
2. **Universal (universal rules)**
3. **Product-Specific (product-specific rules)**

---

# Part 1: Concept (Design Philosophy)

## 0. The Role of Concept

The Playwright API defines what you can do with a Locator. It does not define which Locator to write — the same element can be reached many ways. That choice sits outside the API, and it is what **Concept (the canon set out in this document)** governs.

That is because the Locator affects everything:

- Test stability
- Code maintainability
- The quality of automatic (AI) generation
- The team's comprehension burden
- Resilience to UI change

It is the "core structure" whose influence reaches all of them.

Concept unifies **not "how to write" but "why to write it that way,"** prescribing from outside the 4-layer architecture which layers may write Locators.

---

## 1. What a Locator Is (a Conceptual Definition)

If you see a Locator as mere "element retrieval," you miss both the depth of the design philosophy and the real strength of Playwright.

At the Concept level, the definition is this:

```
Locator =
   "a probe carrying a set of conditions"
 × "explores within a Local Universe"
 × "evaluated as a future value"
```

### 1.1 A Locator Is a "Future Value"

A Locator does not require the element to exist in the DOM right now.

- Lazy evaluation
- Auto-wait
- Auto-retry

With these built in, a Locator is "a conditional expression satisfied in the future" — and that is the fundamental reason it stands up to dynamic UI.

### 1.2 A Locator Should Be Operated in "Semantic Space"

The semantic Locators Playwright recommends explore elements by **meaning (semantics)**, not by structure.

- `role` is the element's role in the UI
- `name` is its visible label
- `label` is the meaning of an input field
- `text` is information a human understands

Grasping the UI through meaning rather than through structure (nested divs) is what leads to stable, readable tests.

### 1.3 A Locator Has a "Universe"

The whole page is too large a place to search.

Playwright's philosophy is close to a single instruction: **explore within a Local Universe.**

Examples of a Local Universe:

- A modal
- A row
- A card
- A section
- A tab panel

Limiting the search scope:

- Improves uniqueness
- Makes the Locator resilient to DOM change
- Makes the test's intent clear
- Improves execution speed as well

This is one of the most important concepts in Locator design.

---

## 2. The Purpose of Concept: Unifying the Philosophy

Concept defines not "implementation techniques" but **the philosophy, priorities, and prohibitions of Locator design**.

As a result:

- The Page Object layer (Layer 1) stops second-guessing itself
- Actions (Layer 2) and Tests (Layer 3) stop writing Locators
- AI (Codex / Claude) stops generating incorrect Locators
- Locator quality becomes uniform across the team

Concept serves as the "constitution" of Locators.

---

## 3. Universal Principles of Locators

The universal rules compress into four principles:

### 3.1 Capture Meaning (Semantic Priority)

The top of the priority order is:

```
role / label / name / text-is
```

Why:

- The meaning of a UI rarely changes
- The intent of the test code stays readable
- It pairs well with AI auto-generation

### 3.2 Limit the Universe (Local Universe)

Example:

```ts
const modal = page.locator('[role="dialog"]');
modal.getByRole('button', { name: 'Save', exact: true });
```

By searching only within a range bounded by a unit of meaning:

- Uniqueness improves dramatically
- The Locator withstands DOM changes
- The purpose becomes clear

### 3.3 Eliminate Coincidence (Deterministic Behavior)

The typical offense: `.first()` abuse.

```ts
page.locator('button').first().click();
```

`.first()` does nothing but freeze the accidental order of the UI. **A test should fix intent in place — not fix an accident in place.**

### 3.4 Do Not Depend on Structure (Anti-XPath / Anti-Structural)

- CSS-only selectors
- XPath
- Structural traversal like `div > div > span`

All of these are far too fragile against DOM change.

Concept **rejects structural dependency itself, as a matter of philosophy**.

---

## 4. Why Product-Specific Rules Are Integrated into Concept

A UI with a minimal semantic layer has these structural characteristics:

- The semantic layer is thin
- The structural layer shifts easily
- The same text appears in many places on one screen
- For icons, `data-icon` is the only anchor
- Modals cannot be identified by class

Because of these, applying the universal principles as-is does not yield enough stability.

Concept therefore treats the product-specific rules not as **"exceptions" but as "structural necessities."**

### 4.1 The Philosophical Position of near()

near() is ordinarily an auxiliary tool, but in a UI that lacks semantic information it functions as a **substitute for meaning**.

Concept prescribes:

```
In a UI lacking semantic information, treat proximity relationships as meaning.
```

### 4.2 The Philosophical Position of role="dialog"

In a product where modals and background UI readily coexist, the only semantic anchor is the role attribute.

```
The modal's Universe is defined with role="dialog" as its base point.
```

### 4.3 The Philosophical Position of svg[data-icon]

Because the UI library assigns icons a stable `data-icon`, an icon carries a **stable anchor equivalent to meaning** — internal specification though it is.

```
For identifying icons, data-icon is the essential anchor.
```

### 4.4 Why the Row Is Adopted as a Universe

The table is one of the few "units of meaning" in a UI with a minimal semantic layer.

```
Rows are adopted as Universes — the UI's units of meaning.
```

---

## 5. The Locator Priority System (Locator Priority Pyramid)

Concept systematizes Locator selection as a **5-level priority pyramid**.

```
       ┌──────────────────────────────┐
       │   1. Semantic-Based               │
       │   role / label / name / text-is   │
       ├──────────────────────────────┤
       │   2. Local Universe               │
       │   dialog / row / card / section   │
       ├──────────────────────────────┤
       │   3. Meaning Complement via near()│
       ├──────────────────────────────┤
       │   4. data-icon (UI Structure)     │
       ├──────────────────────────────┤
       │   5. Last Resort: Structure       │
       │      (Comment Required)           │
       └──────────────────────────────┘
```

This is the official rule set that integrates **universal principles with product-specific circumstances**, and both AI and humans follow it without exception.

### 5.1 Level 1: Semantic-Based (Semantic First)

Examples:

```ts
page.getByRole('button', { name: 'Save' });
page.getByLabel('Email address');
```

Why:

- The meaning of a UI is the thing least likely to change
- The intent is clear to a human reader
- AI can grasp the purpose correctly

### 5.2 Level 2: Local Universe (Confine by Unit of Meaning)

Example:

```ts
const modal = page.locator('[role="dialog"]');
modal.getByRole('button', { name: 'Save', exact: true });
```

Benefits:

- Uniqueness improves dramatically
- Prevents mixing with the background
- Withstands DOM changes

### 5.3 Level 3: near() (Compensating for Missing Semantic Information)

Example:

```ts
page.locator('input[type="checkbox"]:near(:text("I agree to the Terms of Service"))');
```

In a UI with a minimal semantic layer, near() becomes the **third correct answer**.

### 5.4 Level 4: data-icon (Leveraging the UI Library's Internals)

Example:

```ts
row.locator('button:has(svg[data-icon="edit"])');
```

In a UI with a minimal semantic layer, icons carry weak semantic information, so `data-icon` behaves as a **de facto semantic anchor**.

### 5.5 Level 5: Structure (the Last Resort)

Example:

```ts
page.locator('div > div:nth-child(2) > button');
```

Conditions for use:

- All four upper levels are impossible
- A comment is mandatory
- It is used temporarily, on the premise of later replacement

---

## 6. The Locator Philosophy AI Agents Must Follow (for Codex / ChatGPT / Claude)

Concept is also a **rule set that governs the quality of AI output**.

The philosophy an AI must honor:

### 6.1 Do Not Suggest `.first()`

`.first()` merely freezes the "accidental order" of the UI in place, and obstructs the essence of testing: reproducing intent.

→ Whenever you are tempted to reach for `.first()`, suspect a **lack of uniqueness** instead.

### 6.2 Never Suggest XPath

Why:

- Structure-dependent and fragile
- Contrary to Playwright's philosophy
- The worst possible match for a DOM with a minimal semantic layer
- Easy for AI to generate incorrectly

→ At the Concept level, "rejection of structural dependency" is non-negotiable.

### 6.3 Follow the Locator Priority Pyramid

When an AI generates a Locator, it checks, in order:

1. **Semantic-based**
2. **Local Universe**
3. **near()**
4. **data-icon**
5. **Structure-dependent (last resort)**

working down the list as it generates.

### 6.4 Attach a "Reason" to Every Locator

Good AI output always states its reasons.

Example:

> "This UI has no role and its text is duplicated, so I used the row as the Universe and the data-icon inside it as the anchor."

An AI that can articulate its reasons is highly reproducible — and does not mis-hit.

---

## 7. Connection to the 4-Layer Architecture (Where Concept Sits)

Concept is not one of the four layers. It is the **canon that prescribes, from outside the layers, how Locators are written**.

```
     Concept (the canon in this document)
     Locator philosophy, priorities, prohibitions
              │ prescribes
              ▼
┌─────────────────────────────────────────────────┐
│  Layer 3: Tests          writes no Locators     │
│  Layer 2: Actions        writes no Locators     │
│  Layer 1: Page Objects   implements Locators    │
├─────────────────────────────────────────────────┤
│  Layer 4: Config/Env     holds shared selectors │
│                          (read by Page Objects) │
└─────────────────────────────────────────────────┘
              │ uses
              ▼
     Playwright API (the technical foundation)
```

Layer 4 is not a rung in the same execution stack as the three above it; it is the **store of values every layer reads**. What concerns Locators is the shared selectors — `SELECTORS.MODAL` and the like — which Page Objects read from here so that the same selector does not scatter across files.

The purpose of a test is **not to operate the UI but to express intent**. Locators are confined to Page Objects (Layer 1) and excluded from Actions (Layer 2) and Tests (Layer 3).

---

## 8. The "Philosophy → Implementation" Conversion Model

Concept is not code itself; it is a **thinking model that guides implementation**.

### 8.1 The Requirement: "Press the Save Button"

Following the Concept:

1. Meaning → role + name (exact match)
2. Universe → dialog
3. Uniqueness → OK
4. Proximity complement → not needed

→ Implementation:

```ts
modal.getByRole('button', { name: 'Save', exact: true });
```

### 8.2 "I Want to Check a Checkbox"

1. Meaning → none
2. Universe → none
3. Proximity → yes
4. Icon → no

→ Implementation:

```ts
page.locator('input[type="checkbox"]:near(:text("Privacy Policy"))');
```

### 8.3 "I Want to Press the Edit Icon"

1. Meaning → none
2. Universe → row
3. near → not needed
4. Icon → yes

→ Implementation:

```ts
row.locator('button:has(svg[data-icon="edit"])');
```

---

## 9. Concept Summary (the Highest-Level Principles)

The philosophy of Concept condenses into these four points:

```
1. Capture meaning above all else
2. Decompose the UI into small universes (Universe)
3. Select elements by intent, not by coincidence
4. Eliminate structural dependency and design Locators that withstand churn
```

These are the **completed form of the Locator design philosophy**, and the quality foundation of the entire 4-layer architecture.

---

# Part 2: Universal (Universal Rules)

## 0. Purpose of This Part

Whether E2E testing with Playwright succeeds or fails depends on the quality of Locator design. The Locator is the core element that determines the whole suite's maintainability, execution stability, and compatibility with AI auto-generation.

This part systematizes universal Locator design principles that "work for any product."

---

## 1. The Fundamental Understanding of a Locator: a Conditional Expression over Future UI

Playwright's Locator is not mere "element retrieval" — it behaves as "a set of conditions that will hold against UI that appears in the future."

### 1.1 Lazy Evaluation

A Locator does not search the DOM when it is created; it searches when an operation runs, and waits until its conditions are satisfied.

### 1.2 Auto-Wait

During operations such as clicks and input, it automatically waits for the element to become visible, enabled, and stable.

### 1.3 Auto-Retry

Even when the UI is unstable, Playwright retries the search internally, which is what keeps E2E tests from breaking.

---

## 2. Locator Design Philosophy: Capture "Meaning," Not Structure

HTML structure changes; the meaning of the UI (role, name, label, text) rarely does.

Playwright's recommended strategy is to design Locators around meaning rather than by traversing the DOM.

---

## 3. The Principle of Uniqueness

The quality of a Locator is decided by whether it is unique. Ambiguous Locators are the most exposed to UI changes and the leading cause of E2E collapse.

### 3.1 Typical Examples Where Uniqueness Breaks (NG)

```
input[type="checkbox"]
button
div.card
```

These carry "no meaning": they match multiple elements easily and are weak against structural changes in the DOM.

### 3.2 Examples with Uniqueness Secured (OK)

```
getByRole('button', { name: 'Save', exact: true })
input[name="email"]
span:text-is("My Page")
```

Anchor on the UI's "meaning" and the Locator becomes remarkably hard to break.

---

## 4. Text Matching: Using text-is and has-text Correctly

Text matching is one of the Playwright Locator's most powerful features — and, misused, it becomes the most fragile landmine of all.

### 4.1 Exact Match — Reach for It First

```ts
page.getByRole('button', { name: 'Save', exact: true })  // the default for exact leaf matching
page.locator('span:text-is("My Page")')                  // text-is is fine for elements with immediate text
```

- The intent is unmistakable
- Mis-hits are extremely rare
- It captures "meaning" most faithfully

The basic policy: **make exact matching the default.** Note that Playwright's own default is a partial match (for both `getByText` and `getByRole`'s `name`), so you must consciously opt in with `exact: true`.
Also, `:text-is` evaluates only the element's **immediate** text nodes (see 4.3). In UI libraries that wrap labels in a span, `button:text-is(...)` silently returns 0 matches — so **the default for exact leaf matching is role + name + exact**.

### 4.2 has-text (Partial Match) — Dangerous When Misused

```
button:has-text("Save")
```

Every one of the following UI elements could match:

- "Save now"
- "Save draft"
- "Saved"

Partial matching amplifies ambiguity, so the decision to use it must be made carefully.

That said, partial matching also has a legitimate day job: **bracketing**. When `tr:has-text("...")` turns a row into a Local Universe, an exact match against the row's entire text is impossible in principle, so partial matching is the right tool. Distinguish **leaf targeting** (dangerous — be careful) from **bracketing** (its true home).

### 4.3 When the Label and the DOM Text Diverge — UI Library Interference

The 3 text engines "look at" different places:

| Engine | Match | Evaluated against |
|---|---|---|
| `:text-is("x")` | Exact | The element's **immediate** text nodes only |
| `:text("x")` | Partial | Full subtree text; only the **smallest** element matches |
| `:has-text("x")` | Partial | Full subtree text; **every ancestor** matches (the only engine that pierces nesting) |

`getByText(..., { exact: true })` is exact too, but it is evaluated against the **full subtree text** — unlike `:text-is`, which sees immediate text only. Do not treat the two as equivalent just because both are called "exact".

There is no guarantee that the visible label is written into the DOM in that exact shape — because UI libraries interfere.

**Interference 1: labels wrapped in a span (Ant Design Button etc.)**

```html
<button><span>Save</span></button>
```

```ts
page.locator('button:text-is("Save")')   // ❌ the button has no immediate text node
page.locator('button:text("Save")')      // ❌ the "smallest element" is the span, so the button loses
page.locator('button:has-text("Save")')  // ✅ the only engine that pierces nesting
page.getByRole('button', { name: 'Save', exact: true })  // ✅ the accessible name is computed from descendants (recommended)
```

**Interference 2: automatic space insertion into two-CJK-character labels (antd autoInsertSpace)**

When a label is exactly two CJK ideographs (「検索」「保存」「削除」「編集」…), the DOM text becomes 「検 索」. text-is, has-text, and role + name + exact all fall silent; only a regular expression survives:

```ts
page.getByRole('button', { name: /^検\s*索$/ })  // ✅ works with or without the space
```

Do not drop the `^` `$`. A regular expression passed to role's `name` is evaluated as a **partial** match, so `/検\s*索/` also hits 「再検索」. An escape hatch that is itself a partial match defeats the "exact by default" policy.

The insertion is not unconditional, though — it happens only when the label is the single child, there is no icon, and `type` is neither `text` nor `link`. Icon buttons never get the space.

Playwright's whitespace normalization only collapses runs of whitespace into one — it never removes the space. The root fix lives on the app side: turn autoInsertSpace off (a request to the dev team — the same place root-fix TODOs belong). The syntax is `<ConfigProvider button={{ autoInsertSpace: false }}>` on antd 5.17+, and `<ConfigProvider autoInsertSpaceInButton={false}>` on 4.x / before 5.17.

---

## 5. Parent-Container Anchoring (the Local Universe Concept)

A Locator becomes stable when it is used inside a "Local Universe."

Example: search only within a modal.

```ts
const modal = page.locator('[role="dialog"]');
modal.getByRole('button', { name: 'Save', exact: true }).click();
```

### 5.1 Why the Local Universe Matters

- Searching the entire DOM multiplies the match candidates
- The Locator becomes resilient to UI churn
- Performance improves
- The test's intent becomes clearer

### 5.2 Representative Local Universes

- Modals
- Cards
- Table rows
- Tab panels
- Settings sections

Carving the UI into "universes" raises uniqueness and stability at the same time.

---

## 6. `.first()` Is a Last Resort

`.first()` looks convenient, but it is a dangerous tool that seriously undermines the stability of an E2E suite.

### 6.1 Why `.first()` Is Dangerous

**(1) It creates order dependency.**
Many things can change the order: UI changes, A/B tests, sorting. An order-dependent Locator is a fragile Locator.

**(2) It obscures intent.**
```
page.locator('button').first().click();
```
"Why the first button?" "What was intended here?" — both questions vanish from the test.

**(3) It freezes coincidence in place.**
An E2E test exists to reproduce intent. `.first()` blurs that intent.

### 6.2 Situations Where `.first()` Is Acceptable (Very Limited)

- The UI's specification offers no unique attribute
- The design guarantees the order is fixed
- "The first element" exists as a concept in the specification (e.g., the newest item is always on top)

Even then, **always write the following**:

```ts
// TODO: Replace when unique identifier is introduced
await page.locator('...').first().click();
```

---

## 7. Handle Dynamic Values in the PageObject Layer

Embedding dynamic data (user names, course names) directly into Locators turns the selector definitions into a "graveyard of variables" and makes them unmaintainable.

### 7.1 Bad Example (NG)

```ts
export const SELECTORS = {
  USER_ROW: (name) => `tr:has-text("${name}")`,
};
```

- The selectors become dynamic
- They mix with the other, static selectors and cause confusion
- The test's intent becomes unreadable

### 7.2 Good Example (OK)

```ts
// constants.ts contains only static selectors
export const SELECTORS = {
  USER_ROW: 'tr',
};

// PageObject side complements dynamic values
async clickUser(name: string) {
  await this.page.locator(`tr:has-text("${name}")`).click();
}
```

With the responsibilities separated:

- The "semantic space" of the selectors stays organized
- The PageObject manages "operations, conditions, and dynamic values"
- The blast radius of any change is clear

---

## 8. The Philosophy of Preferring Semantic Locators (getByRole and Friends)

Use the following whenever possible:

```
getByRole()
getByLabel()
getByPlaceholder()
getByText()
```

### 8.1 The Benefits of Semantic Locators

- Being meaning-based, they survive minor UI changes
- The test code reads well
- They align with accessibility design
- AI understands the intent correctly and generates them readily from natural language

### 8.2 That Said, "Unprepared HTML" Can Rule Them Out

For example: no role is set, or the label is wired up incorrectly.

Even then, **it is enough to understand why they cannot be used**. Semantic Locators always keep their place at the top of the priority order.

### 8.3 Why getByRole Is the Strongest

**(1) It expresses the UI's semantic structure directly.**
```ts
page.getByRole('button', { name: 'Save' });
```

This expresses **"the UI's role plus the label the user actually sees"** in a single call — something CSS and XPath struggle to say at all.

**(2) It is extremely resilient to DOM change.**
The structure may shift, but a button is still a button, and its name rarely changes.

**(3) It aligns with accessibility design.**
The better the UI, the more appropriate its roles — which makes semantic Locators the most stable choice in the long run.

**(4) It is easy for AI to understand.**
Told in natural language to "press the save button," an AI tends to choose getByRole; the fit with code generation is excellent.

---

## 9. Keep the Locator's Level of Abstraction Appropriate

### 9.1 When the Abstraction Is Too Low
```
div > div > span > button
```
→ Too structure-dependent.

### 9.2 When the Abstraction Is Too High
```
button
```
→ Matches too much; uniqueness is gone.

### 9.3 The Right Level of Abstraction
```
getByRole('button', { name: 'Save', exact: true })
```

The right abstraction means: can you identify the element sufficiently, without losing the meaning?

---

## 10. A Deeper Look at Why XPath Is Not Recommended

XPath is used constantly in UI testing, yet it points in exactly the opposite direction from Playwright's philosophy.

### 10.1 Why XPath Is Fragile

**(1) It depends completely on DOM structure.**
```xpath
//div[2]/div[1]/span
```
It collapses the moment the UI library adds a single div.

**(2) Its intent is hard to read.**
Neither humans nor AI can easily tell what the Locator intends.

**(3) It forfeits Playwright's internal optimizations.**
Waiting, retrying, semantic matching — the strengths of the Locator API go unused.

**(4) It is where AI makes the most mistakes.**
ChatGPT and Claude struggle to generate stable XPath, and unmaintainable code gets mass-produced.

### 10.2 Exceptional Use of XPath

For legacy HTML, or special cases where no selector can be obtained by any other means, XPath may serve as a temporary remedy.

In this project, however, given its:

- Poor readability
- Heavy structural dependency
- Poor maintainability

it is **prohibited in principle**.

---

## 11. Separation of Responsibilities in Locator Design

This connects directly to the 4-layer architecture:

- **Layer 1 (Page Objects)**: where Locators are concretely implemented
- **Layer 2 (Actions) / Layer 3 (Tests)**: the layers that must never touch Locators directly
- **Layer 4 (Config/Env)**: the canonical home of shared selectors (`SELECTORS.MODAL` etc.), read by Page Objects
- **Playwright API**: the technical substance (outside the layers)
- **Concept (the canon in this document)**: the Locator philosophy and its prohibitions, prescribed from outside the layers

An E2E developer understands the "philosophy" of this document and practices it in the Page Object layer.

---

## 12. Success Patterns (Best Practice)

### 12.1 Exact Semantic Match + scope (the Strongest Combination)

```ts
modal.getByRole('button', { name: 'Save', exact: true });
```

- The text pins down the meaning
- The modal, as a Local Universe, bounds the range
→ One of the hardest patterns to break.

### 12.2 Confine to role="dialog" (Modals)

```ts
page.locator('[role="dialog"]').locator('input[name="email"]');
```

Highly effective in UI where the same field may also exist in the background.

### 12.3 Prefer Semantic Locators

```ts
page.getByRole('button', { name: 'Delete' });
```

By using the semantic structure directly, most DOM structural changes are simply absorbed.

### 12.4 Consolidate Dynamic-Value Logic in the POM

```ts
async clickUser(name: string) {
  await this.page.getByRole('row', { name }).click();
}
```

Separating Locator definitions (static) from the application of dynamic values (the POM) keeps both the test code's intent and the selectors' meaning easy to preserve.

---

## 13. Failure Patterns (Anti-Patterns)

The following bring a high probability of test collapse:

- CSS-only selectors
- `.first()` abuse
- Careless use of has-text
- Not using a parent container (scope)
- Dependency on XPath
- Mixing dynamic values into constants.ts

---

## 14. Locator Checklist (Universal Edition)

Check the following at implementation time and at review time:

- ☑ Is uniqueness secured?
- ☑ Could this be expressed with an exact semantic match (role + name + exact / text-is)?
- ☑ Has a parent container (Local Universe) been set?
- ☑ Are semantic Locators given priority?
- ☑ Was a real effort made to avoid `.first()`?
- ☑ Are dynamic values placed in the PageObject layer?
- ☑ Is XPath absent?
- ☑ Is the abstraction level appropriate — neither too low nor too high?

---

## 15. Universal Summary

The universal principles of the Playwright Locator condense into four pillars:

```text
1. Capture meaning (role + name + exact / text-is)
2. Limit the universe (scope / Local Universe)
3. Eliminate coincidence (secure uniqueness)
4. Do not depend on structure (anti-XPath)
```

Follow these, and you can build "long-lived E2E tests" that stay standing even as the UI changes.

---

# Part 3: Product-Specific (Product-Specific Rules)

## 0. Purpose of This Part

This part systematizes a **Locator design strategy dedicated to products whose UI has a minimal semantic layer**.

The universal rules work for any product — but because of structural problems in the HTML and UI, **there are many situations where the universal rules alone cannot stabilize a Locator.**

This part thoroughly lays out the background that makes product-specific rules necessary: **the constraints the UI carries.**

---

## 1. The Essential Constraints of a UI with a Minimal Semantic Layer

### 1.1 ARIA / role / label Are Unprepared

A modern UI is supposed to be rich in semantic layers like these:

- `<button role="button">`
- `<label for="email">Email Address</label>`
- `<input aria-label="Username">`

But in a UI with a minimal semantic layer:

- roles are not assigned correctly
- labels and inputs are not connected
- aria-label is missing, or unstable depending on the UI library

So **there are many situations where getByRole and getByLabel simply cannot be used reliably.**

### 1.2 data-testid Does Not Exist (No Test-Dedicated Anchor)

Worldwide, `data-testid` is the widely used way to stabilize E2E tests — yet it is sometimes absent, for reasons such as:

- It was considered in the past and deferred on priority grounds
- The UI library's structure makes it hard to introduce

→ **The "identification anchor" that E2E testing is built on is missing.**

### 1.3 The DOM Structure Shifts Constantly

These traits appear again and again:

- The UI library generates enormous numbers of divs
- Class names carry no meaning; they exist for style control
- The same UI nests differently in the DOM from screen to screen

Example:

```html
<div>
  <div class="wrapper">
    <div class="content">
      <span>Save</span>
    </div>
  </div>
</div>
```

As a result:

- CSS selectors that trace structure break immediately
- XPath dies almost instantly
- Semantic Locators (role, label) are unusable too, for lack of assignment

→ **The option of using structure-dependent Locators disappears.**

### 1.4 Multiple UI Elements Share the Same Text

Representative examples:

- Several "Save" buttons
- Several "Edit" and "Delete" buttons
- "Back" and "View Details" duplicated as well

Because the UI's text is duplicated:

- An exact match alone cannot achieve uniqueness
- partial text matching mis-hits easily

→ **This is the background that makes the Local Universe (parent container) and near() indispensable.**

### 1.5 Modal Class Names Carry No Meaning; the Only Reliable Anchor Is `role="dialog"`

The class names a UI library generates are, by nature:

- Random
- Abstract
- Meaningless

So identifications like:

- `.modal`
- `.Dialog-root`

are unusable.

The only thing that stays stable is:

```
[role="dialog"]
```

→ **Modal identification is unified on role="dialog".**

### 1.6 Icon Buttons Have UI-Library-Specific Structure

Example:

```html
<button>
  <svg data-icon="ellipsis">
```

- The button's class is useless
- There is no text either
- But `data-icon` is stable, as internal specification

→ At the core of the product-specific rules, **anchoring on svg[data-icon]** is therefore mandatory.

### 1.7 Conclusion: in a UI with a Minimal Semantic Layer, the Structural Layer Churns Wildly

What is needed, therefore:

- Anchor on the UI's "meaning" (text)
- Compensate for missing meaning with proximity (near)
- Narrow the search with a Local Universe
- Exploit the icon structure (data-icon)
- Pin down modals with role

That is what the **systematization of the product-specific strategy** amounts to.

---

## 2. The Optimal Locator Strategy (Product-Specific Rules)

### 2.1 Make near() the Main Force

In a UI with a minimal semantic layer, the structural constraints stack up:

- The element itself has no identifier
- The DOM structure changes constantly
- The same text appears on multiple UI elements
- Class names carry no meaning

Under those conditions, **using "proximity" to pin down an element is the most stable approach there is**.

#### The Representative near() Example (Checkboxes)

```ts
page.locator('input[type="checkbox"]:near(:text("Agree to Terms"))');
```

The background:

1. A checkbox carries no identifying information
2. The DOM structure shifts with the UI library
3. The text is the only stable anchor
4. The distance between the text and the target element does not change

→ **Not structure, not semantics — "proximity to text" becomes the most stable anchor.**

#### Cases Where near() Should Be Actively Adopted

- Checkboxes
- Radio buttons
- Input fields whose labels are not linked to the form
- UI where several buttons exist within one group
- Components whose DOM churns heavily

For UI whose "element itself carries no meaning" — **checkboxes and radio buttons above all** — near() delivers the highest stability.

### 2.2 Confine Modals to role="dialog"

In a UI with a minimal semantic layer:

- Modal class names carry no meaning
- The same text appears both inside the modal and in the background
- The DOM structure differs from screen to screen

So the only anchor that can be trusted is:

```ts
[role="dialog"]
```

#### The Standard Modal Operation Pattern (Required)

```ts
const modal = page.locator('[role="dialog"]');
await modal.getByRole('button', { name: 'Save', exact: true }).click();
```

Benefits:

- No accidental click on the background's "Save" button
- The modal's interior can be treated as a Local Universe
- Resilient to DOM structural change

### 2.3 Anchor Icon Buttons on svg[data-icon]

A button's class and DOM structure change constantly, but the UI library assigns `svg[data-icon]` reliably.

#### Representative Examples: Icon Operations

**The "…" (menu) icon**
```ts
page.locator('button:has(svg[data-icon="ellipsis"])');
```

**The edit icon**
```ts
page.locator('button:has(svg[data-icon="edit"])');
```

**The delete icon**
```ts
page.locator('button:has(svg[data-icon="delete"])');
```

→ **Icon operations should use no anchor other than data-icon.**

### 2.4 Adopt the Stable Pattern Specific to Auth0 Login

Auth0 is an external service — structured differently from the main UI, but with comparatively well-organized HTML.

#### The Stable Pattern (Auth0)

```ts
page.locator('input[name="username"]').fill(email);
page.locator('input[name="password"]').fill(password);
page.locator('button:has-text("Log in")').click();
```

- Semantic anchors exist
- DOM churn is small
- The text is stable too

→ Adopted as the standard pattern for login tests.

### 2.5 Success Patterns (Best Practices)

#### The "Meaning + near + scope" Triple Layer Is the Strongest

**Modal example:**

```ts
const modal = page.locator('[role="dialog"]');
modal.getByRole('button', { name: 'Save', exact: true }).click();
```

**Checkbox example:**

```ts
page.locator('input[type="checkbox"]:near(:text("I agree to the Privacy Policy"))');
```

#### Anchor on the Table Row, Operate the Icons Inside It

```ts
const row = page.locator('tr:has-text("Intro to TypeScript")');
row.locator('button:has(svg[data-icon="edit"])').click();
```

→ The row becomes a "meaningful Local Universe."

#### Use the Local Universe Aggressively

Because UI with a minimal semantic layer is everywhere, carving out universes along "units of meaning" is critically important.

Examples:

- Settings sections
- Course cards
- Tab panels
- Chapter/lesson lists

### 2.6 The Strategy Decision Tree (Judgment Flow)

```
① Does the UI have a clear role / label?
   └ Yes → Semantic Locator
   └ No →
        ② Is the UI text unique?
           └ Yes → exact match (role + name + exact / text-is if immediate text)
           └ No →
                ③ Are the text and the target element in proximity?
                   └ Yes → near()
                   └ No →
                        ④ Is the UI inside a modal?
                           └ Yes → role="dialog" + scope
                           └ No →
                                ⑤ Is the target an icon?
                                   └ Yes → svg[data-icon]
                                   └ No → Exception: structure + comment required
```

---

## 3. Anti-Patterns (Traps to Avoid)

Given what a minimal semantic layer means for the UI (a structure that never stops shifting), the following anti-patterns carry an **"immediate test-collapse risk"** and are prohibited in principle.

### 3.1 CSS-only Selectors

```css
.card > div > button
.wrapper > span.action
```

**Why prohibited:**
- DOM nesting differs from screen to screen
- The UI library adds and removes divs
- Class names carry no meaning and change frequently
- Uniqueness is never guaranteed

→ In a UI with a minimal semantic layer, **CSS-only = fragile, 100% of the time**.

### 3.2 has-text Abuse (Above All, Partial Matching)

```ts
page.locator('button:has-text("Save")');
```

**Why dangerous:**
- Many screens have "Save" in two to four places
- The same text appears in the modal and in the background
- Partial matching mis-hits easily

→ **An exact match (role + name + exact / text-is) + scope (Local Universe) is mandatory.**

### 3.3 Searching for a Modal Across the Whole Page

```ts
page.getByRole('button', { name: 'Save', exact: true }).click();
```

**The typical accidents:**
- The background's "Save" gets clicked instead of the modal's
- The run log looks like a success, but the wrong UI was operated
- Much of what looks like buggy behavior is really a "Locator mis-hit"

→ **The product-specific rules always use the role="dialog" Local Universe.**

### 3.4 Using `.first()`

In a UI where order is not guaranteed, `.first()` is nothing more than "freezing a coincidence."

→ Prohibited apart from the exceptions. When it is used, always write the reason and a TODO.

### 3.5 Mixing Dynamic Values into constants.ts

The selector definition file descends into confusion and becomes unmaintainable.

→ Handle dynamic values in the PageObject layer (same as the universal rule).

### 3.6 Using XPath

A DOM with a minimal semantic layer is a mass of nested divs in constant flux, which gives XPath a level of instability that is **very nearly instant death**.

---

## 4. Success Patterns (Stable Techniques Built on the Product-Specific Rules)

### 4.1 Exact Match + role="dialog" (the Strongest Modal Strategy)

```ts
const modal = page.locator('[role="dialog"]');
modal.getByRole('button', { name: 'Save', exact: true }).click();
```

→ Completely prevents mis-hits against the background UI.
→ The modal's interior "micro-universe (Local Universe)" gives the highest stability.

### 4.2 Use the Row as the Universe and Operate the Icons Inside It

```ts
const row = page.locator('tr:has-text("Intro to TypeScript")');
row.locator('button:has(svg[data-icon="edit"])').click();
```

In a UI with a minimal semantic layer, the row is a rare unit that can still be treated as a "cluster of meaning."

### 4.3 Always Use near() for Checkboxes

```ts
page.locator('input[type="checkbox"]:near(:text("Privacy Policy"))');
```

The checkbox itself carries no anchor; **its proximity to the text is the only stable information there is**.

### 4.4 For Icon Operations, data-icon Is the Only Choice

```ts
row.locator('button:has(svg[data-icon="delete"])');
```

→ Class names and text are of no use here,
→ so **data-icon is the one stable anchor.**

### 4.5 Active Adoption of the Local Universe

- Cards
- Tab content
- Settings sections
- Chapter/lesson lists
- Modals

Bracketing the UI along units of meaning is the greatest defense this kind of product allows.

---

## 5. Product-Specific Checklist (for Practice)

### near()
☑ Did you use near() for checkboxes and radios?
☑ Is the anchoring text unique?

### Modals
☑ Is the scope cut with role="dialog"?
☑ Is there no room left to operate the background UI by mistake?

### Icons
☑ Is svg[data-icon] the anchor?
☑ No dependency on the icon's text or class?

### Row + Internal Elements
☑ Is the row treated as a Local Universe?
☑ Are operations on elements inside the row clearly anchored?

### Text
☑ No has-text abuse?
☑ Is uniqueness achieved with an exact match (role + name + exact / text-is)?

### Structural Dependency
☑ No CSS-only or XPath mixed in?

---

## 6. Product-Specific Rules Summary

The product-specific rules are not exception handling — they are a **rational strategy optimized for the product's structural constraints**.

The five pillars:

```
1. near() (compensating for missing meaning)
2. role="dialog" (the only stable modal anchor)
3. svg[data-icon] (the icon anchor the UI library guarantees)
4. Local Universe (searching by unit of meaning)
5. Row anchor (the row as a universe)
```

Follow these and the hybrid of "universal rules + product-specific rules" holds together, realizing **extremely stable Locator design**.

---

# Summary

This document organized the complete system of Locator design in three layers:

1. **Concept (design philosophy)** — why to write it that way
2. **Universal (universal rules)** — principles that apply to any product
3. **Product-Specific (product-specific rules)** — optimization for UI with a minimal semantic layer

Integrated, they let you build "long-lived E2E tests" that stay standing even as the UI changes.

---

**Last Updated**: 2026-02-02
**Maintainer**: Ray Ishida
