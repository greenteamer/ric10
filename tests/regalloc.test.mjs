import { run, compile, compileError } from "./support/harness.mjs";

describe("register allocation", () => {
  test("registers are reused once values die", () => {
    // 40 sequential temporaries, each dead after the next store
    const body = Array.from({ length: 40 }, (_, i) => `s(d1, "Setting", l(d0, "Setting") * ${i + 1}.)`).join("\n");
    const { stats } = compile(body);
    expect(stats.registers).toBe(1);
  });

  test("16 simultaneously live values fit", () => {
    const names = Array.from({ length: 16 }, (_, i) => `v${i}`);
    const p = [
      ...names.map((n, i) => `let ${n} = l(d0, "Setting") + ${i}.`),
      `s(db, "Setting", ${names.join(" + ")})`,
    ].join("\n");
    const { devices, stats } = run(p, { devices: { d0: { Setting: 1 } } });
    expect(stats.registers).toBe(16);
    expect(devices.db.Setting).toBe(16 + 120);
  });

  test("17 simultaneously live values report the culprits", () => {
    const names = Array.from({ length: 17 }, (_, i) => `v${i}`);
    const p = [
      ...names.map((n, i) => `let ${n} = l(d0, "Setting") + ${i}.`),
      `s(db, "Setting", ${names.join(" + ")})`,
    ].join("\n");
    const err = compileError(p);
    expect(err).toMatch(/more than 16 registers/);
    expect(err).toMatch(/17 values are alive at once \(v0, v1, .*v15/);
  });

  test("values live across a call get different registers than the callee uses", () => {
    const p = `
let work = x => {
  let a = l(d0, "Setting") + x
  let b = a * a
  b - a
}
let keep1 = l(d1, "Setting")
let keep2 = keep1 * 2.
let r1 = work(1.)
let r2 = work(2.)
let r3 = work(3.)
s(db, "Setting", keep1 + keep2 + r1 + r2 + r3)`;
    const { devices } = run(p, { devices: { d0: { Setting: 1 }, d1: { Setting: 5 } } });
    const w = (x) => (1 + x) * (1 + x) - (1 + x);
    expect(devices.db.Setting).toBe(5 + 10 + w(1) + w(2) + w(3));
  });

  test("the old one-ref-per-variant-type limit is gone", () => {
    const p = `
type t = A | B(int)
let x = ref(A)
let y = ref(B(1))
let z = ref(B(2))
z := B(3)
let v = r => switch r { | A => 0 | B(n) => n }
s(db, "Setting", v(x.contents) + v(y.contents) * 10 + v(z.contents) * 100)`;
    expect(run(p).devices.db.Setting).toBe(310);
  });
});
