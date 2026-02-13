# LOCATOR_RULES_UNIVERSAL_FULL_part3.md

## 6. `.first()` Is a Last Resort  
`.first()` seems convenient but is a "dangerous tool" that significantly undermines E2E test stability.

### 6.1 Why `.first()` Is Dangerous

#### **(1) Creates Order Dependency**
Many factors can change order:  
UI changes, A/B testing, sorting, etc.  
Order-dependent Locators are fragile.

#### **(2) Obscures Intent**
```
page.locator('button').first().click();
```
"Why the first button?" "What is the intent?" disappears from the test.

#### **(3) Solidifies Coincidence**
E2E tests aim to "reproduce intent."  
`.first()` makes that intent ambiguous.

---

### 6.2 Situations Where `.first()` Is Acceptable (Very Limited)

- No unique attributes exist by UI specification  
- Design guarantees fixed order  
- "First element" exists as a specification concept (e.g., newest always at top)

Even then, **MUST document**:

```ts
// TODO: Replace when unique identifier is introduced
await page.locator('...').first().click();
```

---

## 7. Handle Dynamic Values in PageObject Layer  
Directly embedding dynamic data (e.g., usernames, course names) into Locators makes selector definitions a "variable graveyard" and unmaintainable.

### 7.1 Bad Example (NG)

```ts
export const SELECTORS = {
  USER_ROW: (name) => `tr:has-text("${name}")`,
};
```

- Selectors become dynamic  
- Mixes with other static selectors, causing confusion  
- Test intent becomes unreadable

---

### 7.2 Good Example (OK)

```ts
// constants.ts contains only static selectors
export const SELECTORS = {
  USER_ROW: 'tr',
};

// PageObject complements dynamic values
async clickUser(name: string) {
  await this.page.locator(`tr:has-text("${name}")`).click();
}
```

Through separation of responsibilities:

- Selector "semantic space" is organized  
- PageObject can manage "operations, conditions, dynamic values"  
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
- AI can correctly understand intent and generate from natural language easily  

### 8.2 However, May Be Unusable in "Unprepared HTML Environments"
Examples: role not set, incorrect labels, etc.

Even then, **it's acceptable if "reason for unusability" is understood**.  
Semantic Locators SHOULD always be at top priority.

---

## 9. Maintain Appropriate "Abstraction Level" of Locators

### 9.1 Abstraction Level Too Low
```
div > div > span > button
```
→ Too structure-dependent.

### 9.2 Abstraction Level Too High
```
button
```
→ Matches too many, loses uniqueness.

### 9.3 Correct Abstraction Level
```
button:text-is("保存")
```

Abstraction level means "can identify sufficiently without losing meaning."

---

## 10. Separation of Responsibilities in Locator Design

Closely related to 4-layer architecture:

- **Layer 1 (Playwright API)**: Technical entity  
- **Layer 2 (PageObject / Actions)**: Where Locators are concretely implemented  
- **Layer 3 (Concept)**: Locator philosophy and prohibitions  
- **Layer 4 (Test)**: Layer that MUST NOT directly touch Locators  

E2E developers MUST understand Layer 3 "philosophy" and practice in Layer 2.

---

**Last Updated**: 2026-02-02
**Maintainer**: Ray Ishida
