// Output-shape tests: the pipeline contract and code quality properties.
import fs from "fs";
import path from "path";
import * as IROptimizer from "../src/compiler/IR/IROptimizer.res.mjs";
import * as TemplateFiles from "../scripts/TemplateFiles.res.mjs";
import { asm, compile, lineCount } from "./support/harness.mjs";

const root = path.resolve(import.meta.dirname, "..");

describe("pipeline contract", () => {
  test("optimizer pass order", () => {
    // Changing the order changes the output: update this list deliberately.
    expect(IROptimizer.passNames).toEqual([
      "foldConstants",
      "propagateCopies",
      "eliminateDeadCode",
      "branchesToSelect",
      "simplifyJumps",
      "removeUnusedFunctions",
      "removeUnusedDefines",
    ]);
  });

  test("ric10 init ships the same bindings as the compiler", () => {
    const bindings = fs.readFileSync(path.join(root, "src/compiler/IC10.res"), "utf8");
    expect(TemplateFiles.ic10Bindings).toBe(bindings);
  });
});

describe("code quality", () => {
  test("comparison with zero uses the z-forms", () => {
    expect(asm(`let x = l(d0, "Setting")\nif x > 0. { s(d1, "On", 1) }`)).toMatch(/^blez r0 /m);
    expect(asm(`let x = l(d0, "Setting")\ns(d1, "On", x == 0.)`)).toMatch(/^seqz r0 r0$/m);
  });

  test("unused code and functions disappear", () => {
    const code = asm(`
let unused = x => x * 2
let alsoUnused = l(d0, "Setting") * 3.
s(d1, "On", 1)`);
    expect(code).toBe("s d1 On 1");
  });

  test("unused defines are dropped", () => {
    expect(asm(`let a = 1\nlet b = 2\ns(d0, "Setting", b)`)).toBe("define b 2\ns d0 Setting b");
  });

  test("a branchy state update stays compact", () => {
    const code = asm(`
let btn = device("d1")
type action = Start | Stop
let action = ref(Stop)
while true {
  if l(btn, "Open") == 1. { action := Start } else { action := Stop }
  s(d0, "On", action.contents == Start ? 1 : 0)
  yield()
}`);
    expect(lineCount(code)).toBeLessThanOrEqual(7);
  });
});

describe("instruction table", () => {
  const table = JSON.parse(fs.readFileSync(path.join(root, "tests/fixtures/ic10-instructions.json"), "utf8"));
  const src = (f) => fs.readFileSync(path.join(root, f), "utf8");

  test("every opcode the backend can emit exists in the game", () => {
    const backend = src("src/compiler/IR/IRToIC10.res");
    const names = new Set();
    // opcode tables: `| Add => "add"` and native calls: native("ls", ...)
    for (const m of backend.matchAll(/=> "([a-z0-9]+)"/g)) names.add(m[1]);
    for (const m of src("src/compiler/IR/IRGen.res").matchAll(/native\("([a-z0-9]+)"/g)) names.add(m[1]);
    for (const m of src("src/compiler/IR/RegAlloc.res").matchAll(/Native\("([a-z0-9]+)"/g)) names.add(m[1]);
    for (const c of ["lt", "le", "gt", "ge", "eq", "ne"]) for (const f of [`s${c}`, `s${c}z`, `b${c}`, `b${c}z`]) names.add(f);
    for (const f of ["j", "jal", "define", "move", "l", "s", "lb", "lbn", "sb", "sbn"]) names.add(f);
    const unknown = [...names].filter((n) => !/^(lt|le|gt|ge|eq|ne)$/.test(n) && !table.instructions[n]);
    expect(unknown).toEqual([]);
  });

  test("the bindings table in the docs only names game instructions", () => {
    const doc = src("docs/user-guide/ic10-bindings.md");
    const mentioned = new Set();
    for (const line of doc.split("\n")) {
      if (!line.startsWith("|")) continue;
      const cell = line.split("|")[2] ?? "";
      for (const m of cell.matchAll(/`([a-z]+)\b/g)) mentioned.add(m[1]);
    }
    const unknown = [...mentioned].filter((n) => !table.instructions[n]);
    expect(unknown).toEqual([]);
  });

  test("the table is the one exported from the game", () => {
    expect(Object.keys(table.instructions).length).toBe(140);
    expect(table.instructions.ld).toBeUndefined();
    expect(table.instructions.getd.operands).toEqual([["Register"], ["Register", "Number"], ["Register", "Number"]]);
  });
});
