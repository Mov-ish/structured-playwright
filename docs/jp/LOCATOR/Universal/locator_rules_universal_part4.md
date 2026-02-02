# LOCATOR_RULES_UNIVERSAL_FULL_part4.md
（普遍ルール 完結編）

---

## 8. セマンティック Locator の詳細  
### ― getByRole / getByLabel は人間にも機械にも優しい ―

Playwright が推奨する「意味ベースの Locator」は次のもの：

```ts
page.getByRole()
page.getByLabel()
page.getByPlaceholder()
page.getByAltText()
page.getByTitle()
page.getByText()
```

特に強力なのが **getByRole** である。

---

### 8.1 getByRole が最強な理由

#### (1) UI の意味構造を直接表現できる
```ts
page.getByRole('button', { name: '保存' });
```

これは CSS や XPath では表現しにくい  
**“UI の役割 + ユーザーが見ているラベル”** を同時に表現している。

#### (2) DOM 変更に非常に強い
構造が多少変化しても、ボタンはボタンであり、名前も変わりにくい。

#### (3) アクセシビリティ設計と整合する
良い UI ほど適切な role が付くため、  
セマンティック Locator は長期的に最も安定する。

#### (4) AI が理解しやすい
自然言語から「保存ボタンを押して」と指示したとき、  
AI は getByRole を選びやすく、コード生成との相性が良い。

---

### 8.2 getByLabel の強み

フォーム系 UI で最強の選択肢となる。

```ts
page.getByLabel("メールアドレス");
```

ラベルと入力欄の対応が維持される限り、DOM 構造が揺れても壊れない。

---

### 8.3 getByText の扱い

getByText は自然文での一致に向いており、  
セマンティック Locator が使えない場面の次善策として有効である。

---

## 9. XPath 非推奨の深掘り  
### ― Playwright Locator の思想と完全に逆を行く存在 ―

XPath は UI テスト現場で頻繁に使われるが、  
Playwright の思想とは真逆の方向性を持つ。

---

### 9.1 XPath が壊れやすい理由

#### (1) DOM 構造に完全依存する
```xpath
//div[2]/div[1]/span
```
UI ライブラリが div を 1 つ追加しただけで崩壊する。

#### (2) 意図が読み取りづらい
人間にも AI にも何を意図した Locator か分かりにくい。

#### (3) Playwright の内部最適化の恩恵を受けられない
待機・リトライ・セマンティック一致といった Locator API の強みが活かせない。

#### (4) AI が最もミスを出しやすい
ChatGPT や Claude は XPath の安定生成が苦手であり、  
保守不能なコードが量産されやすい。

---

### 9.2 例外的な XPath 利用について

レガシーな HTML やどうしても selector が取れない特殊ケースで、  
一時的な救済策として XPath を使うことはあり得る。

しかし本プロジェクトでは、

- 可読性の低さ
- 構造依存の高さ
- 保守性の低さ

から **原則禁止** とする。

---

## 10. 成功パターン（Best Practice）

### 10.1 text-is + scope（最強の組み合わせ）

```ts
modal.locator('button:text-is("保存")');
```

- 文言で意味を確定  
- モーダルという局所宇宙で範囲を限定  
→ 最も壊れにくいパターンのひとつ。

---

### 10.2 role="dialog" に閉じ込める（モーダル）

```ts
page.locator('[role="dialog"]').locator('input[name="email"]');
```

同じフィールドが背景にも存在する可能性がある UI で非常に有効。

---

### 10.3 セマンティック Locator を優先する

```ts
page.getByRole('button', { name: '削除' });
```

意味構造を直接使うことで、  
DOM 構造の変化を大部分吸収できる。

---

### 10.4 POM に動的値ロジックを集約する

```ts
async clickUser(name: string) {
  await this.page.getByRole('row', { name }).click();
}
```

Locator 定義（静的）と動的値の適用（POM）を分離することで、  
テストコードの意図とセレクタの意味を保ちやすくなる。

---

## 11. 失敗パターン（Anti Pattern）

以下は高い確率でテスト崩壊を招く。

- CSS-only セレクタ
- `.first()` の乱用
- has-text を雑に使う
- 親コンテナ（スコープ）を使わない
- XPath への依存
- 動的値を constants.ts に混在させる

---

## 12. Locator チェックリスト（普遍版 完全形）

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

## 13. 総括（Universal 完結）

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

**最終更新**: 2026-02-02
**管理者**: Ray Ishida

