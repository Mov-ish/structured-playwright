# LOCATOR_CONCEPT_GUIDE_part2.md
### ― Complete Locator Philosophy: Priority System, AI Standards, 4-Layer Architecture Integration ―

---

# 5. Locator Priority System (Locator Priority Pyramid)

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

## 5.1 Level 1: Semantic-Based (Semantic First)

Example:

```ts
page.getByRole('button', { name: '保存' });
page.getByLabel('メールアドレス');
```

Reasons:

- UI meaning changes least frequently  
- Intent is clear to humans  
- AI can correctly grasp purpose  

---

## 5.2 Level 2: Local Universe (Confine by Semantic Unit)

Example:

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")');
```

Benefits:

- Uniqueness dramatically improves  
- Prevents mixing with background  
- Resilient to DOM changes  

---

## 5.3 Level 3: near() (Compensate for Lacking Semantic Information)

Example:

```ts
page.locator('input[type="checkbox"]:near(:text("利用規約に同意"))');
```

In UI with [minimal semantic layer](../../CLAUDE_FAQ.md#thin-semantic-ui), near() becomes **the third correct answer**.

---

## 5.4 Level 4: data-icon (Utilize UI Library Internal Specification)

Example:

```ts
row.locator('button:has(svg[data-icon="edit"])');
```

In UI with minimal semantic layer, icon semantic information is weak,  
so data-icon behaves as **effective semantic anchor**.

---

## 5.5 Level 5: Structure (Last Resort)

Example:

```ts
page.locator('div > div:nth-child(2) > button');
```

Usage conditions:

- All upper 4 levels impossible  
- Comment REQUIRED  
- Use temporarily with assumption of later replacement

---

# 6. Locator Philosophy AI Agents MUST Follow (For Codex / ChatGPT / Claude)

The Concept layer is also a **ruleset governing AI output quality**.

Philosophy AI MUST follow:

---

## 6.1 MUST NOT Propose `.first()`

`.first()` merely solidifies UI's "coincidental order,"  
hindering the test essence of "intent reproduction".

→ When tempted to use `.first()`, suspect **lack of uniqueness**.

---

## 6.2 MUST NOT Propose XPath At All

Reasons:

- Structure-dependent, fragile  
- Opposes Playwright philosophy  
- Terrible compatibility with DOM having minimal semantic layer  
- AI prone to mis-generation  

→ "Negation of structure dependency" is mandatory in Concept layer.

---

## 6.3 MUST Follow Locator Priority Pyramid

When AI generates Locators:

1. **Semantic-based**  
2. **Local Universe**  
3. **near()**  
4. **data-icon**  
5. **Structure dependency (last resort)**

Check sequentially during generation.

---

## 6.4 MUST Provide "Reason" for Locators

Good AI output always states reasons:

Example:

> "This UI lacks role and has duplicate text, so I use row as Universe and data-icon inside as anchor."

AI that can articulate reasons has high reproducibility and avoids false positives.

---

# 7. Connection with 4-Layer Architecture (Concept Positioning)

The Concept layer is the **central layer defining philosophy** in 4-layer architecture.

```
┌──────────────────────────────┐
│  Layer 4: Test (Scenario)    │ ← MUST NOT write Locators
├──────────────────────────────┤
│  Layer 3: Concept (Principles)│ ← Locator philosophy & priorities
├──────────────────────────────┤
│  Layer 2: PageObject / Actions│ ← Layer implementing Locators
├──────────────────────────────┤
│  Layer 1: Playwright API     │ ← Technical foundation
└──────────────────────────────┘
```

Test purpose is **not to operate UI but to express intent**.  
Locators are confined to POM (Layer 2),  
excluded from Test (Layer 4).

---

# 8. Concept's "Philosophy → Implementation" Translation Model

Concept is not code itself but  
**thought model guiding implementation**.

---

## 8.1 Requirement: "Press Save Button"

Following Concept:

1. Meaning → text-is  
2. Universe → dialog  
3. Uniqueness → OK  
4. Proximity complement → Unnecessary  

→ Implementation:

```ts
modal.locator('button:text-is("保存")');
```

---

## 8.2 "Want to Check Checkbox"

1. Meaning → None  
2. Universe → None  
3. Proximity → Yes  
4. icon → No  

→ Implementation:

```ts
page.locator('input[type="checkbox"]:near(:text("プライバシーポリシー"))');
```

---

## 8.3 "Want to Press Edit Icon"

1. Meaning → None  
2. Universe → row  
3. near → Unnecessary  
4. icon → Yes  

→ Implementation:

```ts
row.locator('button:has(svg[data-icon="edit"])');
```

---

# 9. Concept Summary (Supreme Principles)

The Concept layer philosophy condenses into 4 points:

```
1. Prioritize capturing meaning first
2. Decompose UI into micro-universes
3. Select elements by intent, not coincidence
4. Eliminate structure dependency, design Locators resilient to fluctuation
```

These are the **complete form of Locator design philosophy**,  
becoming the quality foundation of the entire 4-layer architecture.

---

(Concept Guide Complete)

---

**Last Updated**: 2026-02-02
**Maintainer**: Ray Ishida
