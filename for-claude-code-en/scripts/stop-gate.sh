#!/usr/bin/env bash
# =============================================================================
# Stop hook — runs the gate at the end of a turn
#
# Purpose: prevent the AI from handing gate-violating code back to the human.
#          If there are violations, exit 2 blocks the stop and the stderr
#          feedback makes Claude self-correct.
#
# WHY Stop (not PostToolUse):
#   - PostToolUse fires on every Edit = tsc false-fails on mid-generation
#     intermediate states
#   - Stop is the end of the turn = it runs exactly once when the code is in a
#     consistent state (tsc is meaningful)
#
# WHY exit 2:
#   Exit 2 in a Stop hook means "block the stop and force another turn" + feed
#   stderr back to Claude (= self-correction). Infinite loops are prevented by
#   the stop_hook_active flag + CC-side limits.
# =============================================================================
set -u

# --- Infinite-loop guard: if this turn was already resumed by a Stop-hook bounce, exit 0 immediately
INPUT=$(cat 2>/dev/null || true)
if printf '%s' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

# --- Move to the project root ---------------------------------------------------
# CLAUDE_PROJECT_DIR points at the directory that contains .claude/.
# Using CLAUDE_PROJECT_DIR instead of git rev-parse --show-toplevel keeps this
# working in layouts where .claude/ lives somewhere other than the repo root.
ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$ROOT" || exit 0

# --- Determine the files touched this turn from the git diff ----------------------
# Combine 3 sources:
#   1. git diff HEAD             ... uncommitted working-tree changes (staged + unstaged)
#   2. git ls-files --others     ... new untracked files
#   3. git diff <base>..HEAD     ... committed branch changes
# WHY 3 is needed: committing a violation and then stopping leaves the working
#   tree clean, so with 1+2 alone CHANGED is empty and the violation slips through.
# Turns with no changes (e.g. only answering a question) exit here, so the gate
# cost is not paid.
BASE=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || true)
CHANGED=$( {
  git diff --name-only HEAD 2>/dev/null
  git ls-files --others --exclude-standard 2>/dev/null
  [ -n "$BASE" ] && git diff --name-only "$BASE" HEAD 2>/dev/null
} )
[ -z "$CHANGED" ] && exit 0

# Run the gate not only on src/ changes but also on .claude/ and scripts/ changes
# (docs-only edits skip it).
# WHY: the gate's meta-layer checks (rules total ratchet, cross-skill references,
#   SKILL.md size) read .claude/, not src/. Conditioning on "only when src/
#   changed" would let this hook slip through on exactly the case the ratchet is
#   for — changes that grow the rules.
# Why scripts/ is included: do not let a turn slip through that only changed the
#   companion scripts gate.sh calls (check-verify-wait.js = the AST detection
#   itself). Narrowing to gate.sh alone leaves a hole — lean broad.
#   The side effect (editing stop-gate.sh itself also runs the gate) is a
#   reasonable smoke check right after touching the hook.
printf '%s\n' "$CHANGED" | grep -qE "^(src/|\.claude/|scripts/)" || exit 0

# With dependencies not installed, tsc false-fails → skip (prevents false blocks)
[ -d "node_modules" ] || exit 0

# GATE_CALLER=stop-hook: a marker so the gate can tell the execution context apart.
# It downgrades the "baseline not set" verdict from the manual-run ❌ to ⚠️
# (an unset baseline is a pending human decision the agent cannot resolve —
# blocking Stop with ❌ would create the incentive to "write the baseline
# yourself to escape")
RESULT=$(GATE_CALLER=stop-hook bash scripts/gate.sh 2>&1)
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  {
    echo "🚫 gate violations remain. Fix them before finishing."
    echo "$RESULT"
    echo "(WHY / judgment criteria: .claude/rules/prohibited-patterns.md)"
  } >&2
  exit 2
fi
exit 0
