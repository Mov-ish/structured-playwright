<!--
CONTRIBUTING.md も併せて参照してください。
該当しない項目は削除して構いません（空のチェックボックスを残さない）。
-->

## 関連 Issue

<!-- 例: Closes #12 / Refs #12。Issue を先に立てる運用です -->

## 変更内容

<!-- 何を変えたか。ファイル単位ではなく「何が変わるか」で書いてください -->

## なぜ必要か

<!-- 実際に起きた問題があれば、該当箇所（ファイル・行）や再現手順を引用してください -->

## チェック

- [ ] `docs/` `for-claude-code/` を触った場合、**jp / en の両方**を同一コミットで直した
- [ ] 見出しの追加・削除・構成変更をした場合、両側の見出しレベル列が一致している
- [ ] `bash tests/check-lang-parity.test.sh` が通る
- [ ] `bash tests/check-verify-wait.test.sh` が通る（`scripts/` を触った場合は必須）
- [ ] 改行は LF（CRLF を混ぜていない）

## gate のチェックを変更した場合

<!-- 変更していなければこの節ごと削除してください -->

`gate.sh` 冒頭の ★ コメントに列挙された同期先を潰したか:

- [ ] `.claude/rules/prohibited-patterns.md` の gate 列と代替テキスト
- [ ] `.claude/skills/e2e-review/SKILL.md` の該当チェック項目
- [ ] `.claude/skills/e2e-bootstrap/SKILL.md` の雛形が新チェックに発火しない
- [ ] 文言が矛盾する箇所（`architecture.md` 等）
- [ ] `for-claude-code/` と `for-claude-code-en/` の両方に入れた

<!-- メタ層チェック（21〜23・W6・W7）の変更なら、同期先は e2e-review のみです -->

## rules を追加・拡張した場合

<!-- 追加していなければこの節ごと削除してください -->

rules は毎ターン読み込まれてコンテキストを消費します（📝 Docs update テンプレートの3問）:

- **実績**: その失敗・混乱は実際に起きたか。実例（PR・flaky・事故）を1つ。予防目的なら「予防」と明記
- **対象**: AI の生成・作業挙動を縛るものか（人間向けの運用作法なら `docs/` 行き）
- **頻度**: 毎ターン必要か（特定フェーズなら skills、手順の詳細なら原則＋ポインタの二層化）

`.claude/rules-baseline` を引き上げた場合は、**引き上げの必然性**をここに書いてください。
