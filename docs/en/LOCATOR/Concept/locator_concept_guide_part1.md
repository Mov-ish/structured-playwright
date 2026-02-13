# LOCATOR_CONCEPT_GUIDE_part1.md
### ― Locator Design Philosophy in Four-Layer Architecture (Concept Layer / Principles) ―

---

# 0. Role of Concept Guide

While Locator is a "Layer 1 (Playwright technology)" feature,  
its usage rules are governed by **Layer 3 (Concept / Principles)**.

Because Locator affects:

- Test stability  
- Code maintainability  
- Auto-generation (AI) quality  
- Team comprehension burden  
- Resilience to UI changes  

It is a "core structure" influencing everything.

The Concept layer unifies **"not how to write, but why to write that way"**,  
becoming the philosophical center of the 4-layer architecture.

---

# 1. What Is a Locator (Conceptual Definition)

Viewing Locator as mere "element retrieval"  
misses the depth of design philosophy and Playwright's strengths.

The Concept layer definition is:

```
Locator =
   "probe with condition set"
 × "explores in Local Universe"
 × "evaluated as future value"
```

---

## 1.1 Locator Is a "Future Value"

Locator does not require elements to currently exist in DOM.

- Lazy Evaluation  
- Auto-Wait  
- Auto-Retry  

It is a "conditional expression satisfied in the future,"  
the fundamental reason for resilience to dynamic UI.

---

## 1.2 Locator SHOULD Be Operated in "Semantic Space"

Playwright's recommended semantic Locators  
explore elements based on **meaning (Semantics)**, not structure.

- `role` is UI role  
- `name` is UI label  
- `label` is input field meaning  
- `text` is human-understandable information  

Capturing UI by meaning rather than structure (div nesting)  
leads to test stability and readability.

---

## 1.3 Locator Has a "Universe"

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

# 2. Concept Layer Purpose: Unify Philosophy

The Concept layer defines not "implementation techniques" but  
**Locator design philosophy, priorities, and prohibitions**.

This results in:

- PageObject (Layer 2) operates without confusion  
- Test code (Layer 4) stops writing Locators  
- AI (Codex / Claude) doesn't generate incorrect Locators  
- Team-wide Locator quality is unified  

The Concept layer serves as the "Locator constitution".

---

# 3. Universal Principles in Locators (Universal Concept)

Universal rules compress into 4 principles:

---

## 3.1 Capture Meaning (Semantic Priority)

Top priority:

```
text-is / role / label / name
```

Reasons:

- UI meaning changes infrequently  
- Test code intent is readable  
- Good compatibility with AI auto-generation  

---

## 3.2 Limit Universe (Local Universe)

Example:

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")');
```

By exploring within semantically bounded ranges:

- Uniqueness dramatically improves  
- Resilient to DOM changes  
- Purpose becomes clear  

---

## 3.3 Eliminate Coincidence (Deterministic Behavior)

Typical example: `.first()` abuse

```ts
page.locator('button').first().click();
```

`.first()` merely solidifies UI's coincidental order,  
**Tests should "fix intent" not "fix coincidence".**

---

## 3.4 Don't Depend on Structure (Anti-XPath / Anti-Structural)

- CSS-only  
- XPath  
- Structural tracking like div > div > span

These have too low resilience to DOM changes.

The Concept layer **philosophically rejects structure dependency itself**.

---

# 4. Why Product-Specific Rules Integrate into Concept Layer

UI with minimal semantic layer has these structural characteristics:

- [Minimal semantic layer](../../CLAUDE_FAQ.md#thin-semantic-ui)
- Structural layer fluctuates easily  
- Same text UI exists abundantly within screen  
- Icons have data-icon as sole anchor  
- Modals cannot be identified by class  

Therefore, applying universal principles alone lacks stability.

The Concept layer treats product-specific rules as **"structural necessity" not "exception"**.

---

## 4.1 Philosophical Positioning of near()

While near() is originally auxiliary,  
in UI lacking semantic information it functions as **meaning substitute**.

The Concept layer specifies:

```
In UI lacking semantic information, treat proximity as meaning.
```

---

## 4.2 Philosophical Positioning of role="dialog"

For products where modals and background UI easily mix,  
the sole semantic anchor is the role attribute.

```
Modal Universe is defined based on role="dialog".
```

---

## 4.3 Philosophical Positioning of svg[data-icon]

UI libraries provide stable data-icon to icons,  
possessing **stable anchor equivalent to meaning** despite being internal specification.

```
Icon identification has data-icon as essential anchor.
```

---

## 4.4 Why Use row As Universe

Tables (tables) are among the few "semantic units" in UI with minimal semantic layer.

```
Rows are adopted as Universe as UI semantic units.
```

---

(Continued in Part 2)

---

**Last Updated**: 2026-02-02
**Maintainer**: Ray Ishida
