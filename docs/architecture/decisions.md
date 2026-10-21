# Technical decisions

Short records of choices that shape the compiler, with the alternatives that were rejected.

## D1. Values are doubles; `int` division truncates

IC10 registers are doubles, and device values (temperatures, ratios) are fractional.
IRGen tracks a coarse numeric kind only to emit `trunc` after `/` when both operands are
`int`, matching ReScript.

Rejected: integer-only values (0.1 behaviour; wrong for every physical quantity), full type
inference (the real ReScript compiler already type-checks the program).

## D2. Variants live in registers

A variant is a tag register plus one register per payload slot of its widest constructor.

Rejected: the 0.1 fixed stack layout. It limited each type to one ref, made variants
impossible to pass or return, and cost `poke`/`get` lines on every access. The stack stays
free for user code.

## D3. Inline by default, `jal` when it pays

Single-use, tiny and higher-order functions, and functions receiving compile-time values,
are inlined; the rest are compiled once. IC10 programs are limited by lines, so inlining a
function used many times would not fit.

## D4. Whole-program register allocation, no calling convention

Arguments, results and saved `ra` are ordinary vregs. Liveness with call summaries makes
values that survive a call interfere with everything the callee writes.

Rejected: fixed argument/result registers with caller-saved spills to the stack (more
lines, and the 0.1 version clobbered registers anyway); per-function allocation (cannot
see what the caller keeps alive).

## D5. Branch-free value selection

`if`/`?:` that only pick a value compile to `select` or a single `sXX`; the optimizer also
turns `if/else` assignment diamonds into them. Fewer lines and no labels.

## D6. Constants become `define`

Top-level numeric literal lets become `define name value`, keeping names readable in game.
Each define costs a line; unused ones are removed. Shadowed names are inlined instead.

## D7. ES modules for generated JavaScript

`@rescript/runtime` 12.1.0 is `"type": "module"` but ships CommonJS in `lib/js`; Node and
esbuild both fail to load it. ES module output uses the working `lib/es6` build. Jest runs
with `--experimental-vm-modules`.

## D8. Testing by execution, with ReScript as oracle

An IC10 emulator executes compiler output; differential tests compare it with the same
program compiled by the real ReScript compiler; a seeded generator produces thousands of
such programs. Exact-text expectations are kept only for code-quality properties and golden
files of the examples.

Rejected: the 0.1 suite of exact-string expectations. It passed while `furnace2` and every
function with branches were miscompiled.

## D9. WASM backend removed

It had no structured control flow, used i32 values and its tests ran against a stale build.
The code is in `legacy/` for reference.

## Known limitations (tech debt)

- No spilling: more than 16 simultaneously live values is a compile error.
- No records, tuples or arrays (records and tuples could reuse the variant register-group
  representation; arrays would map to the stack).
- `%` follows IC10 `mod` (always non-negative), unlike JavaScript for negative operands.
- Bitwise operators use IC10's 53-bit semantics; ReScript uses 32-bit integers.
