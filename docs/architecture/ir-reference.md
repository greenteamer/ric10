# IR reference

Defined in `src/compiler/IR/IR.res`. A program is `array<block>`: `main` first, then one
block per out-of-line function (its first instruction is the function's label).

## Operands

| Operand | Meaning | Printed as |
|---|---|---|
| `VReg(n)` | virtual register | `rX` after allocation, `vN` in dumps |
| `Num(f)` | immediate double | `5`, `1.5`, `-0.25` |
| `Name(s)` | `define`d constant | `s` |
| `Hash(s)` | game hash | `HASH("s")` |
| `Special(s)` | non-allocatable register | `ra`, `sp` |

## Devices

| Device | Load / store |
|---|---|
| `Pin("d0")` | `l` / `s` |
| `Batch(prefab)` | `lb` / `sb` (with batch mode on load) |
| `BatchNamed(prefab, name)` | `lbn` / `sbn` |

## Instructions

| Instruction | IC10 |
|---|---|
| `DefNum(name, v)`, `DefHash(name, s)` | `define name v` |
| `Move(d, a)` | `move d a` |
| `Unary(d, op, a)` | `abs sqrt floor ceil round trunc sin cos tan asin acos atan exp log not` |
| `Binary(d, op, a, b)` | `add sub mul div mod min max and or xor sll srl sra atan2` |
| `Compare(d, op, a, b)` | `slt sle sgt sge seq sne`; `sXXz d a` when `b` is 0 |
| `Select(d, c, a, b)` | `select d c a b` |
| `Label(l)`, `Goto(l)` | `l:`, `j l` |
| `Branch(op, a, b, l)` | `blt ble bgt bge beq bne`; `bXXz a l` when one side is 0 |
| `BranchIf(opcode, args, l)` | other conditional jumps: `bdse bdns bnan bap bna bapz bnaz` |
| `Call(f)`, `Return`, `ReturnVia(v)` | `jal f`, `j ra`, `j rX` |
| `DeviceLoad(d, dev, logicType, mode)` | `l`/`lb`/`lbn` |
| `DeviceStore(dev, logicType, v)` | `s`/`sb`/`sbn` |
| `Native(opcode, d?, args, sideEffects)` | any other instruction: `ls ss lbs lbns sbs lr sdse sdns snan sap sapz yield sleep push pop peek get put getd putd rand hcf alias` |
| `Raw(text)` | verbatim |

## Analyses (in IR.res)

- `uses(i)`, `def(i)`: vregs read and written.
- `isPure(i)`: removable when its result is dead (moves, arithmetic, compares, selects,
  loads, side-effect-free natives).
- `isTerminator(i)`: `Goto`, `Return`, `ReturnVia`.
- `branchTarget(i)`: label of `Goto`, `Branch`, `BranchIf`.
- `mapUses(i, f)`: rewrite read operands (used by copy propagation).
- `invertCmp`, `evalCmp`.

When adding an instruction or operand, update every exhaustive `switch` over these types:
`IR.res` (all helpers), `IRGen.res`, `IROptimizer.res`, `IRToIC10.res`. The compiler warns
on non-exhaustive matches; treat that warning as an error.

## Example

```rescript
let t = l(d0, "Temperature")
s(d1, "On", t > 300. ? 1 : 0)
```

IR after optimization (`ric10 --debug`):

```
# block main
l v0 d0 Temperature
sgt v1 v0 300
s d1 On v1
```
