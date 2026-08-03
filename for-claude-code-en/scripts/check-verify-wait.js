#!/usr/bin/env node
// =============================================================================
// AST detection of fixed waits inside verify
//
// Target: waitForTimeout calls inside the body of "methods that return
// Promise<boolean> (= verify)".
// A fixed wait inside verify is a breeding ground for false positives/negatives
// where the correctness of the judgment is gambled on the wait duration
// (.claude/rules/prohibited-patterns.md "Fixed waits inside verify" is the
// canonical judgment criterion).
//
// WHY AST (not grep/awk):
//   Approximating method boundaries and return types with regular expressions
//   misattributes multi-line signatures etc. to the previous method. The
//   TypeScript compiler API ships with tsc in devDependencies — no extra
//   dependency.
//
// Execution: run with node from the project root (the directory containing src/)
//   as cwd (invoked by gate.sh). typescript is resolved from the cwd's
//   node_modules.
//
// Output contract (prevents false ✅ on the gate.sh side):
//   exit 0 = scan succeeded (violations go to stdout, one line each in
//            file:line format; no output when zero)
//   exit 2 = the scan itself failed (typescript unresolvable, API missing, file
//            read failure, etc. — reason on stderr)
//   Never make "zero violations" and "could not inspect" the same exit 0.
//   ※ ts.createSourceFile does not throw on syntax errors and returns a partial
//     AST, so the catch below is effectively for fs read failures. Syntax errors
//     themselves are separately flagged ❌ by the tsc --noEmit at the end of the gate
//
// Known detection gaps (also noted in the gate.sh comments; covered by visual
// review):
//   ① methods without a return-type annotation (relying on type inference) are
//     out of scope — the implementation convention is that verify explicitly
//     declares Promise<boolean>
//   ② waits inside verify → void helper indirect calls are not caught (the call
//     graph is not traced)
//   ③ the module-scope variable form (const isX = async (): Promise<boolean> => ...)
//     is out of scope — only class method declarations and class-property arrow
//     functions are scanned (verify living inside a class is the implementation
//     convention)
// =============================================================================
'use strict';

const path = require('path');
const fs = require('fs');

let ts;
try {
  // Always use the inspected project's OWN typescript (the scripts/ side has no node_modules)
  ts = require(require.resolve('typescript', { paths: [process.cwd()] }));
} catch (e) {
  console.error(`Cannot resolve typescript from the cwd (${process.cwd()}). Run from the project root: ${e.message}`);
  process.exit(2);
}

// TypeScript 7 (the Go-native implementation) does not expose the compiler API
// through the package's "." export. Proceeding without the API would later
// produce a confusing "cannot parse" error, so fail explicitly here
if (typeof ts.createSourceFile !== 'function') {
  console.error('The typescript JS compiler API (createSourceFile) was not found. This check assumes the TypeScript 5 API (check the typescript entry in devDependencies)');
  process.exit(2);
}

// verify methods exist both in Page Objects (pages) and in the Action layer (actions) — limiting to pages is a blind spot
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

const hits = new Set(); // dedupes the rare case of a verify nested inside a verify
let hadError = false;

for (const dir of TARGET_DIRS) {
  for (const file of collectTsFiles(dir, [])) {
    let src;
    try {
      src = ts.createSourceFile(file, fs.readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true);
    } catch (e) {
      console.error(`${file}: cannot parse: ${e.message}`);
      hadError = true;
      continue;
    }

    // Recursively scan the verify body. Waits inside nested anonymous callbacks
    // also run as part of the verify, so they are in scope (lean broad)
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
