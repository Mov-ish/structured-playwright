#!/usr/bin/env bash
# =============================================================================
# 機械ゲート — grep / AST で機械化できる禁止パターンの機械検出の正本
#
# 使い方: プロジェクトルート（src/ があるディレクトリ）で `npm run gate`
#
# 設計:
# - grep は broad パターン（narrow は偽の安心を生む）
# - ❌（違反）は exit 1。⚠️（警告）は要目視で exit code に影響しない
# - fail メッセージには必ず「→ 代替」を含める（gate は事後検出であり、
#   修正方向の提示まで担う。生成誘導の正本は .claude/rules/ 側に残る）
# - ルールの WHY・判定基準は .claude/rules/prohibited-patterns.md 参照
#
# ★ チェックの追加・昇格・削除時は、同じ規範を載せる正本群を同期すること:
#   ① .claude/rules/prohibited-patterns.md — 該当行の gate 列（✓/⚠️/—）と代替テキスト
#   ② .claude/skills/e2e-review/SKILL.md — §2/§3 の該当チェック項目（機械検出済みの明記・目視残余の範囲）
#   ③ .claude/skills/e2e-bootstrap/SKILL.md — 雛形が新チェックに発火しないか（雛形 = 生成誘導の正本）
#   ④ 該当すれば architecture.md 等の文言（矛盾する記述の整合）
#   WHY: 同じ規範を載せる正本が複数あるため、チェックを変えるたびに同期漏れが起きやすい。
#   同期先は毎回違う箇所で漏れる — 都度の記憶に頼らず、発火点である本ファイルのリストで
#   機械的に確認する。
#
#   ※ ①③は src/ のコードパターンを対象とするチェック用。.claude/ 自体を対象とするメタ層の
#     チェック（21〜23・W6・W7）は src/ の生成物に影響しないため ①③ は該当せず、同期先は
#     ② のみになる。メタ層の規範を rules に書かないこと — rules への追記はチェック 21 の
#     予算を自ら消費する。
# =============================================================================
set -u

# cwd ガード: src/ が無い場所で実行すると grep が空振りして「偽 ✅」が並ぶため即 fail
# （「違反ゼロ」と「検索対象が存在しない」を同じ ✅ で表示しない）
[ -d src ] || { echo "❌ src/ が見つかりません。プロジェクトルートで npm run gate を実行してください"; exit 1; }

# 付属スクリプト（check-verify-wait.js 等）を gate.sh 自身の場所から解決する
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

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

# --- ❌ 違反チェック（検出結果渡し）: grep で表現できない awk 系ルール用 ------
# check() と同じ FAIL 経路・同じ出力形式。引数: $1=ルール名 $2=代替（修正方向） $3=検出結果
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

# 14. 未定義タグ（正規4タグ以外）— JSDoc 見出し・検証ポイント要約・コード内コメント・test.step 名の
#     4箇所が対象。正規タグは Arrange/Act/Assert/Cleanup の4つのみ（意味は e2e-test-create §11 が正本）。
#     [Act/Assert] 等の複合タグは書式は正しく見えるが未定義。
#     ブラックリストでなくホワイトリストにする理由: 複合タグは [Act/Assert] の他にも
#     [Arrange/Act] [Assert/Cleanup] のような独立した変異が生まれやすく、固定パターンの
#     ブラックリストでは追いつかない（narrow は偽の安心を生む — 本ファイル冒頭の設計原則と同じ理由）。
#     文字クラスに ASCII 英字 + / のみを許容しているため、[定期] のようなデータ命名プレフィックス等、
#     非タグ用途の角括弧は自然に除外される。
#     既知の限界: ①抽出も同じ文字クラスなので、[Act1]（数字混じり）や [Act 2]（空白混じり）の
#     変異は抽出されず素通りする（ホワイトリストが防ぐのは「抽出された範囲」の変異のみ）
#     ②JSDoc 内に Markdown チェックリスト（* - [x] 等）を書くと [x] が未定義タグとして
#     誤検知される — 検証ポイントは ✅ マーク表記を使う（e2e-test-create §11）
C14_RAW=$(grep -rnE \
  -e '■[[:space:]]*\[[A-Za-z/]+\]' \
  -e '^[[:space:]]*//[[:space:]]*\[[A-Za-z/]+\]' \
  -e '^[[:space:]]*\*[[:space:]]*-[[:space:]]*\[[A-Za-z/]+\]' \
  -e "test\\.step\\([\"']\\[[A-Za-z/]+\\]" \
  src/tests/ 2>/dev/null || true)
#     行単位の除外だと同一行に正規タグと未定義タグが共存する場合に未定義側を見逃す
#     （例: "■ [Act] Phase 3（旧 [Verify/Act]）"）ため、行内の角括弧トークンを
#     すべて抽出して個別に照合する
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
fail_print "未定義タグ（正規4タグ以外）" "Arrange/Act/Assert/Cleanup の4タグへ振り分ける（e2e-test-create §11）" "$C14"

# コメント判定（awk 共通）: 行頭コメント（// * /*）か行内 // を「コメントあり」とみなす。
# JSDoc（* ...）行も理由コメントとして許容する。
# 行内 // は「: の直後でない //」に限定 — https:// 等の URL 文字列をコメント扱いして
# 検出から漏らす偽陰性を防ぐ
AWK_COMMENT_FUNCS='
  function is_comment_line(s)    { return s ~ /^[[:space:]]*(\/\/|\*|\/\*)/ }
  function has_inline_comment(s) { return s ~ /(^|[^:])\/\// }
  function has_comment(s)        { return has_inline_comment(s) || is_comment_line(s) }
'

# 15. ordinal セレクタ（.first/.last/.nth）で当該行にコメントなし（旧 W2 — ❌ に昇格）
#     A（応急処置）= コメント + TODO 必須 / B（不変条件）= 理由コメント必須
#     （prohibited-patterns.md「ordinal セレクタの許容境界」）
#     直前行は見ない — 別の statement の説明コメントを理由コメントと誤認する false negative を
#     防ぐ。理由コメントは当該行（行頭コメント行 or 行末インラインコメント）に書く運用に統一する。
#     複数行呼び出しで理由コメントが引数行にあるケースも検出される（バグではなく仕様 —
#     コメントは呼び出し行に書く）
C15=$(find src -name '*.ts' -print0 2>/dev/null | xargs -0 awk "$AWK_COMMENT_FUNCS"'
  /\.(first|last|nth)\(/ {
    if (!is_comment_line($0) && !has_inline_comment($0))
      print FILENAME ":" FNR ": " $0
  }
' 2>/dev/null || true)
fail_print "ordinal セレクタ コメントなし" "理由コメント（A は + TODO）を付与（prohibited-patterns.md「ordinal セレクタの許容境界」）" "$C15"

# 16. waitForTimeout で当該行に理由コメントなし（旧 W3 — ❌ に昇格）
#     コメントは「直前のどの操作の何を待つか」を書く（定数名の言い換えは不可）。
#     直前行は見ない（15 と同じ理由）。理由コメントは当該行に書く運用に統一する
#     （複数行呼び出しの引数行コメントも検出対象 — 15 と同じく仕様）
C16=$(find src -name '*.ts' -not -path '*/config/*' -print0 2>/dev/null | xargs -0 awk "$AWK_COMMENT_FUNCS"'
  /waitForTimeout/ {
    if (!is_comment_line($0) && !has_inline_comment($0))
      print FILENAME ":" FNR ": " $0
  }
' 2>/dev/null || true)
fail_print "waitForTimeout 理由コメントなし" "TIMEOUTS 定数 + 理由コメント（直前のどの操作の何を待つか）を付与" "$C16"

# 17. expect の部分一致（toContain/toContainText/toMatch）で当該行に理由コメントなし
#     assert は厳密一致（toBe/toEqual）が既定。部分一致は '1' ⊂ '10' 型の偽陽性を生むため
#     「なぜ厳密一致にできないか」の理由コメント必須（prohibited-patterns.md「値の禁止パターン」。
#     expect は Test 層にのみ書けるため src/tests のみ走査）。
#     toContainText は Locator 用の別 matcher（expect(locator).toContainText(...)）— 同じ部分一致の
#     偽陽性を持つため対象に含める（narrow な正規表現は偽の安心 — broad に倒す）
C17=$(find src/tests -name '*.ts' -print0 2>/dev/null | xargs -0 awk "$AWK_COMMENT_FUNCS"'
  /\.(toContain(Text)?|toMatch)\(/ {
    if (!is_comment_line($0) && !has_inline_comment($0))
      print FILENAME ":" FNR ": " $0
  }
' 2>/dev/null || true)
fail_print "expect 部分一致（toContain/toContainText/toMatch）理由コメントなし" "厳密一致（toBe/toEqual）に倒すか理由コメントを付与" "$C17"

# 18. describe 内の test.describe.configure()（トップレベル配置が標準 — e2e-test-create §11）
#     インデントされた configure = describe 内 → その describe にしか効かず、describe 追加時に
#     タイムアウト未設定の穴が生まれる
C18=$(grep -rnE '^[[:space:]]+test\.describe\.configure' src/tests/ 2>/dev/null || true)
fail_print "describe 内の test.describe.configure" "トップレベル（describe の外・直前）に移す" "$C18"

# 19. verify（Promise<boolean> 返却メソッド）内の waitForTimeout — AST 検出
#     判定の正しさが待ち時間に賭かる偽陽性/偽陰性の温床（prohibited-patterns.md
#     「verify 内の固定待機」が判定基準の正本）。
#     grep/awk はメソッド境界を判定できない（複数行シグネチャで直前のメソッドに誤帰属する）ため、
#     TypeScript コンパイラ API（tsc 同梱・追加依存なし）で厳密判定する。走査は src/pages +
#     src/actions（verify は Action 層にも存在する — pages 限定は盲点）。
#     既知の検出漏れ（目視・レビューで補完。詳細は check-verify-wait.js 冒頭）:
#       ① 返り値注釈のないメソッド（型推論依存）は対象外 ② verify → void ヘルパー間接呼び出し内の待機
#       ③ module スコープ変数形（const isX = async (): Promise<boolean> =>）は対象外
#     exit 2 = 走査自体の失敗。「違反ゼロ」と「検査できていない」を同じ ✅ にしない
C19=$(node "$SCRIPT_DIR/check-verify-wait.js" 2>&1); C19_STATUS=$?
if [ "$C19_STATUS" -ne 0 ]; then
  echo "❌ verify 内 waitForTimeout（AST） → 検出スクリプト自体のエラー（node / typescript の解決を確認）"
  echo "$C19" | head -3 | sed 's/^/     /'
  FAIL=1
else
  fail_print "verify 内 waitForTimeout（AST）" "待機は操作メソッド（void）側へ集約し verify は観測のみにする" "$C19"
fi

# 20. 数値定数の宣言元コメントなし（config/）
#     使用側の理由コメント（チェック 16）と対になる宣言元の要求。16 は config/ を除外して使用側のみ
#     走査するため、宣言側はここで検査する。コメントは当該行（行頭コメント行 or 行末インライン）に
#     書く — 直前行・ブロックコメントを見ない理由は 15/16 と同じ（ブロックコメントが
#     どの定数行を説明しているか機械判定できない）。
#     既知の検出漏れ: 対象は「KEY: 数値」のオブジェクトリテラル形式（大文字キー）のみ。
#     `export const FOO = 5000` の直接代入形式・小文字キーは素通りする（constants は
#     オブジェクトリテラル + 大文字キーが実装慣習 — e2e-bootstrap §4 の雛形が正本）
C20=$(find src/config -name '*.ts' -print0 2>/dev/null | xargs -0 awk "$AWK_COMMENT_FUNCS"'
  /^[[:space:]]*[A-Z][A-Z0-9_]*:[[:space:]]*[0-9]/ {
    if (!is_comment_line($0) && !has_inline_comment($0))
      print FILENAME ":" FNR ": " $0
  }
' 2>/dev/null || true)
fail_print "数値定数の宣言元コメントなし（config/）" "宣言行に「何の時間か」を書く（値の根拠があれば併記）" "$C20"

echo "── メタ層（.claude/ の健全性） ──"

if [ -d .claude/rules ]; then

  # 21. Rules 常時ロード総量のラチェット（baseline 超過で ❌）
  #     W6 はファイル単位のため、複数ファイルへの分散追加による総量増を検出できない。
  #     総量の可視化だけでは肥大は止まらない — 入口審査は「追加してよいか」しか問わず、
  #     削除には誰も動機を持たないため一方向ラチェットになる。総量に上限を設けて
  #     「追加するなら何を削るか」の議論を強制する。
  #
  #     baseline は .claude/rules-baseline（数値 1 行の外部ファイル）に置く。gate.sh 直書きに
  #     しない理由: 本ファイルは配布テンプレートであり、導入先が gate.sh を編集すると
  #     テンプレート更新時のコンフリクト源になる。外部ファイルでも「引き上げが必ず diff に
  #     現れる」性質は変わらない。置き場所を .claude/rules/ の外にする理由: rules/ 内に置くと
  #     総量計測が baseline ファイル自身を数える再帰になる。
  #
  #     ★ 初回セットアップ: baseline ファイルは未作成で出荷している。導入したプロジェクトの
  #       rules 構成で実測した値で人間が作成して凍結すること（未作成のままでは手動 gate は
  #       通らない）。値の提示までを機械がやり、ファイル作成は人間が行う — 凍結は「この量を
  #       正とする」という意思決定であり、無意識に行われるべきでない。
  #       **AI エージェントは baseline ファイルを自分で作成・変更しない**（実測値を人間に
  #       伝えて設定を依頼するまでが担当範囲）。
  #     ★ 未作成時の判定は実行文脈で変える: 手動実行では ❌（セットアップを強制）、
  #       Stop フック経由（GATE_CALLER=stop-hook）では ⚠️ に落とす。フックの ❌ は
  #       エージェントの Stop をブロックし続けるため、「自分で baseline を書いて脱出する」
  #       という凍結思想と正面衝突するインセンティブを生む — 人間の意思決定待ちの状態で
  #       エージェントを追い込まない。
  #     ★ BASELINE の引き上げは禁止しない。ただし baseline ファイルの diff に必ず現れるため、
  #       レビューで「なぜ削らずに枠を広げるのか」が必ず議題になる。これが本チェックの本体であり、
  #       別途の例外申請フローは設けない（機構を増やすと形骸化するため）。
  BASELINE_FILE=".claude/rules-baseline"
  RULES_BASELINE=$(grep -oE '[0-9]+' "$BASELINE_FILE" 2>/dev/null | head -1 || true)
  RULES_TOTAL=$(find .claude/rules -name '*.md' -exec cat {} + 2>/dev/null | wc -c | tr -d ' ')
  if [ -z "$RULES_BASELINE" ]; then
    BASELINE_MSG="初回セットアップ: 現在の実測値で ${BASELINE_FILE} を作成して凍結してください（人間が実行: echo ${RULES_TOTAL} > ${BASELINE_FILE}。AI エージェントは作成しない — gate.sh 内★コメント参照）"
    if [ "${GATE_CALLER:-}" = "stop-hook" ]; then
      echo "⚠️  Rules 常時ロード総量: baseline 未設定（${BASELINE_MSG}）"
      WARN=1
    else
      echo "❌ Rules 常時ロード総量 → ${BASELINE_MSG}"
      FAIL=1
    fi
  elif [ "$RULES_TOTAL" -gt "$RULES_BASELINE" ]; then
    fail_print "Rules 常時ロード総量" \
      "同量を削るか、baseline 引き上げの必然性を PR 本文に書く（${BASELINE_FILE} — 引き上げの実行は人間）" \
      "現在 ${RULES_TOTAL}B ($((RULES_TOTAL / 1000))KB) / 上限 ${RULES_BASELINE}B ($((RULES_BASELINE / 1000))KB) — 超過 $((RULES_TOTAL - RULES_BASELINE))B"
  else
    echo "✅ Rules 常時ロード総量: ${RULES_TOTAL}B / ${RULES_BASELINE}B（残 $((RULES_BASELINE - RULES_TOTAL))B）"
  fi

  # 22. Skill 間参照の健全性（違反 = ①他 SKILL.md への §N 参照 ②裸のサブファイル名 ③リンク切れ）
  #     有害軸は「ロード単位の粒度と同期負荷」:
  #       ◎ サブファイルへのフルパス参照（dir 跨ぎ可）— 必要な独立単位だけ読める。
  #         パスは § 番号より安定し、実在を ③ で機械検証できる
  #       ✗ 他 SKILL.md 本文への §N 参照 — 参照先を読むには SKILL.md を丸ごとロードするしか
  #         なく、§ 番号はセクション増減で黙って振れる（ドリフトの温床）
  #       ✗ 裸のサブファイル名（dir なし）— 所在が辿れない。フルパス化で解消
  #     単なるルーティングポインタ（「テスト追加が目的なら /e2e-test-create を使う」）は
  #     §番号・ファイルパスを伴わないため非検出。
  #     rules → skills の参照も対象外 — rules は常時ロード・skills はフェーズロードなので
  #     「原則は rules・詳細は参照先」の二層化はむしろ標準形。
  C22=$({
    for f in .claude/skills/*/*.md; do
      [ -e "$f" ] || continue
      d=$(basename "$(dirname "$f")")

      # ① 他 SKILL.md 本文への §N 参照（`e2e-test-create` §9 型）
      grep -noE "e2e-[a-z-]+\`?[[:space:]]*§[0-9]+" "$f" 2>/dev/null |
        while IFS=: read -r ln m; do
          tgt=${m%%[\`/ ]*}
          [ "$tgt" != "$d" ] && echo "${f#.claude/skills/}:${ln}: ${m}"
        done

      # ② 裸のサブファイル名（dir 接頭辞がない dir 跨ぎ参照）。
      #    直前が `/` はフルパス参照（許容。実在は ③ が検証）なので除外する
      for sub in .claude/skills/*/*.md; do
        sb=$(basename "$sub")
        [ "$sb" = "SKILL.md" ] && continue
        [ "$(basename "$(dirname "$sub")")" = "$d" ] && continue
        grep -noE "(^|[^/[:alnum:]_-])${sb%.md}\.md" "$f" 2>/dev/null |
          while IFS=: read -r ln _; do echo "${f#.claude/skills/}:${ln}: ${sb}（裸参照 — フルパス化）"; done
      done

      # ③ フルパス参照のリンク切れ（フルパス許容の成立条件 = 実在の機械検証。dir 不問）
      grep -noE "e2e-[a-z-]+/[a-z0-9-]+\.md" "$f" 2>/dev/null |
        while IFS=: read -r ln m; do
          [ -e ".claude/skills/$m" ] || echo "${f#.claude/skills/}:${ln}: ${m}（リンク切れ）"
        done
    done
  #   dedup は完全重複行のみ（sort | uniq）。同一行に異なる違反（例: §N 参照とリンク切れの
  #   並記）が共存しても両方表示される（file:line キーの sort -u は片方を隠す）
  } 2>/dev/null | sort -t: -k1,1 -k2,2n | uniq || true)
  fail_print "Skill 間参照の違反（§N 跨ぎ・裸参照・リンク切れ）" "共有正本をサブファイル化しフルパス参照に置き換える（サブファイルへのフルパス参照は dir 跨ぎでも許容）" "$C22"

  # 23. SKILL.md 単体のサイズ（20,480B 超過で ❌）
  #     しきい値は W6（rules ファイル単体）と同一であることが要件 — rules ↔ skills の移送で
  #     判定が変わらない（置き場所によるしきい値回避を防ぐ）。値自体は 1 ロード単位の運用予算。
  #     rules に上限（21）を置くと、逃げ場が skills になる。片側だけ閉じると総量は変わらず
  #     移送されるだけなので、skills 側も同時に塞ぐ。
  #     ただし単位は「skills 総量」ではない — 新規 skill は新しい能力であり、フェーズ排他で
  #     同時にロードされないため総量に意味がない。フェーズ発火時に無条件でロードされるのは
  #     SKILL.md 単体なので、そこだけに上限を置く。
  #     サブファイルは対象外（意図的）。SKILL.md が膨らんだときの正しい逃がし方は
  #     「条件付きサブファイルへの抽出 + フルパス参照」であり、その出口を塞ぐと 22 違反の
  #     §N 参照か docs/（強制力ゼロ）に流れる。
  #     サイズは wc -c の実バイト（awk length() は実装×ロケールで文字数を返し、日本語で大幅に
  #     過小評価する — W6 も同じ理由で wc -c）
  C23=$(find .claude/skills -name 'SKILL.md' 2>/dev/null | sort | while read -r f; do
    b=$(wc -c < "$f" | tr -d ' ')
    [ "$b" -gt 20480 ] && printf "%s: %dB (%.1fKB) — 上限 20,480B 超過\n" "$f" "$b" "$(echo "$b" | awk '{print $1/1000}')"
  done 2>/dev/null || true)
  fail_print "SKILL.md サイズ超過" "条件付きサブファイル（「その状況のときだけ読む」）に抽出しフルパスで参照する — 他 SKILL.md への §N 参照化は 22 違反、docs/ への移動は強制力ゼロ" "$C23"

  # W6. Rules ファイルサイズ（20,480B 超過で警告）
  #     rules は常時ロードされるため肥大するとコンテキストを圧迫する。
  #     超過時は「コード例を Skills ポインタに変換」「重複記述を削除」等で削減する。
  #     しきい値は 23（SKILL.md）と同一が要件（理由は 23 参照 — 片側だけ変えない）。
  #     KB 表示は 10 進（÷1000）。閾値はバイト定義（20,480B）
  W6=$(find .claude/rules -name '*.md' 2>/dev/null | sort | while read -r f; do
    b=$(wc -c < "$f" | tr -d ' ')
    [ "$b" -gt 20480 ] && printf "%s: %dB (%.1fKB) — 上限 20,480B 超過\n" "$f" "$b" "$(echo "$b" | awk '{print $1/1000}')"
  done 2>/dev/null || true)
  warn_print "Rules ファイルサイズ超過" "コード例を Skills ポインタ化・重複記述を削除して削減する" "$W6"

  # W7. Rules の TypeScript/JavaScript コードブロック（「rules はコードを持たない」原則）
  #     ASCII 図（```のみ）は対象外。コード例（```typescript 等）は Skills に移し正本ポインタに留める
  W7=$(grep -rnE '^[[:space:]]*```(typescript|javascript|ts|js)' .claude/rules/ 2>/dev/null || true)
  warn_print "Rules の TS/JS コードブロック" "rules はコードを持たない — コード例は Skills に移し正本ポインタに留める" "$W7"

else
  echo "⚠️  .claude/rules が見つかりません — メタ層チェック（21〜23・W6・W7）をスキップしました（.claude/ をプロジェクトルートに配置してください）"
  WARN=1
fi

echo "── 警告（要目視・exit code に影響しない） ──"

# W1. Page Object の waitForTimeout
#     操作メソッド（void）末尾の固定待機は慣習として許容、verify メソッド（boolean 返却）内は禁止。
#     verify 内はチェック 19（AST）が ❌ で機械検出する。本警告は AST の既知の検出漏れ
#     （返り値注釈なしの推論依存・void ヘルパー間接呼び出し）の目視補完として残置
#     （判定基準: prohibited-patterns.md「verify 内の固定待機」）
W1=$(grep -rn "waitForTimeout" src/pages/ 2>/dev/null | grep -vE "$COMMENT_LINE_FILTER" || true)
warn_print "Page Object waitForTimeout" "verify メソッド内に無いか目視確認" "$W1"

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
