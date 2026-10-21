// Example programs: they type-check with the real ReScript compiler (examples/
// is a source dir in rescript.json), compile with ric10 and behave correctly in
// the emulator. Golden files pin the generated assembly; regenerate them with
//   UPDATE_GOLDEN=1 npm test -- examples
import fs from "fs";
import path from "path";
import { run, compile, writesTo, labelsOf } from "./support/harness.mjs";
import { hash } from "./support/ic10.mjs";

const root = path.resolve(import.meta.dirname, "..");
const examplesDir = path.join(root, "examples");
const goldenDir = path.join(root, "tests", "golden");
const examples = fs.readdirSync(examplesDir).filter((f) => f.endsWith(".res"));
const read = (f) => fs.readFileSync(path.join(examplesDir, f), "utf8");

describe("examples compile", () => {
  test.each(examples)("%s", (file) => {
    const d = compile(read(file));
    expect(d.warnings).toEqual([]);
    expect(d.stats.lines).toBeLessThanOrEqual(128);
    const labels = labelsOf(d.code);
    expect(new Set(labels).size).toBe(labels.length);

    const golden = path.join(goldenDir, file.replace(/\.res$/, ".ic10"));
    if (process.env.UPDATE_GOLDEN || !fs.existsSync(golden)) {
      fs.mkdirSync(goldenDir, { recursive: true });
      fs.writeFileSync(golden, d.code + "\n");
    }
    expect(d.code + "\n").toBe(fs.readFileSync(golden, "utf8"));
  });
});

describe("examples behave", () => {
  test("basic.res thermostat", () => {
    const temps = [280, 295, 310, 299];
    const { emu } = run(read("basic.res"), {
      devices: { d0: { Temperature: 0 }, d1: {}, d2: {} },
      ticks: temps.length,
      onTick: (e, t) => (e.devices.d0.Temperature = temps[t]),
    });
    expect(writesTo(emu, "d1", "On")).toEqual([1, 0, 0, 0]);
    expect(writesTo(emu, "d2", "On")).toEqual([0, 0, 1, 0]);
  });

  test("furnace2.res: start loads, stop returns to idle", () => {
    // NB: Loading(p) keeps the pressure captured when loading started, so with
    // this script the Unloading state is only reached if that pressure was
    // already above 55000 (see the README of the example).
    const script = [
      { p: 100, btn: 1 }, // Idle -> Loading(100)
      { p: 30000, btn: 1 }, // Loading -> loading()
      { p: 60000, btn: 1 }, // Loading(100) -> loading()
      { p: 60000, btn: 0 }, // Stop -> Idle
      { p: 60000, btn: 1 }, // Idle -> Loading(60000)
      { p: 60000, btn: 1 }, // Loading(60000) > 55000 -> Unloading(60000)
      { p: 20000, btn: 1 }, // Unloading(60000) -> unloading()
    ];
    const { emu } = run(read("furnace2.res"), {
      devices: { d0: { Pressure: 0 }, d1: { Open: 0 }, d2: {} },
      ticks: script.length,
      onTick: (e, t) => {
        e.devices.d0.Pressure = script[t].p;
        e.devices.d1.Open = script[t].btn;
      },
    });
    // vent Mode: 1 while loading, 0 while unloading
    expect(writesTo(emu, "d2", "Mode")).toEqual([1, 1, 0]);
    expect(writesTo(emu, "d0", "SettingOutput")).toEqual([0, 0, 50]);
  });

  test("furnace.res reacts to the emergency lever", () => {
    const furnace = { prefabHash: hash("StructureAdvancedFurnace"), nameHash: hash("Furnace"), values: { Temperature: 500, Pressure: 1000 } };
    const dialT = { prefabHash: hash("StructureLogicDial"), nameHash: hash("FurnaceDialTemp"), values: { Setting: 10 } };
    const dialP = { prefabHash: hash("StructureLogicDial"), nameHash: hash("FurnaceDialPress"), values: { Setting: 5 } };
    const lcd = { prefabHash: hash("StructureConsoleLED5"), nameHash: hash("FurnaceLCD2"), values: {} };
    const tankValve = { prefabHash: hash("StructureDigitalValve"), nameHash: hash("FurnaceTankValve"), values: {} };
    const atmValve = { prefabHash: hash("StructureDigitalValve"), nameHash: hash("FurnaceAtmValve"), values: {} };
    const network = [furnace, dialT, dialP, lcd, tankValve, atmValve];
    const devices = {
      d0: { Open: 1 }, // emergency lever
      d1: { Open: 1 }, // deplete lever
      d2: { Temperature: 250 },
      d3: {},
      d4: { Temperature: 400 },
    };
    const { emu } = run(read("furnace.res"), { devices, network, ticks: 2 });
    // emergency + deplete: open the atmosphere valve, vent on, depressurize
    expect(atmValve.values.On).toBe(1);
    expect(tankValve.values.On).toBe(0);
    expect(devices.d3.On).toBe(1);
    expect(furnace.values.SettingOutput).toBe(10);
    expect(lcd.values.Setting).toBe(250);
    expect(emu.ticks).toBe(2);
  });
});
