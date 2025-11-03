"use strict";
// Simple test to inspect AST generation
const Compiler = require("../src/compiler/Compiler.res.js");
const Parser = require("../src/compiler/Parser.res.js");
const Lexer = require("../src/compiler/Lexer.res.js");
// Test cases with increasing complexity
const testCases = [
  {
    name: "Simple variable",
    code: "let x = 5",
  },
  {
    name: "Arithmetic expression",
    code: "let result = 10 + 20",
  },
  {
    name: "Binary operations",
    code: "let a = 5\nlet b = 10\nlet sum = a + b",
  },
  {
    name: "Comparison",
    code: "let x = 5\nlet y = 10\nlet isLess = x < y",
  },
  {
    name: "If statement",
    code: "let x = 5\nif x < 10 {\n  let y = 20\n}",
  },
  {
    name: "If-else statement",
    code: "let x = 5\nif x < 10 {\n  let y = 20\n} else {\n  let y = 30\n}",
  },
  {
    name: "Nested blocks",
    code: "let x = 5\nif x < 10 {\n  let y = 20\n  if y > 15 {\n    let z = 30\n  }\n}",
  },
];
console.log("=".repeat(80));
console.log("AST GENERATION TEST");
console.log("=".repeat(80));
testCases.forEach((test, index) => {
  console.log(`\n${index + 1}. ${test.name}`);
  console.log("-".repeat(80));
  console.log("Source code:");
  console.log(test.code);
  console.log("\nAST:");
  const tokens = Lexer.tokenize(test.code);
  if (tokens._0) {
    const ast = Parser.parse(tokens._0);
    if (ast._0) {
      console.log(JSON.stringify(ast._0, null, 2));
    } else {
      console.log("ERROR:", ast._0);
    }
  }
  console.log("-".repeat(80));
});
console.log("\n" + "=".repeat(80));
//# sourceMappingURL=test-ast.js.map
