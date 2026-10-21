import { run, compile, writesTo } from "./support/harness.mjs";

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

  test("17 simultaneously live values spill to the stack and still compute", () => {
    const names = Array.from({ length: 17 }, (_, i) => `v${i}`);
    const p = [
      ...names.map((n, i) => `let ${n} = l(d0, "Setting") + ${i}.`),
      `s(db, "Setting", ${names.join(" + ")})`,
    ].join("\n");
    const { devices, stats, code } = run(p, { devices: { d0: { Setting: 1 } } });
    expect(devices.db.Setting).toBe(17 + 136);
    expect(stats.spills).toBeGreaterThan(0);
    expect(stats.registers).toBeLessThanOrEqual(16);
    expect(code).toMatch(/^poke 511 r\d+$/m);
    expect(code).toMatch(/^get r\d+ db 511$/m);
  });

  test("long-lived variant state goes to the stack, temporaries stay in registers", () => {
    // four state refs x (tag + 3 payload slots) = 16 long-lived values + temporaries
    const p = `
type st = Idle | Run(float, float, float)
let a = ref(Idle)
let b = ref(Idle)
let c = ref(Idle)
let d = ref(Idle)
let step = (r, t, p) =>
  switch r.contents {
  | Idle => if t > 300. { r := Run(t, p, 0.) }
  | Run(t0, p0, n) => if n > 2. { r := Idle } else { r := Run(t0, Math.max(p0, p), n +. 1.) }
  }
let peak = r => switch r.contents { | Idle => 0. | Run(_, p0, _) => p0 }
while true {
  let t = l(d0, "Temperature")
  let p = l(d0, "Pressure")
  step(a, t, p)
  step(b, t +. 1., p)
  step(c, t +. 2., p)
  step(d, t +. 3., p)
  s(d1, "Setting", peak(a) +. peak(b) +. peak(c) +. peak(d))
  yield()
}`;
    const temps = [310, 310, 310, 310, 310, 310];
    const press = [100, 500, 200, 900, 50, 50];
    const { emu, stats } = run(p, {
      devices: { d0: { Temperature: 0, Pressure: 0 }, d1: {} },
      ticks: temps.length,
      onTick: (e, i) => {
        e.devices.d0.Temperature = temps[i];
        e.devices.d0.Pressure = press[i];
      },
    });
    // tick0: all enter Run(p=100); ticks 1-3 raise peak to 500, 900; tick 3: n>2 -> Idle; tick 4: re-enter with 50
    expect(writesTo(emu, "d1", "Setting")).toEqual([400, 2000, 2000, 3600, 0, 200]);
    expect(stats.spills).toBeGreaterThan(0);
    expect(stats.registers).toBeLessThanOrEqual(16);
  });

  test("spill slots live at the top of the stack, away from user push/pop", () => {
    const names = Array.from({ length: 18 }, (_, i) => `v${i}`);
    const p = [
      `push(1000.)`,
      `push(2000.)`,
      ...names.map((n, i) => `let ${n} = l(d0, "Setting") + ${i}.`),
      `s(db, "Setting", ${names.join(" + ")})`,
      `s(db, "Mode", pop() + pop())`,
    ].join("\n");
    const { devices, code } = run(p, { devices: { d0: { Setting: 0 } } });
    expect(devices.db).toEqual({ Setting: 153, Mode: 3000 });
    const slots = [...code.matchAll(/^poke (\d+) /gm)].map((m) => Number(m[1]));
    expect(Math.min(...slots)).toBeGreaterThanOrEqual(500);
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
