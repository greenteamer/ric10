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
    expect(result._0.TAG).toBe("Program");
    expect(result._0._0).toBe(expected);
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
    expect(result._0.TAG).toBe("Program");
    expect(result._0._0).toBe(expected);
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
    expect(result._0.TAG).toBe("Program");
    expect(result._0._0).toBe(expected);
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
define c 3
define b 2
define a 1
blt x 3 label1
blt x 7 label3
j label2
label3:
label2:
j label0
label1:
label0:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0.TAG).toBe("Program");
    expect(result._0._0).toBe(expected);
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
define grade 3
define grade 2
define grade 1
define grade 0
blt score 60 label1
blt score 70 label3
blt score 80 label5
j label4
label5:
label4:
j label2
label3:
label2:
j label0
label1:
label0:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0.TAG).toBe("Program");
    expect(result._0._0).toBe(expected);
  });
});

