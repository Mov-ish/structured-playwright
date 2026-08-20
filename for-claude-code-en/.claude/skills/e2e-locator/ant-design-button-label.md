# Ant Design Button Label Pitfalls (span wrapping / automatic space insertion)

## Conclusion

**Ant Design's Button makes the "visible label" and the "DOM text" diverge in two stages.**
Pitfall 1 (span wrapping) silences `:text-is` / `:text`; pitfall 2 (automatic space insertion) silences every text-matching tool except regular expressions. Both fail as "0 matches → timeout" — a failure mode where the error message never tells you the real cause.

## Pitfall 1: the label is wrapped in a span

```html
<button class="ant-btn"><span>Save</span></button>
```

| Locator | Result | Reason |
|---|---|---|
| `button:text-is("Save")` | ❌ 0 matches | `:text-is` evaluates only the element's **immediate** text nodes; the button has none |
| `button:text("Save")` | ❌ 0 matches | `:text` matches only the **smallest** qualifying element (= the span) |
| `button:has-text("Save")` | ✅ | Evaluates full subtree text (the only engine that pierces nesting) |
| `getByRole('button', { name: 'Save', exact: true })` | ✅ | The accessible name is computed from descendants (**the default for exact leaf matching**) |

## Pitfall 2: a half-width space is inserted into two-CJK-character labels (autoInsertSpace)

When a Button label is **exactly two CJK ideographs** (e.g. 「検索」「保存」「削除」「編集」), antd inserts a real half-width space into the DOM text: 「検索」 becomes 「検 索」 in the DOM. The behavior comes from a Chinese typographic convention (「确 定」) and is enabled by default.

```typescript
// ❌ All 0 matches → timeout. The DOM text is "検 索"
page.locator('button:text-is("検索")')
page.locator('button:has-text("検索")')                  // even partial match does not contain "検索"
page.getByRole('button', { name: '検索', exact: true })  // the accessible name is also "検 索"

// ✅ Only regular expressions survive (works with or without the space)
page.getByRole('button', { name: /検\s*索/ })
```

Writing the literal 「検 索」 couples the test to antd's configuration (it breaks the moment the app disables autoInsertSpace). A regex with `\s*` handles both.

Note that Playwright's whitespace normalization only **collapses runs of whitespace into one** — it never removes the space.

## Choosing the countermeasure

| Situation | Countermeasure |
|---|---|
| Labels other than two CJK ideographs (kana-mixed, 3+ characters) | `getByRole` + `name` + `exact: true` (only pitfall 1 applies) |
| Two-CJK-ideograph labels | `getByRole` + `name` + regex `/X\s*Y/` + reason comment |
| Root fix | Ask the dev team for `<ConfigProvider button={{ autoInsertSpace: false }}>` on the app side (same "place for the root-fix TODO" as requesting `data-testid`) |
