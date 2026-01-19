# Locator Strategy
### ― 4層アーキテクチャ第3層：Locator 設計思想 / 普遍ルール / 固有ルール ―

本書は、Playwright E2E における **Locator 戦略の全体系**を収録する。
文書は以下の 3 つの観点で構成される：

1. **Concept（設計思想）**
2. **Universal（普遍ルール）**
3. **Product-Specific（固有ルール）**

---

# Part 1: Concept（設計思想）

## 0. Concept の役割

Locator は「第1層（Playwright 技術）」の機能でありながら、
その使い方のルールは **第3層（Concept / Principles）** が支配する。

なぜなら Locator は：

- テストの安定性
- コードの保守性
- 自動生成（AI）の品質
- チームの理解負荷
- UI 変更への耐性

すべてに影響する"中核構造"だからである。

Concept 層は **「どう書くか」ではなく「なぜそう書くのか」** を統一する層であり、
4層アーキテクチャの思想的中心となる。

---

## 1. Locator とは何か（概念レベルの定義）

Locator を単なる「要素の取得」と捉えると、
設計思想の深みや Playwright の強みを理解し損なう。

Concept 層での定義はこうなる：

```
Locator =
   "条件セットを持つ探査機（probe）"
 × "局所宇宙（Local Universe）で探索する"
 × "未来値として評価される"
```

### 1.1 Locator は「未来値（Future）」である

Locator は今 DOM に要素が存在しなくてもよい。

- 遅延評価（Lazy Evaluation）
- 自動待機（Auto-Wait）
- 自動リトライ（Retry）

これらを内包する「未来に成立する条件式」であり、
動的 UI に強い根本理由がここにある。

### 1.2 Locator は「意味空間」で操作されるべき

Playwright が推奨するセマンティック Locator は、
構造ではなく **意味（Semantics）** に基づいて要素を探索する。

- `role` は UI の役割
- `name` は UI 上のラベル
- `label` は入力欄の意味
- `text` は人間が理解する情報

UI を構造（div の入れ子）ではなく意味によって捉えることが、
テストの安定性と可読性につながる。

### 1.3 Locator は「宇宙（Universe）」を持つ

ページ全体は大きすぎる。

Playwright の哲学に近いのは **「局所宇宙（Local Universe）で探索せよ」** の思想。

Local Universe の例：

- モーダル
- 行（row）
- カード
- セクション
- タブパネル

探索範囲を限定すると：

- 一意性が向上
- DOM の変更に強い
- テストの意図が明確
- 実行速度も向上

Locator 設計における最重要概念のひとつ。

---

## 2. Concept 層の目的：思想を統一する

Concept 層は「実装テクニック」ではなく、
**Locator 設計の哲学・優先順位・禁止事項** を定義する。

これにより：

- PageObject（第2層）が迷わなくなる
- テストコード（第4層）が Locator を書かなくなる
- AI（Codex / Claude）が誤った Locator を生成しない
- チーム全体の Locator 品質が統一される

Concept 層は "Locator の憲法" の役割を持つ。

---

## 3. Locator における普遍原則（Universal Concept）

普遍ルールは次の 4 原則に圧縮される：

### 3.1 意味を捉える（Semantic Priority）

優先順位トップは：

```
text-is / role / label / name
```

理由：

- UI の意味は変更されにくい
- テストコードの意図が読み取りやすい
- AI の自動生成と相性が良い

### 3.2 宇宙を限定する（Local Universe）

例：

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")');
```

意味の単位で括った範囲で探索することで：

- 一意性が飛躍的に上がる
- DOM 変更に強い
- 目的が明確になる

### 3.3 偶然を排除する（Deterministic Behavior）

典型例：`.first()` の乱用

```ts
page.locator('button').first().click();
```

`.first()` は UI の偶然の順番を固定化するだけであり、
**テストは「意図の固定」であって「偶然の固定」ではない。**

### 3.4 構造に依存しない（Anti-XPath / Anti-Structural）

- CSS-only
- XPath
- div > div > span のような構造追跡

これらは DOM 変更への耐性が低すぎる。

Concept 層では **構造依存そのものを思想として否定**する。

---

## 4. 固有ルールが Concept 層に統合される理由

[意味層が薄い](../CLAUDE_FAQ.md#thin-semantic-ui) UI は以下の構造的特徴を持つ：

- 意味層が薄い
- 構造層が揺れやすい
- 同じ文言 UI が画面内に多数存在
- アイコンは data-icon が唯一の anchor
- モーダルは class で識別できない

これらにより、普遍原則をそのまま適用するだけでは安定性が足りない。

Concept 層では固有ルールを **「例外」ではなく「構造的必然」** として扱う。

### 4.1 near() の哲学的位置づけ

本来 near() は補助的だが、
意味情報が不足する UI では **意味の代替物** として機能する。

Concept 層では次のように規定する：

```
意味情報が不足する UI では、近接関係を意味として扱う。
```

### 4.2 role="dialog" の哲学的位置づけ

モーダルと背景の UI が混在しやすいプロダクトのため、
唯一のセマンティック anchor は role 属性。

```
モーダルの Universe は role="dialog" を基点に定義する。
```

### 4.3 svg[data-icon] の哲学的位置づけ

UI ライブラリが icon に安定した data-icon を付与するため、
内部仕様だが **意味に相当する安定 anchor** を持つ。

```
アイコンの識別は data-icon が本質 anchor。
```

### 4.4 row（行）を Universe とする理由

表（table）は意味層の薄い UI における数少ない「意味単位」。

```
行は UI の意味単位として Universe に採用する。
```

---

## 5. Locator 優先順位体系（Locator Priority Pyramid）

Concept 層では、Locator の選択を **5 段階の優先順位ピラミッド**として体系化する。

```
       ┌──────────────────────────────┐
       │   1. 意味ベース（Semantic）        │
       │   text-is / role / label / name │
       ├──────────────────────────────┤
       │   2. 局所宇宙（Local Universe）     │
       │   dialog / row / card / section │
       ├──────────────────────────────┤
       │   3. 近接（near）による意味補完     │
       ├──────────────────────────────┤
       │   4. data-icon（UI 構造補完）       │
       ├──────────────────────────────┤
       │   5. 最終手段：構造依存（コメント必須） │
       └──────────────────────────────┘
```

**普遍原則 × 固有事情** を統合した公式ルールであり、
AI も人間も必ずこの優先度に従う。

### 5.1 レベル 1：意味ベース（Semantic First）

例：

```ts
page.getByRole('button', { name: '保存' });
page.getByLabel('メールアドレス');
```

理由：

- UI の意味は最も変更されにくい
- 人間にとって意図が明確
- AI も正しく目的を把握できる

### 5.2 レベル 2：Local Universe（意味単位で閉じ込める）

例：

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")');
```

メリット：

- 一意性が飛躍的に向上
- 背景との混在を防止
- DOM 変更に強い

### 5.3 レベル 3：near()（意味情報の不足を補う）

例：

```ts
page.locator('input[type="checkbox"]:near(:text("利用規約に同意"))');
```

意味層が薄い UI では near() が **第 3 の正解** になる。

### 5.4 レベル 4：data-icon（UI ライブラリの内部仕様を利用）

例：

```ts
row.locator('button:has(svg[data-icon="edit"])');
```

意味層の薄い UI では icon の semantic 情報が弱いため、
data-icon が **実質的な意味 anchor** として振る舞う。

### 5.5 レベル 5：構造（最終手段）

例：

```ts
page.locator('div > div:nth-child(2) > button');
```

使用条件：

- 上位 4 つがすべて不可能
- かつ コメント必須
- 後で置き換える前提で一時的に使用する

---

## 6. AI エージェントが守る Locator 思想（Codex / ChatGPT / Claude 用）

Concept 層は **AI の出力品質を統制するルールセット**でもある。

AI が必ず守るべき思想：

### 6.1 `.first()` を提案しない

`.first()` は UI の"偶然の順番"を固定化するだけであり、
テストの本質である「意図の再現」を妨げる。

→ `.first()` を使いたくなったら **一意性の欠如** を疑う。

### 6.2 XPath を一切提案しない

理由：

- 構造依存で壊れやすい
- Playwright の思想と反する
- 意味層の薄い DOM と相性最悪
- AI が誤生成しやすい

→ Concept 層では "構造依存の否定" が必須。

### 6.3 Locator の優先順位ピラミッドに従う

AI が Locator を生成する際は：

1. **意味ベース**
2. **局所宇宙**
3. **near()**
4. **data-icon**
5. **構造依存（最終手段）**

を逐次チェックしながら生成する。

### 6.4 Locator に「理由」を付与する

良い AI 出力は常に理由を述べる：

例：

> "この UI は role が無く文言が重複するため、row を Universe とし、中の data-icon を anchor にしています。"

理由を語れる AI は再現性が高く、誤爆しない。

---

## 7. 4 層アーキテクチャとの接続（Concept の位置づけ）

Concept 層は 4 層アーキテクチャにおいて **思想を規定する中心層** である。

```
┌──────────────────────────────┐
│  第4層：Test（Scenario）     │ ← Locator を書かない
├──────────────────────────────┤
│  第3層：Concept（Principles）│ ← Locator の思想・優先度
├──────────────────────────────┤
│  第2層：PageObject / Actions  │ ← Locator を実装する層
├──────────────────────────────┤
│  第1層：Playwright API        │ ← 技術の基盤
└──────────────────────────────┘
```

テストの目的は **UI を操作することではなく、意図を表現すること**。
Locator は POM（第2層）に閉じ込め、
Test（第4層）からは排除する。

---

## 8. Concept による「思想 → 実装」変換モデル

Concept はコードそのものではなく、
**実装を導く思考モデル**である。

### 8.1 「保存ボタンを押す」という要求

Concept に従う：

1. 意味 → text-is
2. Universe → dialog
3. 一意性 → OK
4. 近接補完 → 不要

→ 実装例：

```ts
modal.locator('button:text-is("保存")');
```

### 8.2 「チェックボックスをチェックしたい」

1. 意味 → 無い
2. Universe → 無い
3. 近接 → Yes
4. icon → No

→ 実装：

```ts
page.locator('input[type="checkbox"]:near(:text("プライバシーポリシー"))');
```

### 8.3 「編集アイコンを押したい」

1. 意味 → 無い
2. Universe → row
3. near → 不要
4. icon → Yes

→ 実装：

```ts
row.locator('button:has(svg[data-icon="edit"])');
```

---

## 9. Concept のまとめ（最上位原理）

Concept 層の思想は次の 4 点で集約される：

```
1. 意味を最優先で捉える
2. UI を小宇宙（Universe）に分解する
3. 偶然ではなく意図で要素を選択する
4. 構造依存を排除し、揺れに強い Locator を設計する
```

これらが **Locator 設計思想の完成形**であり、
4 層アーキテクチャ全体の品質基盤となる。

---

# Part 2: Universal（普遍ルール）

## 0. 本書の目的

Playwright による E2E テストの成否は、Locator の設計品質に依存する。
Locator はテスト全体の保守性・実行安定性・AI 自動生成との相性を決定する中核要素である。

本書は「どのプロダクトでも通用する」普遍的な Locator 設計原則を体系化する。

---

## 1. Locator の根本理解：未来の UI を扱う条件式

Playwright の Locator はただの "要素の取得" ではなく、
「未来に出現する UI に対して成立する条件セット」として振る舞う。

### 1.1 遅延評価（Lazy Evaluation）

Locator は生成時に DOM を探索せず、操作実行時に探索して条件を満たすまで待機する。

### 1.2 自動待機（Auto-Wait）

クリックや入力などの操作時に、可視化・有効化・安定化まで自動で待つ。

### 1.3 自動リトライ（Retry）

UI が不安定でも Playwright が内部で探索を繰り返すため、E2E が壊れにくい。

---

## 2. Locator 設計思想：構造ではなく"意味"を捉える

HTML の構造は変化するが、UI の意味（role, name, label, text）は変化しにくい。

Playwright の推奨戦略は DOM を辿るのではなく、意味を基準に Locator を設計することである。

---

## 3. 一意性（Uniqueness）の原則

Locator の品質は「一意であるかどうか」で決まる。
曖昧な Locator は UI 変更の影響を最も受けやすく、E2E 崩壊の主要因となる。

### 3.1 一意性が崩れる典型例（NG）

```
input[type="checkbox"]
button
div.card
```

これらは "意味がない" ため、複数一致しやすく、DOM の構造変化にも弱い。

### 3.2 一意性を確保した例（OK）

```
button:text-is("保存")
input[name="email"]
role=button with name="削除"
```

UI の "意味" を基準にすることで驚くほど壊れにくくなる。

---

## 4. テキスト一致：text-is と has-text の正しい使い分け

Playwright Locator の強力な機能のひとつが「テキスト一致」だが、
誤用するともっとも壊れやすい地雷になる。

### 4.1 text-is（完全一致） ― 最優先で使うべき

```
button:text-is("保存")
```

- 意図が明確
- 誤爆が極めて少ない
- "意味" を最も正しく取得できる

基本方針：**text-is を最優先する。**

### 4.2 has-text（部分一致） ― 使い方を誤ると危険

```
button:has-text("保存")
```

次のような UI 全部が一致し得る：

- 「保存する」
- 「下書きを保存」
- 「保存済みです」

部分一致は「曖昧性」を増幅するため、使用判断は慎重にする。

---

## 5. 親コンテナ anchoring（Local Universe の概念）

Locator は「局所宇宙（Local Universe）」で使うと安定する。

例：モーダル内だけを探索する

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")').click();
```

### 5.1 なぜ Local Universe が重要なのか？

- DOM 全体を探索すると一致候補が増える
- UI の揺れに強くなる
- パフォーマンスが向上
- テストの意図が明確になる

### 5.2 Local Universe の代表例

- モーダル
- カード
- テーブル行
- タブパネル
- 設定セクション

UI を「宇宙」として区切ることで、一意性と安定性が同時に高まる。

---

## 6. `.first()` は最終手段である

`.first()` は一見便利だが、E2E テストの安定性を大きく損なう "危険な道具" である。

### 6.1 `.first()` が危険な理由

**(1) 並び順依存になる**
UI 変更・A/B テスト・並べ替えなど、
順番が変わる要因は多い。順序依存の Locator は壊れやすい。

**(2) 意図が不明確になる**
```
page.locator('button').first().click();
```
「なぜ最初のボタンなのか」「何を意図しているのか」がテストから消える。

**(3) 偶然を固定化してしまう**
E2E テストは "意図の再現" を目的とする。
`.first()` はその意図を曖昧にしてしまう。

### 6.2 `.first()` を使っても良い状況（非常に限定される）

- UI の仕様上、一意の属性が存在しない
- デザイン上、並び順が固定であることが保証されている
- 「最初の要素」という概念が仕様として存在する（例：新着が常に先頭）

それでも以下を**必ず記述すること**：

```ts
// TODO: 一意の識別子が導入されたら置き換える
await page.locator('...').first().click();
```

---

## 7. 動的値は PageObject 層で扱う

Locator に動的データ（例：ユーザー名、コース名）を直接埋め込むと、
セレクタ定義が"変数の墓場"となり保守不能になる。

### 7.1 悪い例（NG）

```ts
export const SELECTORS = {
  USER_ROW: (name) => `tr:has-text("${name}")`,
};
```

- セレクタが動的になる
- 他の静的セレクタと混ざり混乱する
- テストの意図が読めない

### 7.2 良い例（OK）

```ts
// constants.ts には静的セレクタのみ
export const SELECTORS = {
  USER_ROW: 'tr',
};

// PageObject 側で動的値を補完
async clickUser(name: string) {
  await this.page.locator(`tr:has-text("${name}")`).click();
}
```

責務分離により：

- セレクタの "意味空間" が整理される
- PageObject が "操作・条件・動的値" を管理できる
- 変更時の影響範囲が明確になる

---

## 8. セマンティック Locator（getByRole 等）を優先する思想

可能な限り以下を使う：

```
getByRole()
getByLabel()
getByPlaceholder()
getByText()
```

### 8.1 セマンティック Locator のメリット

- 意味に基づくため、UI が多少変わっても壊れない
- テストコードが読みやすい
- Accessibility の設計にも合致
- AI が意図を正しく理解し、自然言語から生成しやすい

### 8.2 ただし「HTML が未整備な現場」では使えない場合がある

例：role が設定されていない、label が不正など。

その場合でも **"使えない理由" が分かっていればよし**。
セマンティック Locator は常に優先順位のトップに置く。

### 8.3 getByRole が最強な理由

**(1) UI の意味構造を直接表現できる**
```ts
page.getByRole('button', { name: '保存' });
```

これは CSS や XPath では表現しにくい
**"UI の役割 + ユーザーが見ているラベル"** を同時に表現している。

**(2) DOM 変更に非常に強い**
構造が多少変化しても、ボタンはボタンであり、名前も変わりにくい。

**(3) アクセシビリティ設計と整合する**
良い UI ほど適切な role が付くため、
セマンティック Locator は長期的に最も安定する。

**(4) AI が理解しやすい**
自然言語から「保存ボタンを押して」と指示したとき、
AI は getByRole を選びやすく、コード生成との相性が良い。

---

## 9. Locator の"抽象度"を適切に保つ

### 9.1 抽象度が低すぎる場合
```
div > div > span > button
```
→ 構造依存が強すぎる。

### 9.2 抽象度が高すぎる場合
```
button
```
→ ヒットしすぎて一意でなくなる。

### 9.3 正しい抽象度
```
button:text-is("保存")
```

抽象度とは「意味を損なわずに必要十分な特定ができるか」である。

---

## 10. XPath 非推奨の深掘り

XPath は UI テスト現場で頻繁に使われるが、
Playwright の思想とは真逆の方向性を持つ。

### 10.1 XPath が壊れやすい理由

**(1) DOM 構造に完全依存する**
```xpath
//div[2]/div[1]/span
```
UI ライブラリが div を 1 つ追加しただけで崩壊する。

**(2) 意図が読み取りづらい**
人間にも AI にも何を意図した Locator か分かりにくい。

**(3) Playwright の内部最適化の恩恵を受けられない**
待機・リトライ・セマンティック一致といった Locator API の強みが活かせない。

**(4) AI が最もミスを出しやすい**
ChatGPT や Claude は XPath の安定生成が苦手であり、
保守不能なコードが量産されやすい。

### 10.2 例外的な XPath 利用について

レガシーな HTML やどうしても selector が取れない特殊ケースで、
一時的な救済策として XPath を使うことはあり得る。

しかし本プロジェクトでは、

- 可読性の低さ
- 構造依存の高さ
- 保守性の低さ

から **原則禁止** とする。

---

## 11. Locator 設計における責務の分離

4 層アーキテクチャと密接に関係する：

- **第1層（Playwright API）**：技術の実体
- **第2層（PageObject / Actions）**：Locator を具体的に実装する場所
- **第3層（Concept）**：Locator の思想・禁止事項
- **第4層（Test）**：Locator を直接触ってはならない層

E2E 開発者は第3層の"思想"を理解し、第2層で実践する。

---

## 12. 成功パターン（Best Practice）

### 12.1 text-is + scope（最強の組み合わせ）

```ts
modal.locator('button:text-is("保存")');
```

- 文言で意味を確定
- モーダルという局所宇宙で範囲を限定
→ 最も壊れにくいパターンのひとつ。

### 12.2 role="dialog" に閉じ込める（モーダル）

```ts
page.locator('[role="dialog"]').locator('input[name="email"]');
```

同じフィールドが背景にも存在する可能性がある UI で非常に有効。

### 12.3 セマンティック Locator を優先する

```ts
page.getByRole('button', { name: '削除' });
```

意味構造を直接使うことで、
DOM 構造の変化を大部分吸収できる。

### 12.4 POM に動的値ロジックを集約する

```ts
async clickUser(name: string) {
  await this.page.getByRole('row', { name }).click();
}
```

Locator 定義（静的）と動的値の適用（POM）を分離することで、
テストコードの意図とセレクタの意味を保ちやすくなる。

---

## 13. 失敗パターン（Anti Pattern）

以下は高い確率でテスト崩壊を招く。

- CSS-only セレクタ
- `.first()` の乱用
- has-text を雑に使う
- 親コンテナ（スコープ）を使わない
- XPath への依存
- 動的値を constants.ts に混在させる

---

## 14. Locator チェックリスト（普遍版）

実装時・レビュー時には次の項目を確認する：

- ☑ 一意性は確保されているか？
- ☑ text-is で表現できないか？
- ☑ 親コンテナ（Local Universe）を設定したか？
- ☑ セマンティック Locator を優先しているか？
- ☑ `.first()` から逃げる努力をしたか？
- ☑ 動的値は PageObject 層に置いたか？
- ☑ XPath を使用していないか？
- ☑ 抽象度は適切か？（低すぎず、高すぎず）

---

## 15. Universal 総括

Playwright Locator の普遍原則は次の 4 本柱に集約される：

```text
1. 意味を捉える（text-is / role）
2. 宇宙を限定する（scope / Local Universe）
3. 偶然を排除する（一意性の確保）
4. 構造に依存しない（anti-XPath）
```

これらを守ることで、
UI が変わっても壊れにくい "長寿命 E2E テスト" を構築できる。

---

# Part 3: Product-Specific（固有ルール）

## 0. 本書の目的

本書は **意味層の薄い UI を持つプロダクト専用の Locator 設計戦略**を体系化するものである。

普遍ルール（Universal Edition）はどのプロダクトでも通用するが、
HTML / UI の構造的問題により、
**普遍ルールだけでは Locator を安定化できない場面が多い。**

本パートでは、固有ルールが必要となる背景として
**「UI が抱える制約」** を徹底的に整理する。

---

## 1. 意味層の薄い UI が抱える本質的制約

### 1.1 ARIA / role / label が未整備である

本来、モダン UI では次のような意味層が充実している：

- `<button role="button">`
- `<label for="email">メールアドレス</label>`
- `<input aria-label="ユーザー名">`

しかし意味層の薄い UI では：

- role が正しく付与されていない
- label と input が結びついていない
- aria-label が存在しない、または UI ライブラリ依存で不安定

そのため **getByRole や getByLabel が安定して使えない状況が多い。**

### 1.2 data-testid が存在しない（テスト専用アンカーが無い）

世界的には E2E の安定手法として `data-testid` が広く使われるが、
以下の理由で導入されていないケースがある：

- 過去に導入検討されたが優先度の理由で見送り
- UI ライブラリ構造により導入が簡単ではない

→ **E2E の基礎となる "識別アンカー" が欠落している。**

### 1.3 DOM 構造が頻繁に揺れやすい（div ネストの深さ & 意味の欠如）

次の特徴が頻発する：

- UI ライブラリによって大量の div が生成される
- クラス名が意味を持たず、スタイル制御目的で付与されている
- 同じ UI でも DOM ネストが画面ごとに異なる

例：

```html
<div>
  <div class="wrapper">
    <div class="content">
      <span>保存</span>
    </div>
  </div>
</div>
```

このため：

- CSS セレクタで構造を辿るとすぐ壊れる
- XPath はほぼ即死
- セマンティック Locator（role, label）も付与不足で使えない

→ **構造依存の Locator を使う選択肢は消える。**

### 1.4 同じ文言を持つ UI が複数存在する

代表例：

- 「保存」ボタンが複数
- 「編集」「削除」も複数
- 「戻る」「詳細を見る」なども重複

UI 文言の重複により、

- text-is だけでは一意化できない
- partial テキスト一致では誤爆しやすい

→ **Local Universe（親コンテナ）や near() が必須になる背景。**

### 1.5 モーダルの class 名が意味を持たず、唯一信頼できるのは `role="dialog"`

本来、UI ライブラリが生成する class 名は：

- ランダム
- 抽象的
- 意味を持たない

そのため：

- `.modal`
- `.Dialog-root`

などの判定は使えない。

唯一安定するのは：

```
[role="dialog"]
```

→ **モーダル識別は role="dialog" に統一** する。

### 1.6 アイコンボタンが UI ライブラリ固有の構造を持つ

例：

```html
<button>
  <svg data-icon="ellipsis">
```

- ボタンの class は役に立たない
- text も存在しない
- しかし `data-icon` は内部仕様として安定している

→ 固有ルールの核心として
**svg[data-icon] を anchor とする** ことが必須となる。

### 1.7 結論：意味層の薄い UI は "構造層が揺れまくる"

したがって必要なのは：

- UI の "意味"（text）で anchor を張る
- 近接関係（near）で意味不足を補う
- 局所宇宙（Local Universe）で探索を絞る
- アイコン構造（data-icon）を利用する
- モーダルは role で確定する

という **固有戦略の体系化**である。

---

## 2. 最適 Locator 戦略（固有ルール）

### 2.1 near() を主戦力とする

意味層の薄い UI では：

- 要素自身に識別子がない（id / aria-label / data 属性なし）
- DOM 構造が頻繁に変わる
- 同じ文言 UI が複数ある
- class 名が意味を持たない

という構造的制約が重なる。

そのため、**要素確定には「近接関係（proximity）」を使うのがもっとも安定するアプローチ**となる。

#### near() を使う代表例（チェックボックス）

```ts
page.locator('input[type="checkbox"]:near(:text("利用規約に同意する"))');
```

背景：

1. チェックボックスには識別情報がない
2. DOM 構造は UI ライブラリ依存で揺れる
3. テキストだけが安定した anchor
4. テキストと対象要素の距離は変わらない

→ **構造でもセマンティックでもなく、"テキストの近接"が最も安定 anchor となる。**

#### near() を積極採用すべきケース

- チェックボックス
- ラジオボタン
- ラベルとフォームが結びついていない入力欄
- グループ内でボタンが複数存在する UI
- DOM の揺れが激しいコンポーネント

特に **チェックボックス・ラジオボタン** のように
「要素自体が意味を持たない UI」では near() が最も高い安定性を示す。

### 2.2 モーダルは role="dialog" に閉じ込める

意味層の薄い UI では：

- モーダルの class 名が意味を持たない
- モーダル内部と背景に同じ文言 UI が複数出現する
- DOM 構造が画面ごとに異なる

そのため、唯一信頼できる anchor は：

```ts
[role="dialog"]
```

#### モーダル操作の標準パターン（必須）

```ts
const modal = page.locator('[role="dialog"]');
await modal.locator('button:text-is("保存")').click();
```

メリット：

- 背景の「保存」ボタンを誤クリックしない
- モーダル内部を "局所宇宙（Local Universe）" として扱える
- DOM 構造変化に強い

### 2.3 アイコンボタンは svg[data-icon] を anchor にする

ボタンの class や DOM 構造は頻繁に変化するが、
UI ライブラリは `svg[data-icon]` を安定して付与する。

#### 代表例：アイコン操作

**"…"（メニュー）アイコン**
```ts
page.locator('button:has(svg[data-icon="ellipsis"])');
```

**編集アイコン**
```ts
page.locator('button:has(svg[data-icon="edit"])');
```

**削除アイコン**
```ts
page.locator('button:has(svg[data-icon="delete"])');
```

→ **icon 操作は data-icon 以外の anchor を使うべきではない。**

### 2.4 Auth0 ログインには固有の安定パターンを採用する

Auth0 は外部サービスであり、
本体 UI とは異なる構造だが HTML が比較的整っている。

#### 安定パターン（Auth0）

```ts
page.locator('input[name="username"]').fill(email);
page.locator('input[name="password"]').fill(password);
page.locator('button:has-text("ログイン")').click();
```

- 意味的 anchor がある
- DOM の揺れが小さい
- 文言も安定している

→ ログインテストの標準パターンとして採用。

### 2.5 成功パターン（Best Practices）

#### "意味 + near + scope" の三段構えが最強

**モーダル例：**

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")').click();
```

**チェックボックス例：**

```ts
page.locator('input[type="checkbox"]:near(:text("プライバシーポリシーに同意"))');
```

#### テーブル行に anchor を置き、中のアイコンを操作する

```ts
const row = page.locator('tr:has-text("TypeScript入門")');
row.locator('button:has(svg[data-icon="edit"])').click();
```

→ 行（row）が"意味のある局所宇宙"となる。

#### Local Universe を積極的に使う

意味層の薄い UI が多いため、
「意味を持つ単位」で宇宙を切り出すのが極めて重要。

例：

- 設定セクション
- コースカード
- タブパネル
- 章・レッスン一覧

### 2.6 戦略適用の Decision Tree（判断フロー）

```
① UI に明確な role / label がある？
   └ Yes → セマンティック Locator
   └ No →
        ② UI 文言は唯一か？
           └ Yes → text-is
           └ No →
                ③ 文言と対象要素は近接しているか？
                   └ Yes → near()
                   └ No →
                        ④ UI はモーダル内か？
                           └ Yes → role="dialog" + scope
                           └ No →
                                ⑤ 対象はアイコンか？
                                   └ Yes → svg[data-icon]
                                   └ No → 特例：構造 + コメント必須
```

---

## 3. アンチパターン（避けるべき罠）

意味層の薄い UI 特性（構造が揺れる）を踏まえると
以下のアンチパターンは **"即テスト崩壊リスク"** を持つため原則禁止となる。

### 3.1 CSS-only セレクタ

```css
.card > div > button
.wrapper > span.action
```

**なぜ禁止か**
- DOM の入れ子が画面ごとに違う
- UI ライブラリが div を増減させる
- class 名が意味を持たず変更頻度が高い
- 一意性が保証されない

→ 意味層の薄い UI では **CSS-only = 100% 壊れやすい**。

### 3.2 has-text の乱用（とくに部分一致）

```ts
page.locator('button:has-text("保存")');
```

**なぜ危険か**
- 「保存」が 2〜4 箇所ある画面が多い
- モーダルと背景で同じ文言が出る
- 部分一致は誤爆が発生しやすい

→ **text-is + scope（Local Universe）が必須。**

### 3.3 モーダルを page 全体で探索する

```ts
page.locator('button:text-is("保存")').click();
```

**典型的な事故**
- モーダル内の保存ではなく背景の保存を押してしまう
- 実行ログ上は成功に見えても、本当は誤った UI を操作している
- バグに見える挙動の多くが「Locator の誤爆」

→ **固有ルールでは role="dialog" の Local Universe を必ず使用。**

### 3.4 `.first()` の使用

順番が保証されない UI では、
`.first()` は「偶然の固定化」でしかない。

→ 例外を除いて禁止。使う場合は理由と TODO を必ず書くこと。

### 3.5 動的値を constants.ts に混ぜる

セレクタ定義のファイルが混乱し、保守不能になる。

→ 動的値は PageObject 層で扱う（普遍ルールと同じ）。

### 3.6 XPath の使用

意味層の薄い DOM は div 大量ネストで頻繁に変化するため、
XPath は **ほぼ即死レベルの不安定さ**を持つ。

---

## 4. 成功パターン（固有ルールに基づく安定手法）

### 4.1 text-is + role="dialog"（最強モーダル戦略）

```ts
const modal = page.locator('[role="dialog"]');
modal.locator('button:text-is("保存")').click();
```

→ 背景 UI への誤爆を完全に防止。
→ モーダル内部の"小宇宙（Local Universe）"で安定性が最高。

### 4.2 row（行）を Universe とし、中のアイコンを操作する

```ts
const row = page.locator('tr:has-text("TypeScript入門")');
row.locator('button:has(svg[data-icon="edit"])').click();
```

行は意味層の薄い UI で「意味のまとまり」として扱える希少な単位。

### 4.3 チェックボックスは near() を必ず使う

```ts
page.locator('input[type="checkbox"]:near(:text("プライバシーポリシー"))');
```

チェックボックス自身には anchor が無く、
**テキストとの近接関係だけが安定情報**となる。

### 4.4 アイコン操作は data-icon 一択

```ts
row.locator('button:has(svg[data-icon="delete"])');
```

→ class 名・text が役に立たないため、
→ **data-icon が唯一の安定 anchor。**

### 4.5 Local Universe の積極採用

- カード
- タブコンテンツ
- 設定セクション
- 章・レッスン一覧
- モーダル

意味の単位で UI を括り出すことが、固有 UI における最大の防御になる。

---

## 5. 固有チェックリスト（実務用）

### near()
☑ チェックボックス／ラジオで near() を使用したか？
☑ anchor にしたテキストは一意か？

### モーダル
☑ role="dialog" でスコープを切っているか？
☑ 背景 UI を誤操作する余地がないか？

### アイコン
☑ svg[data-icon] を anchor としているか？
☑ アイコンの text や class に依存していないか？

### row + 内部要素
☑ 行を Local Universe として扱っているか？
☑ 行内の要素操作が明確に anchor されているか？

### テキスト
☑ has-text 乱用していないか？
☑ text-is で一意性が取れているか？

### 構造依存
☑ CSS-only や XPath が混ざっていないか？

---

## 6. 固有ルールの総括

固有ルールは例外対応ではなく、
**プロダクトの構造的制約に最適化された合理的戦略**である。

柱は以下の 5 つ：

```
1. near()（意味不足の補完）
2. role="dialog"（唯一安定するモーダル anchor）
3. svg[data-icon]（UI ライブラリが保証する icon anchor）
4. Local Universe（意味単位での探索）
5. 行 anchor（row を宇宙とする）
```

これらを守ることで、
"普遍ルール + 固有ルール" のハイブリッドが成立し、
**極めて安定した Locator 設計**が実現する。

---

# 総括

本書は Locator 設計の全体系を以下の 3 層で整理した：

1. **Concept（設計思想）** - なぜそう書くのか
2. **Universal（普遍ルール）** - どのプロダクトでも通用する原則
3. **Product-Specific（固有ルール）** - 意味層の薄い UI への最適化

これらを統合することで、
UI が変わっても壊れにくい "長寿命 E2E テスト" を構築できる。
