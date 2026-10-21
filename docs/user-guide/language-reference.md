# Language reference

ric10 compiles a subset of ReScript 12. Everything below is valid ReScript: with the
bindings in `src/compiler/IC10.res` opened (`-open IC10`), the official compiler
type-checks your program, and ric10 compiles the same file to IC10.

## Values

IC10 registers hold doubles, so every value is a number:

| ReScript | On the chip |
|---|---|
| `int`, `float` | the number |
| `bool` | `1` / `0` |
| variant constructor | its index (`type t = A \| B` → `A = 0`, `B = 1`) plus payload slots |
| `device("d0")`, `d0`..`d5`, `db` | compile-time pin, costs nothing |
| `"Temperature"` | only as a logic-type argument of a binding |

`int` arithmetic follows ReScript where it matters: `7 / 2 == 3` (ric10 emits `trunc`
after `div`). Integers do not wrap at 32 bits and bitwise operators work on IC10's
53-bit values; `%` uses IC10 `mod`, which differs from JavaScript for negative operands.

Literals: `42`, `1_000`, `0xFF`, `0b1010`, `1.5`, `2.`, `1e-3`, `true`, `false`.

## Bindings and constants

```rescript
let limit = 500.           // top-level numeric literal -> `define limit 500`
let tank = hash("StructureTankSmall")   // -> `define tank HASH("StructureTankSmall")`
let t = l(d0, "Temperature")            // a register
let t = t - 273.15                      // shadowing is fine
```

Unused definitions disappear from the output. Defines are only emitted for top-level
literal lets whose name is not already defined.

## Operators

Precedence (lowest first), as in ReScript:

| Level | Operators |
|---|---|
| assignment | `:=`, `r.contents = v` |
| ternary | `c ? a : b` |
| logical | `\|\|`, then `&&` (short-circuit) |
| bitwise | `\|\|\|`, then `^^^`, then `&&&` |
| comparison | `== != === !== < <= > >=` |
| shift | `<< >> >>>` |
| additive | `+ - +. -.` |
| multiplicative | `* / % *. /.` |
| power | `**` (right associative) |
| unary | `- -. ! ~~~` (binds tighter than `**`: `-2 ** 2 == 4`) |
| postfix | `.contents`, calls, `->` |

`&&`/`||` used as values evaluate the right side only when needed if it has side effects;
pure operands compile to `and`/`or`. Comparisons of variants (`state == Idle`) compare the
tag and, against a constructor with payload, the payload.

## Control flow

```rescript
if t > limit { s(d1, "On", 0) } else if t < 290. { s(d1, "On", 1) }

let mode = if t < 60. { 0 } else if t < 80. { 1 } else { 2 }   // expression
let heat = t < 290. ? 1 : 0                                   // ternary

while true {
  // game loop
  yield()
}

for i in 0 to 5 { ... }
for i in 5 downto 0 { ... }
```

`if`, `switch` and `{ ... }` blocks are expressions; a block's value is its last
expression. Value-picking `if`s compile to `select` or a single `sXX` instead of jumps.
ReScript has no `break`/`continue`/`return`; use a ref flag or restructure the loop.

## Refs

```rescript
let count = ref(0)
count := count.contents + 1
count.contents = 10
```

Reading `.contents` takes a snapshot; later assignments do not change it. The register
allocator removes the copy whenever it is not needed, so `n := n.contents + 1` is a single
`add`.

## Functions

```rescript
let clamp = (x, lo, hi) => x < lo ? lo : x > hi ? hi : x
let toggle = (d) => s(d, "On", l(d, "On") == 0.)
let twice = (f, x) => f(f(x))

s(d1, "Setting", clamp(l(d0, "Setting"), 0., 100.))
toggle(d2)
let y = l(d0, "Setting")->Math.max(5.)
```

- Functions called once, very small functions, and functions receiving devices, strings,
  refs or other functions are inlined.
- Other functions are compiled once and called with `jal`. Arguments and results travel in
  registers chosen by the allocator; values the caller still needs are never overwritten.
  Functions that call other functions save `ra` in a register.
- Functions can read and assign top-level refs (closures).
- Recursion is rejected: IC10 has no stack frames.
- `let rec`, labeled and optional arguments are not supported.

Annotate a parameter with a variant type (`(s: state) => ...`) to pass variants to a
function that is not inlined.

## Variants and pattern matching

```rescript
type state = Idle | Loading(float) | Venting(float, int)

let st = ref(Idle)

st :=
  switch st.contents {
  | Idle => Loading(l(d0, "Pressure"))
  | Loading(p) if p > 50000. => Venting(p, 3)
  | Loading(p) => Loading(p)
  | Venting(_, 0) => Idle
  | Venting(p, n) => Venting(p, n - 1)
  }
```

- A variant value occupies one register for the tag plus one per payload slot of the
  largest constructor. Any number of refs and variables of the same type may exist.
- Patterns: constructors with variable, `_` or literal payloads; `A | B` (without
  bindings); `_`; a variable; number and boolean literals for `switch` on numbers.
- Guards: `| P if cond =>`.
- A non-exhaustive variant switch produces a warning; the last case of an exhaustive
  switch needs no test.
- Case bodies may contain several statements without braces.

`switch` also works on numbers:

```rescript
switch Float.toInt(l(d0, "Mode")) {
| 0 => s(d1, "On", 0)
| 1 | 2 => s(d1, "On", 1)
| n => s(d1, "Setting", n)
}
```

## Raw assembly

```rescript
%raw("sb -851746783 On 1")
```

The text is copied verbatim. Registers named in it (`r0`..`r15`) are excluded from
allocation for the whole program.

## Not supported

Records, tuples, arrays, lists, strings as values, `option`/`result`, modules, exceptions,
recursion, labeled arguments, `as` patterns, nested patterns inside payloads. Programs that
need more than 16 simultaneously live values are rejected with a list of the variables
involved (there is no spilling to the stack yet).

## Diagnostics

Errors carry `line:col` and often a hint:

```
[Parser.res][parsePrimary] 3:12: unexpected end of file in expression
[RegAlloc.res][allocate]: program needs more than 16 registers: 17 values are alive at once (a, b, ...)
  hint: shorten variable lifetimes, move values into refs that are reused, or split the program across chips
```

Warnings: non-exhaustive switch, unreachable case, constructor shadowing, more than 128
output lines, output lines longer than 90 characters.
