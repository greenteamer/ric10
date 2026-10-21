# IC10 bindings

`src/compiler/IC10.res` declares the IC10 operations as ordinary ReScript functions so the
official compiler can type-check your program. ric10 recognizes the same names and emits
the matching instructions. `ric10 init` copies this file into new projects.

Logic types and slot logic types are string literals (`"Temperature"`, `"Occupied"`).
Values written to devices may be `int`, `float` or `bool`.

## Devices

| ReScript | IC10 |
|---|---|
| `device("d0")` … `device("d5")`, `device("db")` | compile-time pin |
| `d0` … `d5`, `db` | the same pins, predefined |
| `deviceId(referenceId)` | device addressed by ReferenceId (`ld` / `sd`) |
| `isSet(dev)`, `isNotSet(dev)` | `sdse` / `sdns` |

## Reading and writing

| ReScript | IC10 |
|---|---|
| `l(dev, "Temperature")` | `l r? d? Temperature` (or `ld` for `deviceId`) |
| `s(dev, "On", v)` | `s d? On v` (or `sd`) |
| `ls(dev, slot, "Occupied")` | `ls r? d? slot Occupied` |
| `ss(dev, slot, "Lock", v)` | `ss d? slot Lock v` |
| `lr(dev, Contents, reagentHash)` | `lr r? d? Contents hash` |

## Batch operations

`batchMode` is `Average | Sum | Minimum | Maximum`.

| ReScript | IC10 |
|---|---|
| `hash("StructureTankSmall")` | `HASH("StructureTankSmall")` (a `define` at top level) |
| `lb(prefab, "Pressure", Average)` | `lb r? prefab Pressure Average` |
| `lbn(prefab, name, "Pressure", Maximum)` | `lbn r? prefab name Pressure Maximum` |
| `sb(prefab, "On", v)` | `sb prefab On v` |
| `sbn(prefab, name, "On", v)` | `sbn prefab name On v` |
| `lbs(prefab, slot, "Quantity", Sum)` | `lbs r? prefab slot Quantity Sum` |
| `lbns(prefab, name, slot, "Quantity", Sum)` | `lbns ...` |
| `sbs(prefab, slot, "Lock", v)` | `sbs ...` |

## Execution and stack

| ReScript | IC10 |
|---|---|
| `yield()` | `yield` |
| `sleep(seconds)` | `sleep seconds` |
| `push(v)`, `pop()`, `peek()` | `push`, `pop`, `peek` |
| `poke(addr, v)` | `poke addr v` |
| `get(dev, addr)`, `put(dev, addr, v)`, `clr(dev)` | `get`, `put`, `clr` |

ric10 uses the stack only when a program has more than 16 simultaneously live values; it
then takes slots from address 511 downwards. `push`/`pop` grow from address 0, so the two
do not collide unless the stack is nearly full.

## Math

Use the standard library; ric10 maps these to single instructions:

`Math.abs`, `Math.sqrt`, `Math.floor`, `Math.ceil`, `Math.round`, `Math.trunc`,
`Math.sin`, `Math.cos`, `Math.tan`, `Math.asin`, `Math.acos`, `Math.atan`, `Math.atan2`,
`Math.exp`, `Math.log`, `Math.min`, `Math.max`, `Math.Int.min`, `Math.Int.max`,
`Math.Int.abs`, `Math.random` (`rand`), `Float.toInt` (`trunc`), `Int.toFloat` (no code).

Also from `IC10.res`: `select(cond, a, b)` (`select`), `lerp(a, b, t)` (`lerp`),
`rand()`.

## Anything else

`%raw("instruction ...")` emits text verbatim; registers it names are reserved.
