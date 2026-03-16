# Locator設計思想と優先順位

## Locatorの本質（未知のパターンに遭遇したらここに立ち戻る）

**1. 未来値（Future）である**
Locatorは今DOMに要素が存在しなくてもよい。遅延評価・自動待機・自動リトライを内包する「未来に成立する条件式」。
→ `isVisible()`（即時評価）より`waitFor()`（未来値評価）が適切な場面が多い。

**2. 意味空間で操作されるべき**
構造（divの入れ子）ではなく意味（role, name, label, text）で要素を捉える。UIの意味は変更されにくいが、構造は頻繁に変わる。
→ CSS構造セレクタやXPathは原則禁止。

**3. 局所宇宙（Local Universe）で探索する**
ページ全体は探索空間として大きすぎる。モーダル・行・カード等の意味単位で括ると、一意性向上・DOM変更に強い・意図が明確。
→ スコープなし`page.locator()`より`modal.locator()`や`row.locator()`。

## 4つの普遍原則 — 各原則が防ぐもの

| 原則 | 防ぐもの |
|------|---------|
| **意味を捉える（Semantic Priority）** | UI変更時のLocator崩壊。意味は最も変更されにくい層 |
| **宇宙を限定する（Local Universe）** | 同一文言の誤爆。「保存」が背景とモーダルに2つある場面 |
| **偶然を排除する（Deterministic）** | `.first()`によるUI並び替え・要素追加時の突然の破壊 |
| **構造に依存しない（Anti-XPath）** | UIライブラリがdiv1つ追加しただけでの全Locator崩壊 |

## 優先順位ピラミッド（常にこの順で検討する）

```
  1. 意味ベース（Semantic）       getByRole / getByLabel / text-is
  2. 局所宇宙（Local Universe）   dialog / row / card / section
  3. 近接（near）による意味補完    :near(:text("..."))
  4. data属性（UIライブラリ補完）  data-testid / data-icon 等
  5. 最終手段：構造依存           コメント + TODO 必須
```

## 判断フローチャート

```
① UI に明確な role / label / data-testid がある？
   └ Yes → セマンティック Locator / data-testid
   └ No →
        ② UI 文言は唯一か？
           └ Yes → text-is（完全一致）
           └ No →
                ③ 文言と対象要素は近接？
                   └ Yes → near()
                   └ No →
                        ④ 意味のあるスコープ内？（モーダル、行、カード等）
                           └ Yes → Local Universe + scope内セレクタ
                           └ No →
                                ⑤ UIライブラリのdata属性がある？
                                   └ Yes → data-icon等
                                   └ No → 構造 + コメント必須
```

## 意味層の薄いUIへの対応（プロダクト固有制約がある場合）

HTMLの意味層が薄い（data-testidなし、aria-label不足、class名無意味）プロダクトでは、普遍原則だけでは不足する場合がある。以下は「例外」ではなく「構造的必然」として扱う：

| 状況 | 固有ルール | なぜ必然か |
|------|-----------|-----------|
| 要素自身に識別子がない | `near()` を主戦力にする | 近接テキストだけが安定anchor |
| モーダルのclass名が無意味 | `role="dialog"` でスコープ | roleが唯一のセマンティックanchor |
| アイコンにテキストもaria-labelもない | `svg[data-icon]` 等のUIライブラリ内部属性 | 内部仕様だが安定したanchor |
| 同じ文言が画面内に複数存在 | 行（row）をUniverseに | 表は数少ない意味単位 |

**プロジェクト導入時の確認事項**:
1. `data-testid` は存在するか？ → あるなら最優先で使う
2. `aria-label` / `label` の整備状況は？ → 不足箇所の代替戦略を決める
3. UIライブラリは何か？ → ライブラリ固有の安定属性を特定する
4. 同じ文言UIの重複はどの程度か？ → Local Universeの設計方針を決める

## 未知のパターンに遭遇したら

1. 判断フローチャートを試す
2. 当てはまらない → **4原則に立ち戻る**
3. 「意味は？」「Universeは？」「一意か？」を順に考える
4. それでも不可 → 構造依存（コメント+TODO必須）
5. **自分で新パターンを発明する前に、人間に確認を求める**
