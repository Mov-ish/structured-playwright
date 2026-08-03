#!/usr/bin/env bash
# =============================================================================
# jp/en パリティチェック（翻訳ペアの構造ドリフト検出）
#
# 並列ディレクトリ方式（for-claude-code / for-claude-code-en、docs/jp / docs/en）は
# 既存パス参照を壊さない代わりに、jp 側だけ更新されて en 側が置き去りになる
# ドリフトを構造的に許してしまう。このテストはその乖離を機械検出する。
#
# 検証する 2 ケース:
#   1. ファイル構成の一致 — 各ペアの相対パス一覧が完全一致する
#      （jp に足して en に足し忘れた／片側だけ削除した、を検出）
#   2. Markdown 見出し構造の一致 — 各 .md ペアの見出しレベル列が完全一致する
#      （見出しテキストは翻訳で変わるため比較しない。コードフェンス内の # は除外）
#
# 検証しないこと: 訳文の内容・鮮度。見出し構造が同じでも本文が古い可能性は残る
# （本文レベルの同期は PR レビューの責務。ここは「構造が割れたら即検出」の網）
#
# 実行: リポジトリルートで bash tests/check-lang-parity.test.sh
# =============================================================================
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

FAILED=0
fail() { echo "❌ $1"; FAILED=1; }
pass() { echo "✅ $1"; }

# 翻訳ペア（jp:en）。ペアを増やす場合はここに追記する
PAIRS=(
  "docs/jp:docs/en"
  "for-claude-code:for-claude-code-en"
)

# --- ケース 1: ファイル構成の一致 -----------------------------------------------
for pair in "${PAIRS[@]}"; do
  jp_dir="${pair%%:*}"
  en_dir="${pair##*:}"
  if diff <(cd "$jp_dir" && find . -type f | sort) \
          <(cd "$en_dir" && find . -type f | sort); then
    pass "ケース1: ${jp_dir} と ${en_dir} のファイル構成が一致"
  else
    fail "ケース1: ${jp_dir} と ${en_dir} のファイル構成が不一致（上記 diff。< が ${jp_dir} / > が ${en_dir}）"
  fi
done

# --- ケース 2: Markdown 見出し構造の一致 -----------------------------------------
# 見出しレベル列（例: 1,2,3,3,2,...）を抽出して比較する。
# コードフェンス（``` / ~~~）内の # 行はコメント等でありうるため除外する。
# 既知の限界: フェンスは行頭のみ認識（インデントされたフェンスは対象外）。
# 両側に同じ抽出を適用するため、抽出の癖は比較の公平性を損なわない
heading_levels() {
  awk 'BEGIN{fence=0}
       /^(```|~~~)/{fence=!fence; next}
       !fence && /^#{1,6} /{match($0, /^#+/); print RLENGTH}' "$1"
}

for pair in "${PAIRS[@]}"; do
  jp_dir="${pair%%:*}"
  en_dir="${pair##*:}"
  pair_ok=1
  while IFS= read -r rel; do
    # ケース 1 で構成不一致が出ている場合、en 側欠落はここでは重複報告しない
    [ -f "$en_dir/$rel" ] || continue
    if ! diff <(heading_levels "$jp_dir/$rel") <(heading_levels "$en_dir/$rel") > /dev/null; then
      fail "ケース2: 見出し構造が不一致 — ${jp_dir}/${rel} vs ${en_dir}/${rel}"
      diff <(heading_levels "$jp_dir/$rel") <(heading_levels "$en_dir/$rel") | head -20 || true
      pair_ok=0
    fi
  done < <(cd "$jp_dir" && find . -type f -name '*.md' | sed 's|^\./||' | sort)
  if [ "$pair_ok" -eq 1 ]; then
    pass "ケース2: ${jp_dir} と ${en_dir} の全 .md で見出し構造が一致"
  fi
done

echo "━━ 結果 ━━"
if [ "$FAILED" -eq 1 ]; then
  echo "❌ check-lang-parity.test FAIL"
  exit 1
fi
echo "✅ check-lang-parity.test PASS"
