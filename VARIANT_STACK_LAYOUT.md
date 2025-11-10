# Variant Stack Layout Design

## Overview

This document describes how ReScript variants are compiled to IC10 assembly using a fixed stack layout that never modifies the stack pointer (`sp`) after initialization.

## Core Principle

**The stack pointer (`sp`) is set once during ref creation and NEVER modified afterwards.**

- Reading: Use `get r? db address` to read from device stack without touching `sp`
- Writing: Use `poke address value` to write to stack without touching `sp`
- Stack slots are pre-allocated for all variant cases and their arguments

## Stack Layout Convention

### Slot Allocation

```
stack[0]     = Current variant tag (0, 1, 2, ...)
stack[1]     = Variant 0, Argument 0
stack[2]     = Variant 0, Argument 1
stack[3]     = Variant 1, Argument 0
stack[4]     = Variant 1, Argument 1
stack[5]     = Variant 2, Argument 0
stack[6]     = Variant 2, Argument 1
...
```

### Formulas

Given a variant type with `N` constructors, each supporting up to `M` arguments:

**Total stack slots needed:** `1 + (N * M)`

- 1 slot for the variant tag
- N × M slots for all possible arguments
  https://excalidraw.com/#json=eoEP3WZFL6GMkwmUvAAgG,sELPVBW5f9Ik2IF9lDjx3A

**Argument address calculation:**

```
stack[variantTag * M + 1 + argIndex]
```

Where:

- `variantTag` = 0, 1, 2, ... (the current variant)
- `M` = maximum arguments per constructor (fixed at compile time)
- `argIndex` = 0, 1, ... (which argument)

## Example: Two-Argument Variants

### ReScript Code

```rescript
type state = Idle(int, int) | Fill(int, int)
let state = ref(Idle(0, 0))

while true {
  switch state.contents {
  | Idle(p, t) => state := Fill(p + 10, t + 5)
  | Fill(p, t) => state := Idle(p - 10, t - 5)
  }
  yield
}
```

### Stack Layout

```
stack[0] = variant tag (0=Idle, 1=Fill)
stack[1] = Idle arg0 (pressure)
stack[2] = Idle arg1 (temperature)
stack[3] = Fill arg0 (pressure)
stack[4] = Fill arg1 (temperature)
```

After initialization: **sp = 5** (and never changes)

### Generated Assembly

```asm
# Initialization: Allocate all slots
push 0        # stack[0] = 0 (Idle tag); sp = 1
push 0        # stack[1] = 0 (Idle arg0); sp = 2
push 0        # stack[2] = 0 (Idle arg1); sp = 3
push 0        # stack[3] = 0 (Fill arg0); sp = 4
push 0        # stack[4] = 0 (Fill arg1); sp = 5
              # sp = 5 forever!

label0:             # Loop start
# Read current variant tag
get r15 db 0        # r15 = stack[0] (variant tag)
                    # sp UNCHANGED (still 5)
beq r15 0 case_idle
beq r15 1 case_fill

case_idle:          # Match Idle(p, t)
# Extract arguments from Idle slots (using temp registers)
get r15 db 1        # r15 = stack[1] (Idle pressure) - temp
get r14 db 2        # r14 = stack[2] (Idle temperature) - temp

# Compute new values
add r15 r15 10      # p + 10
add r14 r14 5       # t + 5

# Write to Fill variant
poke 0 1            # stack[0] = 1 (Fill tag)
poke 3 r15          # stack[3] = new pressure
poke 4 r14          # stack[4] = new temperature
                    # sp UNCHANGED (still 5)
j end

case_fill:          # Match Fill(p, t)
# Extract arguments from Fill slots (using temp registers)
get r15 db 3        # r15 = stack[3] (Fill pressure) - temp
get r14 db 4        # r14 = stack[4] (Fill temperature) - temp

# Compute new values
sub r15 r15 10      # p - 10
sub r14 r14 5       # t - 5

# Write to Idle variant
poke 0 0            # stack[0] = 0 (Idle tag)
poke 1 r15          # stack[1] = new pressure
poke 2 r14          # stack[2] = new temperature
                    # sp UNCHANGED (still 5)
j end

end:
yield
j label0            # Loop back, sp still 5!
```

## Key Instructions

### Reading from Stack (Without Modifying sp)

```asm
get r? db address
```

- `db` = IC Housing device (current device's own stack)
- `address` = Stack slot index (can be register or literal)
- Reads `stack[address]` into register without modifying `sp`

### Writing to Stack (Without Modifying sp)

```asm
poke address value
```

- Writes `value` to `stack[address]` without modifying `sp`
- Both `address` and `value` can be registers or literals

### Stack Pointer Behavior

```asm
push value      # Writes to stack[sp], then sp++
peek r?         # Reads stack[sp] into register
pop r?          # Reads stack[sp] into register, then sp--
```

**We NEVER use peek/pop after initialization!** Only `get db address`.

## Why This Works

### Problem with Old Approach

The old code used `move sp scrutineeReg` to position `sp` before using `peek`:

```asm
# OLD (BROKEN):
move sp r0      # sp = 0
peek r15        # Read stack[0]
# Later...
push 1          # Writes to stack[0]! (because sp was 0)
                # This OVERWRITES instead of growing the stack
```

In loops, this caused:

- Stack pointer corruption
- Variants being overwritten at stack[0]
- Switch always matching the last-written value

### Solution: Fixed Stack + get/poke

```asm
# NEW (FIXED):
get r15 db 0    # Read stack[0] without touching sp
# Later...
poke 0 1        # Write to stack[0] without touching sp
                # sp remains stable, stack integrity maintained
```

Benefits:

- `sp` never changes after initialization
- No stack corruption in loops
- Stack layout is predictable and fixed
- Variant switching works correctly

## Compile-Time Decisions

### Determining Maximum Arguments

When parsing a type declaration:

```rescript
type state = Idle | Fill(int, int) | Waiting(int)
```

The compiler calculates:

- Number of variants: 3
- Maximum arguments: 2 (from `Fill`)
- **Normalize to 2 arguments per variant**

Total stack slots: `1 + (3 * 2) = 7`

Even though `Idle` has 0 args and `Waiting` has 1 arg, we allocate 2 slots for each to maintain uniform addressing.

### Stack Allocation

```asm
push 0      # stack[0] = tag
push 0      # stack[1] = Idle arg0 (unused)
push 0      # stack[2] = Idle arg1 (unused)
push 0      # stack[3] = Fill arg0
push 0      # stack[4] = Fill arg1
push 0      # stack[5] = Waiting arg0
push 0      # stack[6] = Waiting arg1 (unused)
# sp = 7 (never changes)
```

### Address Calculation Examples

```rescript
// Fill(int, int) is variant 1 with 2 args
Fill(100, 200)
```

Addresses:

- Tag: `stack[0]` = 1
- Arg0: `stack[1 * 2 + 1]` = `stack[3]` = 100
- Arg1: `stack[1 * 2 + 2]` = `stack[4]` = 200

```rescript
// Waiting(int) is variant 2 with 1 arg (but allocated 2 slots)
Waiting(42)
```

Addresses:

- Tag: `stack[0]` = 2
- Arg0: `stack[2 * 2 + 1]` = `stack[5]` = 42
- Arg1: `stack[2 * 2 + 2]` = `stack[6]` = unused

## Implementation Notes

### Ref Creation (StmtGen.res)

```rescript
// let state = ref(Idle(10, 20))
// type state = Idle(int, int) | Fill(int, int)

1. Calculate: 2 variants × 2 args = 4 arg slots + 1 tag slot = 5 total
2. Generate:
   push 0        # Tag = Idle (0)
   push 10       # Idle arg0
   push 20       # Idle arg1
   push 0        # Fill arg0 (placeholder)
   push 0        # Fill arg1 (placeholder)
3. Stack pointer is now sp=5 and never changes
   # Variant always lives at stack[0] (compile-time constant)
```

### Ref Assignment (StmtGen.res)

```rescript
// state := Fill(p + 10, t + 5)
// Fill is variant tag 1, max args = 2
// Assume p and t are in r15 and r14 (temp registers)

1. Evaluate arguments (results in temp registers):
   add r15 r15 10        # Arg0 = p + 10 (temp)
   add r14 r14 5         # Arg1 = t + 5 (temp)
2. Generate tag write:
   poke 0 1              # stack[0] = 1 (Fill)
3. Generate arg writes:
   poke 3 r15            # stack[1*2+1] = stack[3]
   poke 4 r14            # stack[1*2+2] = stack[4]
```

### Switch Scrutinee (ExprGen.res)

```rescript
// switch state.contents

1. Read tag (using temp register):
   get r15 db 0          # r15 = stack[0] - temp
2. Branch on tag:
   beq r15 0 case_idle
   beq r15 1 case_fill
   # r15 is reused in each case for pattern bindings
```

### Pattern Matching with Arguments (ExprGen.res)

```rescript
// | Fill(p, t) => ...
// Fill is tag 1, max args = 2

1. Extract args (using temp registers):
   get r15 db 3          # p = stack[1*2+1] - temp register
   get r14 db 4          # t = stack[1*2+2] - temp register
2. Bind to variables in scope:
   // r15 and r14 are now available in case body
   // Temp registers are freed after case completes
```

## Register Allocation Strategy

### Temp Registers vs. Variable Registers

IC10 provides 16 registers (r0-r15). We use a split allocation strategy:

**Variable Registers** (r0-r13):

- User-declared variables (`let x = 5`)
- Persistent across statements
- Tracked in symbol table
- Allocated from low to high

**Temp Registers** (r15-r14-r13...):

- Pattern match bindings (variant arguments)
- Intermediate computation results
- Short-lived (within single expression/case)
- Allocated from high to low
- Automatically freed after use

### Why Use Temps for Pattern Match Bindings?

```rescript
switch state.contents {
| Idle(p, t) => state := Fill(p + 10, t + 5)
| Fill(p, t) => state := Idle(p - 10, t - 5)
}
```

The bindings `p` and `t` are:

- ✅ **Only live within each case** - not needed after the case completes
- ✅ **Reusable across cases** - different cases can reuse the same temp registers
- ✅ **Don't pollute variable space** - leaves r0-r13 for actual program variables

**Assembly with temp registers:**

```asm
case_idle:
    get r15 db 1        # p (temp)
    get r14 db 2        # t (temp)
    add r15 r15 10      # Compute p + 10
    add r14 r14 5       # Compute t + 5
    poke 0 1            # Write Fill tag
    poke 3 r15          # Write Fill args
    poke 4 r14
    j end

case_fill:
    get r15 db 3        # p (temp) - REUSES r15!
    get r14 db 4        # t (temp) - REUSES r14!
    sub r15 r15 10
    sub r14 r14 5
    poke 0 0
    poke 1 r15
    poke 2 r14
    j end
```

### Benefits

- **Efficient register usage** - maximizes available registers for user variables
- **No register leaks** - temps are implicitly freed at case boundaries
- **Predictable allocation** - variables always start at r0, temps always start at r15
- **Simplifies compiler** - no need to track pattern match variable lifetimes

## Summary

✅ **sp is sacred** - set once, never modified
✅ **Fixed addressing** - predictable slot layout
✅ **get/poke only** - no peek/pop after init
✅ **Pre-allocation** - all slots reserved upfront
✅ **Temp registers** - pattern bindings use r15-n for efficiency
✅ **Works in loops** - no corruption or overwrites

This design ensures reliable variant behavior in all contexts, especially loops and nested switches.
