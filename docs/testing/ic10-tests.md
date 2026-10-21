# Testing

```bash
npm test                     # everything below except the deep fuzz run
npm test -- functions        # one suite
npm run test:fuzz            # 2000 random programs against ReScript
npm run golden:update        # rewrite tests/golden/*.ic10 after an intended change
```

Jest runs native ES modules (`--experimental-vm-modules`); test files are `tests/*.test.mjs`
and import the compiled `src/compiler/*.res.mjs`. Run `npm run res:build` first if sources
changed.

## Layers

| Suite | What it proves |
|---|---|
| `expressions`, `control-flow`, `refs-variants`, `functions`, `devices` | language semantics, by running output in the emulator |
| `regalloc` | register reuse, the 16-register limit, values surviving calls |
| `errors` | messages, locations, hints, warnings |
| `codegen` | pass order, binding sync, code-quality properties (z-forms, `select`, dead code) |
| `examples` | `examples/*.res` compile without warnings, fit 128 lines, match golden files, behave in scripted scenarios |
| `differential` | ReScript and ric10 produce the same device-write traces for hand-written programs, the examples and 60 seeded random programs |

## The emulator (`tests/support/ic10.mjs`)

Executes IC10 with mock devices (`devices: {d0: {...}}`), a batch network
(`network: [{prefabHash, nameHash, values}]`), ReferenceId devices (`byId`), the 512-slot
stack and tick accounting (a tick ends at `yield`/`sleep` or after 128 lines). It records
every device write as `{tick, target, prop, value}`.

It is strict on purpose: duplicate or undefined labels, unknown instructions, reads of
missing logic types and programs over 128 lines throw.

Helpers in `tests/support/harness.mjs`:

```js
run(src, { devices, network, ticks: 5, onTick: (emu, tick) => {...} }) // { emu, code, devices }
evaluate("a * 2.", "let a = l(d0, \"Setting\")", { d0: { Setting: 3 } }) // 6
asm(src); compileError(src); warnings(src); writesTo(emu, "d1", "On")
```

## Differential tests

`tests/differential.test.mjs` writes each program to `tests/.work/src`, together with
`tests/support/IC10.runtime.res`, a twin of the bindings whose functions call a mock chip
(`tests/support/jsChip.mjs`). The real ReScript compiler builds that directory; each program
is imported with the same devices and per-tick inputs as the emulator run. The two traces
must be equal.

`tests/support/progen.mjs` generates random programs from a seed: float arithmetic, `Math.*`,
ternaries, refs, `if`, `for`, `while`, variants with guards, and functions called several
times so they are compiled out of line. Programs that genuinely need more than 16 registers
are accepted as correctly rejected. `RIC10_FUZZ=N` sets the number of programs.
