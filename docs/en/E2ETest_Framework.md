# Design Philosophy of the 4-Layer Architecture

Once an E2E suite grows past a few dozen tests, most teams hit the same wall. Every small UI change means editing dozens of files. A convenience method someone wrote breaks a different test. Tests that stay green while verifying nothing keep piling up. This document identifies that wall as "mixed responsibilities," and explains the **why** behind a design that separates E2E tests into four layers.

This document is about philosophy; it does not cover concrete implementations, procedures, or conventions (their canonical source is the rules / skills / gate under [`for-claude-code-en/`](../../for-claude-code-en/README.md), which keep being updated alongside the implementation). What this document says is intended to remain true no matter how the implementation changes.

---

## 1. Why Separate into Layers — Separating Reasons to Change

The reasons E2E test code is forced to change fall, for the most part, into four kinds.

| Source of change | Example |
|---|---|
| **The UI structure changed** | Changes to a button's DOM position, its selector, or the screen layout |
| **The business procedure changed** | A confirmation step was inserted into a flow that used to be "register → approve" |
| **The test perspective changed** | Expected results to be verified were added or changed |
| **The environment changed** | URLs, credentials, appropriate timeout values |

Strictly speaking, a fifth source exists — changes to the test infrastructure itself, such as a Playwright API change. But that kind of change comes from the tooling, not the product, and it lands cross-cuttingly no matter which design you choose. What layer separation can guarantee — "the place to fix is confined to a single layer" — covers the four product-driven kinds above.

When selectors, operation steps, expected values, and environment values all live together in a single test file, all four kinds of change land in that same file. Conversely, if you separate layers by reason to change, then **whichever kind of change arrives, the place to fix it is confined to a single layer**.

```
Layer 4: Config/Env     ← only environment changes land here
Layer 3: Tests          ← only test-perspective changes land here
   ↕ Fixture            ← not a layer, but the wiring that connects layers (see §3)
Layer 2: Actions        ← only business-procedure changes land here
Layer 1: Page Objects   ← only UI-structure changes land here
```

This is nothing more than the single responsibility principle ("there is only one reason to change") applied to E2E tests. The experience of fixing only the Page Object when the UI changes and watching every test come back to life is the entire value of this structure.

## 2. Responsibilities of Each Layer — What They Are and What They Are Not

### Layer 1: Page Objects — the "Semantic Dictionary" of the UI

A Page Object is a dictionary that defines "this element on this screen carries this meaning." It gives names to **meanings** such as the login button, the search input, the results table, and centrally manages where each meaning lives in the DOM (the Locator).

What a Page Object may hold goes only as far as element definitions, basic operations on a single element, and observation of state. **It must not know the business context.** "Click the search button" is fine to write, but knowing "find a product and buy it" is the job of a higher layer. When a dictionary starts telling stories, every UI change breaks the story along with it.

Locator design has its own independent body of philosophy (see [Locator Strategy](./LOCATOR/locator_strategy.md)). In brief: a Locator is a "conditional expression satisfied in the future"; write it by meaning rather than structure, and narrow the search scope.

### Layer 2: Actions — the "Verbs" of the User Story

An Action implements the verbs that appear in a user story: "log in," "search for a product," "approve a request." It spans multiple Page Objects, controls multiple screens, and offers a business-meaningful unit of flow as a single method.

The value of an Action is **reuse**. "Log in" is a precondition of nearly every test, and if its implementation lives in one place, a change to the login screen's procedure is fixed in that one place. Precisely for that reason, an Action must not bring in test-specific circumstances (such as "this test expects this value"). **Assertions are a test's concern; the moment you write one into an Action, that Action becomes dedicated to one specific test and loses its reusability.**

### Layer 3: Tests — the "Declaration" of Expectations

A test is a declaration of "if you do this, this should happen." Ideal test code consists only of a sequence of Action verbs and the verification of expected results — that is, it **corresponds almost 1:1 to a natural-language test procedure document**.

A test has no need to know Locators or DOM structure. Once it does, a UI change forces the test file to be rewritten even though the test perspective did not change — and there, the benefit that layer separation was meant to protect disappears.

### Layer 4: Config/Env — the "Absorber" for the Environment

This layer centrally manages values that change with the environment or with operational judgment: URLs, credentials, timeouts, shared selectors. When such values are scattered through the code, an environment change becomes a cross-cutting fix across every layer. Isolating credentials into environment variables is also a security requirement.

## 3. Why Are the Boundaries "Absolute"?

Anyone can honor the definition of the layers. What is hard is maintaining the boundaries. "Just this once, write the Locator inline in the test." "Only this Action gets an expect." — exceptions that each look reasonable on their own dissolve the layer structure within months. That is why this design treats the boundaries as **absolute boundaries** and admits no exceptions.

Two boundaries matter above all.

**No Locators in the Test layer / no expect() in the Action layer.** Honoring both at once raises the question, "then how does an Action return a verification result?" The answer is a division of roles: the Action **observes state and returns a boolean** (a verify method), and the test verifies that return value with expect. By splitting verification's "observation" and "judgment" across layers, the observation logic stays reusable while the judgment remains as the test's declaration.

**Inject dependencies.** When a test assembles Actions by hand (with `new`), the coupling between test and Action becomes implicit, and the wiring of infrastructure that ought to be shared (step logging, counters, and so on) leaks into every test. By going through dependency injection (the Fixture), a test only declares "which verbs I use," and the wiring is consolidated in one place.

Let us be explicit here about why the diagram at the top (§1) does not draw Fixture as a fifth layer. Layers are cut along "reasons to change," but **Fixture has no reason to change of its own** — it holds no UI structure, no business procedure, no test perspective, no environment value; it changes only when a new verb (an Action) is registered. Fixture is therefore not a layer but **the wiring that connects layer to layer**, and at the same time the **enforcement mechanism** for the absolute boundaries. Once tests are wired to receive both their means of verification (test / expect) and their verbs (Actions) via the Fixture, the correct way to write becomes the easiest way to write, and boundary erosion (a test assembling an Action by hand, or importing the test runner directly to create a rogue verification path) can only be written as an **explicit deviation that bypasses the wiring** — and explicit deviations can be detected mechanically (§4). The boundaries are still alive months later not because the people guarding them have strong wills, but because structural gravity works in favor of those who keep them, while those who break them can only exist in a detectable form.

## 4. The Fight Against False Positives — What This Design Really Protects

The greatest enemy of E2E testing is not a test that fails. It is **a test that passes when it must not**. A test that stays green while only its verification has died keeps handing out a reassurance that does not exist, and the later it is discovered, the more it costs.

The boundaries of the 4 layers, and the norms layered on top of them (do not put fixed waits in verification methods; do not swallow errors and return false; do not silently skip when the test's conditions cannot be met), all derive, when pushed to the limit, from one and the same principle:

> **A test's value lies in its ability to fail. Close off, structurally, every path by which it quietly loses that ability.**

"It works" and "it is correct" are different things. Especially in an era where generative AI writes test code, code that "runs but verifies nothing" multiplies faster than humans imagine — because AI imitates existing code as the pattern of correctness, once a single false-positive pattern slips in, it keeps being replicated. So this design does not rely on preaching norms in prose: **violations that can be detected mechanically are detected by machines** (the gate in the operational kit is that implementation).

## 5. Where Should Norms Live — the Position of This Document

Finally, a note on this document's own design decision. There are two kinds of norms.

- **Philosophy that stays true even as the implementation changes** — why we separate layers, why the boundaries are absolute, why we fight false positives. This document and [Locator Strategy](./LOCATOR/locator_strategy.md) carry these
- **Operational norms that keep changing along with the implementation** — concrete prohibited patterns, templates, procedures, thresholds. These do not function unless they are placed somewhere with enforcing power (rules that the AI always loads, skills read per phase, gates that judge by exit code). Because documentation can go unread while the implementation moves ahead regardless

The canonical source for operational norms is [`for-claude-code-en/`](../../for-claude-code-en/README.md). The absence of procedures and conventions in this document is not something we forgot to write; it is the result of a choice: **do not write implementation into a document that must not drift**.
