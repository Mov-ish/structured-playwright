# Test Procedure Document (JSDoc) Template (canonical source for §11)

> **Canonical source = this file** (extracted from e2e-test-create §11). Read when writing a test procedure document, or when checking JSDoc-implementation sync in review. The norm (required items, the Phase = test.step principle, the sync MUST) is canonical in `architecture.md` "Test layer header comments".

```typescript
/**
 * TC-XX: Test case name
 *
 * Execution time: approx. X.X min
 *
 * ■ [Arrange] Data preparation (approx. X min)
 *   1. Do XX
 *   2. Do YY
 *
 * ■ [Act] Phase 1: Phase name (approx. X min)
 *   3. Do XX
 *   4. Do YY → ✅ Verify ZZ
 *
 * ■ [Assert] Phase 2: Phase name (approx. X min)
 *   5. ✅ Verify ZZ
 *
 * ■ [Cleanup] Cleanup (approx. X min)
 *   6. Delete data
 *
 * ■ Verification points (expect)
 *   - Phase 1: verification of XX (N places)
 *   - Phase 2: verification of YY
 *
 * ■ Intentional differences from the original procedure
 *   - None
 */
```

**The "Intentional differences from the original procedure" section**: any implementation that differs from the original (test procedure document / checklist / user story) — substituted test data, merged or omitted steps, stricter verification, newly added verifications or steps absent from the original, etc. — must be **consolidated in this section, differences and reasons together**, not scattered as comments within the steps. If there are no differences, write "None". For a new test driven by a user story, where no original procedure document exists, write "No original (new)" — plain "None" cannot be distinguished from "an original exists but there is no difference".

**Place `test.describe.configure({ timeout })` at the top level (outside and just before the describe).** Placed inside a describe, it **applies only to that describe**, which creates a hole where a second `describe` added later (smoke etc.) runs with no timeout configured. Top-level placement precisely matches the intent of applying to the whole file (the gate mechanically detects inside-describe placement).

**Tag meanings**:

| Tag | Meaning | Relation to the test's purpose |
|------|------|-------------------|
| `[Arrange]` | Preparing the data/state the test needs | Not the test subject. A failure here is not a defect in the test subject |
| `[Act]` | Operating the test subject | The main event. The operation the user story wants to verify |
| `[Assert]` | Verifying the expected results | May be written inline within the same Phase as `[Act]` |
| `[Cleanup]` | Deleting test data / restoring the environment | Not the test subject. Optional (when leftover data is harmless). **Do not write a logout** (Playwright automatically destroys the browser context at test end, so it's unnecessary). However, see "The Cleanup logout principle" below |

### The Cleanup logout principle

Playwright automatically destroys the browser context at test end. In environments not using `storageState`, the authenticated state does not carry over to the next test. Therefore **there is no need to write a logout at the end of Cleanup**.

However, keep the logout in the following cases:

| Category | Description | Example |
|---------|------|---|
| ❌ **Trailing Cleanup logout** | Don't write it (unnecessary, redundant) | Placing `await logoutAction.execute()` at the end of the test |
| ✅ **Mid-flow user switch** | Keep (needed for the next login) | Create data as admin → logout → log in as another role |
| ✅ **Logout itself is the subject** | Keep (it is what's verified) | A test verifying the logout feature itself (`isLogoutComplete()` etc.) |

**Why this is not a gate check**: a Cleanup `execute()` and a mid-flow `execute()` cannot be distinguished by grep and would misfire, so this is handled through generation-time guidance (this skill).
