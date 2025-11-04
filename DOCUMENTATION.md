# ReScript → IC10 Compiler Documentation

Complete language reference for the ReScript to IC10 assembly compiler.

## Table of Contents

- [Overview](#overview)
- [Basic Syntax](#basic-syntax)
- [Variables](#variables)
- [Literals](#literals)
- [Operators](#operators)
- [Control Flow](#control-flow)
- [Mutable References](#mutable-references)
- [Variant Types](#variant-types)
- [Pattern Matching](#pattern-matching)
- [Raw Assembly Instructions](#raw-assembly-instructions)
- [IC10 Target Details](#ic10-target-details)
- [Limitations](#limitations)

---

## Overview

This compiler translates a subset of ReScript to IC10 assembly language for the Stationeers game. It supports essential programming constructs while targeting IC10's 16-register architecture.

**Key Features:**
- ✅ Variables and expressions
- ✅ Arithmetic and comparison operations
- ✅ If/else conditionals
- ✅ While loops (including infinite loops)
- ✅ Mutable references
- ✅ Variant types (enums)
- ✅ Pattern matching
- ✅ Raw IC10 assembly injection
- ✅ Register allocation and optimization

---

## Basic Syntax

### Variable Declarations

Variables are immutable by default (use refs for mutability):

```rescript
let x = 5
let y = x + 3
let result = x * y
```

**Compiles to:**
```assembly
move r0 5
add r1 r0 3
mul r2 r0 r1
```

### Comments

ReScript-style comments:
```rescript
// Single-line comment
let x = 10  // End-of-line comment
```

---

## Literals

### Integer Literals

```rescript
let zero = 0
let positive = 42
let negative = -10  // Note: implemented as 0 - 10
```

### Boolean Literals

```rescript
let flag = true  // Compiles to 1
```

**Note:** `false` is not yet implemented. Use `0` for false values.

---

## Operators

### Arithmetic Operators

```rescript
let sum = 5 + 3       // Addition
let diff = 10 - 4     // Subtraction
let product = 6 * 7   // Multiplication
let quotient = 20 / 4 // Integer division
```

**Compiles to:**
```assembly
add r0 5 3
sub r1 10 4
mul r2 6 7
div r3 20 4
```

### Comparison Operators

```rescript
let isGreater = x > y   // Greater than
let isLess = x < y      // Less than
let isEqual = x == y    // Equal to
```

**Note:** Other comparison operators (`>=`, `<=`, `!=`) are not yet implemented.

### Operator Precedence

Standard precedence rules apply:
1. `*`, `/` (multiplication, division)
2. `+`, `-` (addition, subtraction)
3. `<`, `>`, `==` (comparisons)

Use parentheses to override:
```rescript
let result = (5 + 3) * 2  // Evaluates to 16
```

---

## Control Flow

### If Statements

```rescript
if x > 5 {
  let a = 1
}
```

**Compiles to:**
```assembly
move r0 10
bge r0 6 label0
move r1 1
label0:
```

### If-Else Statements

```rescript
if x > 5 {
  let a = 1
} else {
  let a = 2
}
```

**Compiles to:**
```assembly
move r0 10
bgt r0 5 label1
move r1 2
j label0
label1:
move r1 1
label0:
```

### Nested If Statements

```rescript
if x > 0 {
  if y > 0 {
    let positive = 1
  }
}
```

### While Loops

```rescript
let counter = ref(0)
while counter.contents < 10 {
  counter := counter.contents + 1
}
```

**Compiles to:**
```assembly
move r0 0
label0:
move r15 r0
bge r15 10 label1
add r0 r0 1
j label0
label1:
```

### Infinite Loops

Use `while true` for game loops:

```rescript
while true {
  // Game logic here
  %raw("yield")
}
```

**Compiles to:**
```assembly
label0:
move r15 1
beqz r15 label1
yield
j label0
label1:
```

### Nested Loops

```rescript
let i = ref(0)
while i.contents < 3 {
  let j = ref(0)
  while j.contents < 2 {
    j := j.contents + 1
  }
  i := i.contents + 1
}
```

---

## Mutable References

Since ReScript variables are immutable by default, use `ref()` for mutable state:

### Creating References

```rescript
let counter = ref(0)
let temperature = ref(273)
```

### Reading Reference Values

Use `.contents` to read the current value:

```rescript
let current = counter.contents
let doubled = counter.contents * 2
```

### Updating References

Use the `:=` operator to update:

```rescript
counter := counter.contents + 1
temperature := 300
```

### Complete Example

```rescript
let score = ref(0)

while score.contents < 100 {
  score := score.contents + 10
}
```

**Compiles to:**
```assembly
move r0 0
label0:
move r15 r0
bge r15 100 label1
add r0 r0 10
j label0
label1:
```

---

## Variant Types

Variant types (also known as enums or algebraic data types) allow you to define custom types with multiple cases:

### Basic Variants (Tag-Only)

```rescript
type State = Idle | Running | Complete

let currentState = Idle
```

### Variants with Payloads

```rescript
type Result = Success(int) | Failure(int)

let result = Success(42)
let error = Failure(404)
```

### Using Variants

```rescript
type Direction = North | South | East | West

let heading = North
```

**Compiles to:**
```assembly
push 0
move r15 sp
sub r15 r15 1
move r0 r15
```

**Implementation Notes:**
- Variants are compiled to stack-based tagged unions
- Tag-only constructors push a tag value onto the stack
- Constructors with payloads push both tag and value
- Each variant case gets a numeric tag (0, 1, 2, ...)

---

## Pattern Matching

Use `switch` expressions to match on variant values:

### Basic Pattern Matching

```rescript
type State = Idle | Running | Done

let state = Running

let statusCode = switch state {
| Idle => 0
| Running => 1
| Done => 2
}
```

### Matching Variants with Payloads

```rescript
type Result = Success(int) | Failure(int)

let result = Success(42)

let value = switch result {
| Success(code) => code
| Failure(err) => err * -1
}
```

### Multiple Case Bodies

```rescript
type Temperature = Cold | Warm | Hot

let temp = Warm

switch temp {
| Cold => {
  let heater = 1
  let cooler = 0
}
| Warm => {
  let heater = 0
  let cooler = 0
}
| Hot => {
  let heater = 0
  let cooler = 1
}
}
```

**Implementation Notes:**
- Pattern matching compiles to efficient tag comparisons
- Each case generates a unique label
- Bindings (like `code` in `Success(code)`) allocate registers
- All cases must be covered (exhaustiveness checking)

---

## Raw Assembly Instructions

For advanced use cases, inject raw IC10 assembly using `%raw()`:

### Basic Usage

```rescript
%raw("yield")
```

### Multiple Instructions

```rescript
%raw("yield")
%raw("move r0 100")
%raw("sb 12345 Setting 1")
```

### Game Loop Pattern

The most common use case - main game loop with yield:

```rescript
let counter = ref(0)

while true {
  // Game logic
  counter := counter.contents + 1

  // Pause until next tick
  %raw("yield")
}
```

**Compiles to:**
```assembly
move r0 0
label0:
move r15 1
beqz r15 label1
add r0 r0 1
yield
j label0
label1:
```

### Advanced Example

Combining regular code with raw instructions:

```rescript
let device = 12345
let value = 100

// Compiled code
let calculated = value * 2

// Raw IC10 instruction
%raw("sb 12345 Setting 200")

// More compiled code
let result = calculated + 50
```

**Important Notes:**
- Raw instructions are NOT validated at compile time
- You're responsible for correct IC10 syntax
- Single instruction per `%raw()` call
- Use for IC10-specific operations (yield, device I/O, etc.)
- Maintains register allocation context

---

## IC10 Target Details

### Register Architecture

IC10 has 16 registers: `r0` through `r15`

**Register Allocation Strategy:**
- `r0-r14`: Variable and temporary storage (allocated from low to high)
- `r15`: Reserved for temporary operations and comparisons

### Instruction Set

The compiler generates these IC10 instructions:

**Arithmetic:**
- `move <dest> <src>` - Copy value to register
- `add <dest> <src1> <src2>` - Addition
- `sub <dest> <src1> <src2>` - Subtraction
- `mul <dest> <src1> <src2>` - Multiplication
- `div <dest> <src1> <src2>` - Integer division

**Comparison:**
- `slt <dest> <src1> <src2>` - Set if less than
- `sgt <dest> <src1> <src2>` - Set if greater than
- `seq <dest> <src1> <src2>` - Set if equal

**Branching:**
- `blt <src1> <src2> <label>` - Branch if less than
- `bgt <src1> <src2> <label>` - Branch if greater than
- `bge <src1> <src2> <label>` - Branch if greater or equal
- `ble <src1> <src2> <label>` - Branch if less or equal
- `beq <src1> <src2> <label>` - Branch if equal
- `bne <src1> <src2> <label>` - Branch if not equal
- `beqz <src> <label>` - Branch if zero
- `j <label>` - Unconditional jump

**Stack Operations:**
- `push <value>` - Push value onto stack
- `peek <dest>` - Read from stack without popping
- `pop <dest>` - Pop value from stack

**Device I/O:**
- Use `%raw()` for device operations like `sb`, `lb`, `ls`, etc.

### Optimizations

The compiler performs several optimizations:

1. **Constant Folding**
   ```rescript
   let x = 5 + 3  // Compiles to: move r0 8
   ```

2. **Algebraic Identities**
   ```rescript
   let x = y + 0  // Compiles to: move r0 r1
   let z = a * 1  // Compiles to: move r0 r2
   ```

3. **Direct Branch Instructions**
   ```rescript
   if x < 5 { }  // Uses: bge r0 5 label0 (single instruction)
   ```

4. **Dead Code Elimination**
   ```rescript
   if true {      // Optimizer removes dead else branch
     let x = 1
   }
   ```

---

## Limitations

### Not Yet Implemented

- **Boolean `false` literal** - Use `0` instead
- **String literals** - Except in `%raw()`
- **Floating-point numbers** - IC10 is integer-only
- **Arrays** - Not supported
- **Functions** - Not supported
- **Loops:** Only `while` loops (no `for` loops)
- **Break/Continue** - Not supported
- **Comparison operators:** Only `<`, `>`, `==` (no `>=`, `<=`, `!=`)
- **Logical operators:** No `&&`, `||`, `!`
- **Bitwise operators:** No `&`, `|`, `^`, `<<`, `>>`

### Resource Constraints

**Register Limit:**
- Maximum 16 registers (r0-r15)
- Exceeding this causes compilation error
- Variables persist across scopes
- Nested loops increase register pressure

**Example that exhausts registers:**
```rescript
let a = 1
let b = 2
let c = 3
// ... continue to 16+ variables
// ERROR: "No more registers available"
```

**IC10 Program Size:**
- IC10 chips have instruction limits (varies by device)
- Large programs may exceed chip capacity
- Consider splitting complex logic across multiple chips

### Scope and Lifetime

**Variable Shadowing:**
```rescript
let x = 10
if true {
  let x = 20  // Reuses same register
}
// x is 20 here (inner scope value persists)
```

**No Stack Variables:**
- All variables live in registers
- No automatic memory management
- Stack only used for variant types

---

## Complete Examples

### Example 1: Counter with Threshold

```rescript
let counter = ref(0)
let threshold = 100

while counter.contents < threshold {
  counter := counter.contents + 1
  %raw("yield")
}
```

### Example 2: State Machine

```rescript
type State = Init | Running | Done

let state = ref(Init)
let counter = ref(0)

while true {
  let current = state.contents

  switch current {
  | Init => {
      state := Running
      counter := 0
    }
  | Running => {
      counter := counter.contents + 1
      if counter.contents > 100 {
        state := Done
      }
    }
  | Done => {
      counter := 0
      state := Init
    }
  }

  %raw("yield")
}
```

### Example 3: Temperature Controller

```rescript
type Mode = Heating | Cooling | Idle

let mode = ref(Idle)
let temperature = ref(273)
let target = 300

while true {
  if temperature.contents < target {
    mode := Heating
    temperature := temperature.contents + 1
  } else if temperature.contents > target {
    mode := Cooling
    temperature := temperature.contents - 1
  } else {
    mode := Idle
  }

  %raw("yield")
}
```

### Example 4: Nested Loop Grid Processing

```rescript
let x = ref(0)
let y = ref(0)

while x.contents < 10 {
  y := 0
  while y.contents < 10 {
    // Process grid cell (x, y)
    let cellValue = x.contents * y.contents
    y := y.contents + 1
  }
  x := x.contents + 1
}
```

---

## Best Practices

### 1. Use Refs for Mutable State

```rescript
// ✅ Good: Use refs for values that change
let counter = ref(0)
while counter.contents < 10 {
  counter := counter.contents + 1
}

// ❌ Bad: Can't mutate immutable variables
let counter = 0
// counter = counter + 1  // ERROR
```

### 2. Always Yield in Game Loops

```rescript
// ✅ Good: Yields control every tick
while true {
  // game logic
  %raw("yield")
}

// ❌ Bad: Infinite loop freezes the game
while true {
  // game logic with no yield
}
```

### 3. Mind Register Limits

```rescript
// ✅ Good: Reuse variables
let x = ref(0)
while x.contents < 100 {
  let temp = x.contents * 2  // temp register freed after block
  x := x.contents + 1
}

// ❌ Bad: Declares too many variables
let v1 = 1
let v2 = 2
// ...
let v20 = 20  // ERROR: Out of registers
```

### 4. Use Pattern Matching for State

```rescript
// ✅ Good: Clear state handling
type State = A | B | C
let state = ref(A)

switch state.contents {
| A => // handle A
| B => // handle B
| C => // handle C
}

// ❌ Bad: Manual state comparison
let stateA = 0
let stateB = 1
if state.contents == stateA {
  // harder to maintain
}
```

### 5. Optimize Comparisons

```rescript
// ✅ Good: Direct comparison (single branch instruction)
if x < 5 { }

// ⚠️ Less optimal: Complex expressions need temp registers
if x + y < z * 2 { }
```

---

## Troubleshooting

### Common Errors

**"No more registers available"**
- Too many variables in scope
- Solution: Reduce variable count, use nested blocks to free registers

**"Undefined variable: x"**
- Variable not declared before use
- Solution: Ensure `let x = ...` before referencing

**"Parse error: Expected LeftBrace but found ..."**
- Syntax error in code
- Solution: Check braces, parentheses, keywords

**"X is not a ref - cannot use := operator"**
- Trying to mutate immutable variable
- Solution: Declare with `ref()`: `let x = ref(0)`

**"X is not a ref - cannot use .contents"**
- Trying to read `.contents` on non-ref variable
- Solution: Remove `.contents` or make variable a ref

---

## Version History

**v0.3.0** (Current)
- ✅ Raw assembly instructions (`%raw()`)
- ✅ Boolean `true` literal
- ✅ Infinite loops (`while true`)
- ✅ Game loop pattern support

**v0.2.0**
- ✅ While loops
- ✅ Mutable references (refs)
- ✅ Variant types
- ✅ Pattern matching

**v0.1.0**
- ✅ Variables and expressions
- ✅ Arithmetic operators
- ✅ Comparisons
- ✅ If/else statements
- ✅ Register allocation

---

## Further Reading

- [ReScript Language Documentation](https://rescript-lang.org/)
- [Stationeers IC10 Wiki](https://stationeers-wiki.com/IC10)
- [Project README](./README.md)
- [Loop Implementation Details](./LOOPS_IMPLEMENTATION.md)
- [Project Guidelines](./CLAUDE.md)

---

**Last Updated:** 2025-11-04
**Compiler Version:** 0.3.0
