import { run, evaluate, asm, compileError, warnings, writesTo } from "./support/harness.mjs";

describe("refs", () => {
  test(":= and .contents =", () => {
    const p = `let r = ref(1)\nr := r.contents + 1\nr.contents = r.contents * 10\ns(db, "Setting", r.contents)`;
    expect(run(p).devices.db.Setting).toBe(20);
  });

  test("reading a ref copies its value", () => {
    const p = `
let r = ref(l(d0, "Setting"))
let before = r.contents
r := 99
s(db, "Setting", before)
s(db, "Mode", r.contents)`;
    const out = run(p, { devices: { d0: { Setting: 5 } } }).devices.db;
    expect(out).toEqual({ Setting: 5, Mode: 99 });
  });

  test("assigning to a non-ref is an error", () => {
    expect(compileError(`let x = 1\nx := 2`)).toMatch(/cannot assign/);
  });

  test("ref increment compiles to a single add", () => {
    const code = asm(`let n = ref(0)\nwhile true {\n  n := n.contents + 1\n  s(d0, "Setting", n.contents)\n  yield()\n}`);
    expect(code).toMatch(/^add (r\d+) \1 1$/m);
    expect(code).not.toMatch(/^move r\d+ r\d+$/m);
  });
});

describe("variants and switch", () => {
  const prelude = `type shape = Circle(float) | Rect(float, float) | Empty`;

  test.each([
    ["Circle(2.)", 12],
    ["Rect(3., 4.)", 12],
    ["Empty", 0],
  ])("switch on %s", (ctor, area) => {
    const p = `${prelude}
let v = ref(${ctor})
let area = switch v.contents {
| Circle(r) => r * r * 3.
| Rect(w, h) => w * h
| Empty => 0.
}
s(db, "Setting", area)`;
    expect(run(p).devices.db.Setting).toBe(area);
  });

  test("variant values can be bound, compared by pattern and passed around", () => {
    const p = `${prelude}
let pick = (n: float) => n > 1. ? Rect(n, 2.) : Circle(n)
let v = pick(l(d0, "Setting"))
let w = switch v {
| Rect(a, _) => a
| Circle(r) => -.r
| Empty => 0.
}
s(db, "Setting", w)`;
    expect(run(p, { devices: { d0: { Setting: 5 } } }).devices.db.Setting).toBe(5);
    expect(run(p, { devices: { d0: { Setting: 0.5 } } }).devices.db.Setting).toBe(-0.5);
  });

  test("several refs of the same variant type are independent", () => {
    const p = `
type st = Off | On(int)
let a = ref(Off)
let b = ref(On(7))
a := On(3)
let read = r => switch r { | Off => 0 | On(n) => n }
s(db, "Setting", read(a.contents) * 10 + read(b.contents))`;
    expect(run(p).devices.db.Setting).toBe(37);
  });

  test("or-patterns, guards and wildcards", () => {
    const p = `
type dir = N | E | S | W
let classify = (d: dir, speed: float) =>
  switch d {
  | N | S if speed > 10. => 1
  | N | S => 2
  | _ => 3
  }
let speed = l(d0, "Setting")
s(db, "Setting", classify(N, speed) * 100 + classify(S, 1.) * 10 + classify(W, speed))`;
    expect(run(p, { devices: { d0: { Setting: 20 } } }).devices.db.Setting).toBe(123);
    expect(run(p, { devices: { d0: { Setting: 5 } } }).devices.db.Setting).toBe(223);
  });

  test("switch on numbers and booleans", () => {
    const p = `
let n = l(d0, "Setting")->Float.toInt
let label = switch n {
| 0 => 10
| 1 | 2 => 20
| x => x * 100
}
s(db, "Setting", label)`;
    const go = (v) => run(p, { devices: { d0: { Setting: v } } }).devices.db.Setting;
    expect(go(0)).toBe(10);
    expect(go(2)).toBe(20);
    expect(go(7)).toBe(700);
  });

  test("literal payload patterns", () => {
    const p = `
type cmd = Set(int) | Reset
let c = ref(Set(l(d0, "Setting")->Float.toInt))
let v = switch c.contents {
| Set(0) => 1
| Set(_) => 2
| Reset => 3
}
s(db, "Setting", v)`;
    expect(run(p, { devices: { d0: { Setting: 0 } } }).devices.db.Setting).toBe(1);
    expect(run(p, { devices: { d0: { Setting: 4 } } }).devices.db.Setting).toBe(2);
  });

  test("exhaustive switch omits the last tag test", () => {
    const code = asm(`type t = A | B\nlet x = ref(A)\nwhile true {\n  switch x.contents {\n  | A => x := B\n  | B => x := A\n  }\n  s(d0, "Setting", x.contents == A ? 1 : 0)\n  yield()\n}`);
    expect(code.match(/^b\w+ /gm)?.length ?? 0).toBe(1);
  });

  test("non-exhaustive switch warns", () => {
    expect(warnings(`type t = A | B | C\nlet x = ref(A)\nswitch x.contents { | A => () | B => () }`).join("\n")).toMatch(
      /not exhaustive; missing: C/,
    );
  });

  test("state machine across ticks (furnace2 regression)", () => {
    // Loading -> Unloading used to fall through into the Stop case
    const p = `
type state = Idle | Loading(float) | Unloading(float)
let state = ref(Idle)
while true {
  let pressure = l(d0, "Pressure")
  let start = l(d1, "Open") == 1.
  state :=
    switch state.contents {
    | Idle => start ? Loading(pressure) : Idle
    | Loading(p) => !start ? Idle : p > 100. ? Unloading(p) : Loading(pressure)
    | Unloading(p) => !start ? Idle : p < 10. ? Loading(p) : Unloading(pressure)
    }
  s(d2, "Mode", switch state.contents { | Idle => 0 | Loading(_) => 1 | Unloading(_) => 2 })
  yield()
}`;
    const pressures = [50, 150, 150, 50, 5, 5];
    const { emu } = run(p, {
      devices: { d0: { Pressure: 0 }, d1: { Open: 1 }, d2: {} },
      ticks: pressures.length,
      onTick: (e, t) => (e.devices.d0.Pressure = pressures[t]),
    });
    expect(writesTo(emu, "d2", "Mode")).toEqual([1, 1, 2, 2, 2, 1]);
  });

  test("constructors of another type are rejected in patterns", () => {
    expect(compileError(`type a = X | Y\ntype b = Z\nlet v = ref(X)\nswitch v.contents { | Z => () | _ => () }`)).toMatch(
      /does not belong to type 'a'/,
    );
  });
});
