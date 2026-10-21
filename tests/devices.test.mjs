import { run, asm, compileError, writesTo } from "./support/harness.mjs";
import { hash } from "./support/ic10.mjs";

describe("device I/O", () => {
  test("l and s on named pins", () => {
    const p = `
let furnace = device("d0")
let display = device("d1")
s(display, "Setting", l(furnace, "Temperature") - 273.15)`;
    const { devices, code } = run(p, { devices: { d0: { Temperature: 300 }, d1: {} } });
    expect(devices.d1.Setting).toBeCloseTo(26.85, 10);
    expect(code).toBe("l r0 d0 Temperature\nsub r0 r0 273.15\ns d1 Setting r0");
  });

  test("bare pins and db", () => {
    expect(asm(`s(db, "Setting", l(d3, "Pressure"))`)).toBe("l r0 d3 Pressure\ns db Setting r0");
  });

  test("booleans are written as 0/1", () => {
    const { devices } = run(`s(d0, "On", true)\ns(d0, "Lock", false)`, { devices: { d0: {} } });
    expect(devices.d0).toEqual({ On: 1, Lock: 0 });
  });

  test("batch reads and writes", () => {
    const tank = hash("StructureTankSmall");
    const named = hash("Main");
    const network = [
      { prefabHash: tank, nameHash: named, values: { Pressure: 100 } },
      { prefabHash: tank, nameHash: 0, values: { Pressure: 300 } },
    ];
    const p = `
let tank = hash("StructureTankSmall")
let main = hash("Main")
s(db, "Setting", lb(tank, "Pressure", Average))
s(db, "Mode", lbn(tank, main, "Pressure", Maximum))
sb(tank, "On", 1)
sbn(tank, main, "Lock", 1)`;
    const { devices } = run(p, { network });
    expect(devices.db).toEqual({ Setting: 200, Mode: 100 });
    expect(network.map((d) => d.values.On)).toEqual([1, 1]);
    expect(network.map((d) => d.values.Lock)).toEqual([1, undefined]);
  });

  test("slots", () => {
    const p = `
let sorter = device("d0")
let occupied = ls(sorter, 0, "Occupied")
ss(sorter, 1, "Lock", occupied)`;
    const { devices } = run(p, { devices: { d0: { slots: [{ Occupied: 1 }, {}] } } });
    expect(devices.d0.slots[1].Lock).toBe(1);
  });

  test("ReferenceId access uses ld/sd", () => {
    const p = `let pump = deviceId(4711.)\ns(pump, "Setting", l(pump, "Setting") + 1.)`;
    const byId = { 4711: { Setting: 2 } };
    const { code } = run(p, { byId });
    expect(code).toMatch(/^ld r0 4711 Setting$/m);
    expect(byId[4711].Setting).toBe(3);
  });

  test("isSet checks the pin", () => {
    const p = `if isSet(d1) { s(db, "Setting", 1) } else { s(db, "Setting", 0) }`;
    expect(run(p, { devices: { d1: {} } }).devices.db.Setting).toBe(1);
    expect(run(p, { devices: {} }).devices.db.Setting).toBe(0);
  });

  test("stack builtins", () => {
    const p = `
push(10)
push(20)
let top = peek()
let a = pop()
poke(5, a + top)
s(db, "Setting", get(db, 5) + pop())`;
    expect(run(p).devices.db.Setting).toBe(50);
  });

  test("sleep and yield", () => {
    expect(asm(`yield()\nsleep(2.5)`)).toBe("yield\nsleep 2.5");
  });

  test("logic types must be literal names", () => {
    expect(compileError(`let p = 1\nlet x = l(d0, p)`)).toMatch(/literal name/);
    expect(compileError(`let x = l(d0, "Bad Name")`)).toMatch(/not a valid IC10 name/);
  });

  test("device() validates the pin", () => {
    expect(compileError(`let x = device("d9")`)).toMatch(/device\(\) expects/);
  });

  test("%raw passes instructions through and reserves the registers it names", () => {
    const p = `
%raw("move r0 42")
let a = l(d0, "Setting")
let b = a * 2.
%raw("s d1 Setting r0")
s(d1, "Mode", b)`;
    const { devices, code } = run(p, { devices: { d0: { Setting: 4 }, d1: {} } });
    expect(devices.d1).toEqual({ Setting: 42, Mode: 8 });
    expect(code.split("\n").filter((l) => !l.includes("42") && /\br0\b/.test(l))).toEqual(["s d1 Setting r0"]);
  });
});

describe("game loop", () => {
  test("thermostat with hysteresis", () => {
    const p = `
let sensor = device("d0")
let heater = device("d1")
let heating = ref(false)
while true {
  let t = l(sensor, "Temperature")
  if t < 290. { heating := true } else if t > 300. { heating := false }
  s(heater, "On", heating.contents)
  yield()
}`;
    const temps = [280, 295, 305, 295, 285];
    const { emu } = run(p, {
      devices: { d0: { Temperature: 0 }, d1: {} },
      ticks: temps.length,
      onTick: (e, t) => (e.devices.d0.Temperature = temps[t]),
    });
    expect(writesTo(emu, "d1", "On")).toEqual([1, 1, 0, 0, 1]);
  });
});
