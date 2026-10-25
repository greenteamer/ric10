// Ergonomics layer: batch devices as values, generated Logic/Slot accessors,
// user modules and `open`.
import fs from "fs";
import path from "path";
import { run, asm, compileError, writesTo } from "./support/harness.mjs";
import { hash } from "./support/ic10.mjs";
import { generate, splice, accessorName, logicTypeOf, generatePrefabTable, prefabAccessor } from "../scripts/gen-bindings.mjs";

const root = path.resolve(import.meta.dirname, "..");

describe("batch devices as values", () => {
  const tank = hash("StructureTankSmall");
  const main = hash("Main");
  const network = () => [
    { prefabHash: tank, nameHash: main, values: { Pressure: 100, On: 0 } },
    { prefabHash: tank, nameHash: 0, values: { Pressure: 300, On: 0 } },
  ];

  test("l/s on batch and named devices", () => {
    const p = `
let tanks = batch(hash("StructureTankSmall"))
let mainTank = named(hash("StructureTankSmall"), hash("Main"))
s(db, "Setting", l(tanks, "Pressure"))        // Maximum by default
s(db, "Mode", lm(tanks, "Pressure", Average))
s(db, "Open", l(mainTank, "Pressure"))
s(tanks, "On", 1)
s(mainTank, "Lock", 1)`;
    const net = network();
    const { devices, code } = run(p, { network: net });
    expect(devices.db).toEqual({ Setting: 300, Mode: 200, Open: 100 });
    expect(net.map((d) => d.values.On)).toEqual([1, 1]);
    expect(net.map((d) => d.values.Lock)).toEqual([1, undefined]);
    expect(code).toMatch(/^lb r\d+ HASH\("StructureTankSmall"\) Pressure Maximum$/m);
    expect(code).toMatch(/^lbn r\d+ .* Pressure Maximum$/m);
    expect(code).toMatch(/^sbn /m);
  });

  test("lm on a pin and isSet on a batch are errors", () => {
    expect(compileError(`let x = lm(d0, "Pressure", Average)`)).toMatch(/lm\(\) reads batch devices/);
    expect(compileError(`let t = batch(hash("X"))\nlet x = isSet(t)`)).toMatch(/only works with device pins/);
  });
});

describe("Logic and Slot accessors", () => {
  test("read, write, pipe-first, keyword escape", () => {
    const p = `
let sensor = device("d0")
let vent = device("d1")
let t = sensor->Logic.temperature
vent->Logic.setOn(t > 300.)
Logic.setMode(vent, 1)
s(db, "Setting", Logic.open_(vent) +. Slot.occupied(sensor, 0))
Slot.setLock(sensor, 1, true)`;
    const devices = { d0: { Temperature: 310, slots: [{ Occupied: 1 }, {}] }, d1: { Open: 1 } };
    const { devices: out, code } = run(p, { devices });
    expect(out.d1).toEqual({ Open: 1, On: 1, Mode: 1 });
    expect(out.db.Setting).toBe(2);
    expect(out.d0.slots[1].Lock).toBe(1);
    expect(code).toMatch(/^l r\d+ d0 Temperature$/m);
    expect(code).toMatch(/^ls r\d+ d0 0 Occupied$/m);
    expect(code).toMatch(/^ss d0 1 Lock r\d+$/m); // ss only accepts a register value
    expect(code).not.toMatch(/jal/);
  });

  test("accessors on batch devices", () => {
    const tank = hash("StructureTankSmall");
    const net = [{ prefabHash: tank, nameHash: 0, values: { Pressure: 5 } }];
    const p = `let tanks = batch(hash("StructureTankSmall"))\ns(db, "Setting", tanks->Logic.pressure)\ntanks->Logic.setOn(true)`;
    const { devices } = run(p, { network: net });
    expect(devices.db.Setting).toBe(5);
    expect(net[0].values.On).toBe(1);
  });

  test("reads are pure (dead ones disappear), writes are not", () => {
    expect(asm(`let x = d0->Logic.temperature\ns(d1, "On", 1)`)).toBe("s d1 On 1");
    expect(asm(`d0->Logic.setOn(1)`)).toBe("s d0 On 1");
  });

  test("accessors whose logic type starts with 'Set' are reads", () => {
    const p = `s(db, "Setting", d0->Logic.setting +. Logic.settingInput(d0))\nd1->Logic.setSettingOutput(d0->Logic.settingOutput)`;
    const { devices } = run(p, { devices: { d0: { Setting: 1, SettingInput: 2, SettingOutput: 3 }, d1: {} } });
    expect(devices.db.Setting).toBe(3);
    expect(devices.d1.SettingOutput).toBe(3);
  });

  test("slot reads and writes on batch and named devices", () => {
    const tray = hash("StructureHydroponicsTray");
    const net = [
      { prefabHash: tray, nameHash: hash("T1"), values: {}, slots: [{ Seeding: 1, Health: 0.5 }] },
      { prefabHash: tray, nameHash: hash("T2"), values: {}, slots: [{ Seeding: -1, Health: 1 }] },
    ];
    const p = `
let seeds = (name: string) => named(hash("StructureHydroponicsTray"), hash(name))->Slot.seeding(0) > 0. ? 1 : 0
let trays = batch(hash("StructureHydroponicsTray"))
s(db, "Setting", seeds("T1") + seeds("T2"))
s(db, "Mode", ls(trays, 0, "Health"))
trays->Slot.setLock(0, true)`;
    const { devices, code } = run(p, { network: net });
    expect(devices.db).toEqual({ Setting: 1, Mode: 1 });
    expect(net.map((d) => d.slots[0].Lock)).toEqual([1, 1]);
    expect(code).toMatch(/^lbns r\d+ HASH\("StructureHydroponicsTray"\) HASH\("T1"\) 0 Seeding Maximum$/m);
    expect(code).toMatch(/^lbs r\d+ HASH\("StructureHydroponicsTray"\) 0 Health Maximum$/m);
    expect(code).toMatch(/^sbs HASH\("StructureHydroponicsTray"\) 0 Lock r\d+$/m);
    expect(compileError(`let t = named(hash("A"), hash("B"))\nss(t, 0, "Lock", 1)`)).toMatch(/no instruction to write a slot of a named device/);
  });

  test("hash() of a compile-time string", () => {
    const p = `let name = "Main"\nlet h = (n: string) => hash(n)\ns(db, "Setting", h("Tank") + hash(name))`;
    expect(asm(p)).toMatch(/HASH\("Tank"\)/);
    expect(asm(p)).toMatch(/HASH\("Main"\)/);
    expect(run(p).devices.db.Setting).toBe(hash("Tank") + hash("Main"));
    expect(compileError(`let x = hash(l(d0, "Setting"))`)).toMatch(/string known at compile time/);
  });

  test("arity errors", () => {
    expect(compileError(`let x = Logic.temperature(d0, 1)`)).toMatch(/got 2 argument/);
  });

  test("generated bindings are up to date and cover the game table", () => {
    const table = JSON.parse(fs.readFileSync(path.join(root, "tests/fixtures/ic10-instructions.json"), "utf8"));
    for (const f of ["src/compiler/IC10.res", "tests/support/IC10.runtime.res"]) {
      const src = fs.readFileSync(path.join(root, f), "utf8");
      expect(splice(src)).toBe(src);
    }
    const gen = generate();
    for (const t of table.logicTypes) expect(gen).toContain(`let ${accessorName(t)} = (d: device): float => l(d, "${t}")`);
    expect(accessorName("Open")).toBe("open_");
    expect(logicTypeOf("open_")).toBe("Open");
    expect(logicTypeOf("settingInput")).toBe("SettingInput");
  });
});

describe("Prefab hashes", () => {
  const prefabs = JSON.parse(fs.readFileSync(path.join(root, "tests/fixtures/prefabs.json"), "utf8")).prefabs;

  test("known prefab names compile to HASH(\"...\"), unknown ones to the number", () => {
    const unnamed = prefabs.find((p) => !p.name);
    const p = `
let tanks = batch(Prefab.structureTankSmall)
sb(Prefab.structureAdvancedFurnace, "On", 1)
s(db, "Setting", Prefab.${prefabAccessor(unnamed)})`;
    const code = asm(p + `\ns(tanks, "Lock", 1)`);
    expect(code).toMatch(/^sb HASH\("StructureTankSmall"\) Lock 1$/m);
    expect(code).toMatch(/^sb HASH\("StructureAdvancedFurnace"\) On 1$/m);
    expect(code).toMatch(new RegExp(`^s db Setting ${unnamed.hash}$`, "m"));
  });

  test("works with the emulator's network", () => {
    const net = [{ prefabHash: hash("StructureTankSmall"), nameHash: 0, values: { Pressure: 42 } }];
    const { devices } = run(`s(db, "Setting", batch(Prefab.structureTankSmall)->Logic.pressure)`, { network: net });
    expect(devices.db.Setting).toBe(42);
  });

  test("unknown prefab", () => {
    expect(compileError(`let x = Prefab.structureTankSmal`)).toMatch(/unknown prefab 'structureTankSmal'/);
  });

  test("every named prefab hashes to its game hash; accessors are unique", () => {
    const named = prefabs.filter((p) => p.name);
    expect(named.length).toBeGreaterThan(1100);
    for (const p of named) expect([p.name, hash(p.name)]).toEqual([p.name, p.hash]);
    const accessors = prefabs.map(prefabAccessor);
    expect(new Set(accessors).size).toBe(accessors.length);
    for (const a of accessors) expect(a).toMatch(/^[a-z][A-Za-z0-9_]*$/);
  });

  test("the compiler's prefab table is generated from the fixture", () => {
    expect(fs.readFileSync(path.join(root, "src/compiler/PrefabTable.res"), "utf8")).toBe(generatePrefabTable());
  });
});

describe("modules", () => {
  test("module namespaces devices, constants and functions", () => {
    const p = `
module Furnace = {
  let dev = named(hash("StructureAdvancedFurnace"), hash("Furnace"))
  let limit = 1000.
  let temperature = () => dev->Logic.temperature
  let stop = () => {
    dev->Logic.setSettingInput(0)
    dev->Logic.setSettingOutput(0)
  }
  let tooHot = () => temperature() > limit
}
module Vent = {
  let dev = device("d3")
  let set = (mode: int) => dev->Logic.setMode(mode)
}
if Furnace.tooHot() { Furnace.stop() }
Vent.set(1)
s(db, "Setting", Furnace.limit)`;
    const furnace = { prefabHash: hash("StructureAdvancedFurnace"), nameHash: hash("Furnace"), values: { Temperature: 1200 } };
    const { devices, code } = run(p, { network: [furnace], devices: { d3: {} } });
    expect(furnace.values.SettingInput).toBe(0);
    expect(furnace.values.SettingOutput).toBe(0);
    expect(devices.d3.Mode).toBe(1);
    expect(devices.db.Setting).toBe(1000);
    expect(code).toMatch(/^define Furnace_limit 1000$/m);
  });

  test("functions inside modules compile out of line with sanitized labels", () => {
    const p = `
module M = {
  let scale = (x, k) => {
    let a = x *. k
    let b = a +. 1.
    b *. b
  }
}
let x = l(d0, "Setting")
s(db, "Setting", M.scale(x, 2.) +. M.scale(x, 3.) +. M.scale(x, 4.))`;
    const { devices, code } = run(p, { devices: { d0: { Setting: 1 } } });
    const sc = (k) => (1 * k + 1) ** 2;
    expect(devices.db.Setting).toBe(sc(2) + sc(3) + sc(4));
    expect(code).toMatch(/^jal M_scale$/m);
  });

  test("nested modules, open, qualified constructors and patterns", () => {
    const p = `
module Plant = {
  type state = Idle | Running(float)
  module Pump = {
    let dev = device("d0")
    let on = () => dev->Logic.setOn(true)
  }
  let next = (s: state, p: float) =>
    switch s {
    | Plant.Idle => p > 10. ? Plant.Running(p) : Idle
    | Running(peak) => Running(Math.max(peak, p))
    }
}
open Plant
let st = ref(Idle)
st := next(st.contents, l(d1, "Pressure"))
st := Plant.next(st.contents, 50.)
Pump.on()
s(db, "Setting", switch st.contents { | Plant.Running(peak) => peak | Idle => -1. })`;
    const { devices } = run(p, { devices: { d0: {}, d1: { Pressure: 20 } } });
    expect(devices.d0.On).toBe(1);
    expect(devices.db.Setting).toBe(50);
  });

  test("errors", () => {
    expect(compileError(`module A = B`)).toMatch(/module aliases/);
    expect(compileError(`module F = (X: S) => {}`)).toMatch(/functors/);
    expect(compileError(`open Nope`)).toMatch(/unknown module 'Nope'/);
    expect(compileError(`module A = { let x = 1 }\nlet y = A.z`)).toMatch(/unknown identifier 'A.z'/);
  });
});
