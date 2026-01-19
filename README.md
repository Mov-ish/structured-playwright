# Structured Playwright for Sustainability

[English](#english) | [日本語](#japanese)

---

<a id="english"></a>
## English

A maintainable and scalable Playwright test architecture focused on sustainability through clear separation of concerns across 4 distinct layers.

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

### Documentation

Detailed documentation (in Japanese) is available on Zenn:
[Coming in February 2025]

### Author

Developed through years of experience maintaining E2E test frameworks in the education technology sector.

### License

MIT

---

<a id="japanese"></a>
## 日本語

持続可能性のための構造化Playwright設計

保守性・拡張性・継続性に焦点を当てた、メンテナブルでスケーラブルなPlaywrightテスト設計パターンです。

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

### ドキュメント

詳細なドキュメントはZennで公開予定：
[2025年2月公開予定]

### 著者について

教育テクノロジー分野でのE2Eテスト基盤構築・運用の経験から、
長期的に維持可能なテスト設計の重要性を実感し体系化。

### ライセンス

MIT