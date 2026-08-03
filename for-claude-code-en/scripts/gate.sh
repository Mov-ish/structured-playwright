#!/usr/bin/env bash
# =============================================================================
# Machine gate — the canonical source of machine detection for prohibited
# patterns that can be mechanized with grep / AST
#
# Usage: run `npm run gate` at the project root (the directory containing src/)
#
# Design:
# - grep patterns are broad (narrow patterns create false reassurance)
# - ❌ (violation) exits 1. ⚠️ (warning) requires visual review and does not affect the exit code
# - Every fail message must include a "→ alternative" (the gate is after-the-fact
#   detection and also carries the job of pointing toward the fix. The canonical
#   source for generation guidance remains on the .claude/rules/ side)
# - For the WHY and judgment criteria of each rule, see .claude/rules/prohibited-patterns.md
#
# ★ When adding, promoting, or removing a check, synchronize the canonical
#   documents that carry the same norm:
#   ① .claude/rules/prohibited-patterns.md — the gate column (✓/⚠️/—) of the affected row and its alternative text
#   ② .claude/skills/e2e-review/SKILL.md — the corresponding check items in §2/§3 (state what is machine-detected and the remaining scope of visual review)
#   ③ .claude/skills/e2e-bootstrap/SKILL.md — verify the scaffold does not trigger the new check (the scaffold = canonical source of generation guidance)
#   ④ If applicable, wording in architecture.md etc. (reconcile any contradictory statements)
#   WHY: the same norm lives in multiple canonical documents, so every change to a
#   check tends to miss a sync target. The missed target is different every time —
#   do not rely on ad-hoc memory; verify mechanically against the list in this
#   file, which is the firing point.
#
#   ※ ① and ③ apply to checks that target code patterns in src/. Meta-layer checks
#     that target .claude/ itself (21–23, W6, W7) do not affect what is generated
#     into src/, so ① and ③ do not apply and the only sync target is ②. Do not
#     write meta-layer norms into rules — adding to rules consumes the very
#     budget that check 21 enforces.
# =============================================================================
set -u

# cwd guard: running where src/ does not exist makes every grep miss and prints
# a row of "false ✅", so fail immediately
# (never display "zero violations" and "the search target does not exist" as the same ✅)
[ -d src ] || { echo "❌ src/ not found. Run npm run gate at the project root"; exit 1; }

# Resolve companion scripts (check-verify-wait.js etc.) relative to gate.sh itself
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

FAIL=0
WARN=0

# Exclusion filter for comment-only lines (// * /*).
# Mentioning a prohibited pattern inside a WHY comment must not fail
# (code lines + trailing inline comments are still detected)
COMMENT_LINE_FILTER=':[0-9]+:[[:space:]]*(\*|//|/\*)'

# --- ❌ violation check: hit = exit 1 ---------------------------------------
# Args: $1=rule name $2=alternative (fix direction) $3...=grep args
check() {
  local name="$1"; shift
  local alt="$1"; shift
  local raw status hits
  raw=$(grep "$@" 2>&1); status=$?
  # grep exit 2 = the search itself failed (missing layer directory, bad pattern, etc.).
  # Never display "zero violations" and "the search could not run" as the same ✅
  # (root fix for false ✅)
  if [ "$status" -ge 2 ]; then
    echo "❌ ${name} → search target error (missing layer directory? If you changed the directory layout, update gate.sh to follow)"
    echo "$raw" | head -3 | sed 's/^/     /'
    FAIL=1
    return
  fi
  hits=$(echo "$raw" | grep -vE "$COMMENT_LINE_FILTER")
  if [ -n "$hits" ]; then
    echo "❌ ${name} → ${alt}"
    echo "$hits" | sed 's/^/     /'
    FAIL=1
  else
    echo "✅ ${name}"
  fi
}

# --- ❌ violation check (pre-computed hits): for awk-based rules grep cannot express ---
# Same FAIL path and output format as check(). Args: $1=rule name $2=alternative (fix direction) $3=hits
fail_print() {
  local name="$1"; shift
  local alt="$1"; shift
  local hits="$1"
  if [ -n "$hits" ]; then
    echo "❌ ${name} → ${alt}"
    echo "$hits" | sed 's/^/     /'
    FAIL=1
  else
    echo "✅ ${name}"
  fi
}

# --- ⚠️ warning check: hits do not fail (visual review required) --------------
warn_print() {
  local name="$1"; shift
  local note="$1"; shift
  local hits="$1"
  if [ -n "$hits" ]; then
    local count
    count=$(echo "$hits" | wc -l | tr -d ' ')
    echo "⚠️  ${name}: ${count} hit(s) (${note})"
    echo "$hits" | head -10 | sed 's/^/     /'
    [ "$count" -gt 10 ] && echo "     ... and $((count - 10)) more"
    WARN=1
  else
    echo "✅ ${name}"
  fi
}

echo "━━ gate: prohibited pattern detection ($(basename "$PWD")) ━━"

# 1. text= syntax (does not work in Playwright)
check "text= syntax" "use :has-text() / getByRole" \
  -rn -e "'text=" -e '"text=' -e '`text=' src/

# 2. XPath (structure-dependent; a breeding ground for AI mis-generation)
check "XPath" "CSS + semantic (see locator-principles.md)" \
  -rnE 'locator\((['"'"'"\`])(//|xpath=)' src/

# 3. private readonly in Page Objects (hard to debug)
check "private readonly (Page Object)" "make it readonly (public)" \
  -rn "private readonly" src/pages/

# 4. Direct @playwright/test import in the Test layer (bypassing Fixture)
check "direct @playwright/test import (Test layer)" "import from fixtures/app.fixture" \
  -rnE "from ['\"]@playwright/test['\"]" src/tests/

# 5. Manual `new` of an Action inside a Test (dependencies not made explicit)
check "new XxxAction() inside Test" "receive it via a Fixture argument" \
  -rnE 'new [A-Za-z]+Action\(' src/tests/

# 6. expect() in the Action layer (assertions are the Test layer's responsibility)
check "expect() in Action layer" "return a waitFor()-based verify method and expect in the Test layer" \
  -rn "expect(" src/actions/

# 7. Inline Locator in the Action layer (4-layer boundary violation; broad, receiver-independent)
check "inline Locator in Action layer" "move it into a Page Object and call it through a method" \
  -rnE '\.(locator|getBy[A-Za-z]+)\(' src/actions/

# 8. Inline Locator in the Test layer (4-layer boundary violation)
check "inline Locator in Test layer" "verify through the Action's verify method" \
  -rnE '\.(locator|getBy[A-Za-z]+)\(' src/tests/

# 9. .catch suppression (hides timeouts; false positives)
#    Detected: .catch(()=>false) / .catch(() => { return true }) / .catch(e => false) etc.
#    Not detected: .catch(handleError) / .catch(e => fallback(e)) etc. (legitimate forms)
check ".catch(() => false/true) suppression" "split into waitFor + try-catch (see prohibited-patterns.md for the boundary)" \
  -rnE '\.catch\([[:space:]]*(\(\)|\(?[A-Za-z_$][A-Za-z0-9_$]*\)?)[[:space:]]*=>[[:space:]]*(\{?[[:space:]]*return[[:space:]]+)?(false|true)' src/

# 10. Hard-coded timeout numbers (outside config/)
check "hard-coded timeout number" "use TIMEOUTS constants" \
  -rnE '(timeout: |waitForTimeout\(|setTimeout\()[0-9]' --exclude-dir=config src/

# 11. Inline URL in waitForURL
check "hard-coded URL pattern" "use URL_PATTERNS constants" \
  -rnE 'waitForURL\((['"'"'"\`]|/)' src/

# 12. Unique-name generation via Date.now() (parallel-worker collisions)
check "Date.now() unique-name generation" "use uniqueId() (src/utils/uniqueId.ts)" \
  -rnE 'Date\.now\(\)\.toString|\$\{Date\.now\(\)\}|String\(Date\.now\(\)\)' --exclude=uniqueId.ts src/

# 13. SELECTORS.MODAL + ordinal hybrid (stale-element countermeasure for candidate sets that include hidden ones)
check "locator(SELECTORS.MODAL).last() hybrid" "use getByRole('dialog').last()" \
  -rnE 'SELECTORS\.MODAL\)\.(last|first|nth)\(' src/

# 14. Undefined tags (anything outside the 4 canonical tags) — targets 4 places:
#     JSDoc headings, verification-point summaries, in-code comments, and test.step names.
#     The canonical tags are exactly Arrange/Act/Assert/Cleanup (their meaning is
#     canonically defined in e2e-test-create §11).
#     Compound tags like [Act/Assert] look well-formed but are undefined.
#     Why a whitelist instead of a blacklist: besides [Act/Assert], compound tags
#     easily spawn independent mutations like [Arrange/Act] [Assert/Cleanup], and a
#     fixed-pattern blacklist cannot keep up (narrow creates false reassurance —
#     same design principle as at the top of this file).
#     The character class allows only ASCII letters + /, so non-tag square brackets
#     such as Japanese data-naming prefixes like [定期] are naturally excluded.
#     Known limitations: ① extraction uses the same character class, so mutations
#     like [Act1] (with digits) or [Act 2] (with spaces) are not extracted and slip
#     through (the whitelist only guards mutations "within the extracted range")
#     ② writing a Markdown checklist (* - [x] etc.) inside JSDoc makes [x] a false
#     positive as an undefined tag — write verification points using the ✅ mark
#     notation instead (e2e-test-create §11)
C14_RAW=$(grep -rnE \
  -e '■[[:space:]]*\[[A-Za-z/]+\]' \
  -e '^[[:space:]]*//[[:space:]]*\[[A-Za-z/]+\]' \
  -e '^[[:space:]]*\*[[:space:]]*-[[:space:]]*\[[A-Za-z/]+\]' \
  -e "test\\.step\\([\"']\\[[A-Za-z/]+\\]" \
  src/tests/ 2>/dev/null || true)
#     Line-level exclusion misses the undefined tag when a canonical tag and an
#     undefined tag coexist on the same line
#     (e.g. "■ [Act] Phase 3 (formerly [Verify/Act])"), so extract every square-bracket
#     token on the line and check each one individually
C14=$(echo "$C14_RAW" | awk '
  {
    rest = $0; bad = 0
    while (match(rest, /\[[A-Za-z\/]+\]/)) {
      tag = substr(rest, RSTART + 1, RLENGTH - 2)
      if (tag !~ /^(Arrange|Act|Assert|Cleanup)$/) bad = 1
      rest = substr(rest, RSTART + RLENGTH)
    }
    if (bad) print
  }
' || true)
fail_print "undefined tag (outside the 4 canonical tags)" "sort into the 4 tags Arrange/Act/Assert/Cleanup (e2e-test-create §11)" "$C14"

# Comment detection (shared awk): a leading-comment line (// * /*) or an inline //
# counts as "has a comment". JSDoc (* ...) lines are also accepted as reason comments.
# Inline // is restricted to "// not immediately after :" — prevents false negatives
# where URL strings like https:// are treated as comments and escape detection
AWK_COMMENT_FUNCS='
  function is_comment_line(s)    { return s ~ /^[[:space:]]*(\/\/|\*|\/\*)/ }
  function has_inline_comment(s) { return s ~ /(^|[^:])\/\// }
  function has_comment(s)        { return has_inline_comment(s) || is_comment_line(s) }
'

# 15. Ordinal selector (.first/.last/.nth) with no comment on that line (formerly W2 — promoted to ❌)
#     A (stopgap) = comment + TODO required / B (invariant) = reason comment required
#     (prohibited-patterns.md "Acceptable Boundaries for Ordinal Selectors")
#     Do not look at the previous line — prevents the false negative of mistaking a
#     comment explaining a different statement for the reason comment. The convention
#     is unified: write the reason comment on the line itself (leading comment line
#     or trailing inline comment).
#     A multi-line call whose reason comment sits on an argument line is also
#     detected (not a bug but the spec — write the comment on the call line)
C15=$(find src -name '*.ts' -print0 2>/dev/null | xargs -0 awk "$AWK_COMMENT_FUNCS"'
  /\.(first|last|nth)\(/ {
    if (!is_comment_line($0) && !has_inline_comment($0))
      print FILENAME ":" FNR ": " $0
  }
' 2>/dev/null || true)
fail_print "ordinal selector without comment" "add a reason comment (case A also needs + TODO) (prohibited-patterns.md \"Acceptable Boundaries for Ordinal Selectors\")" "$C15"

# 16. waitForTimeout with no reason comment on that line (formerly W3 — promoted to ❌)
#     The comment must state "which preceding operation this waits for, and what
#     about it" (paraphrasing the constant name is not acceptable).
#     Do not look at the previous line (same reason as 15). The convention is
#     unified: write the reason comment on the line itself
#     (argument-line comments of multi-line calls are also detected — spec, as in 15)
C16=$(find src -name '*.ts' -not -path '*/config/*' -print0 2>/dev/null | xargs -0 awk "$AWK_COMMENT_FUNCS"'
  /waitForTimeout/ {
    if (!is_comment_line($0) && !has_inline_comment($0))
      print FILENAME ":" FNR ": " $0
  }
' 2>/dev/null || true)
fail_print "waitForTimeout without reason comment" "use a TIMEOUTS constant + a reason comment (which preceding operation this waits for, and what about it)" "$C16"

# 17. Partial-match expect (toContain/toContainText/toMatch) with no reason comment on that line
#     Strict equality (toBe/toEqual) is the default for asserts. Partial matching
#     produces '1' ⊂ '10'-style false positives, so a reason comment explaining
#     "why strict equality is not possible" is required (prohibited-patterns.md
#     "Prohibited value patterns". expect may only be written in the Test layer,
#     so only src/tests is scanned).
#     toContainText is a separate Locator matcher (expect(locator).toContainText(...)) —
#     it has the same partial-match false positives, so it is included
#     (a narrow regex is false reassurance — lean broad)
C17=$(find src/tests -name '*.ts' -print0 2>/dev/null | xargs -0 awk "$AWK_COMMENT_FUNCS"'
  /\.(toContain(Text)?|toMatch)\(/ {
    if (!is_comment_line($0) && !has_inline_comment($0))
      print FILENAME ":" FNR ": " $0
  }
' 2>/dev/null || true)
fail_print "partial-match expect (toContain/toContainText/toMatch) without reason comment" "switch to strict equality (toBe/toEqual) or add a reason comment" "$C17"

# 18. test.describe.configure() inside a describe (top-level placement is the standard — e2e-test-create §11)
#     An indented configure = inside a describe → it only affects that describe,
#     leaving a timeout-not-set hole whenever a describe is added
C18=$(grep -rnE '^[[:space:]]+test\.describe\.configure' src/tests/ 2>/dev/null || true)
fail_print "test.describe.configure inside describe" "move it to the top level (outside and just before the describe)" "$C18"

# 19. waitForTimeout inside verify (methods returning Promise<boolean>) — AST detection
#     A breeding ground for false positives/negatives where the correctness of the
#     judgment is gambled on the wait duration (prohibited-patterns.md "Fixed waits
#     inside verify" is the canonical judgment criterion).
#     grep/awk cannot determine method boundaries (multi-line signatures get
#     misattributed to the previous method), so we judge strictly with the
#     TypeScript compiler API (bundled with tsc, no extra dependency). Scans
#     src/pages + src/actions (verify also exists in the Action layer — limiting to
#     pages is a blind spot).
#     Known detection gaps (covered by visual review; details at the top of check-verify-wait.js):
#       ① methods without a return-type annotation (relying on inference) are out of scope
#       ② waits inside verify → void helper indirect calls
#       ③ module-scope variable form (const isX = async (): Promise<boolean> =>) is out of scope
#     exit 2 = the scan itself failed. Never display "zero violations" and
#     "could not inspect" as the same ✅
C19=$(node "$SCRIPT_DIR/check-verify-wait.js" 2>&1); C19_STATUS=$?
if [ "$C19_STATUS" -ne 0 ]; then
  echo "❌ waitForTimeout inside verify (AST) → the detection script itself failed (check node / typescript resolution)"
  echo "$C19" | head -3 | sed 's/^/     /'
  FAIL=1
else
  fail_print "waitForTimeout inside verify (AST)" "consolidate waits into the operation (void) methods; verify should only observe" "$C19"
fi

# 20. Numeric constants without a declaration-site comment (config/)
#     The declaration-side counterpart of the usage-side reason comment (check 16).
#     16 excludes config/ and only scans the usage side, so the declaration side is
#     inspected here. Write the comment on the line itself (leading comment line or
#     trailing inline) — the reason for not looking at previous lines / block
#     comments is the same as 15/16 (a block comment cannot be mechanically
#     attributed to a specific constant line).
#     Known detection gap: only the "KEY: number" object-literal form (uppercase
#     keys) is covered. Direct assignment (`export const FOO = 5000`) and lowercase
#     keys slip through (object literal + uppercase keys is the implementation
#     convention for constants — the e2e-bootstrap §4 scaffold is canonical)
C20=$(find src/config -name '*.ts' -print0 2>/dev/null | xargs -0 awk "$AWK_COMMENT_FUNCS"'
  /^[[:space:]]*[A-Z][A-Z0-9_]*:[[:space:]]*[0-9]/ {
    if (!is_comment_line($0) && !has_inline_comment($0))
      print FILENAME ":" FNR ": " $0
  }
' 2>/dev/null || true)
fail_print "numeric constant without declaration-site comment (config/)" "state \"what duration this is\" on the declaration line (add the rationale for the value if you have one)" "$C20"

echo "── Meta layer (health of .claude/) ──"

if [ -d .claude/rules ]; then

  # 21. Ratchet on the total always-loaded rules volume (❌ when exceeding baseline)
  #     W6 is per-file, so it cannot detect total growth spread across multiple
  #     files. Merely visualizing the total does not stop the bloat — entry review
  #     only asks "may this be added", and nobody is motivated to delete, so it
  #     becomes a one-way ratchet. Putting a cap on the total forces the discussion
  #     "if you add, what do you remove?".
  #
  #     The baseline lives in .claude/rules-baseline (an external file with a single
  #     number). Why not hard-code it in gate.sh: this file is a distributed
  #     template, and an adopter editing gate.sh becomes a conflict source on
  #     template updates. Even as an external file, the property "raising it always
  #     shows up in the diff" is unchanged. Why it lives outside .claude/rules/:
  #     placing it inside rules/ makes the total measurement recursively count the
  #     baseline file itself.
  #
  #     ★ Initial setup: the baseline file ships unset. A human must create and
  #       freeze it with the value measured against the adopting project's rules
  #       layout (manual gate does not pass while it is missing). The machine goes
  #       as far as presenting the value; a human creates the file — freezing is the
  #       decision "this volume is correct" and must not happen unconsciously.
  #       **AI agents must not create or modify the baseline file themselves**
  #       (their scope ends at reporting the measured value to a human and asking
  #       for it to be set).
  #     ★ When unset, the verdict depends on the execution context: manual runs get
  #       ❌ (forcing setup); via the Stop hook (GATE_CALLER=stop-hook) it is
  #       downgraded to ⚠️. A hook ❌ would keep blocking the agent's Stop, creating
  #       an incentive to "write the baseline yourself to escape" — a head-on
  #       collision with the freezing philosophy. Do not corner an agent in a state
  #       that awaits a human decision.
  #     ★ Raising the BASELINE is not forbidden. But it necessarily appears in the
  #       baseline file's diff, so "why widen the budget instead of deleting?" is
  #       guaranteed to become a review topic. That is the real substance of this
  #       check; there is no separate exception-request flow (more mechanism means
  #       more dead letter).
  BASELINE_FILE=".claude/rules-baseline"
  RULES_BASELINE=$(grep -oE '[0-9]+' "$BASELINE_FILE" 2>/dev/null | head -1 || true)
  RULES_TOTAL=$(find .claude/rules -name '*.md' -exec cat {} + 2>/dev/null | wc -c | tr -d ' ')
  if [ -z "$RULES_BASELINE" ]; then
    BASELINE_MSG="initial setup: create ${BASELINE_FILE} with the current measured value and freeze it (run as a human: echo ${RULES_TOTAL} > ${BASELINE_FILE}. AI agents must not create it — see the ★ comments in gate.sh)"
    if [ "${GATE_CALLER:-}" = "stop-hook" ]; then
      echo "⚠️  Total always-loaded rules volume: baseline not set (${BASELINE_MSG})"
      WARN=1
    else
      echo "❌ Total always-loaded rules volume → ${BASELINE_MSG}"
      FAIL=1
    fi
  elif [ "$RULES_TOTAL" -gt "$RULES_BASELINE" ]; then
    fail_print "Total always-loaded rules volume" \
      "delete the same amount, or justify raising the baseline in the PR body (${BASELINE_FILE} — the raise itself is done by a human)" \
      "current ${RULES_TOTAL}B ($((RULES_TOTAL / 1000))KB) / limit ${RULES_BASELINE}B ($((RULES_BASELINE / 1000))KB) — over by $((RULES_TOTAL - RULES_BASELINE))B"
  else
    echo "✅ Total always-loaded rules volume: ${RULES_TOTAL}B / ${RULES_BASELINE}B (${RULES_BASELINE}B limit, $((RULES_BASELINE - RULES_TOTAL))B remaining)"
  fi

  # 22. Health of cross-skill references (violations = ① §N references into other
  #     SKILL.md files ② bare sub-file names ③ broken links)
  #     The harmful axis is "load-unit granularity and sync burden":
  #       ◎ full-path reference to a sub-file (cross-dir OK) — loads only the
  #         independent unit you need. Paths are more stable than § numbers, and
  #         existence is machine-verified by ③
  #       ✗ §N reference into another SKILL.md body — reading the target requires
  #         loading the whole SKILL.md, and § numbers silently shift as sections
  #         are added/removed (a breeding ground for drift)
  #       ✗ bare sub-file name (no dir) — the location cannot be traced. Fixed by
  #         using the full path
  #     Plain routing pointers ("if the goal is adding a test, use /e2e-test-create")
  #     carry no § number or file path and are not detected.
  #     rules → skills references are also out of scope — rules are always loaded
  #     and skills are phase-loaded, so the two-tier "principles in rules, details
  #     at the reference target" is in fact the standard shape.
  C22=$({
    for f in .claude/skills/*/*.md; do
      [ -e "$f" ] || continue
      d=$(basename "$(dirname "$f")")

      # ① §N references into another SKILL.md body (the `e2e-test-create` §9 form)
      grep -noE "e2e-[a-z-]+\`?[[:space:]]*§[0-9]+" "$f" 2>/dev/null |
        while IFS=: read -r ln m; do
          tgt=${m%%[\`/ ]*}
          [ "$tgt" != "$d" ] && echo "${f#.claude/skills/}:${ln}: ${m}"
        done

      # ② bare sub-file names (cross-dir references missing the dir prefix).
      #    A preceding `/` means a full-path reference (allowed; ③ verifies
      #    existence), so exclude it
      for sub in .claude/skills/*/*.md; do
        sb=$(basename "$sub")
        [ "$sb" = "SKILL.md" ] && continue
        [ "$(basename "$(dirname "$sub")")" = "$d" ] && continue
        grep -noE "(^|[^/[:alnum:]_-])${sb%.md}\.md" "$f" 2>/dev/null |
          while IFS=: read -r ln _; do echo "${f#.claude/skills/}:${ln}: ${sb} (bare reference — use the full path)"; done
      done

      # ③ broken full-path references (the condition that makes full paths
      #    acceptable = machine-verified existence. Any dir)
      grep -noE "e2e-[a-z-]+/[a-z0-9-]+\.md" "$f" 2>/dev/null |
        while IFS=: read -r ln m; do
          [ -e ".claude/skills/$m" ] || echo "${f#.claude/skills/}:${ln}: ${m} (broken link)"
        done
    done
  #   dedup only removes fully identical lines (sort | uniq). If different
  #   violations coexist on one line (e.g. a §N reference next to a broken link),
  #   both are shown (a sort -u keyed on file:line would hide one of them)
  } 2>/dev/null | sort -t: -k1,1 -k2,2n | uniq || true)
  fail_print "cross-skill reference violations (§N cross-reference / bare reference / broken link)" "extract the shared canonical content into a sub-file and reference it by full path (full-path references to sub-files are allowed even across dirs)" "$C22"

  # 23. Size of a single SKILL.md (❌ when exceeding 20,480B)
  #     The threshold being identical to W6 (single rules file) is a requirement —
  #     moving content between rules ↔ skills must not change the verdict
  #     (prevents threshold evasion by relocation). The value itself is the
  #     operating budget for one load unit.
  #     Putting a cap on rules (21) makes skills the escape hatch. Closing only one
  #     side just relocates the volume without changing the total, so close the
  #     skills side at the same time.
  #     However, the unit is NOT "total skills volume" — a new skill is a new
  #     capability, and phases are mutually exclusive so skills are never loaded
  #     together; a total is meaningless. What loads unconditionally when a phase
  #     fires is the single SKILL.md, so the cap sits only there.
  #     Sub-files are exempt (intentional). The correct relief valve when a SKILL.md
  #     swells is "extraction into conditional sub-files + full-path references";
  #     blocking that exit pushes content into §N references (a 22 violation) or
  #     into docs/ (zero enforcement power).
  #     Size is real bytes via wc -c (awk length() returns character counts
  #     depending on implementation × locale, drastically undercounting Japanese —
  #     W6 uses wc -c for the same reason)
  C23=$(find .claude/skills -name 'SKILL.md' 2>/dev/null | sort | while read -r f; do
    b=$(wc -c < "$f" | tr -d ' ')
    [ "$b" -gt 20480 ] && printf "%s: %dB (%.1fKB) — exceeds the 20,480B limit\n" "$f" "$b" "$(echo "$b" | awk '{print $1/1000}')"
  done 2>/dev/null || true)
  fail_print "SKILL.md size exceeded" "extract into conditional sub-files (\"read only in that situation\") and reference by full path — converting to §N references into other SKILL.md files violates 22, and moving to docs/ has zero enforcement power" "$C23"

  # W6. Rules file size (warning when exceeding 20,480B)
  #     Rules are always loaded, so bloat squeezes the context window.
  #     When exceeded, reduce by "converting code examples into Skills pointers",
  #     "removing duplicated statements", etc.
  #     The threshold must equal 23 (SKILL.md) (see 23 for why — never change only
  #     one side).
  #     KB display is decimal (÷1000). The threshold is defined in bytes (20,480B)
  W6=$(find .claude/rules -name '*.md' 2>/dev/null | sort | while read -r f; do
    b=$(wc -c < "$f" | tr -d ' ')
    [ "$b" -gt 20480 ] && printf "%s: %dB (%.1fKB) — exceeds the 20,480B limit\n" "$f" "$b" "$(echo "$b" | awk '{print $1/1000}')"
  done 2>/dev/null || true)
  warn_print "rules file size exceeded" "reduce by converting code examples into Skills pointers and removing duplicated statements" "$W6"

  # W7. TypeScript/JavaScript code blocks in rules (the "rules carry no code" principle)
  #     ASCII diagrams (bare ```) are exempt. Code examples (```typescript etc.)
  #     belong in Skills; keep only a canonical pointer
  W7=$(grep -rnE '^[[:space:]]*```(typescript|javascript|ts|js)' .claude/rules/ 2>/dev/null || true)
  warn_print "TS/JS code blocks in rules" "rules carry no code — move code examples to Skills and keep only a canonical pointer" "$W7"

else
  echo "⚠️  .claude/rules not found — skipped the meta-layer checks (21–23, W6, W7) (place .claude/ at the project root)"
  WARN=1
fi

echo "── Warnings (visual review required — do not affect the exit code) ──"

# W1. waitForTimeout in Page Objects
#     A fixed wait at the end of an operation (void) method is tolerated by
#     convention; inside a verify method (boolean-returning) it is forbidden.
#     Inside verify, check 19 (AST) machine-detects it as ❌. This warning remains
#     as the visual-review complement for the AST's known detection gaps
#     (return type inferred without annotation; indirect calls through void helpers)
#     (judgment criterion: prohibited-patterns.md "Fixed waits inside verify")
W1=$(grep -rn "waitForTimeout" src/pages/ 2>/dev/null | grep -vE "$COMMENT_LINE_FILTER" || true)
warn_print "Page Object waitForTimeout" "visually confirm none are inside verify methods" "$W1"

# W4. Module-scope dynamic values (a breeding ground for implicit inter-test dependencies)
W4=$(grep -rnE '^const .*(uniqueId\(|Date\.now\()' src/tests/ 2>/dev/null || true)
warn_print "module-scope dynamic value" "move into test() / beforeAll / a Setup Action argument" "$W4"

# W5. click/fill inside a try block (try-catch boundary violation)
#     Only waitFor goes inside try-catch; operations like click/fill go outside
#     Known detection gap: nested try (a click inside an outer try) is not detected
#     due to the depth reset
W5=$(find src/actions src/pages -name '*.ts' -print0 2>/dev/null | xargs -0 awk '
  /try[[:space:]]*\{/ { in_try=1; depth=1; next }
  in_try {
    for(i=1;i<=length($0);i++){
      c=substr($0,i,1)
      if(c=="{") depth++
      if(c=="}") { depth--; if(depth==0){ in_try=0; break } }
    }
    if(in_try && $0 ~ /await[[:space:]]+[^;]*\.(click|fill|check|uncheck|press|dblclick|hover|type|selectOption)\(/ && $0 !~ /waitFor/) {
      print FILENAME ":" FNR ": " $0
    }
  }
' 2>/dev/null || true)
warn_print "click/fill inside try block (try-catch boundary violation)" "put only waitFor inside try-catch and move operations outside" "$W5"

echo "── tsc --noEmit ──"
if npx tsc --noEmit; then
  echo "✅ tsc"
else
  echo "❌ tsc → resolve the type errors (including unused imports / variables)"
  FAIL=1
fi

echo "━━ Result ━━"
if [ "$FAIL" -eq 1 ]; then
  echo "❌ gate FAIL — fix the violations above (WHY / judgment criteria: .claude/rules/prohibited-patterns.md)"
  exit 1
fi
if [ "$WARN" -eq 1 ]; then
  echo "✅ gate PASS (⚠️ warnings present — visual review required)"
else
  echo "✅ gate PASS"
fi
exit 0
