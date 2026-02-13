# LOCATOR_RULES_UNIVERSAL_FULL_part4.md
(Universal Rules - Final Part)

---

## 8. Semantic Locator Details  
### ― getByRole / getByLabel Are Friendly to Both Humans and Machines ―

Playwright's recommended "meaning-based Locators" are:

```ts
page.getByRole()
page.getByLabel()
page.getByPlaceholder()
page.getByAltText()
page.getByTitle()
page.getByText()
```

The most powerful is **getByRole**.

---

### 8.1 Why getByRole Is the Strongest

#### (1) Can Directly Express UI Semantic Structure
```ts
page.getByRole('button', { name: '保存' });
```

This simultaneously expresses  
**"UI role + label users see"**  
which is difficult with CSS or XPath.

#### (2) Highly Resilient to DOM Changes
Even if structure changes slightly, a button remains a button, and names rarely change.

#### (3) Aligns with Accessibility Design
Better UI has appropriate roles,  
so semantic Locators are most stable long-term.

#### (4) AI-Friendly
When instructed in natural language "press save button,"  
AI easily selects getByRole, with good code generation compatibility.

---

### 8.2 Strength of getByLabel

The strongest choice for form-based UI.

```ts
page.getByLabel("メールアドレス");
```

As long as label-input correspondence is maintained, it won't break even when DOM structure fluctuates.

---

### 8.3 Handling getByText

getByText suits natural text matching,  
effective as a fallback when semantic Locators are unavailable.

---

## 9. Deep Dive into XPath Non-Recommendation  
### ― Completely Opposes Playwright Locator Philosophy ―

XPath is frequently used in UI testing,  
but has a completely opposite direction from Playwright's philosophy.

---

### 9.1 Why XPath Is Fragile

#### (1) Completely Dependent on DOM Structure
```xpath
//div[2]/div[1]/span
```
Collapses when UI library adds just one div.

#### (2) Intent Is Hard to Read
Difficult for both humans and AI to understand Locator intent.

#### (3) Cannot Benefit from Playwright's Internal Optimizations
Cannot leverage Locator API strengths like waiting, retry, semantic matching.

#### (4) AI Makes the Most Mistakes
ChatGPT and Claude struggle with stable XPath generation,  
easily mass-producing unmaintainable code.

---

### 9.2 Exceptional XPath Usage

For legacy HTML or special cases where selectors are unavailable,  
XPath MAY be used as a temporary remedy.

However, in this project, due to:

- Low readability
- High structure dependency
- Low maintainability

It is **prohibited in principle**.

---

## 10. Success Patterns (Best Practices)

### 10.1 text-is + scope (Strongest Combination)

```ts
modal.locator('button:text-is("保存")');
```

- Meaning determined by text  
- Range limited to modal (local universe)  
→ One of the most resilient patterns.

---

### 10.2 Confine to role="dialog" (Modals)

```ts
page.locator('[role="dialog"]').locator('input[name="email"]');
```

Very effective for UI where the same field may exist in the background.

---

### 10.3 Prioritize Semantic Locators

```ts
page.getByRole('button', { name: '削除' });
```

By directly using semantic structure,  
can absorb most DOM structural changes.

---

### 10.4 Consolidate Dynamic Value Logic in POM

```ts
async clickUser(name: string) {
  await this.page.getByRole('row', { name }).click();
}
```

By separating Locator definition (static) and dynamic value application (POM),  
test code intent and selector meaning are easier to maintain.

---

## 11. Failure Patterns (Anti-Patterns)

The following highly likely cause test failures:

- CSS-only selectors
- `.first()` abuse
- Careless use of has-text
- Not using parent containers (scope)
- XPath dependency
- Mixing dynamic values in constants.ts

---

## 12. Locator Checklist (Universal Complete Version)

During implementation and review, verify the following:

- ☑ Is uniqueness ensured?  
- ☑ Can it be expressed with text-is?  
- ☑ Is parent container (Local Universe) set?  
- ☑ Are semantic Locators prioritized?  
- ☑ Was effort made to avoid `.first()`?  
- ☑ Are dynamic values placed in PageObject layer?  
- ☑ Is XPath not used?  
- ☑ Is abstraction level appropriate? (Not too low, not too high)

---

## 13. Summary (Universal Conclusion)

Playwright Locator universal principles condense into 4 pillars:

```text
1. Capture meaning (text-is / role)
2. Limit universe (scope / Local Universe)
3. Eliminate coincidence (ensure uniqueness)
4. Don't depend on structure (anti-XPath)
```

By following these,  
"long-lived E2E tests" resilient to UI changes can be built.

---

**Last Updated**: 2026-02-02
**Maintainer**: Ray Ishida
