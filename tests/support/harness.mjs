// Test helpers: compile ReScript with ric10 and execute the result in the
// IC10 emulator. Tests assert on observable behaviour (device writes, values)
// rather than on the exact text of the assembly.

import * as Compiler from "../../src/compiler/Compiler.res.mjs";
import { IC10 } from "./ic10.mjs";

export { IC10 } from "./ic10.mjs";

export function diagnostics(src, options) {
  return Compiler.compileWithDiagnostics(src, options);
}

export function compile(src, options) {
  const d = Compiler.compileWithDiagnostics(src, options);
  if (!d.ok) throw new Error(d.errors.map(Compiler.formatDiagnostic).join("\n"));
  return d;
}

export function asm(src, options) {
  return compile(src, options).code;
}

export function compileError(src) {
  const d = Compiler.compileWithDiagnostics(src);
  if (d.ok) throw new Error("expected a compile error, got:\n" + d.code);
  return d.errors.map(Compiler.formatDiagnostic).join("\n");
}

export function warnings(src) {
  return compile(src).warnings.map(Compiler.formatDiagnostic);
}

// Compile and run. `ticks: "end"` runs until the program falls off its end.
export function run(src, { devices = {}, network, byId, ticks = "end", onTick, strict } = {}) {
  const d = compile(src);
  const emu = new IC10(d.code, { devices, network, byId, strict });
  try {
    if (ticks === "end") emu.runToEnd();
    else emu.run({ ticks, onTick });
  } catch (e) {
    e.message += "\n--- program ---\n" + d.code;
    throw e;
  }
  return { emu, code: d.code, stats: d.stats, devices: emu.devices };
}

// Evaluate a ReScript expression on the chip and return its value.
// `prelude` may declare types, functions and variables.
export function evaluate(expr, prelude = "", devices = {}) {
  const src = `${prelude}\ns(db, "Setting", ${expr})`;
  const { devices: out } = run(src, { devices });
  return out.db.Setting;
}

// All values written to `target.prop`, in order
export function writesTo(emu, target, prop) {
  return emu.writes.filter((w) => w.target === target && w.prop === prop).map((w) => w.value);
}

export function lineCount(code) {
  return code.split("\n").length;
}

export function labelsOf(code) {
  return code.split("\n").filter((l) => /^[A-Za-z_][\w.]*:$/.test(l)).map((l) => l.slice(0, -1));
}
