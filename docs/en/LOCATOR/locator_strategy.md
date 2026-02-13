# Locator Strategy
### ― 4-Layer Architecture Layer 3: Locator Design Philosophy / Universal Rules / Product-Specific Rules ―

This document contains **the complete Locator strategy system** for Playwright E2E.
The document is organized from 3 perspectives:

1. **Concept (Design Philosophy)**
2. **Universal (Universal Rules)**
3. **Product-Specific (Product-Specific Rules)**

---

# Part 1: Concept (Design Philosophy)

## 0. Role of Concept

While Locator is a "Layer 1 (Playwright technology)" feature,  
its usage rules are governed by **Layer 3 (Concept / Principles)**.

Because Locator affects:

- Test stability
- Code maintainability
- Auto-generation (AI) quality
- Team comprehension burden
- Resilience to UI changes

It is a "core structure" influencing everything.

The Concept layer unifies **"not how to write, but why to write that way,"**  
becoming the philosophical center of 4-layer architecture.

---

## 1. What Is a Locator (Conceptual Definition)

Viewing Locator as mere "element retrieval"  
misses the depth of design philosophy and Playwright's strengths.

The Concept layer definition is:

```
Locator =
   "probe with condition set"
 × "explores in Local Universe"
 × "evaluated as future value"
```

### 1.1 Locator Is a "Future Value"

Locator does not require elements to currently exist in DOM.

- Lazy Evaluation
- Auto-Wait
- Auto-Retry

It is a "conditional expression satisfied in the future,"  
the fundamental reason for resilience to dynamic UI.

### 1.2 Locator SHOULD Be Operated in "Semantic Space"

Playwright's recommended semantic Locators  
explore elements based on **meaning (Semantics)**, not structure.

- `role` is UI role
- `name` is UI label
- `label` is input field meaning
- `text` is human-understandable information

Capturing UI by meaning rather than structure (div nesting)  
leads to test stability and readability.

### 1.3 Locator Has a "Universe"

The entire page is too large.

Playwright's philosophy aligns with **"explore in Local Universe"**.

Local Universe examples:

- Modals
- Rows
- Cards
- Sections
- Tab panels

Limiting search scope:

- Improves uniqueness
- Resilient to DOM changes
- Clarifies test intent
- Also improves execution speed

One of the most critical concepts in Locator design.

---

## 2. Concept Layer Purpose: Unify Philosophy

The Concept layer defines not "implementation techniques" but  
**Locator design philosophy, priorities, and prohibitions**.

This results in:

- PageObject (Layer 2) operates without confusion
- Test code (Layer 4) stops writing Locators
- AI (Codex / Claude) doesn't generate incorrect Locators
- Team-wide Locator quality is unified

The Concept layer serves as the "Locator constitution".

---

## 3. Universal Principles in Locators

Universal rules compress into 4 principles:

### 3.1 Capture Meaning (Semantic Priority)

Top priority:

```
text-is / role / label / name
```

Reasons:

- UI meaning changes infrequently
- Test code intent is readable
- Good compatibility with AI auto-generation

### 3.2 Limit Universe (Local Universe)

Example:

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("Save")');
```

By exploring within semantically bounded ranges:

- Uniqueness dramatically improves
- Resilient to DOM changes
- Purpose becomes clear

### 3.3 Eliminate Coincidence (Deterministic Behavior)

Typical example: `.first()` abuse

```ts
page.locator('button').first().click();
```

`.first()` merely solidifies UI's coincidental order.  
**Tests should "fix intent" not "fix coincidence".**

### 3.4 Don't Depend on Structure (Anti-XPath / Anti-Structural)

- CSS-only
- XPath
- Structural tracking like div > div > span

These have too low resilience to DOM changes.

The Concept layer **philosophically rejects structure dependency itself**.

---

## 4. Why Product-Specific Rules Integrate into Concept Layer

UI with minimal semantic layer has these structural characteristics:

- Minimal semantic layer
- Structural layer fluctuates easily
- Same text UI exists abundantly within screen
- Icons have data-icon as sole anchor
- Modals cannot be identified by class

Therefore, applying universal principles alone lacks stability.

The Concept layer treats product-specific rules as **"structural necessity" not "exception"**.

### 4.1 Philosophical Position of near()

Originally near() is auxiliary,
but in UI lacking semantic information, it functions as a **substitute for meaning**.

The Concept layer prescribes:

```
In UI lacking semantic information, proximity relationships are treated as meaning.
```

### 4.2 Philosophical Position of role="dialog"

In products where modal and background UI easily coexist,
the sole semantic anchor is the role attribute.

```
Modal Universe is defined with role="dialog" as the base point.
```

### 4.3 Philosophical Position of svg[data-icon]

Since UI libraries assign stable data-icon to icons,
it is internal specification but possesses a **stable anchor equivalent to meaning**.

```
Icon identification uses data-icon as the essential anchor.
```

### 4.4 Why row Is Adopted as Universe

Tables are one of the few "semantic units" in UI with minimal semantic layer.

```
Rows are adopted as Universe as semantic units of UI.
```

---

## 5. Locator Priority System (Locator Priority Pyramid)

The Concept layer systematizes Locator selection as a **5-level priority pyramid**.

```
       ┌──────────────────────────────┐
       │   1. Semantic-Based               │
       │   text-is / role / label / name   │
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

Official rules integrating **universal principles × product-specific circumstances**,  
which both AI and humans MUST follow.

### 5.1 Level 1: Semantic-Based (Semantic First)

Examples:

```ts
page.getByRole('button', { name: '保存' });
page.getByLabel('メールアドレス');
```

Reasons:

- UI meaning is the least likely to change
- Intent is clear for humans
- AI can correctly grasp the purpose

### 5.2 Level 2: Local Universe (Confine by Semantic Unit)

Examples:

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")');
```

Benefits:

- Uniqueness dramatically improves
- Prevents mixing with background
- Resilient to DOM changes

### 5.3 Level 3: near() (Complement Lacking Semantic Information)

Example:

```ts
page.locator('input[type="checkbox"]:near(:text("利用規約に同意"))');
```

In UI with minimal semantic layer, near() becomes the **3rd correct answer**.

### 5.4 Level 4: data-icon (Leveraging UI Library Internals)

Example:

```ts
row.locator('button:has(svg[data-icon="edit"])');
```

In UI with minimal semantic layer, icon semantic information is weak,
so data-icon acts as a **de facto semantic anchor**.

### 5.5 Level 5: Structure (Last Resort)

Example:

```ts
page.locator('div > div:nth-child(2) > button');
```

Usage conditions:

- All upper 4 levels are impossible
- AND comment is required
- Used temporarily with the premise of later replacement

---

## 6. Locator Philosophy AI Agents MUST Follow (For Codex / ChatGPT / Claude)

The Concept layer is also a **ruleset that governs AI output quality**.

Philosophy AI MUST follow:

### 6.1 Do Not Suggest `.first()`

`.first()` merely fixes the "coincidental order" of UI,
and obstructs the essence of testing: "reproducing intent".

→ When tempted to use `.first()`, suspect **lack of uniqueness**.

### 6.2 Never Suggest XPath

Reasons:

- Structure-dependent and fragile
- Contradicts Playwright's philosophy
- Worst compatibility with DOM having minimal semantic layer
- AI easily generates incorrectly

→ The Concept layer mandates "denial of structural dependency".

### 6.3 Follow the Locator Priority Pyramid

When AI generates Locators:

1. **Semantic-based**
2. **Local Universe**
3. **near()**
4. **data-icon**
5. **Structure-dependent (last resort)**

Check sequentially while generating.

### 6.4 Attach "Reasons" to Locators

Good AI output always states reasons:

Example:

> "This UI has no role and text is duplicated, so I used the row as Universe and data-icon inside as anchor."

AI that can articulate reasons has high reproducibility and avoids false positives.

---

## 7. Connection to 4-Layer Architecture (Position of Concept)

The Concept layer is the **central layer that prescribes philosophy** in the 4-layer architecture.

```
┌──────────────────────────────┐
│  Layer 4: Test (Scenario)    │ ← Does NOT write Locators
├──────────────────────────────┤
│  Layer 3: Concept (Principles)│ ← Locator philosophy & priorities
├──────────────────────────────┤
│  Layer 2: PageObject / Actions│ ← Layer that implements Locators
├──────────────────────────────┤
│  Layer 1: Playwright API      │ ← Technical foundation
└──────────────────────────────┘
```

The purpose of testing is **not to operate UI, but to express intent**.
Locators are confined to POM (Layer 2),
and excluded from Test (Layer 4).

---

## 8. "Philosophy → Implementation" Conversion Model by Concept

Concept is not code itself,
but a **thinking model that guides implementation**.

### 8.1 Requirement: "Press the Save Button"

Following Concept:

1. Meaning → text-is
2. Universe → dialog
3. Uniqueness → OK
4. Proximity complement → Not needed

→ Implementation:

```ts
modal.locator('button:text-is("保存")');
```

### 8.2 "Want to Check a Checkbox"

1. Meaning → None
2. Universe → None
3. Proximity → Yes
4. Icon → No

→ Implementation:

```ts
page.locator('input[type="checkbox"]:near(:text("プライバシーポリシー"))');
```

### 8.3 "Want to Press the Edit Icon"

1. Meaning → None
2. Universe → row
3. near → Not needed
4. Icon → Yes

→ Implementation:

```ts
row.locator('button:has(svg[data-icon="edit"])');
```

---

## 9. Concept Summary (Highest-Level Principles)

The Concept layer's philosophy is summarized in these 4 points:

```
1. Capture meaning with highest priority
2. Decompose UI into small universes (Universe)
3. Select elements by intent, not coincidence
4. Eliminate structural dependency and design Locators resilient to fluctuation
```

These are the **completed form of Locator design philosophy**,
and serve as the quality foundation for the entire 4-layer architecture.

---

# Part 2: Universal (Universal Rules)

## 0. Purpose of This Document

The success or failure of E2E testing with Playwright depends on Locator design quality.
Locators are core elements that determine the maintainability, execution stability, and compatibility with AI auto-generation of the entire test suite.

This document systematizes universal Locator design principles that "work for any product."

---

## 1. Fundamental Understanding of Locator: Condition Expressions for Future UI

Playwright's Locator is not mere "element retrieval" but  
behaves as a "condition set that holds against UI appearing in the future."

### 1.1 Lazy Evaluation

Locators don't search DOM at generation time but search during operation execution, waiting until conditions are satisfied.

### 1.2 Auto-Wait

During operations like clicks and inputs, automatically waits for visibility, enablement, and stabilization.

### 1.3 Auto-Retry

Even with unstable UI, Playwright internally repeats searches, making E2E tests resilient.

---

## 2. Locator Design Philosophy: Capture "Meaning" Not Structure

HTML structure changes, but UI meaning (role, name, label, text) rarely changes.

Playwright's recommended strategy is to design Locators based on meaning rather than traversing DOM.

---

## 3. Uniqueness Principle

Locator quality is determined by "whether it is unique."  
Ambiguous Locators are most susceptible to UI changes and are the primary cause of E2E test failures.

### 3.1 Typical Examples Where Uniqueness Breaks (NG)

```
input[type="checkbox"]
button
div.card
```

These have "no meaning," easily match multiple elements, and are weak against DOM structural changes.

### 3.2 Examples with Uniqueness Ensured (OK)

```
button:text-is("保存")
input[name="email"]
role=button with name="削除"
```

By using UI "meaning" as the criterion, they become remarkably resilient.

---

## 4. Text Matching: Correct Usage of text-is vs has-text

One of Playwright Locator's powerful features is "text matching," but  
misuse turns it into the most fragile landmine.

### 4.1 text-is (Exact Match) ― SHOULD Be Used First

```
button:text-is("保存")
```

- Intent is clear
- False positives are extremely rare
- Can capture "meaning" most accurately

Basic policy: **Prioritize text-is.**

### 4.2 has-text (Partial Match) ― Dangerous When Misused

```
button:has-text("保存")
```

The following UI elements could all match:

- "保存する" (Save now)
- "下書きを保存" (Save as draft)
- "保存済みです" (Already saved)

Partial matching amplifies "ambiguity," so usage decisions MUST be made carefully.

---

## 5. Parent Container Anchoring (Local Universe Concept)

Locators become stable when used within a "Local Universe."

Example: Search only within a modal

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")').click();
```

### 5.1 Why Local Universe Is Critical

- Searching the entire DOM increases match candidates
- Becomes resilient to UI fluctuations
- Performance improves
- Test intent becomes clearer

### 5.2 Representative Examples of Local Universe

- Modals
- Cards
- Table rows
- Tab panels
- Settings sections

Dividing UI into "universes" simultaneously increases uniqueness and stability.

---

## 6. `.first()` Is a Last Resort

`.first()` seems convenient but is a "dangerous tool" that significantly undermines E2E test stability.

### 6.1 Why `.first()` Is Dangerous

**(1) Creates Order Dependency**  
Many factors can change order: UI changes, A/B testing, sorting, etc.
Order-dependent Locators are fragile.

**(2) Obscures Intent**
```
page.locator('button').first().click();
```
"Why the first button?" "What was intended?" disappears from the test.

**(3) Solidifies Coincidence**  
E2E tests aim to "reproduce intent."  
`.first()` makes that intent ambiguous.

### 6.2 Situations Where `.first()` Is Acceptable (Very Limited)

- UI specification has no unique attribute
- Design guarantees the order is fixed
- The concept of "first element" exists as specification (e.g., newest is always at top)

Even then, **always write the following**:

```ts
// TODO: Replace when unique identifier is introduced
await page.locator('...').first().click();
```

---

## 7. Handle Dynamic Values in PageObject Layer

Directly embedding dynamic data (e.g., user names, course names) into Locators  
makes selector definitions a "variable graveyard" and unmaintainable.

### 7.1 Bad Example (NG)

```ts
export const SELECTORS = {
  USER_ROW: (name) => `tr:has-text("${name}")`,
};
```

- Selectors become dynamic
- Mix with other static selectors causes confusion
- Test intent becomes unreadable

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

Through separation of responsibilities:

- The "semantic space" of selectors is organized
- PageObject can manage "operations, conditions, and dynamic values"
- Impact scope of changes becomes clear

---

## 8. Philosophy of Prioritizing Semantic Locators (getByRole, etc.)

Use the following whenever possible:

```
getByRole()
getByLabel()
getByPlaceholder()
getByText()
```

### 8.1 Benefits of Semantic Locators

- Based on meaning, resilient even when UI changes slightly
- Test code is readable
- Aligns with Accessibility design
- AI can correctly understand intent and easily generate from natural language

### 8.2 However, "Unprepared HTML Environments" May Prevent Use

Example: role is not set, label is incorrect, etc.

Even then, **it's fine as long as you understand "why it can't be used"**.
Semantic Locators MUST always be placed at the top of priority.

### 8.3 Why getByRole Is the Strongest

**(1) Can directly express UI's semantic structure**
```ts
page.getByRole('button', { name: '保存' });
```

This simultaneously expresses **"UI role + label the user sees"**,  
which is difficult to express with CSS or XPath.

**(2) Extremely resilient to DOM changes**  
Even when structure changes somewhat, a button is still a button, and its name rarely changes.

**(3) Aligns with accessibility design**  
Better UI has appropriate roles,  
so semantic Locators are the most stable in the long term.

**(4) Easy for AI to understand**  
When instructed "press the save button" in natural language,  
AI tends to choose getByRole, with excellent code generation compatibility.

---

## 9. Keep Locator "Abstraction Level" Appropriate

### 9.1 When Abstraction Is Too Low
```
div > div > span > button
```
→ Too structure-dependent.

### 9.2 When Abstraction Is Too High
```
button
```
→ Hits too many elements, no longer unique.

### 9.3 Correct Abstraction Level
```
button:text-is("保存")
```

Abstraction level means "can you sufficiently identify without losing meaning."

---

## 10. Deep Dive: Why XPath Is Not Recommended

XPath is frequently used in UI testing, but  
its direction is the exact opposite of Playwright's philosophy.

### 10.1 Why XPath Is Fragile

**(1) Completely dependent on DOM structure**
```xpath
//div[2]/div[1]/span
```
Collapses when UI library adds just one div.

**(2) Intent is hard to read**  
Difficult for both humans and AI to understand what the Locator intends.

**(3) Cannot benefit from Playwright's internal optimization**  
Locator API strengths like waiting, retry, and semantic matching cannot be leveraged.

**(4) AI makes the most mistakes here**  
ChatGPT and Claude struggle with stable XPath generation,  
easily mass-producing unmaintainable code.

### 10.2 Exceptional XPath Usage

For legacy HTML or special cases where selectors absolutely cannot be obtained,  
XPath may be used as a temporary remedy.

However, in this project:

- Low readability
- High structural dependency
- Low maintainability

make it **prohibited in principle**.

---

## 11. Separation of Responsibilities in Locator Design

Closely related to the 4-layer architecture:

- **Layer 1 (Playwright API)**: Technical substance
- **Layer 2 (PageObject / Actions)**: Where Locators are concretely implemented
- **Layer 3 (Concept)**: Locator philosophy and prohibitions
- **Layer 4 (Test)**: Layer that MUST NOT directly touch Locators

E2E developers understand Layer 3's "philosophy" and practice it in Layer 2.

---

## 12. Success Patterns (Best Practice)

### 12.1 text-is + scope (Strongest Combination)

```ts
modal.locator('button:text-is("保存")');
```

- Meaning confirmed by text
- Range limited by modal as Local Universe
→ One of the most resilient patterns.

### 12.2 Confine to role="dialog" (Modals)

```ts
page.locator('[role="dialog"]').locator('input[name="email"]');
```

Highly effective for UI where the same field may exist in the background.

### 12.3 Prioritize Semantic Locators

```ts
page.getByRole('button', { name: '削除' });
```

By directly using semantic structure,  
most DOM structural changes can be absorbed.

### 12.4 Consolidate Dynamic Value Logic in POM

```ts
async clickUser(name: string) {
  await this.page.getByRole('row', { name }).click();
}
```

Separating Locator definition (static) and dynamic value application (POM)  
makes it easier to maintain test code intent and selector meaning.

---

## 13. Failure Patterns (Anti Pattern)

The following have high probability of causing test collapse:

- CSS-only selectors
- `.first()` overuse
- Careless has-text usage
- Not using parent containers (scope)
- XPath dependency
- Mixing dynamic values into constants.ts

---

## 14. Locator Checklist (Universal Version)

Verify the following items during implementation and review:

- ☑ Is uniqueness ensured?
- ☑ Can it be expressed with text-is?
- ☑ Has a parent container (Local Universe) been set?
- ☑ Are semantic Locators prioritized?
- ☑ Have you made effort to avoid `.first()`?
- ☑ Are dynamic values placed in the PageObject layer?
- ☑ Is XPath not being used?
- ☑ Is the abstraction level appropriate? (Not too low, not too high)

---

## 15. Universal Summary

Playwright Locator universal principles are summarized in 4 pillars:

```text
1. Capture meaning (text-is / role)
2. Limit universe (scope / Local Universe)
3. Eliminate coincidence (ensure uniqueness)
4. Don't depend on structure (anti-XPath)
```

By following these,  
you can build "long-lived E2E tests" that are resilient even when UI changes.

---

# Part 3: Product-Specific (Product-Specific Rules)

## 0. Purpose of This Section

This section systematizes **Locator design strategy specific to products with minimal semantic layer UI**.

Universal rules work for any product, but  
due to HTML/UI structural issues,  
**universal rules alone cannot stabilize Locators in many situations.**

This part thoroughly organizes the background requiring product-specific rules:  
**"Constraints the UI has."**

---

## 1. Essential Constraints of UI with Minimal Semantic Layer

### 1.1 ARIA / role / label Are Unprepared

In modern UI, the following semantic layers should be rich:

- `<button role="button">`
- `<label for="email">Email Address</label>`
- `<input aria-label="Username">`

However, in UI with minimal semantic layer:

- role not properly assigned
- label and input not connected
- aria-label doesn't exist or unstable depending on UI library

Therefore **getByRole and getByLabel cannot be used stably in many situations.**

### 1.2 data-testid Does Not Exist

Globally, `data-testid` is widely used as a stable E2E method, but  
not introduced in some cases for reasons such as:

- Previously considered but postponed due to priority
- Not easy to introduce due to UI library structure

→ **"Identification anchor" that is the foundation of E2E is missing.**

### 1.3 DOM Structure Frequently Fluctuates

The following characteristics occur frequently:

- UI libraries generate massive amounts of divs
- Class names have no meaning, assigned for style control purposes
- DOM nesting differs by screen for the same UI

Example:

```html
<div>
  <div class="wrapper">
    <div class="content">
      <span>保存</span>
    </div>
  </div>
</div>
```

Therefore:

- CSS selectors tracing structure break immediately
- XPath nearly dies instantly
- Semantic Locators (role, label) also unusable due to lack of assignment

→ **Option to use structure-dependent Locators disappears.**

### 1.4 Multiple UI with Same Text Exist

Representative examples:

- Multiple "Save" buttons
- Multiple "Edit" and "Delete"
- "Back" and "View Details" also duplicated

Due to UI text duplication:

- text-is alone cannot uniquely identify
- Partial text matching prone to false positives

→ **Background requiring Local Universe (parent container) and near().**

### 1.5 Modal Class Names Have No Meaning, Only Reliable Anchor Is `role="dialog"`

Originally, class names generated by UI libraries are:

- Random
- Abstract
- Meaningless

Therefore:

- `.modal`
- `.Dialog-root`

such identifications are unusable.

The only stable anchor is:

```
[role="dialog"]
```

→ **Modal identification is unified to role="dialog".**

### 1.6 Icon Buttons Have UI Library-Specific Structure

Example:

```html
<button>
  <svg data-icon="ellipsis">
```

- Button class is useless
- Text doesn't exist either
- However, `data-icon` is stable as internal specification

→ As the core of product-specific rules,  
**using svg[data-icon] as anchor** is mandatory.

### 1.7 Conclusion: UI with Minimal Semantic Layer Has "Wildly Fluctuating Structural Layer"

Therefore what is needed:

- Anchor on UI "meaning" (text)
- Complement meaning insufficiency with proximity (near)
- Narrow search with Local Universe
- Leverage icon structure (data-icon)
- Confirm modals with role

This is the **systematization of product-specific strategy**.

---

## 2. Optimal Locator Strategy (Product-Specific Rules)

### 2.1 Use near() as Main Force

In UI with minimal semantic layer:

- Element itself has no identifier
- DOM structure changes frequently
- Same text UI exists multiple times
- Class names have no meaning

Therefore, **using "proximity" to determine elements is the most stable approach**.

#### Representative Example Using near() (Checkboxes)

```ts
page.locator('input[type="checkbox"]:near(:text("Agree to Terms"))');
```

Background:

1. Checkbox has no identification information
2. DOM structure fluctuates depending on UI library
3. Only text is stable anchor
4. Distance between text and target element doesn't change

→ **Neither structure nor semantic, but "text proximity" becomes the most stable anchor.**

### 2.2 Confine Modals to role="dialog"

In UI with minimal semantic layer:

- Modal class names have no meaning
- Same text UI appears multiple times inside modal and background
- DOM structure differs by screen

Therefore, the only reliable anchor is:

```ts
[role="dialog"]
```

#### Standard Modal Operation Pattern (Required)

```ts
const modal = page.locator('[role="dialog"]');
await modal.locator('button:text-is("Save")').click();
```

Benefits:

- No accidental clicks on background "Save" button
- Can treat modal interior as "Local Universe"
- Resilient to DOM structure changes

### 2.3 Use svg[data-icon] as Anchor for Icon Buttons

Button class or DOM structure changes frequently, but  
UI libraries stably assign `svg[data-icon]`.

#### Representative Examples: Icon Operations

**"..." (Menu) Icon**
```ts
page.locator('button:has(svg[data-icon="ellipsis"])');
```

**Edit Icon**
```ts
page.locator('button:has(svg[data-icon="edit"])');
```

**Delete Icon**
```ts
page.locator('button:has(svg[data-icon="delete"])');
```

→ **Icon operations SHOULD NOT use anchors other than data-icon.**

### 2.4 Adopt Stable Patterns Specific to Auth0 Login

Auth0 is an external service with different structure from the main UI,  
but its HTML is relatively well-organized.

#### Stable Pattern (Auth0)

```ts
page.locator('input[name="username"]').fill(email);
page.locator('input[name="password"]').fill(password);
page.locator('button:has-text("ログイン")').click();
```

- Semantic anchors exist
- DOM fluctuation is small
- Text is also stable

→ Adopted as the standard pattern for login tests.

### 2.5 Success Patterns (Best Practices)

#### "Meaning + near + scope" Triple-Layer Is Strongest

**Modal example:**

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")').click();
```

**Checkbox example:**

```ts
page.locator('input[type="checkbox"]:near(:text("プライバシーポリシーに同意"))');
```

#### Place Anchor on Table Row, Operate Internal Icons

```ts
const row = page.locator('tr:has-text("TypeScript入門")');
row.locator('button:has(svg[data-icon="edit"])').click();
```

→ The row becomes a "meaningful Local Universe."

#### Actively Use Local Universe

Since UI with minimal semantic layer is prevalent,  
cutting out universes by "meaningful units" is critically important.

Examples:

- Settings sections
- Course cards
- Tab panels
- Chapter/lesson lists

### 2.6 Strategy Application Decision Tree (Judgment Flow)

```
① Does the UI have clear role / label?
   └ Yes → Semantic Locator
   └ No →
        ② Is the UI text unique?
           └ Yes → text-is
           └ No →
                ③ Are text and target element in proximity?
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

Given the UI characteristics with minimal semantic layer (fluctuating structure),  
the following anti-patterns carry **"immediate test collapse risk"** and are prohibited in principle.

### 3.1 CSS-only Selectors

```css
.card > div > button
.wrapper > span.action
```

**Why prohibited:**
- DOM nesting differs by screen
- UI libraries increase/decrease divs
- Class names have no meaning and change frequently
- Uniqueness is not guaranteed

→ In UI with minimal semantic layer, **CSS-only = 100% fragile**.

### 3.2 has-text Overuse (Especially Partial Match)

```ts
page.locator('button:has-text("保存")');
```

**Why dangerous:**
- Many screens have "保存" in 2-4 places
- Same text appears in modal and background
- Partial matching is prone to false positives

→ **text-is + scope (Local Universe) is mandatory.**

### 3.3 Searching Modals Across Entire Page

```ts
page.locator('button:text-is("保存")').click();
```

**Typical accidents:**
- Clicks background "Save" instead of modal "Save"
- Appears successful in execution logs, but actually operated wrong UI
- Many seemingly buggy behaviors are "Locator false positives"

→ **Product-specific rules MUST always use role="dialog" Local Universe.**

### 3.4 `.first()` Usage

In UI where order is not guaranteed,  
`.first()` is merely "solidifying coincidence."

→ Prohibited except for exceptions. When used, always write reason and TODO.

### 3.5 Mixing Dynamic Values into constants.ts

Selector definition files become confused and unmaintainable.

→ Handle dynamic values in PageObject layer (same as universal rules).

### 3.6 XPath Usage

DOM with minimal semantic layer has massive div nesting that changes frequently,  
making XPath have **near-instant-death level instability**.

---

## 4. Success Patterns (Stable Methods Based on Product-Specific Rules)

### 4.1 text-is + role="dialog" (Strongest Modal Strategy)

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")').click();
```

→ Completely prevents false positives to background UI.  
→ Highest stability with modal interior "micro-universe (Local Universe)."

### 4.2 Use row As Universe and Operate Internal Icons

```ts
const row = page.locator('tr:has-text("TypeScript入門")');
row.locator('button:has(svg[data-icon="edit"])').click();
```

Rows are a rare unit that can be treated as a "semantic grouping" in UI with minimal semantic layer.

### 4.3 MUST Use near() for Checkboxes

```ts
page.locator('input[type="checkbox"]:near(:text("プライバシーポリシー"))');
```

Checkboxes themselves have no anchor,  
**only proximity to text is stable information**.

### 4.4 Icon Operations: data-icon Only Choice

```ts
row.locator('button:has(svg[data-icon="delete"])');
```

→ Class names and text are useless,  
→ **data-icon is the only stable anchor.**

### 4.5 Active Adoption of Local Universe

- Cards
- Tab content
- Settings sections
- Chapter/lesson lists
- Modals

Bracketing UI by meaningful units is the greatest defense in product-specific UI.

---

## 5. Product-Specific Checklist (For Practice)

### near()
☑ Used near() for checkboxes/radios?  
☑ Is anchored text unique?

### Modals
☑ Scoped with role="dialog"?  
☑ No possibility of accidental background UI operation?

### Icons
☑ Using svg[data-icon] as anchor?  
☑ Not dependent on icon text or class?

### row + internal elements
☑ Treating row as Local Universe?  
☑ Clearly anchored element operations within row?

### Text
☑ Not abusing has-text?  
☑ Uniqueness achieved with text-is?

### Structure Dependency
☑ No CSS-only or XPath mixed in?

---

## 6. Product-Specific Rules Summary

Product-specific rules are not exception handling but  
**rational strategy optimized for product's structural constraints**.

5 pillars:

```
1. near() (Complement meaning insufficiency)
2. role="dialog" (Only stable modal anchor)
3. svg[data-icon] (Icon anchor guaranteed by UI library)
4. Local Universe (Search by semantic unit)
5. Row anchor (Row as universe)
```

By following these,  
"universal rules + product-specific rules" hybrid is established,  
realizing **extremely stable Locator design**.

---

# Summary

This document organized the complete Locator design system in 3 layers:

1. **Concept (Design Philosophy)** - Why write that way
2. **Universal (Universal Rules)** - Principles applicable to any product
3. **Product-Specific (Product-Specific Rules)** - Optimization for UI with minimal semantic layer

By integrating these,  
"long-lived E2E tests" resilient to UI changes can be built.

---

**Last Updated**: 2026-02-02
**Maintainer**: Ray Ishida
