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
bnez 0 label0
define c 1
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
bnez 1 label0
define grade 2
j label1
label0:
define grade 1
label1:`;

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
bnez 0 label0
j label1
label0:
label1:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });

  test("else if chain", () => {
    const code = `let x = 5
if x < 3 {
  let a = 1
} else if x < 7 {
  let b = 2
} else {
  let c = 3
}`;
    const expected = `define x 5
bnez 0 label0
bnez 1 label2
define c 3
j label1
label2:
define b 2
label0:
define a 1
label1:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });

  test("multiple else if", () => {
    const code = `let score = 85
if score < 60 {
  let grade = 0
} else if score < 70 {
  let grade = 1
} else if score < 80 {
  let grade = 2
} else {
  let grade = 3
}`;
    const expected = `define score 85
bnez 0 label0
bnez 0 label2
bnez 0 label4
define grade 3
j label1
label4:
define grade 2
label2:
define grade 1
label0:
define grade 0
label1:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });
});

