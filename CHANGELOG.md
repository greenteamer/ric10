# Changelog

## 0.2.0

A rewrite of the compiler core. Programs that compiled before may need small edits
to type-check against the new bindings (see "Breaking changes").

### Fixed

- Functions reused labels and registers of the main program: a call could overwrite
  live values, and the output could contain duplicate labels.
- `x + 1 > 5` parsed as `x + (1 > 5)`: comparisons bound tighter than arithmetic.
- In switch cases, a jump at the end of an `if` branch could be lost, so execution fell
  into the next case (`examples/furnace2.res`: Loading → Unloading went straight to Idle).
- Nested function calls lost their return address.
- `move sp` for variants was emitted with the wrong size.

### Added

- Full expression language: `>= <= != && || !`, `false`, unary minus, floats, `%`, `**`,
  bitwise operators, `c ? a : b`, `if`/`switch`/blocks as values, `for` loops, pipes.
- Functions with parameters and return values; inlining of single-use, tiny and
  higher-order functions; refs and devices can be passed to functions.
- Variants live in registers: any number of refs per variant type, variant values can
  be bound, compared (`==`), passed and returned. Or-patterns, guards, literal patterns,
  exhaustiveness warnings.
- Register allocation based on whole-program liveness with copy coalescing; registers are
  reused as soon as values die. Errors name the variables alive at the point of pressure.
- Optimizer: constant folding, copy propagation, dead code elimination, jump threading,
  branch-free `select`/`sXX` for value-picking `if`s, removal of unused functions and
  defines. `bXXz`/`sXXz` forms for comparisons with zero.
- Bindings: `ls`, `ss`, `lbs`, `lbns`, `sbs`, `lr`, `deviceId` (`ld`/`sd`), `isSet`,
  `yield`, `sleep`, stack operations, `select`, `lerp`, `Math.*`, `Float.toInt`,
  `Int.toFloat`.
- Diagnostics with line and column, hints, warnings for >128 lines and long lines.
- CLI: `-o`, `--stdout`, `--debug`, exit code 1 on errors.
- Test suite: IC10 emulator, differential tests against the real ReScript compiler,
  seeded program fuzzer, golden files for examples.

### Breaking changes

- `l()` returns `float`; compare with float literals (`t > 300.`). Values written with
  `s()` may be int, float or bool.
- Batch modes are constructors: `lb(h, "Pressure", Average)` instead of `"Average"`.
- Devices are `device("d0")` or `d0`..`d5`/`db`; integers are no longer devices.
- The WASM backend was removed (it had no control flow support and its tests ran against
  a stale build).
- Generated JavaScript is ES modules (`*.res.mjs`); `@rescript/runtime` 12.1's CommonJS
  build does not load under Node or esbuild.

## 0.1.5

Initial npm releases: IR-based compiler with zero-argument functions, refs, variants on the
stack and device I/O.
