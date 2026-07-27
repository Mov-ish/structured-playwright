#!/usr/bin/env bash
# =============================================================================
# Stop フック — ターン終了時に gate を実行する
#
# 目的: AI が gate 違反コードを生成したまま人間に返すのを防ぐ。違反があれば
#       exit 2 で停止をブロックし、stderr のフィードバックで Claude に自己修正させる。
#
# WHY Stop（PostToolUse ではなく）:
#   - PostToolUse は毎 Edit 発火 = 生成途中の中間状態で tsc が偽 fail する
#   - Stop はターン終了 = コードが整合した状態で一度だけ走る（tsc が意味を持つ）
#
# WHY exit 2:
#   Stop フックの exit 2 は「停止をブロックして次ターンを強制」+ stderr を Claude に
#   差し戻す（= 自己修正）。無限ループは stop_hook_active フラグ + CC 側の上限で防ぐ。
# =============================================================================
set -u

# --- 無限ループ防止: 既に Stop フックが差し戻して再開したターンなら即 0 ---------
INPUT=$(cat 2>/dev/null || true)
if printf '%s' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

# --- プロジェクトルートへ -------------------------------------------------------
# CLAUDE_PROJECT_DIR は .claude/ が存在するディレクトリを指す。
# git rev-parse --show-toplevel ではなく CLAUDE_PROJECT_DIR を使うことで、
# .claude/ がリポジトリルート以外に置かれた構成でも正しく動作する。
ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$ROOT" || exit 0

# --- このターンで触れたファイルを git 差分から判定 --------------------------------
# 3 系統を合算する:
#   1. git diff HEAD             … 作業ツリーの未コミット変更（staged + unstaged）
#   2. git ls-files --others     … 新規未追跡ファイル
#   3. git diff <base>..HEAD     … コミット済みのブランチ変更
# WHY 3 が要る: 違反を git commit してから Stop すると作業ツリーがクリーンになり、
#   1+2 だけでは CHANGED が空になって素通りする。
# 変更が無いターン（質問への回答だけ等）はここで抜けるので gate コストを払わない。
BASE=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || true)
CHANGED=$( {
  git diff --name-only HEAD 2>/dev/null
  git ls-files --others --exclude-standard 2>/dev/null
  [ -n "$BASE" ] && git diff --name-only "$BASE" HEAD 2>/dev/null
} )
[ -z "$CHANGED" ] && exit 0

# src/ に加え .claude/ と scripts/ の変更でも gate を回す（docs のみの編集ではスキップ）。
# WHY: gate のメタ層チェック（Rules 総量ラチェット・Skill 間参照・SKILL.md サイズ）は
#   src/ ではなく .claude/ を読む。「src/ に変更があるときだけ」を条件にすると、rules を
#   増やす変更 = まさにラチェットが効くべきケースで本フックが素通りする。
# scripts/ を含める理由: gate.sh が呼ぶ付属スクリプト（check-verify-wait.js = AST 判定本体）
#   だけを変更したターンで素通りさせない（gate.sh 単体に絞ると穴が残る — broad に倒す）。
#   副作用（stop-gate.sh 自身の編集でも gate が回る）は、フックを触った直後の動作確認として妥当。
printf '%s\n' "$CHANGED" | grep -qE "^(src/|\.claude/|scripts/)" || exit 0

# 依存未インストールだと tsc が偽 fail する → スキップ（偽 block 防止）
[ -d "node_modules" ] || exit 0

RESULT=$(bash scripts/gate.sh 2>&1)
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  {
    echo "🚫 gate 違反が残っています。完了する前に修正してください。"
    echo "$RESULT"
    echo "（WHY・判定基準: .claude/rules/prohibited-patterns.md）"
  } >&2
  exit 2
fi
exit 0
