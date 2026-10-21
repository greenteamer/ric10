# ric10

Write [Stationeers](https://store.steampowered.com/app/544550/Stationeers/) IC10
scripts in [ReScript](https://rescript-lang.org) and compile them to IC10 assembly.

Your source is real ReScript: the official ReScript compiler type-checks it (with the
bindings in `IC10.res`), and `ric10` turns the same file into compact IC10 that fits
the chip's 16 registers and 128 lines.

```rescript
type state = Idle | Heating | Venting(float)

let sensor = device("d0")
let heater = device("d1")
let vent = device("d2")

let state = ref(Idle)

while true {
  let t = l(sensor, "Temperature")
  let p = l(sensor, "Pressure")
  state :=
    switch state.contents {
    | _ if p > 5000. => Venting(p)
    | Venting(_) if p > 1000. => Venting(p)
    | _ if t < 290. => Heating
    | _ => Idle
    }
  s(heater, "On", state.contents == Heating)
  s(vent, "On", switch state.contents { | Venting(_) => true | _ => false })
  yield()
}
```

## Install

```bash
npm install -D rescript-ic10-compiler
```

or start a new project with type-checked bindings:

```bash
npx ric10 init my-scripts
```

## Usage

```bash
npx ric10 furnace.res              # writes furnace.ic10
npx ric10 furnace.res --stdout     # print instead
npx ric10 furnace.res -o chip.ic10
npx ric10 furnace.res --debug      # also print the IR
```

The CLI prints warnings (non-exhaustive switch, more than 128 lines, lines longer than
90 characters) and the number of lines and registers used.

From JavaScript, in this repository (after `npm run res:build`):

```js
import * as Compiler from "./src/compiler/Compiler.res.mjs";
const d = Compiler.compileWithDiagnostics(source);
d.ok ? console.log(d.code) : console.error(d.errors.map(Compiler.formatDiagnostic));
```

## Language

A subset of ReScript 12, all of it valid ReScript:

- `let`, shadowing, blocks, `if`/`switch`/blocks as expressions, `c ? a : b`
- numbers are IC10 doubles; `int` division truncates like ReScript; `true`/`false` are 1/0
- all operators: `+ - * / % **`, `+.` family, comparisons, `&& || !`, `&&& ||| ^^^ ~~~ << >> >>>`
- `ref`, `:=`, `.contents`, `while`, `for i in a to b` / `downto`
- functions with parameters and results, closures over top-level values, pipes `->`,
  higher-order functions (inlined)
- variants with payloads, `switch` with or-patterns, guards, literal and wildcard patterns
- IC10 bindings: `l`, `s`, `ls`, `ss`, `lb`, `lbn`, `sb`, `sbn`, `lbs`, `lbns`, `sbs`,
  `deviceId` (`ld`/`sd`), `hash`, `isSet`, `yield`, `sleep`, stack (`push`, `pop`,
  `peek`, `poke`, `get`, `put`, `clr`), `select`, `lerp`, `Math.*`
- `%raw("...")` for anything else; registers it mentions are left alone

Not supported (yet): records, tuples, arrays, strings beyond logic-type names, recursion,
spilling when more than 16 values are alive at once.

See [docs/user-guide/language-reference.md](docs/user-guide/language-reference.md) and
[docs/user-guide/ic10-bindings.md](docs/user-guide/ic10-bindings.md).

## How it works

Lexer → Pratt parser → IRGen → optimizer (passes run to a fixpoint) → whole-program
liveness → register allocation with copy coalescing → IC10. Functions called once are
inlined; others are called with `jal`, and liveness keeps callee registers away from
values the caller still needs. See [docs/architecture/compiler-overview.md](docs/architecture/compiler-overview.md).

## Testing

```bash
npm test             # unit, emulator and differential tests
npm run test:fuzz    # 2000 random programs checked against ReScript
```

Generated code is executed in an IC10 emulator (`tests/support/ic10.mjs`). Differential
tests compile each program with the real ReScript compiler too and require identical
device-write traces. See [docs/testing/ic10-tests.md](docs/testing/ic10-tests.md).

## License

MIT
