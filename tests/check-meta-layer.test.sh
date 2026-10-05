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
#   2. skills → rules の §N 参照を検出する — 一時コピーに次の3行を注入し、exit 1 と報告内容を確認
#      a. #31 ですり抜けた形（`locator-principles.md` §1）→ 検出
#      b. 日本語の直後に書いた形（詳細はlocator-principles.md §2）→ 検出
#         （UTF-8 ロケールでは日本語が [:alnum:] に入るため、左境界の書き方次第で取りこぼす。
#           その条件を確実に作るため LC_ALL=C.UTF-8 で走らせる）
#      c. 名前が rules 名で終わる別名（my-locator-principles.md §3）→ 検出しない
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

# --- ケース 2: skills → rules の §N 参照を検出する --------------------------------
# 注入先は skills のサブファイル。行番号まで一致することを見る（検出の有無だけでなく位置も）
for kit in "${KITS[@]}"; do
  dst="$WORK/$kit"
  mkdir -p "$dst"
  cp -r "$ROOT/$kit/.claude" "$dst/.claude"
  target=".claude/skills/e2e-locator/ant-design-tabs-disabled.md"
  printf -- '- `locator-principles.md` §1 injected by check-meta-layer.test.sh\n' >> "$dst/$target"
  line=$(wc -l < "$dst/$target" | tr -d ' ')
  printf -- '- 詳細はlocator-principles.md §2 injected by check-meta-layer.test.sh\n' >> "$dst/$target"
  printf -- '- my-locator-principles.md §3 injected by check-meta-layer.test.sh\n' >> "$dst/$target"
  set +e
  OUT=$(cd "$dst" && LC_ALL=C.UTF-8 GATE_SCOPE=kit bash "$ROOT/$kit/scripts/gate.sh" 2>&1)
  STATUS=$?
  set -e
  # a〜c は 1 つでも外れたらケース全体を fail にする（偽 ✅ を出さない）
  ok=1
  [ "$STATUS" -eq 1 ] || ok=0
  printf '%s\n' "$OUT" | grep -qF "e2e-locator/ant-design-tabs-disabled.md:${line}: locator-principles.md\` §1" || ok=0
  printf '%s\n' "$OUT" | grep -qF "e2e-locator/ant-design-tabs-disabled.md:$((line + 1)): locator-principles.md §2" || ok=0
  if printf '%s\n' "$OUT" | grep -qF "§3"; then ok=0; fi
  if [ "$ok" -eq 1 ]; then
    pass "ケース2: ${kit} で skills → rules の §N 参照を検出（exit 1・行 ${line}〜$((line + 1))。別名は非検出）"
  else
    printf '%s\n' "$OUT"
    fail "ケース2: ${kit} の §N 参照の検出結果が期待と違う（exit ${STATUS}。上記出力）"
  fi
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
