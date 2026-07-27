#!/usr/bin/env bash
# =============================================================================
# check-verify-wait.js（verify 内固定待機の AST 検出）のテスト
#
# 検証する 3 ケース:
#   1. 検出精度 — fixtures/verify-wait/ に対する検出結果が expected.txt と完全一致する
#      （検出すべき違反・検出してはいけない正当形・既知の検出漏れ①③を含む）
#   2. コンパイラ API 不在 — TypeScript 7 系相当（"." export が API を公開しない）で
#      exit 2 + 明示メッセージで停止する（静かに素通りしない）
#   3. typescript 未解決 — node_modules に typescript が無い環境で exit 2
#
# 実行: リポジトリルートで bash tests/check-verify-wait.test.sh
#       （typescript@5 を一時ディレクトリに npm install するためネットワークが必要）
# =============================================================================
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FAILED=0
fail() { echo "❌ $1"; FAILED=1; }
pass() { echo "✅ $1"; }

# --- 対象プロジェクトを組み立てる（fixtures + テスト対象スクリプト） ------------
cp -r "$ROOT/tests/fixtures/verify-wait/src" "$WORK/src"
mkdir -p "$WORK/scripts"
cp "$ROOT/for-claude-code/scripts/check-verify-wait.js" "$WORK/scripts/"
printf '{"name":"verify-wait-test","private":true}\n' > "$WORK/package.json"
cd "$WORK"

# --- ケース 1: TypeScript 5 系での検出精度 -------------------------------------
npm install --no-save 'typescript@5' > /dev/null 2>&1

set +e
ACTUAL=$(node scripts/check-verify-wait.js 2>/tmp/cvw-stderr.log)
STATUS=$?
set -e

if [ "$STATUS" -ne 0 ]; then
  fail "ケース1: exit 0 を期待したが exit ${STATUS}（stderr: $(head -1 /tmp/cvw-stderr.log)）"
else
  if diff <(printf '%s\n' "$ACTUAL" | sort) <(sort "$ROOT/tests/fixtures/verify-wait/expected.txt"); then
    pass "ケース1: 検出結果が expected.txt と完全一致（違反 4 件・非検出 6 形）"
  else
    fail "ケース1: 検出結果が expected.txt と不一致（上記 diff。< が実際 / > が期待）"
  fi
fi

# --- ケース 2: コンパイラ API 不在（TypeScript 7 系相当のスタブ） ----------------
rm -rf node_modules
mkdir -p node_modules/typescript
printf '{"name":"typescript","version":"7.0.0-stub","main":"index.js"}\n' > node_modules/typescript/package.json
printf 'module.exports = { version: "7.0.0-stub" };\n' > node_modules/typescript/index.js

set +e
node scripts/check-verify-wait.js > /dev/null 2>/tmp/cvw-stderr.log
STATUS=$?
set -e

if [ "$STATUS" -eq 2 ] && grep -q 'createSourceFile' /tmp/cvw-stderr.log; then
  pass "ケース2: API 不在で exit 2 + createSourceFile への言及あり"
else
  fail "ケース2: exit 2 + 明示メッセージを期待したが exit ${STATUS}（stderr: $(head -1 /tmp/cvw-stderr.log)）"
fi

# --- ケース 3: typescript 未解決 ------------------------------------------------
rm -rf node_modules

set +e
node scripts/check-verify-wait.js > /dev/null 2>/tmp/cvw-stderr.log
STATUS=$?
set -e

if [ "$STATUS" -eq 2 ]; then
  pass "ケース3: typescript 未解決で exit 2"
else
  fail "ケース3: exit 2 を期待したが exit ${STATUS}"
fi

echo "━━ 結果 ━━"
if [ "$FAILED" -eq 1 ]; then
  echo "❌ check-verify-wait.test FAIL"
  exit 1
fi
echo "✅ check-verify-wait.test PASS"
