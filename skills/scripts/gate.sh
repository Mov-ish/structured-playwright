#!/usr/bin/env bash
# =============================================================================
# 機械ゲート — grep 可能な禁止パターンの機械検出
#
# 使い方: プロジェクトルート（src/ があるディレクトリ）で `npm run gate`
#
# 設計:
# - grep は broad パターン（narrow は偽の安心を生む）
# - ❌（違反）は exit 1。⚠️（警告）は要目視で exit code に影響しない
# - fail メッセージには必ず「→ 代替」を含める
# - ルールの WHY・判定基準は .claude/rules/prohibited-patterns.md 参照
# =============================================================================
set -u

# cwd ガード: src/ が無い場所で実行すると grep が空振りして「偽 ✅」が並ぶため即 fail
[ -d src ] || { echo "❌ src/ が見つかりません。プロジェクトルートで npm run gate を実行してください"; exit 1; }

FAIL=0
WARN=0

# 行頭コメント行（// * /*）の除外フィルタ。
# WHY コメント内で禁止パターンに言及しても fail させない（コード行 + 行末コメントは引き続き検出）
COMMENT_LINE_FILTER=':[0-9]+:[[:space:]]*(\*|//|/\*)'

# --- ❌ 違反チェック: ヒット = exit 1 --------------------------------------
# 引数: $1=ルール名 $2=代替（修正方向） $3...=grep 引数
check() {
  local name="$1"; shift
  local alt="$1"; shift
  local raw status hits
  raw=$(grep "$@" 2>&1); status=$?
  # grep exit 2 = 検索自体のエラー（層ディレクトリ不在・パターン不正等）。
  # 「違反ゼロ」と「検索できていない」を同じ ✅ にしない（偽 ✅ の根治）
  if [ "$status" -ge 2 ]; then
    echo "❌ ${name} → 検索対象エラー（層ディレクトリ不在? ディレクトリ構成を変えた場合は gate.sh を追随させる）"
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

# --- ⚠️ 警告チェック: ヒットしても fail しない（要目視） --------------------
warn_print() {
  local name="$1"; shift
  local note="$1"; shift
  local hits="$1"
  if [ -n "$hits" ]; then
    local count
    count=$(echo "$hits" | wc -l | tr -d ' ')
    echo "⚠️  ${name}: ${count}件（${note}）"
    echo "$hits" | head -10 | sed 's/^/     /'
    [ "$count" -gt 10 ] && echo "     ... ほか $((count - 10)) 件"
    WARN=1
  else
    echo "✅ ${name}"
  fi
}

echo "━━ gate: 禁止パターン検出（$(basename "$PWD")） ━━"

# 1. text= 記法（Playwright で動作しない）
check "text= 記法" ":has-text() / getByRole を使う" \
  -rn -e "'text=" -e '"text=' -e '`text=' src/

# 2. XPath（構造依存・AI 誤生成の温床）
check "XPath" "CSS + セマンティック（locator-principles.md 参照）" \
  -rnE 'locator\((['"'"'"\`])(//|xpath=)' src/

# 3. Page Object の private readonly（デバッグ困難）
check "private readonly（Page Object）" "readonly（public）にする" \
  -rn "private readonly" src/pages/

# 4. Test 層の @playwright/test 直 import（Fixture 未経由）
check "@playwright/test 直 import（Test 層）" "fixtures/app.fixture から import する" \
  -rnE "from ['\"]@playwright/test['\"]" src/tests/

# 5. Test 内の Action 手動 new（依存が明示されない）
check "Test 内 new XxxAction()" "Fixture 引数で受け取る" \
  -rnE 'new [A-Za-z]+Action\(' src/tests/

# 6. Action 層の expect()（アサーションは Test 層の責務）
check "Action 層 expect()" "waitFor() ベースの verify メソッドを返し Test 層で expect する" \
  -rn "expect(" src/actions/

# 7. Action 層の Locator 直書き（4層境界違反。broad・レシーバ非依存）
check "Action 層 Locator 直書き" "Page Object に移しメソッド経由で呼ぶ" \
  -rnE '\.(locator|getBy[A-Za-z]+)\(' src/actions/

# 8. Test 層の Locator 直書き（4層境界違反）
check "Test 層 Locator 直書き" "Action の verify メソッド経由で検証する" \
  -rnE '\.(locator|getBy[A-Za-z]+)\(' src/tests/

# 9. .catch 隠蔽（タイムアウト隠蔽・偽陽性）
#    検出: .catch(()=>false) / .catch(() => { return true }) / .catch(e => false) 等
#    非検出: .catch(handleError) / .catch(e => fallback(e)) 等（正当形）
check ".catch(() => false/true) 隠蔽" "waitFor + try-catch に分離（境界は prohibited-patterns.md 参照）" \
  -rnE '\.catch\([[:space:]]*(\(\)|\(?[A-Za-z_$][A-Za-z0-9_$]*\)?)[[:space:]]*=>[[:space:]]*(\{?[[:space:]]*return[[:space:]]+)?(false|true)' src/

# 10. タイムアウト数値ハードコード（config/ 以外）
check "タイムアウト数値ハードコード" "TIMEOUTS 定数を使う" \
  -rnE '(timeout: |waitForTimeout\(|setTimeout\()[0-9]' --exclude-dir=config src/

# 11. waitForURL の URL 直書き
check "URL パターンハードコード" "URL_PATTERNS 定数を使う" \
  -rnE 'waitForURL\((['"'"'"\`]|/)' src/

# 12. Date.now() による一意名生成（並列ワーカー衝突）
check "Date.now() 一意名生成" "uniqueId() を使う（src/utils/uniqueId.ts）" \
  -rnE 'Date\.now\(\)\.toString|\$\{Date\.now\(\)\}|String\(Date\.now\(\)\)' --exclude=uniqueId.ts src/

# 13. SELECTORS.MODAL + ordinal ハイブリッド（hidden 込み候補集合への stale 対策）
check "locator(SELECTORS.MODAL).last() ハイブリッド" "getByRole('dialog').last() を使う" \
  -rnE 'SELECTORS\.MODAL\)\.(last|first|nth)\(' src/

echo "── 警告（要目視・exit code に影響しない） ──"

# W1. Page Object の waitForTimeout
#     操作メソッド（void）末尾は許容、verify メソッド（boolean 返却）内は禁止。
#     メソッド種別は grep で判定できないため警告に留める（判定基準: prohibited-patterns.md「verify 内の固定待機」）
W1=$(grep -rn "waitForTimeout" src/pages/ 2>/dev/null | grep -vE "$COMMENT_LINE_FILTER" || true)
warn_print "Page Object waitForTimeout" "verify メソッド内に無いか目視確認" "$W1"

# コメント判定（awk 共通）: 行頭コメント（// * /*）か行内 // を「コメントあり」とみなす。
# 行内 // は「: の直後でない //」に限定 — https:// 等の URL 文字列をコメント扱いしない
AWK_COMMENT_FUNCS='
  function is_comment_line(s)    { return s ~ /^[[:space:]]*(\/\/|\*|\/\*)/ }
  function has_inline_comment(s) { return s ~ /(^|[^:])\/\// }
  function has_comment(s)        { return has_inline_comment(s) || is_comment_line(s) }
'

# W2. ordinal セレクタ（.first/.last/.nth）で当該行・直前2行にコメントなし
#     A（応急処置）= コメント + TODO 必須 / B（不変条件）= 理由コメント必須（prohibited-patterns.md「ordinal セレクタの許容境界」）
W2=$(find src -name '*.ts' -print0 2>/dev/null | xargs -0 awk "$AWK_COMMENT_FUNCS"'
  FNR == 1 { prev1 = ""; prev2 = "" }
  /\.(first|last|nth)\(/ {
    if (!is_comment_line($0) && !has_inline_comment($0) && !has_comment(prev1) && !has_comment(prev2))
      print FILENAME ":" FNR ": " $0
  }
  { prev2 = prev1; prev1 = $0 }
' 2>/dev/null || true)
warn_print "ordinal セレクタ コメントなし" "理由コメント（A は + TODO）を付与" "$W2"

# W3. waitForTimeout で当該行・直前2行に理由コメントなし
W3=$(find src -name '*.ts' -not -path '*/config/*' -print0 2>/dev/null | xargs -0 awk "$AWK_COMMENT_FUNCS"'
  FNR == 1 { prev1 = ""; prev2 = "" }
  /waitForTimeout/ {
    if (!is_comment_line($0) && !has_inline_comment($0) && !has_comment(prev1) && !has_comment(prev2))
      print FILENAME ":" FNR ": " $0
  }
  { prev2 = prev1; prev1 = $0 }
' 2>/dev/null || true)
warn_print "waitForTimeout 理由コメントなし" "TIMEOUTS 定数 + 理由コメントを付与" "$W3"

# W4. module スコープの動的値（テスト間暗黙依存の温床）
W4=$(grep -rnE '^const .*(uniqueId\(|Date\.now\()' src/tests/ 2>/dev/null || true)
warn_print "module スコープ動的値" "test() 内 / beforeAll / Setup Action 引数化に移す" "$W4"

# W5. try ブロック内の click/fill（try-catch 境界違反）
#     waitFor のみ try-catch に入れ、click/fill 等の操作は外に出す
#     既知の検出漏れ: ネストされた try（外側 try 内の click）は depth リセットで検出されない
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
warn_print "try ブロック内の click/fill（try-catch 境界違反）" "waitFor のみ try-catch に入れ、操作は外に出す" "$W5"

echo "── tsc --noEmit ──"
if npx tsc --noEmit; then
  echo "✅ tsc"
else
  echo "❌ tsc → 型エラー（未使用 import / 変数含む）を解消する"
  FAIL=1
fi

echo "━━ 結果 ━━"
if [ "$FAIL" -eq 1 ]; then
  echo "❌ gate FAIL — 上記の違反を修正してください（WHY・判定基準は .claude/rules/prohibited-patterns.md）"
  exit 1
fi
if [ "$WARN" -eq 1 ]; then
  echo "✅ gate PASS（⚠️ 警告あり — 要目視）"
else
  echo "✅ gate PASS"
fi
exit 0
