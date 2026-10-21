import { evaluate, asm, compileError, run } from "./support/harness.mjs";

describe("arithmetic", () => {
  test.each([
    ["1 + 2 * 3", 7],
    ["(1 + 2) * 3", 9],
    ["10 - 4 - 3", 3],
    ["2 * 3 + 4 * 5", 26],
    ["7 / 2", 3], // int division truncates like ReScript
    ["-7 / 2", -3],
    ["7. / 2.", 3.5],
    ["7.0 /. 2.0", 3.5],
    ["1.5 + 2.25", 3.75],
    ["1.5 +. 2.25", 3.75],
    ["2. ** 3.", 8],
    ["2 ** 10", 1024],
    ["9. ** 0.5", 3],
    ["-2 ** 2", 4], // unary minus binds tighter than ** in ReScript
    ["2 ** 3 ** 2", 512], // right associative
    ["7 % 3", 1],
    ["1_000 + 0x10 + 0b11", 1019],
    ["1e3 + 1.5e-1", 1000.15],
  ])("%s = %p", (expr, expected) => {
    expect(evaluate(expr)).toBeCloseTo(expected, 10);
  });

  test("int division of variables truncates", () => {
    expect(evaluate("a / b", "let a = ref(17)\nlet b = ref(5)\nlet a = a.contents\nlet b = b.contents")).toBe(3);
  });

  test("float division of device values does not truncate", () => {
    expect(evaluate(`l(d0, "Temperature") / 2.`, "", { d0: { Temperature: 301 } })).toBe(150.5);
  });

  test("unary minus on variables", () => {
    expect(evaluate("-x + 1", "let x = l(d0, \"Setting\")", { d0: { Setting: 5 } })).toBe(-4);
  });
});

describe("comparisons and logic", () => {
  test.each([
    ["3 > 2", 1],
    ["3 < 2", 0],
    ["3 >= 3", 1],
    ["3 <= 2", 0],
    ["3 == 3", 1],
    ["3 != 3", 0],
    ["3 === 3", 1],
    ["3 !== 4", 1],
    ["true && false", 0],
    ["true || false", 1],
    ["!true", 0],
    ["!(1 > 2)", 1],
    ["1 < 2 == (2 < 3)", 1],
    ["1 + 1 > 1", 1], // arithmetic binds tighter than comparison
  ])("%s = %p", (expr, expected) => {
    expect(evaluate(expr)).toBe(expected);
  });

  test.each([
    ["a > 0 && b > 0", 5, 7, 1],
    ["a > 0 && b > 0", 5, -7, 0],
    ["a > 0 || b > 0", -5, 7, 1],
    ["a > 0 || b > 0", -5, -7, 0],
    ["!(a > b)", 5, 7, 1],
    ["a > 0 && b > 0 || a < -100", -200, 0, 1],
  ])("%s with a=%p b=%p is %p", (expr, a, b, expected) => {
    const devices = { d0: { Setting: a }, d1: { Setting: b } };
    const prelude = `let a = l(d0, "Setting")\nlet b = l(d1, "Setting")`;
    expect(evaluate(expr.replace(/(-?\d+)(?![\d.])/g, "$1."), prelude, devices)).toBe(expected);
  });

  test("&& short-circuits side effects", () => {
    const src = `
let check = () => {
  s(d1, "On", 1)
  true
}
let a = l(d0, "Setting")
let r = a > 0. && check()
s(db, "Setting", r)`;
    const off = run(src, { devices: { d0: { Setting: -1 }, d1: {} } });
    expect(off.devices.d1.On).toBeUndefined();
    const on = run(src, { devices: { d0: { Setting: 1 }, d1: {} } });
    expect(on.devices.d1.On).toBe(1);
  });
});

describe("bitwise", () => {
  test.each([
    ["5 &&& 3", 1],
    ["5 ||| 3", 7],
    ["5 ^^^ 3", 6],
    ["1 << 4", 16],
    ["256 >> 2", 64],
    ["-16 >> 2", -4],
    ["5 ||| 2 &&& 3", 7], // &&& binds tighter than |||
  ])("%s = %p", (expr, expected) => {
    expect(evaluate(expr)).toBe(expected);
  });
});

describe("conditional expressions", () => {
  test.each([
    [10, 1],
    [70, 2],
    [100, 3],
  ])("else-if chain as a value (t=%p)", (t, expected) => {
    const prelude = `let t = l(d0, "Temperature")
let mode = if t < 60. { 1 } else if t < 80. { 2 } else { 3 }`;
    expect(evaluate("mode", prelude, { d0: { Temperature: t } })).toBe(expected);
  });

  test("ternary", () => {
    const prelude = `let t = l(d0, "Temperature")`;
    expect(evaluate("t > 5. ? 10 : 20", prelude, { d0: { Temperature: 7 } })).toBe(10);
    expect(evaluate("t > 5. ? 10 : 20", prelude, { d0: { Temperature: 3 } })).toBe(20);
  });

  test("simple if-expressions compile to select", () => {
    const code = asm(`let t = l(d0, "Temperature")\ns(d1, "On", t > 300. ? 1 : 0)`);
    expect(code).not.toMatch(/^j /m);
    expect(code.split("\n").length).toBeLessThanOrEqual(3);
  });

  test("block expression value is its last expression", () => {
    expect(evaluate("{ let a = 2\n let b = 3\n a * b }")).toBe(6);
  });
});

describe("math builtins", () => {
  test.each([
    ["Math.abs(-3.5)", 3.5],
    ["Math.sqrt(16.)", 4],
    ["Math.floor(2.7)", 2],
    ["Math.ceil(2.1)", 3],
    ["Math.round(2.4)", 2],
    ["Math.trunc(-2.7)", -2],
    ["Math.min(3., 4.)", 3],
    ["Math.max(3., 4.)", 4],
    ["Math.Int.max(3, 4)", 4],
    ["Float.toInt(3.9)", 3],
    ["Int.toFloat(3)", 3],
    ["select(true, 1, 2)", 1],
    ["lerp(10., 20., 0.25)", 12.5],
    ["Math.pow(2., ~exp=10.)", 1024],
    ["Math.Int.pow(3, ~exp=3)", 27],
    ["Math.log10(1000.)", 3],
    ["Math.log2(8.)", 3],
    ["Math.cbrt(27.)", 3],
    ["Math.cbrt(-8.)", -2],
    ["Math.sign(-7.)", -1],
    ["Math.sign(0.)", 0],
    ["Math.hypot(3., 4.)", 5],
    ["Float.clamp(~min=0., ~max=1., 2.5)", 1],
    ["Float.clamp(~min=0., -2.5)", 0],
    ["Float.clamp(~max=1., -2.5)", -2.5],
    ["Int.clamp(~min=0, ~max=5, 7)", 5],
    ["Float.mod(7.5, 2.)", 1.5],
    ["Int.mod(7, 3)", 1],
    ["mod(7, 3)", 1],
    ["Float.isNaN(1.)", 0],
    ["Float.isNaN(0. /. 0.)", 1],
    ["Float.equal(1.5, 1.5)", 1],
    ["Int.bitwiseAnd(12, 10)", 8],
    ["Int.bitwiseOr(12, 10)", 14],
    ["Int.bitwiseXor(12, 10)", 6],
    ["Int.bitwiseNot(0)", -1],
    ["Int.shiftLeft(1, 4)", 16],
    ["Int.shiftRight(-16, 2)", -4],
    ["land(12, 10)", 8],
    ["Math.Constants.pi", Math.PI],
    ["approx(1., 1.0000001, 1e-6)", 1],
    ["approx(1., 1.1, 1e-6)", 0],
    ["approxZero(0., 1e-9)", 1],
  ])("%s = %p", (expr, expected) => {
    expect(evaluate(expr)).toBeCloseTo(expected, 10);
  });

  test("math on runtime values", () => {
    const devices = { d0: { Setting: 2 } };
    const prelude = `let x = l(d0, "Setting")`;
    expect(evaluate("Math.sqrt(x *. 8.)", prelude, devices)).toBe(4);
    expect(evaluate("Math.atan2(x, x)", prelude, devices)).toBeCloseTo(Math.PI / 4, 10);
    expect(evaluate("x->Math.max(5.)", prelude, devices)).toBe(5);
  });
});

describe("labeled arguments to builtins", () => {
  test("unknown label", () => {
    expect(compileError(`let x = Math.sqrt(~foo=1.)`)).toMatch(/has no labeled argument ~foo/);
  });
  test("pow without ~exp", () => {
    expect(compileError(`let x = Math.pow(2.)`)).toMatch(/needs ~exp/);
  });
  test("labels outside calls", () => {
    expect(compileError(`let x = ~a`)).toMatch(/unexpected/);
  });
});

describe("constants", () => {
  test("top-level numeric lets become defines", () => {
    const code = asm(`let limit = 500.\nlet t = l(d0, "Temperature")\nif t > limit { s(d1, "On", 1) }`);
    expect(code).toMatch(/^define limit 500$/m);
    expect(code).toMatch(/limit/);
  });

  test("shadowed constants do not produce duplicate defines", () => {
    const code = asm(`let x = 1\nlet x = 2\ns(d0, "Setting", x)`);
    expect(code.match(/^define x/gm)?.length ?? 0).toBeLessThanOrEqual(1);
  });

  test("constant folding", () => {
    const code = asm(`s(d0, "Setting", 2 * 3 + 4)`);
    expect(code).toBe("s d0 Setting 10");
  });

  test("hash constants", () => {
    const code = asm(`let pump = hash("StructureVolumePump")\nsb(pump, "On", 1)`);
    expect(code).toBe('define pump HASH("StructureVolumePump")\nsb pump On 1');
  });
});

describe("type errors are reported", () => {
  test("using a device as a number", () => {
    expect(compileError(`let x = d0 + 1`)).toMatch(/expected a number.*device/);
  });
  test("unknown identifier", () => {
    expect(compileError(`let x = y + 1`)).toMatch(/unknown identifier 'y'/);
  });
});

