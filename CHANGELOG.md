# Changelog

## Unreleased

### Added

- `ric10 watch [dir]`: recompiles `.res` files on save and runs the project's
  `rescript watch` alongside; `npm run watch` in projects from `ric10 init`.

- `ls`/`ss` and `Slot.*` work on batch and named devices (`lbs`/`lbns`/`sbs`).
- `hash()` accepts any compile-time string, e.g. a parameter of an inlined helper.
- A `switch` that maps constructors to numbers linear in the tag (`| Idle => 0 | Busy => 1`)
  compiles to arithmetic on the tag instead of a chain of branches.

### Fixed

- `Logic.setting`, `Logic.settingInput`, `Logic.settingOutput` were compiled as setters.

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
  reused as soon as values die. When more than 16 values are alive at once, long-lived
  state (variant and ref cells) is spilled to the top of the stack (`put`/`get`) and
  temporaries keep their registers; the CLI reports the number of spilled values.
- Optimizer: constant folding, copy propagation, dead code elimination, jump threading,
  branch-free `select`/`sXX` for value-picking `if`s, removal of unused functions and
  defines. `bXXz`/`sXXz` forms for comparisons with zero.
- Bindings: `ls`, `ss`, `lbs`, `lbns`, `sbs`, `lr`, `isSet`, `yield`, `sleep`, stack
  operations including `getd`/`putd`, `select`, `lerp`, `Math.*`, `Float.toInt`,
  `Int.toFloat`.
- The IC10 instruction table (`tests/fixtures/ic10-instructions.json`, exported from the
  game via ic10lsp) is test data: every emitted opcode is checked against it and the
  emulator rejects anything outside it. `ld`, `sd`, `clr`, `poke` and `lerp` are no longer
  game instructions and are not emitted.
- Labeled function parameters and arguments (`(~weight, x) => ...`, `f(~weight=2., x)`).
- Stdlib coverage: `Math.pow`, `log10`, `log2`, `cbrt`, `sign`, `hypot`, `Float.clamp`,
  `Int.clamp`, `Float.mod`, `Int.mod`, `Float.isNaN`, `Float.equal`, `Int.bitwise*`,
  `Int.shift*`, `Math.Constants.pi/e`; game bindings `approx`, `approxZero`, `hcf`.
- Conditions on `isSet`, `Float.isNaN`, `approx` compile to `bdse`/`bdns`/`bnan`/`bap`/`bna`.
- Modules (`module Name = { ... }`, nested, `open`); qualified constructors in expressions
  and patterns. Functors and module aliases are rejected.
- Devices as values: `batch(prefab)` and `named(prefab, name)` work with `l`/`s` (Maximum
  by default, `lm` for another mode) and with the accessors.
- `Logic` and `Slot` accessor modules generated from the game's logic-type list
  (`scripts/gen-bindings.mjs`): `dev->Logic.temperature`, `dev->Logic.setOn(v)`,
  `Slot.occupied(dev, 0)`.
- `Prefab` module with all 1179 prefab hashes (`Prefab.structureTankSmall` compiles to
  `HASH("StructureTankSmall")`); data in `tests/fixtures/prefabs.json`, built by
  `scripts/import-prefabs.mjs`.
- `ss`/`sbs` write through a register, as the game requires.
- Diagnostics with line and column, hints, warnings for >128 lines and long lines.
- CLI: `-o`, `--stdout`, `--debug`, `--alias` (emit `alias name dX` for named devices),
  exit code 1 on errors.
- Test suite: IC10 emulator, differential tests against the real ReScript compiler,
  seeded program fuzzer, golden files for examples.

### Breaking changes

- `l()` returns `float`; compare with float literals (`t > 300.`). Values written with
  `s()` may be int, float or bool.
- Batch modes are constructors: `lb(h, "Pressure", Average)` instead of `"Average"`.
- Devices are `device("d0")` or `d0`..`d5`/`db`; integers are no longer devices.
- The WASM backend was removed (it had no control flow support and its tests ran against
  a stale build).
- The unfinished OpenAPI codegen experiment was removed from this repository (it lives on
  as the separate osury project).
- Generated JavaScript is ES modules (`*.res.mjs`); `@rescript/runtime` 12.1's CommonJS
  build does not load under Node or esbuild.

## 0.1.5

Initial npm releases: IR-based compiler with zero-argument functions, refs, variants on the
stack and device I/O.
