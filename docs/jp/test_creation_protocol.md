# TEST_CREATION_PROTOCOL.md
## Doc-first Test Authoring（テスト作成フェーズの入口）

この文書は **「既存のPlaywright環境にE2Eテストを追加する」** ための入口です。  
環境構築が目的なら **BOOTSTRAP.md** を参照してください。

---

## 最上位ルール
- **CLAUDE.md** が最上位（矛盾があれば CLAUDE.md を優先）
- 4層の責務は **E2ETest_Framework.md** を基準にする

---

## Locator の最終判断（必須）
Locator に迷ったら、必ず以下の順で参照し、判断を止める：

1. **Concept**（思想・優先順位）  
2. **Universal**（普遍原則）  
3. **Product-Specific（PRODUCT_A）**（PRODUCT_Aの製品固有の制約）

参照先：`./LOCATOR/`

---

## 作業の基本原則（AI向け）
- “既存構造を壊さずに追加する” が最優先（勝手に大改修しない）
- 既存の Actions / PageObject / ユーティリティをまず探索して再利用する
- `.first()` と XPath は原則禁止（やむを得ない場合は理由と TODO を明記）
- 機密情報は `.env` / CI 環境変数から取得する

---

## 4層アーキテクチャの責務（簡約）
- **Test（Scenario）**：意図・期待結果を書く。Locatorを直接書かない
- **Actions（手順）**：ユーザ行動のまとまり（再利用単位）
- **PageObject**：画面要素・操作のカプセル化（Locatorはここ）
- **Data / Config**：テストデータ・環境差分・認証情報（envなど）

※詳細は **E2ETest_Framework.md** を参照。

---

## AIの作業手順（SOP）

### 1) ストーリーをテスト単位に分解
入力のユーザーストーリー（またはGiven/When/Then）を、テストケースへ分割する。

### 2) 既存資産の探索（必須）
- 既存の `Actions` を探す
- 既存の `PageObject` を探す
- 類似の `Test` を探す

> 既存があるのに新規作成するのは **コスト増** なので、まず再利用。

### 3) 追加ファイルを決める（最小追加）
- 既存で足りるなら Test だけ追加
- 足りない部分のみ Actions / PageObject を追加 or 拡張
- Locator は `./LOCATOR` のルールに従う

### 4) 命名と配置
- 仕様に沿ったファイル名・ディレクトリへ配置
- テスト名は「何を保証するか」が分かる名称

### 5) 仕上げ（実行・安定化）
- flake を避ける（待機は Locator と expect の自動待機を優先）
- 失敗時に読みやすい expect を書く
- 必要なら trace / screenshot を付与（プロジェクト方針に従う）

---

## 参考（実装例）
- 即効レシピ：`CLAUDE_Selectors.md`
- 詰まったら：`CLAUDE_FAQ.md`

---

## 指示テンプレ（そのまま使える）

> TEST_CREATION_PROTOCOL.md に従って、以下のユーザーストーリーでE2Eテストを追加して。  
> 既存のActions/PageObjectをまず探して再利用し、足りない部分だけ追加して。

- 対象機能：
- ユーザーストーリー：
  1.
  2.
  3.
- 制約：
  - 追加のみ／既存修正OK
  - 新規Actions作成OK／既存Actions優先
  - PRODUCT_A固有の制約（あれば）
