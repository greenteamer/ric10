// Generates the `Logic` and `Slot` accessor modules from the game's instruction
// table and writes them between the GENERATED markers of
//   src/compiler/IC10.res            (type-checking bindings shipped to users)
//   tests/support/IC10.runtime.res   (executable twin for differential tests)
//
//   node scripts/gen-bindings.mjs            # rewrite both files
//   node scripts/gen-bindings.mjs --check    # exit 1 when a file is stale
import fs from "fs";
import path from "path";

const root = path.resolve(import.meta.dirname, "..");
const table = JSON.parse(fs.readFileSync(path.join(root, "tests/fixtures/ic10-instructions.json"), "utf8"));

const KEYWORDS = new Set(
  "and as assert constraint else exception external false for if in include lazy let module mutable of open rec switch true try type when while with private".split(" "),
);

// "SettingInput" -> "settingInput", "Open" -> "open_"
export function accessorName(logicType) {
  const n = logicType[0].toLowerCase() + logicType.slice(1);
  return KEYWORDS.has(n) ? n + "_" : n;
}

// inverse of accessorName, used by the compiler: "open_" -> "Open"
export function logicTypeOf(accessor) {
  const n = accessor.endsWith("_") ? accessor.slice(0, -1) : accessor;
  return n[0].toUpperCase() + n.slice(1);
}

export function generate() {
  const lines = [];
  lines.push("// Typed accessors for every logic type the game knows: Logic.temperature(d) is");
  lines.push('// l(d, "Temperature"), Logic.setOn(d, v) is s(d, "On", v); a typo is a type error.');
  lines.push("module Logic = {");
  for (const t of table.logicTypes) {
    const a = accessorName(t);
    const setter = "set" + t;
    lines.push(`  let ${a} = (d: device): float => l(d, "${t}")`);
    lines.push(`  let ${setter} = (d: device, v: 'a): unit => s(d, "${t}", v)`);
  }
  lines.push("}");
  lines.push("");
  lines.push('// Slot accessors: Slot.occupied(d, 0) is ls(d, 0, "Occupied").');
  lines.push("module Slot = {");
  for (const t of table.slotLogicTypes) {
    const a = accessorName(t);
    lines.push(`  let ${a} = (d: device, slot: int): float => ls(d, slot, "${t}")`);
    lines.push(`  let set${t} = (d: device, slot: int, v: 'a): unit => ss(d, slot, "${t}", v)`);
  }
  lines.push("}");
  return lines.join("\n") + "\n";
}

const BEGIN = "// --- BEGIN GENERATED (scripts/gen-bindings.mjs) ---";
const END = "// --- END GENERATED ---";

export function splice(source) {
  const a = source.indexOf(BEGIN);
  const b = source.indexOf(END);
  if (a < 0 || b < 0) throw new Error("GENERATED markers not found");
  return source.slice(0, a + BEGIN.length) + "\n" + generate() + source.slice(b);
}

const targets = ["src/compiler/IC10.res", "tests/support/IC10.runtime.res"];

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename)) {
  const check = process.argv.includes("--check");
  let stale = false;
  for (const t of targets) {
    const file = path.join(root, t);
    const current = fs.readFileSync(file, "utf8");
    const next = splice(current);
    if (next !== current) {
      stale = true;
      if (check) console.error(`${t} is out of date; run node scripts/gen-bindings.mjs`);
      else fs.writeFileSync(file, next);
    }
  }
  if (check && stale) process.exit(1);
  if (!check) console.log(`generated ${table.logicTypes.length} logic types, ${table.slotLogicTypes.length} slot types`);
}
