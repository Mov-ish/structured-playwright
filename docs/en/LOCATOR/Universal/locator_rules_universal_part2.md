# LOCATOR_RULES_UNIVERSAL_FULL_part2.md

## 3. Principle of Uniqueness

Locator quality is determined by "whether it is unique."
Ambiguous Locators are most susceptible to UI changes and are the primary cause of E2E test failures.

### 3.1 Typical Examples of Lost Uniqueness (NG)

```
input[type="checkbox"]
button
div.card
```

These have "no meaning" and therefore easily match multiple elements and are weak against DOM structural changes.

### 3.2 Examples with Ensured Uniqueness (OK)

```
button:text-is("保存")
input[name="email"]
role=button with name="削除"
```

By using UI "meaning" as the basis, tests become remarkably resilient.

---

## 4. Text Matching: Correct Usage of text-is vs has-text

One of Playwright Locator's powerful features is "text matching," but when misused, it becomes the most fragile landmine.

### 4.1 text-is (Exact Match) ― SHOULD Be Used First

```
button:text-is("保存")
```

- Intent is clear  
- False positives are extremely rare  
- Can capture "meaning" most accurately  

Basic policy: **Prioritize text-is.**

---

### 4.2 has-text (Partial Match) ― Dangerous When Misused

```
button:has-text("保存")
```

The following UI elements could all match:

- "保存する" (Save)  
- "下書きを保存" (Save Draft)  
- "保存済みです" (Already Saved)  

Partial matching amplifies "ambiguity," so usage decisions MUST be made carefully.

---

## 5. Parent Container Anchoring (Local Universe Concept)

Locators become stable when used within a "Local Universe."

Example: Search only within a modal

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")').click();
```

### 5.1 Why Is Local Universe Critical?

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

By dividing UI into "universes," uniqueness and stability improve simultaneously.

---

**Last Updated**: 2026-02-02
**Maintainer**: Ray Ishida
