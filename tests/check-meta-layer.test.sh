#!/usr/bin/env bash
# =============================================================================
# メタ層チェック（gate.sh の 22・23・W6・W7）をキット自身に走らせるテスト
#
# gate.sh は src/ を持つ導入先で動く前提のため、src/ を持たないキット自身には一度も
# 走っていなかった — rules/skills を触る PR に機械的な防御線が接続されていなかった（#35）。
# 判定ロジックは tests/ に複製せず、正本の gate.sh を GATE_SCOPE=kit で呼ぶ
# （二重管理は必ず劣化する）。
#
# 検証する 3 ケース（for-claude-code / for-claude-code-en の両方）:
#   1. キットが clean — exit 0 かつ ⚠️ なし（キットは導入先がコピーする雛形なので警告も残さない）
#   2. チェック 22 の ①② を書き方ごとに検査する — CASE2_ROWS を一時コピーに注入し、行ごとの報告を照合。
#      日本語の扱いがロケールで変わるため LC_ALL=C.UTF-8 と C の両方で走らせる（#51）
#   3. cwd ガード — .claude/rules の無い場所で GATE_SCOPE=kit は exit 1（偽 ✅ を出さない）
#
# 検証しないこと: チェック 21（rules 総量ラチェット）。キットは baseline を同梱しない設計で、
# GATE_SCOPE=kit では判定しない（理由は gate.sh のチェック 21 の ★ コメント）
#
# 実行: リポジトリルートで bash tests/check-meta-layer.test.sh
# =============================================================================
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FAILED=0
fail() { echo "❌ $1"; FAILED=1; }
pass() { echo "✅ $1"; }

KITS=(for-claude-code for-claude-code-en)

# --- ケース 1: キット自身が clean ---------------------------------------------------
for kit in "${KITS[@]}"; do
  set +e
  OUT=$(cd "$ROOT/$kit" && GATE_SCOPE=kit bash scripts/gate.sh 2>&1)
  STATUS=$?
  set -e
  if [ "$STATUS" -ne 0 ] || printf '%s\n' "$OUT" | grep -q '⚠️'; then
    printf '%s\n' "$OUT"
    fail "ケース1: ${kit} のメタ層チェックが clean でない（exit ${STATUS}。上記出力）"
  else
    pass "ケース1: ${kit} のメタ層チェックが clean（22・23・W6・W7）"
  fi
done

# --- ケース 2: §N 参照・裸参照の検出（書き方ごと） ----------------------------------
# 1 行 = 「注入する文|その行の file:line に続く報告」（- は報告なし）。注入先は e2e-locator のサブファイル
CASE2_ROWS=(
  # rules への §N 参照
  '`locator-principles.md` §1|locator-principles.md` §1'          # #31 ですり抜けた形
  '詳細はlocator-principles.md §2|locator-principles.md §2'       # 日本語の直後
  'my-locator-principles.md §3|-'                                 # 名前が rules 名で終わる別名
  '`locator-principles.md` の §4|locator-principles.md` の §4'
  'locator-principles.md（§5）|locator-principles.md（§5'
  # 他 SKILL.md への §N 参照
  '`e2e-review` の §3|e2e-review` の §3'
  'e2e-reviewの§3|e2e-reviewの§3'
  'e2e-review（§3）|e2e-review（§3'
  'e2e-review/SKILL.md §3|e2e-review/SKILL.md §3'
  '`e2e-review` § 3|e2e-review` § 3'
  # 自 dir（e2e-locator）への §N 参照は許容
  'e2e-locator（§2）|-'
  'e2e-locator§2|-'
  '`e2e-locator` の §2|-'
  'e2e-locator/SKILL.md §2|-'
  # 裸のサブファイル名（日本語の直後）
  '詳細はtest-data-management.md を参照|test-data-management.md'
)
target=".claude/skills/e2e-locator/ant-design-tabs-disabled.md"
for kit in "${KITS[@]}"; do
  dst="$WORK/$kit"
  mkdir -p "$dst"
  cp -r "$ROOT/$kit/.claude" "$dst/.claude"
  first=$(( $(wc -l < "$dst/$target" | tr -d ' ') + 1 ))
  for row in "${CASE2_ROWS[@]}"; do printf -- '- %s\n' "${row%%|*}" >> "$dst/$target"; done
  for loc in C.UTF-8 C; do
    set +e
    OUT=$(cd "$dst" && LC_ALL=$loc GATE_SCOPE=kit bash "$ROOT/$kit/scripts/gate.sh" 2>&1)
    STATUS=$?
    set -e
    bad=""
    [ "$STATUS" -eq 1 ] || bad="exit ${STATUS}（1 を期待）"
    ln=$first
    for row in "${CASE2_ROWS[@]}"; do
      want=${row#*|}
      key="e2e-locator/ant-design-tabs-disabled.md:${ln}: "
      if [ "$want" = "-" ]; then
        printf '%s\n' "$OUT" | grep -qF "$key" && bad="${bad} / 行${ln}「${row%%|*}」が報告された"
      else
        printf '%s\n' "$OUT" | grep -qF "${key}${want}" || bad="${bad} / 行${ln}「${row%%|*}」が期待どおり報告されない"
      fi
      ln=$((ln + 1))
    done
    if [ -z "$bad" ]; then
      pass "ケース2: ${kit}（LC_ALL=${loc}）で ${#CASE2_ROWS[@]} 通りの書き方がすべて期待どおり"
    else
      printf '%s\n' "$OUT"
      fail "ケース2: ${kit}（LC_ALL=${loc}）— ${bad#" / "}"
    fi
  done
done

# --- ケース 3: cwd ガード -------------------------------------------------------------
mkdir -p "$WORK/empty"
for kit in "${KITS[@]}"; do
  set +e
  (cd "$WORK/empty" && GATE_SCOPE=kit bash "$ROOT/$kit/scripts/gate.sh" > /dev/null 2>&1)
  STATUS=$?
  set -e
  if [ "$STATUS" -eq 1 ]; then
    pass "ケース3: ${kit} の gate.sh は .claude/rules が無い場所で GATE_SCOPE=kit を exit 1 で止める"
  else
    fail "ケース3: ${kit} の gate.sh が .claude/rules の無い場所で exit ${STATUS}（exit 1 を期待）"
  fi
done

echo "━━ 結果 ━━"
if [ "$FAILED" -eq 1 ]; then
  echo "❌ check-meta-layer.test FAIL"
  exit 1
fi
echo "✅ check-meta-layer.test PASS"
