import { run, asm, compileError, labelsOf, writesTo } from "./support/harness.mjs";

describe("functions", () => {
  test("parameters and return values", () => {
    const p = `
let clamp = (x, lo, hi) => x < lo ? lo : x > hi ? hi : x
s(db, "Setting", clamp(l(d0, "Setting"), 0., 10.))`;
    const go = (v) => run(p, { devices: { d0: { Setting: v } } }).devices.db.Setting;
    expect(go(-5)).toBe(0);
    expect(go(5)).toBe(5);
    expect(go(50)).toBe(10);
  });

  test("functions called many times are compiled once and called with jal", () => {
    const p = `
let blend = (a, b) => {
  let m = Math.max(a, b)
  let n = Math.min(a, b)
  (m * 3. + n) / 4.
}
let x = l(d0, "Setting")
let y = l(d1, "Setting")
s(db, "Setting", blend(x, y) + blend(y, 1.) + blend(2., x))`;
    const { code, devices } = run(p, { devices: { d0: { Setting: 8 }, d1: { Setting: 4 } } });
    expect(code.match(/^jal blend$/gm)).toHaveLength(3);
    expect(devices.db.Setting).toBeCloseTo((8 * 3 + 4) / 4 + (4 * 3 + 1) / 4 + (8 * 3 + 2) / 4, 10);
  });

  test("a call does not clobber values live in the caller (regression)", () => {
    const p = `
let sensor = device("d0")
let out = device("d1")
let helper = () => {
  let btn = l(sensor, "Open")
  if btn == 1. { s(out, "On", 1) } else { s(out, "On", 0) }
}
while true {
  let temp = l(sensor, "Temperature")
  helper()
  helper()
  s(out, "Setting", temp)
  yield()
}`;
    const { emu, code } = run(p, { devices: { d0: { Temperature: 321, Open: 1 }, d1: {} }, ticks: 2 });
    expect(writesTo(emu, "d1", "Setting")).toEqual([321, 321]);
    const labels = labelsOf(code);
    expect(new Set(labels).size).toBe(labels.length);
  });

  test("nested calls keep the return address", () => {
    const p = `
let inner = x => {
  s(d0, "Count", l(d0, "Count") + 1.)
  x * 2.
}
let outer = x => inner(x) + inner(x + 1.)
let a = outer(1.)
let b = outer(10.)
s(db, "Setting", a + b)`;
    const { devices, code } = run(p, { devices: { d0: { Count: 0 } } });
    expect(devices.db.Setting).toBe(6 + 42);
    expect(devices.d0.Count).toBe(4);
    expect(code).toMatch(/^move r\d+ ra$/m);
  });

  test("functions receiving devices are inlined per call site", () => {
    const p = `
let toggle = (d) => s(d, "On", l(d, "On") == 0. ? 1 : 0)
toggle(d0)
toggle(d1)
toggle(d0)`;
    const { devices, code } = run(p, { devices: { d0: { On: 0 }, d1: { On: 1 } } });
    expect(devices.d0.On).toBe(0);
    expect(devices.d1.On).toBe(0);
    expect(code).not.toMatch(/jal/);
  });

  test("functions taking refs mutate the caller's ref", () => {
    const p = `
let bump = (r, by) => r := r.contents + by
let n = ref(1)
bump(n, 2)
bump(n, 3)
s(db, "Setting", n.contents)`;
    expect(run(p).devices.db.Setting).toBe(6);
  });

  test("higher-order functions are inlined", () => {
    const p = `
let twice = (f, x) => f(f(x))
let inc = x => x + 1
s(db, "Setting", twice(inc, 5))`;
    expect(run(p).devices.db.Setting).toBe(7);
  });

  test("closures read top-level refs", () => {
    const p = `
let total = ref(0.)
let add = x => total := total.contents + x
let a = l(d0, "Setting")
add(a)
add(a * 2.)
add(1.)
s(db, "Setting", total.contents)`;
    expect(run(p, { devices: { d0: { Setting: 3 } } }).devices.db.Setting).toBe(10);
  });

  test("pipe syntax", () => {
    const p = `let double = x => x * 2.\ns(db, "Setting", l(d0, "Setting")->double->Math.max(5.))`;
    expect(run(p, { devices: { d0: { Setting: 1 } } }).devices.db.Setting).toBe(5);
    expect(run(p, { devices: { d0: { Setting: 4 } } }).devices.db.Setting).toBe(8);
  });

  test("main falls through to __end, not into function bodies", () => {
    const p = `
let f = x => {
  let prev = l(d0, "Hit")
  s(d0, "Hit", prev * 10. + x)
  s(d0, "Count", l(d0, "Count") + 1.)
}
f(1.)
f(2.)
f(3.)
s(db, "Setting", 1)`;
    const { devices, code } = run(p, { devices: { d0: { Hit: 0, Count: 0 } } });
    expect(devices.db.Setting).toBe(1);
    expect(devices.d0).toEqual({ Hit: 123, Count: 3 });
    expect(code).toMatch(/^j __end$/m);
    expect(code.split("\n").at(-1)).toBe("__end:");
  });

  test("recursion is rejected", () => {
    expect(compileError(`let rec f = x => f(x)`)).toMatch(/recursive functions are not supported/);
    expect(compileError(`let f = x => x\nlet g = x => g(x)\ng(1)`)).toMatch(/unknown function 'g'/);
  });

  test("arity mismatch", () => {
    expect(compileError(`let f = (a, b) => a + b\nlet x = f(1)`)).toMatch(/expects 2 argument/);
  });
});
