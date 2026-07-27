# Structured Playwright for Sustainability

[English](#english) | [日本語](#japanese)

---

<a id="english"></a>
## English

Maintainable and scalable Playwright test design patterns—and the associated skills and rules to implement them—focused on maintainability, extensibility, and sustainability.

### Core Principles

- **Reviewability**: Easy to understand and review
- **Maintainability**: Resilient to changes  
- **Sustainability**: Transferable and long-lasting

### Architecture Overview

This architecture separates concerns across 4 distinct layers:

1. **Layer 1: Page Objects** - UI element definitions and basic operations
2. **Layer 2: Actions** - Business logic and multi-page flows
3. **Layer 3: Tests** - Test scenarios and assertions (AAA pattern)
4. **Layer 4: Config/Env** - Environment configuration and settings


### Getting Started (Claude Code)

The [`for-claude-code/`](./for-claude-code/) directory is a drop-in kit for Claude Code: copy `.claude/`, `scripts/`, and `CLAUDE.md` into your project, and generate maintainable 4-layer Playwright tests from test procedures, checklists, or user stories — guarded by a mechanical gate (`npm run gate`). See [for-claude-code/README.md](./for-claude-code/README.md) (setup guide currently in Japanese: [docs/jp/claude-code-guide.md](./docs/jp/claude-code-guide.md)).


### Author

**Ray-ish** ([@Mov-ish](https://github.com/Mov-ish))

Developed through years of experience maintaining E2E test frameworks in the education technology sector.

### License

MIT — free to use, modify, and distribute. When redistributing, please keep the copyright notice (`Copyright (c) 2026 Ray-ish`) as required by the license.

If this template helps your project, a mention in your README or blog — or a star — is always appreciated (welcome, not required).

---

<a id="japanese"></a>
## 日本語

持続可能性のための構造化Playwright設計

保守性・拡張性・継続性に焦点を当てた、メンテナブルでスケーラブルなPlaywrightテスト設計パターンと、それを実現するためのSkills/rules群です。

### コアコンセプト

- **レビュー性**: 理解しやすく、レビューしやすい
- **保守性**: 変更に強い
- **継続性**: 引き継ぎ可能で長期運用できる

### アーキテクチャ概要

責任を4つの層に明確に分離：

1. **Layer 1: Page Objects** - UI要素定義・基本操作
2. **Layer 2: Actions** - ビジネスロジック・複数画面フロー  
3. **Layer 3: Tests** - テストシナリオ・検証（AAAパターン）
4. **Layer 4: Config/Env** - 環境設定・環境変数


### はじめかた（Claude Code）

[`for-claude-code/`](./for-claude-code/) は Claude Code 用のドロップイン キットです。`.claude/` `scripts/` `CLAUDE.md` をプロジェクトへコピーするだけで、テスト手順書・チェックリスト・ユーザーストーリーから保守継続性の高い 4 層 Playwright テストを生成・維持できます（機械ゲート `npm run gate` 付き）。入口は [for-claude-code/README.md](./for-claude-code/README.md)、詳細は [docs/jp/claude-code-guide.md](./docs/jp/claude-code-guide.md)。


### 著者について

**Ray-ish**（[@Mov-ish](https://github.com/Mov-ish)）

教育テクノロジー分野でのE2Eテスト基盤構築・運用の経験から、
長期的に維持可能なテスト設計の重要性を実感し体系化。

### ライセンス

MIT ライセンスです。利用・改変・再配布は自由ですが、再配布の際はライセンス条件に従い著作権表示（`Copyright (c) 2026 Ray-ish`）を保持してください。

このテンプレートが役に立ったら、README やブログでの言及・スターを歓迎します（義務ではなく、歓迎です）。