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

---

# Part 2: Universal (Universal Rules)

## 1. Fundamental Understanding of Locator

Playwright's Locator is not mere "element retrieval" but  
behaves as a "condition set satisfied by UI appearing in the future."

### 1.1 Lazy Evaluation

Locators don't search DOM at generation time but search during operation execution, waiting until conditions are satisfied.

### 1.2 Auto-Wait

During operations like clicks and inputs, automatically waits for visibility, enablement, and stabilization.

### 1.3 Auto-Retry

Even with unstable UI, Playwright internally repeats searches, making E2E tests resilient.

---

## 2. Uniqueness Principle

Locator quality is determined by "whether it is unique."  
Ambiguous Locators are most susceptible to UI changes and are the primary cause of E2E test failures.

---

## 3. Text Matching: Correct Usage of text-is vs has-text

### 3.1 text-is (Exact Match) ― SHOULD Be Used First

```
button:text-is("Save")
```

- Intent is clear
- False positives are extremely rare
- Can capture "meaning" most accurately

Basic policy: **Prioritize text-is.**

### 3.2 has-text (Partial Match) ― Dangerous When Misused

```
button:has-text("Save")
```

The following UI elements could all match:

- "Save Now"
- "Save as Draft"
- "Already Saved"

Partial matching amplifies "ambiguity," so usage decisions MUST be made carefully.

---

## 4. Parent Container Anchoring (Local Universe Concept)

Locators become stable when used within a "Local Universe."

Example: Search only within a modal

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("Save")').click();
```

### Why Local Universe Is Critical

- Searching the entire DOM increases match candidates
- Becomes resilient to UI fluctuations
- Performance improves
- Test intent becomes clearer

---

## 5. `.first()` Is a Last Resort

`.first()` seems convenient but is a "dangerous tool" that significantly undermines E2E test stability.

### Why `.first()` Is Dangerous

**(1) Creates Order Dependency**  
Many factors can change order: UI changes, A/B testing, sorting, etc.

**(2) Obscures Intent**
```
page.locator('button').first().click();
```
"Why the first button?" disappears from the test.

**(3) Solidifies Coincidence**  
E2E tests aim to "reproduce intent."  
`.first()` makes that intent ambiguous.

---

## 6. Handle Dynamic Values in PageObject Layer

Directly embedding dynamic data into Locators makes selector definitions a "variable graveyard" and unmaintainable.

---

## 7. Philosophy of Prioritizing Semantic Locators

Use the following whenever possible:

```
getByRole()
getByLabel()
getByPlaceholder()
getByText()
```

### Benefits of Semantic Locators

- Based on meaning, resilient even when UI changes slightly
- Test code is readable
- Aligns with Accessibility design
- AI can correctly understand intent

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

---

## 3. Success Patterns (Stable Methods Based on Product-Specific Rules)

### 3.1 text-is + role="dialog" (Strongest Modal Strategy)

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("Save")').click();
```

→ Completely prevents false positives to background UI.  
→ Highest stability with modal interior "micro-universe (Local Universe)."

### 3.2 Use row As Universe and Operate Internal Icons

```ts
const row = page.locator('tr:has-text("TypeScript Intro")');
row.locator('button:has(svg[data-icon="edit"])').click();
```

Rows are a rare unit that can be treated as a "semantic grouping" in UI with minimal semantic layer.

### 3.3 MUST Use near() for Checkboxes

```ts
page.locator('input[type="checkbox"]:near(:text("Privacy Policy"))');
```

Checkboxes themselves have no anchor,  
**only proximity to text is stable information**.

### 3.4 Icon Operations: data-icon Only Choice

```ts
row.locator('button:has(svg[data-icon="delete"])');
```

→ Class names and text are useless,  
→ **data-icon is the only stable anchor.**

---

## 4. Product-Specific Checklist (For Practice)

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

## 5. Product-Specific Rules Summary

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
