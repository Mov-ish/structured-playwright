---
name: 📝 Docs update
about: README・docs・CLAUDE.md・rules・skills の更新
title: '[DOCS] '
labels: documentation
assignees: ''
---

## 対象
どのドキュメント / ルール / Skill か、ファイルパスで示してください。
（例: `docs/jp/E2ETest_Framework.md` / `for-claude-code/.claude/rules/locator-principles.md`）

## 変更内容
何を追加・修正するか記述してください。

## 背景・目的
なぜ必要か記述してください。既存の記述に問題がある場合は、該当箇所（ファイル・行）を引用してください。

## jp / en の対応
`docs/` と `for-claude-code/` は jp / en が対になっており、CI がファイル構成と見出し構造の一致を検査します（`tests/check-lang-parity.test.sh`）。片側だけで済むか、両側必要かを記述してください。

## rules / skills を変更する場合
rules は常時ロードされ、毎ターンのコンテキストを消費します。以下に答えられない要求は rules に置かないでください。

- **Q1 実績**: その失敗・混乱は実際に起きましたか？ 実例（PR・flaky・事故）を1つ引用してください。実例がなく予防目的なら「予防」と明記してください
- **Q2 対象**: AI の生成・作業挙動を縛るものですか？ 人間向けの運用作法・参考情報であれば `docs/` 行きです
- **Q3 頻度**: 毎ターン必要ですか？ 常時なら rules、特定フェーズなら skills、手順の詳細なら rules は原則＋ポインタの二層化、一回きりならこの Issue の記録のみに留めます

## その他
参考資料や関連 Issue / PR があれば記述してください。
