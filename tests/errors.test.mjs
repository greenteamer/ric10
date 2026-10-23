import { compileError, diagnostics } from "./support/harness.mjs";

describe("diagnostics", () => {
  test.each([
    ["let x = 1 +", /\[Parser.res\]\[parsePrimary\] 1:12: unexpected end of file/],
    ["let x = (1", /expected '\)'/],
    ["let x = 1 $ 2", /\[Lexer.res\]\[tokenize\] 1:11: unexpected character '\$'/],
    ['let s = "abc', /unterminated string/],
    ["/* open", /unterminated block comment/],
    ["let x = [1, 2]", /arrays are not supported/],
    ["type t = {a: int}", /record types are not supported/],
    ["let x = r.field", /field access '.field' is not supported/],
    ["module F = (X: S) => {}", /functors are not supported/],
    ["let (a, b) = (1, 2)", /destructuring is not supported/],
    ["let x = Some(1)", /option\/result are not supported/],
    ["let x = Foo", /unknown constructor 'Foo'/],
    ["type t = A(int)\nlet x = A", /expects 1 argument/],
    ["let x = undefinedFn(1)", /unknown function 'undefinedFn'/],
    ["let x = l(d0)", /l\(\) expects 2 argument/],
    ["let x = ref(1)\nlet y = x + 1", /expected a number.*ref/],
  ])("%s", (src, pattern) => {
    expect(compileError(src)).toMatch(pattern);
  });

  test("errors carry line and column", () => {
    const d = diagnostics("let a = 1\nlet b = a +\n");
    expect(d.ok).toBe(false);
    expect(d.errors[0].loc).toEqual({ line: 3, col: 1 });
  });

  test("hints are included", () => {
    expect(compileError("let rec f = x => x")).toMatch(/hint: IC10 has no call stack frames/);
  });

  test("comments and semicolons are accepted", () => {
    const d = diagnostics(`// line comment
/* block /* nested */ comment */
let a = 1; let b = 2;
s(db, "Setting", a + b) // trailing`);
    expect(d.ok).toBe(true);
  });

  test("open IC10 is accepted", () => {
    expect(diagnostics(`open IC10\ns(d0, "On", 1)`).ok).toBe(true);
  });

  test("line limit warning", () => {
    const body = Array.from({ length: 130 }, (_, i) => `s(d0, "Setting", ${i})`).join("\n");
    const d = diagnostics(body);
    expect(d.ok).toBe(true);
    expect(d.warnings.map((w) => w.message).join()).toMatch(/130 lines; an IC10 chip runs at most 128/);
  });
});
