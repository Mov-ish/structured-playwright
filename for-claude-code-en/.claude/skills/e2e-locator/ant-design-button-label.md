# Ant Design Button Label Pitfalls (span wrapping / automatic space insertion)

## Conclusion

**Ant Design's Button makes the "visible label" and the "DOM text" diverge in two stages.**
Pitfall 1 (span wrapping) silences `:text-is` / `:text`; pitfall 2 (automatic space insertion) silences every text-matching tool except regular expressions. Both fail as "0 matches → timeout" — a failure mode where the error message never tells you the real cause.

**Pitfall 1 always applies. Pitfall 2 is conditional** (trigger conditions below). Keeping that asymmetry in mind stops you from over-applying the countermeasure.

## Pitfall 1: the label is wrapped in a span

```html
<button class="ant-btn"><span>Save</span></button>
```

String children are wrapped in a span unconditionally — independently of the `autoInsertSpace` setting. So as long as antd's Button is in use, this pitfall is always live.

| Locator | Result | Reason |
|---|---|---|
| `button:text-is("Save")` | ❌ 0 matches | `:text-is` evaluates only the element's **immediate** text nodes; the button has none |
| `button:text("Save")` | ❌ 0 matches | `:text` matches only the **smallest** qualifying element (= the span) |
| `button:has-text("Save")` | ✅ | Evaluates full subtree text (the only engine that pierces nesting) |
| `getByRole('button', { name: 'Save', exact: true })` | ✅ | The accessible name is computed from descendants (**the default for exact leaf matching**) |
| `getByText('Save', { exact: true })` | ✅ (matches the span) | `getByText`'s `exact` is evaluated against the full subtree text — unlike `:text-is`, it pierces span wrapping |

## Pitfall 2: a half-width space is inserted into two-CJK-character labels (autoInsertSpace)

When a Button label is **exactly two CJK ideographs** (e.g. 「検索」「保存」「削除」「編集」), antd inserts a real half-width space into the DOM text: 「検索」 becomes 「検 索」 in the DOM. The behavior comes from a Chinese typographic convention (「确 定」) and is enabled by default.

The test is `/^[一-龥]{2}$/` — exactly two characters from the basic CJK Unified Ideographs block. Kana-mixed labels, 3+ characters, and 「々」 are out of scope.

**Trigger conditions** (the space is inserted only when all hold):

- There is exactly one child (labels built from multiple elements are out of scope)
- No `icon` prop (**buttons with an icon never get the space**)
- The variant is not `text` / `link` (`type="text"` / `type="link"` buttons never get it)

Conversely: if an icon button shows 「検索」, the DOM says 「検索」 too. Check the real DOM before blaming pitfall 2.

```typescript
// ❌ All 0 matches → timeout. The DOM text is "検 索"
page.locator('button:text-is("検索")')
page.locator('button:has-text("検索")')                  // even partial match does not contain "検索"
page.getByRole('button', { name: '検索', exact: true })  // the accessible name is also "検 索"

// ✅ Only regular expressions survive (works with or without the space)
page.getByRole('button', { name: /^検\s*索$/ })
```

**Do not drop the `^` `$` anchors.** A regular expression passed to role's `name` is evaluated as a partial match, so `/検\s*索/` also hits 「再検索」 and 「検索条件」. An escape hatch that is itself a partial match defeats the "exact by default" policy.

Writing the literal 「検 索」 couples the test to antd's configuration (it breaks the moment the app disables autoInsertSpace). A regex with `\s*` handles both.

Note that Playwright's whitespace normalization only **collapses runs of whitespace into one** — it never removes the space.

## Choosing the countermeasure

| Situation | Countermeasure |
|---|---|
| Labels other than two CJK ideographs (kana-mixed, 3+ characters) | `getByRole` + `name` + `exact: true` (only pitfall 1 applies) |
| Two-CJK-ideograph label, no icon, `type` other than text/link | `getByRole` + `name` + regex `/^X\s*Y$/` + reason comment |
| Two-CJK-ideograph label but with an icon / `type="text"` / `type="link"` | Pitfall 2 does not trigger. `getByRole` + `name` + `exact: true` is enough |
| Root fix | Ask the dev team to turn autoInsertSpace off on the app side (same "place for the root-fix TODO" as requesting `data-testid`) |

The root-fix syntax depends on the antd version:

```tsx
// antd 5.17 and later
<ConfigProvider button={{ autoInsertSpace: false }}>
// antd 4.x / before 5.17
<ConfigProvider autoInsertSpaceInButton={false}>
```
