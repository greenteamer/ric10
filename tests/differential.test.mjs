// Differential tests: ReScript itself is the oracle.
//
// Each program is compiled twice:
//   1. by the real ReScript compiler to JS, with IC10 bindings implemented on a
//      mock chip (tests/support/IC10.runtime.res + jsChip.mjs);
//   2. by ric10 to IC10, executed in the emulator (tests/support/ic10.mjs).
// Both runs see the same devices and the same per-tick inputs; their traces of
// device writes must match. This catches miscompiles that golden files and
// hand-written expectations cannot.
import fs from "fs";
import path from "path";
import { execFileSync } from "child_process";
import { pathToFileURL } from "url";
import { compile, IC10 } from "./support/harness.mjs";
import { JsChip, StopSimulation } from "./support/jsChip.mjs";
import { hash } from "./support/ic10.mjs";
import { generateProgram, inputsFor } from "./support/progen.mjs";

const root = path.resolve(import.meta.dirname, "..");
const work = path.join(root, "tests", ".work");
const rescriptBin = path.join(root, "node_modules", ".bin", "rescript");

const seq = (key, values) => (devices, tick) => {
  for (const [pin, prop] of [key]) devices[pin][prop] = values[Math.min(tick, values.length - 1)];
};

const programs = [
  {
    name: "Arithmetic",
    src: `
let a = l(d0, "Setting")
let b = l(d1, "Setting")
s(db, "Setting", a * b + a / b - (a - b) * 2.)
s(db, "Mode", Float.toInt(a) / 3 + Float.toInt(b) % 4)
s(db, "Ratio", Math.sqrt(a *. a +. b *. b))
s(db, "On", a > b && !(b == 0.) || a < -100.)`,
    devices: { d0: { Setting: 17 }, d1: { Setting: 5 } },
  },
  {
    name: "Loops",
    src: `
let acc = ref(0)
for i in 1 to 10 {
  if i % 2 == 0 { acc := acc.contents + i * i } else { acc := acc.contents - i }
}
let j = ref(10)
while j.contents > 0 {
  j := j.contents - 3
  s(d0, "Setting", j.contents)
}
for k in 3 downto 1 { s(d0, "Mode", k * acc.contents) }`,
    devices: { d0: {} },
  },
  {
    name: "Thermostat",
    src: `
let heating = ref(false)
while true {
  let t = l(d0, "Temperature")
  if t < 290. { heating := true } else if t > 300. { heating := false }
  s(d1, "On", heating.contents)
  s(d1, "Setting", heating.contents ? t +. 5. : t)
  yield()
}`,
    devices: { d0: { Temperature: 0 }, d1: {} },
    ticks: 8,
    inputs: seq(["d0", "Temperature"], [280, 289, 295, 301, 299, 288, 300, 310]),
  },
  {
    name: "StateMachine",
    src: `
type state = Idle | Filling(float) | Venting(float, int)
let st = ref(Idle)
while true {
  let p = l(d0, "Pressure")
  st :=
    switch st.contents {
    | Idle => p < 100. ? Filling(p) : Idle
    | Filling(start) if p > start +. 500. => Venting(p, 3)
    | Filling(start) => Filling(start)
    | Venting(_, 0) => Idle
    | Venting(peak, n) => Venting(Math.max(peak, p), n - 1)
    }
  switch st.contents {
  | Idle => s(d1, "Mode", 0)
  | Filling(start) =>
    s(d1, "Mode", 1)
    s(d1, "Setting", start)
  | Venting(peak, n) =>
    s(d1, "Mode", 2)
    s(d1, "Setting", peak)
    s(d1, "Quantity", n)
  }
  yield()
}`,
    devices: { d0: { Pressure: 0 }, d1: {} },
    ticks: 12,
    inputs: seq(["d0", "Pressure"], [200, 50, 300, 700, 900, 650, 400, 300, 80, 90, 900, 950]),
  },
  {
    name: "Functions",
    src: `
let clamp = (x, lo, hi) => x < lo ? lo : x > hi ? hi : x
let mix = (a, b, t) => {
  let t = clamp(t, 0., 1.)
  a *. (1. -. t) +. b *. t
}
let report = (pin, v) => {
  s(pin, "Setting", v)
  s(pin, "Mode", v > 50. ? 1 : 0)
}
let x = l(d0, "Setting")
let y = l(d1, "Setting")
report(d2, mix(x, y, 0.25))
report(d2, mix(y, x, x / 100.))
report(d3, mix(0., 100., y / 10.))
report(d3, clamp(x *. y, -1000., 1000.))`,
    devices: { d0: { Setting: 40 }, d1: { Setting: 90 }, d2: {}, d3: {} },
  },
  {
    name: "OutOfLineCalls",
    src: `
let counter = ref(0)
let step = (scale: float) => {
  counter := counter.contents + 1
  let reading = l(d0, "Temperature")
  let corrected = reading *. scale -. Int.toFloat(counter.contents)
  s(d1, "Setting", corrected)
  corrected > 100.
}
while true {
  let keep = l(d0, "Pressure")
  let a = step(1.)
  let b = step(2.)
  let c = step(0.5)
  s(d1, "On", a || b && c)
  s(d1, "Pressure", keep)
  yield()
}`,
    devices: { d0: { Temperature: 0, Pressure: 0 }, d1: {} },
    ticks: 4,
    inputs: (d, t) => {
      d.d0.Temperature = [60, 120, 30, 250][t];
      d.d0.Pressure = 1000 + t;
    },
  },
  {
    name: "Variants",
    src: `
type shape = Circle(float) | Rect(float, float) | Point
let area = sh =>
  switch sh {
  | Circle(r) => r *. r *. 3.
  | Rect(w, h) => w *. h
  | Point => 0.
  }
let a = l(d0, "Setting")
let shapes = ref(Point)
let total = ref(0.)
for i in 0 to 5 {
  shapes := (i % 3 == 0 ? Circle(a +. Int.toFloat(i)) : i % 3 == 1 ? Rect(a, Int.toFloat(i)) : Point)
  total := total.contents +. area(shapes.contents)
  s(d1, "Setting", total.contents)
  s(d1, "Mode", shapes.contents == Point ? 1 : 0)
}`,
    devices: { d0: { Setting: 2 }, d1: {} },
  },
  {
    name: "Bitwise",
    src: `
let v = Float.toInt(l(d0, "Setting"))
s(d1, "Setting", (v &&& 12) ||| (v << 2))
s(d1, "Mode", v ^^^ 255)
s(d1, "On", (v >> 1) &&& 1)`,
    devices: { d0: { Setting: 45 }, d1: {} },
  },
  {
    name: "Batch",
    src: `
let tanks = hash("StructureTankSmall")
let main = hash("Main")
while true {
  let avg = lb(tanks, "Pressure", Average)
  let peak = lbn(tanks, main, "Pressure", Maximum)
  sb(tanks, "On", avg < 1000.)
  sbn(tanks, main, "Lock", peak > 2000.)
  s(db, "Setting", avg)
  yield()
}`,
    network: () => [
      { prefabHash: hash("StructureTankSmall"), nameHash: hash("Main"), values: { Pressure: 500 } },
      { prefabHash: hash("StructureTankSmall"), nameHash: 7, values: { Pressure: 900 } },
    ],
    ticks: 3,
    inputs: (_d, t, chip) => {
      chip.network[0].values.Pressure = [500, 2500, 3000][t];
    },
  },
  {
    name: "Stack",
    src: `
for i in 1 to 5 { push(i * i) }
let sum = ref(0.)
for _ in 1 to 5 { sum := sum.contents +. pop() }
put(db, 10, sum.contents)
push(100)
s(db, "Setting", get(db, 10) +. peek())`,
  },
  {
    name: "Pipes",
    src: `
let double = x => x * 2.
let x = l(d0, "Setting")
s(d1, "Setting", x->double->Math.max(5.)->Math.min(40.))
s(d1, "Mode", x->Float.toInt->Math.Int.abs)`,
    devices: { d0: { Setting: -7 }, d1: {} },
  },
  {
    name: "ShortCircuit",
    src: `
let touched = ref(0)
let probe = v => {
  touched := touched.contents + 1
  v > 0.
}
let a = l(d0, "Setting")
if a > 0. && probe(a) { s(d1, "Mode", 1) }
if a > 0. || probe(-.a) { s(d1, "Mode", 2) }
let both = probe(a) && probe(a -. 1.)
s(d1, "Setting", touched.contents)
s(d1, "On", both)`,
    devices: { d0: { Setting: 1 }, d1: {} },
  },
];

const examples = fs
  .readdirSync(path.join(root, "examples"))
  .filter((f) => f.endsWith(".res"))
  .map((f) => ({ file: f, name: "Ex_" + f.replace(/\.res$/, "") }));

const exampleSetups = {
  Ex_basic: {
    devices: { d0: { Temperature: 0 }, d1: {}, d2: {} },
    ticks: 6,
    inputs: seq(["d0", "Temperature"], [280, 295, 305, 299, 289, 310]),
  },
  Ex_furnace2: {
    devices: { d0: { Pressure: 0 }, d1: { Open: 0 }, d2: {} },
    ticks: 8,
    inputs: (d, t) => {
      d.d0.Pressure = [100, 30000, 60000, 60000, 60000, 60000, 20000, 400][t];
      d.d1.Open = [1, 1, 1, 0, 1, 1, 1, 0][t];
    },
  },
  Ex_furnace: {
    devices: { d0: { Open: 0 }, d1: { Open: 0 }, d2: { Temperature: 250 }, d3: {}, d4: { Temperature: 400 } },
    network: () =>
      [
        ["StructureAdvancedFurnace", "Furnace", { Temperature: 500, Pressure: 1000 }],
        ["StructureLogicDial", "FurnaceDialTemp", { Setting: 10 }],
        ["StructureLogicDial", "FurnaceDialPress", { Setting: 5 }],
        ["StructureConsoleLED5", "FurnaceLCD2", {}],
        ["StructureDigitalValve", "FurnaceTankValve", {}],
        ["StructureDigitalValve", "FurnaceAtmValve", {}],
      ].map(([p, n, values]) => ({ prefabHash: hash(p), nameHash: hash(n), values })),
    ticks: 6,
    inputs: (d, t, chip) => {
      chip.network[0].values.Pressure = [1000, 3000, 6000, 6000, 2000, 60000][t];
      d.d0.Open = [0, 0, 0, 0, 0, 1][t];
    },
  },
};

// Seeded random programs (tests/support/progen.mjs)
const RANDOM_PROGRAMS = Number(process.env.RIC10_FUZZ ?? 60);
const randomPrograms = Array.from({ length: RANDOM_PROGRAMS }, (_, i) => ({
  name: `Random${i}`,
  src: generateProgram(1000 + i),
  devices: inputsFor(1000 + i),
}));

const clone = (x) => structuredClone(x ?? {});
const round = (writes) =>
  writes.map((w) => {
    const v = Math.round(w.value * 1e9) / 1e9;
    return { ...w, value: Object.is(v, -0) ? 0 : v };
  });

let built = false;
beforeAll(() => {
  fs.rmSync(path.join(work, "src"), { recursive: true, force: true });
  fs.mkdirSync(path.join(work, "src"), { recursive: true });
  fs.writeFileSync(
    path.join(work, "rescript.json"),
    JSON.stringify({
      name: "ric10-differential",
      sources: [{ dir: "src" }],
      "package-specs": [{ module: "esmodule", "in-source": true }],
      suffix: ".res.mjs",
      "compiler-flags": ["-open IC10"],
      warnings: { number: "-a" },
    }),
  );
  fs.copyFileSync(path.join(root, "tests/support/IC10.runtime.res"), path.join(work, "src/IC10.res"));
  for (const p of [...programs, ...randomPrograms]) fs.writeFileSync(path.join(work, "src", `${p.name}.res`), p.src);
  for (const e of examples) fs.copyFileSync(path.join(root, "examples", e.file), path.join(work, "src", `${e.name}.res`));
  try {
    execFileSync(rescriptBin, [], { cwd: work, stdio: "pipe" });
  } catch (e) {
    throw new Error("ReScript rejected a differential program:\n" + e.stdout + e.stderr);
  }
  built = true;
}, 60000);

async function runBoth(name, src, setup) {
  const ticks = setup.ticks ?? Infinity;
  const network = setup.network ? setup.network() : [];
  const inputs = setup.inputs ?? (() => {});

  // 1. ReScript -> JS on the mock chip
  const chip = new JsChip({
    devices: clone(setup.devices),
    network: structuredClone(network),
    ticks,
    onTick: (c, t) => inputs(c.devices, t, c),
  });
  globalThis.__ic10 = chip;
  try {
    await import(pathToFileURL(path.join(work, "src", `${name}.res.mjs`)).href);
  } catch (e) {
    if (!(e instanceof StopSimulation)) throw e;
  }

  // 2. ric10 -> IC10 in the emulator
  const { code } = compile(src);
  // semantics only: the 128-line limit is checked by the examples tests
  const emu = new IC10(code, { devices: clone(setup.devices), network: structuredClone(network), maxLines: Infinity });
  if (ticks === Infinity) emu.runToEnd();
  else emu.run({ ticks, onTick: (e, t) => inputs(e.devices, t, e) });

  return { js: round(chip.writes), ic10: round(emu.writes), code };
}

describe("ric10 agrees with ReScript", () => {
  test.each(programs.map((p) => [p.name, p]))("%s", async (name, p) => {
    expect(built).toBe(true);
    const { js, ic10 } = await runBoth(name, p.src, p);
    expect(js.length).toBeGreaterThan(0);
    expect(ic10).toEqual(js);
  });

  test.each(randomPrograms.map((p) => [p.name, p]))("%s", async (name, p) => {
    expect(built).toBe(true);
    const { js, ic10, code } = await runBoth(name, p.src, p);
    if (JSON.stringify(ic10) !== JSON.stringify(js)) {
      console.log(`--- ${name} source ---\n${p.src}\n--- ic10 ---\n${code}`);
    }
    expect(ic10).toEqual(js);
  });

  test.each(examples.map((e) => [e.name, e]))("example %s", async (name, e) => {
    const src = fs.readFileSync(path.join(root, "examples", e.file), "utf8");
    const { js, ic10 } = await runBoth(name, src, exampleSetups[name] ?? {});
    expect(js.length).toBeGreaterThan(0);
    expect(ic10).toEqual(js);
  });
});
