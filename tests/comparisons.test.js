const Compiler = require("../out/compiler/Compiler.res.js");

describe("Comparison Operations and If Statements", () => {
  test("if with comparison", () => {
    const code = `let a = 3
let b = 5
if a < 10 {
  let c = 1
}`;
    const expected = `define a 3
define b 5
define c 1
bge a 10 label0
label0:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });

  test("if-else with comparison", () => {
    const code = `let score = 75
if score < 80 {
  let grade = 1
} else {
  let grade = 2
}`;
    const expected = `define score 75
define grade 2
define grade 1
blt score 80 label1
j label0
label1:
label0:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });

  test("variable shadowing in if-else", () => {
    const code = `let x = 10
if x < 5 {
  let x = x + 1
} else {
  let x = x - 1
}`;
    const expected = `define x 10
blt x 5 label1
move r15 x
sub r0 r15 1
j label0
label1:
move r15 x
add r0 r15 1
label0:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });
});

