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
