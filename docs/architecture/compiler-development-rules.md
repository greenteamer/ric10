# Compiler development rules

Project invariants. Each rule names the failure it prevents. Reasons and rejected
alternatives live in [decisions.md](decisions.md).

## 1. One pipeline

`Lexer → Parser → IRGen → IROptimizer → IRToIC10`. A feature exists once it is expressed in
IR; no AST-to-assembly shortcuts. (Before 0.2 a legacy path and the IR path coexisted and
drifted apart.)

## 2. The source language is ReScript

Every construct ric10 accepts must be valid ReScript 12 and mean the same thing. Check new
syntax against the real compiler (`tests/.work` or a scratch project) before implementing
it. Operator precedence was copied from compiled ReScript output, not from memory.
(Before 0.2 `x + 1 > 5` parsed as `x + (1 > 5)`.)

## 3. Exhaustive matches over IR

Adding an operand, device or instruction means updating every `switch` over it: `IR.res`
helpers, `IRGen`, `IROptimizer`, `IRToIC10`. Pattern-match warnings are blocking.

## 4. Virtual registers until the end

IRGen and the optimizer use unlimited vregs. Only `RegAlloc` maps them to r0..r15. Do not
emit physical registers from earlier phases; `%raw` registers are reserved, not modelled.

## 5. Whole-program liveness owns correctness across calls

Never special-case "registers a function may use". Values that must survive a call are live
inside the callee by construction (`Liveness.res`). (Before 0.2 functions reused the
caller's registers and labels.)

## 6. Passes are data

Add optimizations to `IROptimizer.makePasses`, with a comment saying why the position is
right, and update the pass-order test. Passes must be semantics-preserving for every input
including NaN and Infinity (`x * 0 → 0` was removed for that reason).

## 7. Errors are structured

Raise with `Errors.fail(~file, ~fn, ~loc, ~hint?, message)`. Include a location whenever
the AST has one; add a hint when the fix is not obvious. `Errors.format` is the only place
a diagnostic becomes text.

## 8. Behaviour is tested by execution

Every feature gets emulator tests (`tests/*.test.mjs`) that assert on device writes, not on
assembly text. Assembly-shape assertions are only for code-quality properties (line count,
`select` instead of jumps, no copies). A green golden file proves nothing about semantics.

## 9. ReScript is the oracle

Programs in `tests/differential.test.mjs` and the fuzzer must produce the same device-write
trace when compiled by ReScript to JS and by ric10 to IC10. Run `npm run test:fuzz` after
touching IRGen, the optimizer or the allocator.

## 10. The emulator is strict

`tests/support/ic10.mjs` throws on duplicate labels, undefined labels, unknown
instructions, missing logic types and programs over the line limit. Do not loosen it to
make a test pass; fix the compiler.

## 11. Bindings have one source

`src/compiler/IC10.res` is the API. `scripts/TemplateFiles.res` embeds it verbatim and
`tests/support/IC10.runtime.res` mirrors its signatures; tests keep them in sync.

## 12. Docs move with the code

Changing a language feature updates `docs/user-guide/language-reference.md`; changing an
invariant updates this file and `decisions.md`.

## Checklist before merge

1. The feature is expressed in IR and accepted by the real ReScript compiler.
2. Emulator tests cover it; `npm test` is green.
3. `npm run test:fuzz` is green when codegen changed.
4. Golden files updated deliberately (`npm run golden:update`) and the diff reviewed.
5. Docs updated.
