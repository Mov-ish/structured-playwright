# BOOTSTRAP.md
## Doc-first Bootstrap（環境構築フェーズの入口）

この文書は **「Playwright E2E の実行環境を作る」** ための入口です。  
テスト追加（既存環境へのテスト実装）が目的の場合は、**TEST_CREATION_PROTOCOL.md** を参照してください。

---

## 目的（Definition of Done）
次が成立していること：

- `npm test` が実行できる（少なくとも smoke が 1 本通る）
- Playwright のインストールとブラウザ依存が揃っている
- 4層アーキテクチャの最小ディレクトリが用意されている
- 認証情報・機密情報は `.env`（またはCI環境変数）で管理される

---

## 参照する上位文書
- **CLAUDE.md**（最上位ルール。ClaudeCode は必ず最初に読む）
- **E2ETest_Framework.md**（4層アーキテクチャの理想構成・責務）

---

## 4層アーキテクチャの最小骨格（必須）

環境構築時点で、以下の最小ディレクトリ構成を用意すること。
これは **4層アーキテクチャの型を固定するための最低要件**である。

src/
├─ tests/ # シナリオ（意図と期待結果のみを書く）
├─ actions/ # ユーザ操作の流れ（Actions）
├─ pages/ # 画面要素と操作（PageObject / Locatorはここ）
└─ config/ # 環境差分・設定・テストデータ

## 各層の責務（要約）
- **tests**: テストの意図・期待結果を記述する。ロジックやLocatorを書かない
- **actions**: 複数操作をまとめた再利用可能な手順
- **pages**: 画面構造と操作をカプセル化する（Locatorはこの層に限定）
- **config**: 環境差分・認証情報（`.env` 経由）・固定データ

詳細な責務定義・禁止事項・変更影響の考え方は  
`e2e_test_framework.md` を正とする。

---

## 手順（AI/人間 共通）

### 1) 依存をインストール
```bash
npm ci
```
（初回や lock が無い場合は `npm install` を使う）

### 2) Playwright のブラウザをインストール
```bash
npx playwright install
```
CI向けに依存も揃える場合：
```bash
npx playwright install --with-deps
```

### 3) 設定ファイルを整備
最低限、次の存在を確認／生成する：

- `playwright.config.ts`
- `tsconfig.json`
- `package.json`（scripts に `test` を含める）
- `.env.example`（秘密情報を **書かない**。キーだけ）

> 4層アーキテクチャのディレクトリ指針は **E2ETest_Framework.md** を正とする。

### 4) smoke test を 1 本用意
目的：環境が正しく動くことの確認。

例：`src/tests/smoke/smoke.spec.ts`

- 1ページアクセス
- 1つの確実な要素検証
- 必要ならログイン（env から）

### 5) 実行確認
```bash
npm test
```

---

## 禁止事項（重要）
- 認証情報・パスワード・トークンをリポジトリへコミットしない
- `.env` をコミットしない（`.env.example` はOK）
- テスト作成フェーズなのに、環境設定を作り直さない（その場合は TEST_CREATION_PROTOCOL.md）

---

## 次に進む
環境が動いたら、テスト追加はこの文書へ：

- **TEST_CREATION_PROTOCOL.md**
