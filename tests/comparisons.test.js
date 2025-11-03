const Compiler = require("../out/compiler/Compiler.res.js");

describe("Comparison Operations and If Statements", () => {
  test("if with less than comparison", () => {
    const code = `let a = 3
let b = 5
if a < 10 {
  let c = 1
}`;
    const expected = `move r0 3
move r1 5
bge r0 10 label0
move r2 1
label0:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });

  test("if with greater than comparison", () => {
    const code = `let x = 15
if x > 10 {
  let y = 2
}`;
    const expected = `move r0 15
ble r0 10 label0
move r1 2
label0:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });

  test("if with equality comparison", () => {
    const code = `let value = 42
if value == 42 {
  let status = 1
}`;
    const expected = `move r0 42
bne r0 42 label0
move r1 1
label0:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });

  test("if-else with less than", () => {
    const code = `let score = 75
if score < 80 {
  let grade = 1
} else {
  let grade = 2
}`;
    const expected = `move r0 75
blt r0 80 label1
move r1 2
j label0
label1:
move r1 1
label0:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });

  test("if-else with greater than", () => {
    const code = `let temp = 25
if temp > 30 {
  let hot = 1
} else {
  let cool = 0
}`;
    const expected = `move r0 25
bgt r0 30 label1
move r1 0
j label0
label1:
move r2 1
label0:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });

  test("if-else with equality", () => {
    const code = `let input = 5
if input == 0 {
  let zero = 1
} else {
  let nonzero = 1
}`;
    const expected = `move r0 5
beq r0 0 label1
move r1 1
j label0
label1:
move r2 1
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
    const expected = `move r0 10
blt r0 5 label1
sub r0 r0 1
j label0
label1:
add r0 r0 1
label0:`;

    const result = Compiler.compile(code);
    expect(result.TAG).toBe("Ok");
    expect(result._0).toBe(expected);
  });
});

