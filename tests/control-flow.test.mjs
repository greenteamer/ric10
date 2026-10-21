import { run, evaluate, asm, writesTo } from "./support/harness.mjs";

describe("if / else", () => {
  const prog = `
let t = l(d0, "Temperature")
if t < 60. {
  s(d1, "Mode", 0)
} else if t < 80. {
  s(d1, "Mode", 1)
} else {
  s(d1, "Mode", 2)
}`;
  test.each([
    [20, 0],
    [60, 1],
    [79, 1],
    [80, 2],
  ])("t=%p -> mode %p", (t, mode) => {
    expect(run(prog, { devices: { d0: { Temperature: t }, d1: {} } }).devices.d1.Mode).toBe(mode);
  });

  test("if without else", () => {
    const p = `let t = l(d0, "Temperature")\nif t > 5. { s(d1, "On", 1) }\ns(d1, "Done", 1)`;
    expect(run(p, { devices: { d0: { Temperature: 9 }, d1: {} } }).devices.d1).toEqual({ On: 1, Done: 1 });
    expect(run(p, { devices: { d0: { Temperature: 1 }, d1: {} } }).devices.d1).toEqual({ Done: 1 });
  });

  test("nested conditions with && and ||", () => {
    const p = `
let a = l(d0, "Setting")
let b = l(d1, "Setting")
if (a > 0. && b > 0.) || a == -1. {
  s(db, "Setting", 1)
} else {
  s(db, "Setting", 0)
}`;
    const go = (a, b) => run(p, { devices: { d0: { Setting: a }, d1: { Setting: b } } }).devices.db.Setting;
    expect(go(1, 1)).toBe(1);
    expect(go(1, -1)).toBe(0);
    expect(go(-1, -5)).toBe(1);
    expect(go(-2, 5)).toBe(0);
  });

  test("constant conditions are folded away", () => {
    expect(asm(`if true { s(d0, "On", 1) } else { s(d0, "On", 0) }`)).toBe("s d0 On 1");
    expect(asm(`if 1 > 2 { s(d0, "On", 1) }`)).toBe("");
  });
});

describe("loops", () => {
  test("while with a counter", () => {
    const p = `
let i = ref(0)
let sum = ref(0)
while i.contents < 10 {
  sum := sum.contents + i.contents
  i := i.contents + 1
}
s(db, "Setting", sum.contents)`;
    expect(run(p).devices.db.Setting).toBe(45);
  });

  test("for loop up and down", () => {
    const up = `let acc = ref(0)\nfor i in 1 to 5 { acc := acc.contents * 10 + i }\ns(db, "Setting", acc.contents)`;
    expect(run(up).devices.db.Setting).toBe(12345);
    const down = `let acc = ref(0)\nfor i in 5 downto 1 { acc := acc.contents * 10 + i }\ns(db, "Setting", acc.contents)`;
    expect(run(down).devices.db.Setting).toBe(54321);
  });

  test("for loop with runtime bounds and empty range", () => {
    const p = `let n = l(d0, "Setting")->Float.toInt\nlet acc = ref(0)\nfor i in 1 to n { acc := acc.contents + i }\ns(db, "Setting", acc.contents)`;
    expect(run(p, { devices: { d0: { Setting: 4 } } }).devices.db.Setting).toBe(10);
    expect(run(p, { devices: { d0: { Setting: 0 } } }).devices.db.Setting).toBe(0);
  });

  test("nested loops", () => {
    const p = `
let count = ref(0)
for i in 0 to 3 {
  for j in 0 to 3 {
    if i < j { count := count.contents + 1 }
  }
}
s(db, "Setting", count.contents)`;
    expect(run(p).devices.db.Setting).toBe(6);
  });

  test("game loop yields once per tick", () => {
    const p = `
let n = ref(0)
while true {
  n := n.contents + 1
  s(d0, "Setting", n.contents)
  yield()
}`;
    const { emu } = run(p, { devices: { d0: {} }, ticks: 5 });
    expect(writesTo(emu, "d0", "Setting")).toEqual([1, 2, 3, 4, 5]);
  });

  test("sensor changes between ticks drive the loop", () => {
    const p = `
while true {
  let t = l(d0, "Temperature")
  s(d1, "On", t < 300.)
  yield()
}`;
    const temps = [290, 310, 295];
    const { emu } = run(p, {
      devices: { d0: { Temperature: 0 }, d1: {} },
      ticks: 3,
      onTick: (e, tick) => (e.devices.d0.Temperature = temps[tick]),
    });
    expect(writesTo(emu, "d1", "On")).toEqual([1, 0, 1]);
  });

  test("while true needs no compare", () => {
    const code = asm(`while true { yield() }`);
    expect(code).toBe("while0:\nyield\nj while0");
  });
});
