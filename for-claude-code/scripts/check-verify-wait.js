#!/usr/bin/env node
// =============================================================================
// verify 内固定待機の AST 検出
//
// 検出対象: 「Promise<boolean> を返すメソッド（= verify）」の本体内の waitForTimeout 呼び出し。
// verify 内の固定待機は判定の正しさが待ち時間に賭かる偽陽性/偽陰性の温床
// （.claude/rules/prohibited-patterns.md「verify 内の固定待機」が判定基準の正本）。
//
// WHY AST（grep/awk でない）:
//   メソッド境界と返り値型は正規表現で近似すると複数行シグネチャ等で直前のメソッドに
//   誤帰属する。TypeScript コンパイラ API は devDependencies（tsc）に同梱で追加依存なし。
//
// 実行: プロジェクトルート（src/ があるディレクトリ）を cwd にして node で実行
//   （gate.sh から呼ばれる）。typescript は cwd の node_modules から解決する。
//
// 出力契約（gate.sh 側の偽 ✅ 防止）:
//   exit 0 = 走査成功（違反は stdout に file:line 形式で 1 行ずつ。0 件なら無出力）
//   exit 2 = 走査自体の失敗（typescript 解決不可・API 不在・ファイル読み込み失敗など。stderr に理由）
//   「違反ゼロ」と「検査できていない」を同じ exit 0 にしない。
//   ※ ts.createSourceFile は構文エラーでも throw せず部分 AST を返すため、下の catch は
//     実質 fs 読み込み失敗用。構文エラー自体は gate 末尾の tsc --noEmit が別途 ❌ にする
//
// 既知の検出漏れ（gate.sh 側のコメントにも記載。目視・レビューで補完）:
//   ① 返り値注釈のないメソッド（型推論依存）は対象外 — verify は Promise<boolean> 明示が実装慣習
//   ② verify → void ヘルパー間接呼び出しの中の待機は拾えない（呼び出しグラフは追跡しない）
//   ③ module スコープ変数形（const isX = async (): Promise<boolean> => ...）は対象外 —
//     走査するのはクラスのメソッド宣言とクラスプロパティのアロー関数のみ（verify はクラス内が実装慣習）
// =============================================================================
'use strict';

const path = require('path');
const fs = require('fs');

let ts;
try {
  // 常に「検査対象プロジェクト自身の」typescript を使う（scripts/ 側は node_modules を持たない）
  ts = require(require.resolve('typescript', { paths: [process.cwd()] }));
} catch (e) {
  console.error(`typescript を cwd（${process.cwd()}）から解決できません。プロジェクトルートで実行してください: ${e.message}`);
  process.exit(2);
}

// TypeScript 7 系（Go ネイティブ実装）はパッケージの "." export がコンパイラ API を公開しない。
// API 不在のまま進むと後段が「parse できません」という紛らわしいエラーになるため、ここで明示的に落とす
if (typeof ts.createSourceFile !== 'function') {
  console.error('typescript の JS コンパイラ API（createSourceFile）が見つかりません。本チェックは TypeScript 5 系の API を前提とします（devDependencies の typescript を確認してください）');
  process.exit(2);
}

// verify メソッドは Page Object（pages）にも Action 層（actions）にも存在する — pages 限定は盲点
const TARGET_DIRS = ['src/pages', 'src/actions'];

function collectTsFiles(dir, acc) {
  if (!fs.existsSync(dir)) return acc;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) collectTsFiles(p, acc);
    else if (entry.isFile() && p.endsWith('.ts')) acc.push(p);
  }
  return acc;
}

function isPromiseBoolean(typeNode) {
  return !!typeNode
    && ts.isTypeReferenceNode(typeNode)
    && typeNode.typeName.getText() === 'Promise'
    && !!typeNode.typeArguments
    && typeNode.typeArguments.length === 1
    && typeNode.typeArguments[0].kind === ts.SyntaxKind.BooleanKeyword;
}

const hits = new Set(); // verify 内に verify がネストする稀ケースの重複列挙を防ぐ
let hadError = false;

for (const dir of TARGET_DIRS) {
  for (const file of collectTsFiles(dir, [])) {
    let src;
    try {
      src = ts.createSourceFile(file, fs.readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true);
    } catch (e) {
      console.error(`${file}: parse できません: ${e.message}`);
      hadError = true;
      continue;
    }

    // verify 本体内を再帰走査。ネストした無名コールバック内の待機も verify の実行に含まれるため対象（broad に倒す）
    const findWaits = (body, ownerName) => {
      const walk = (n) => {
        if (
          ts.isCallExpression(n)
          && ts.isPropertyAccessExpression(n.expression)
          && n.expression.name.text === 'waitForTimeout'
        ) {
          const { line } = src.getLineAndCharacterOfPosition(n.getStart());
          hits.add(`${file}:${line + 1}: [${ownerName}] ${src.text.split('\n')[line].trim()}`);
        }
        ts.forEachChild(n, walk);
      };
      walk(body);
    };

    const visit = (node) => {
      let fnBody = null;
      let returnType = null;
      let name = '(anonymous)';
      if ((ts.isMethodDeclaration(node) || ts.isFunctionDeclaration(node)) && node.body) {
        fnBody = node.body;
        returnType = node.type;
        if (node.name) name = node.name.getText();
      } else if (
        ts.isPropertyDeclaration(node)
        && node.initializer
        && (ts.isArrowFunction(node.initializer) || ts.isFunctionExpression(node.initializer))
      ) {
        fnBody = node.initializer.body;
        returnType = node.initializer.type;
        name = node.name.getText();
      }
      if (fnBody && isPromiseBoolean(returnType)) findWaits(fnBody, name);
      ts.forEachChild(node, visit);
    };

    visit(src);
  }
}

if (hadError) process.exit(2);
if (hits.size) console.log([...hits].join('\n'));
process.exit(0);
