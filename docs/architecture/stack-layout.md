# Stack Layout and IC10 Stack Operations

## Overview

This document describes how the compiler uses IC10 stack operations and implements variant types using a fixed stack layout strategy.

## Table of Contents

1. [IC10 Stack Instructions Reference](#ic10-stack-instructions-reference)
2. [Variant Stack Layout Design](#variant-stack-layout-design)
3. [Implementation Strategy](#implementation-strategy)
4. [Register Allocation](#register-allocation)

---

## IC10 Stack Instructions Reference

### Stack Operations

#### clr
**Description:** Clears the stack memory for the provided device.  
**Syntax:** `clr d?`

#### clrd
**Description:** Seeks directly for the provided device id and clears the stack memory of that device.  
**Syntax:** `clrd id(r?|num)`

#### get
**Description:** Using the provided device, attempts to read the stack value at the provided address, and places it in the register.  
**Syntax:** `get r? device(d?|r?|id) address(r?|num)`  
**Compiler Usage:** Primary instruction for reading variant data

#### getd
**Description:** Seeks directly for the provided device id, attempts to read the stack value at the provided address, and places it in the register.  
**Syntax:** `getd r? id(r?|id) address(r?|num)`

#### peek
**Description:** Register = the value at the top of the stack (at sp).  
**Syntax:** `peek r?`  
**Note:** Only reads from current stack pointer (sp), no address argument available.

#### poke
**Description:** Stores the provided value at the provided address in the stack.  
**Syntax:** `poke address(r?|num) value(r?|num)`  
**Compiler Usage:** Primary instruction for writing variant data

#### pop
**Description:** Register = the value at the top of the stack and decrements sp.  
**Syntax:** `pop r?`

#### push
**Description:** Pushes the value to the stack at sp and increments sp.  
**Syntax:** `push a(r?|num)`  
**Compiler Usage:** Only used during variant initialization

#### put
**Description:** Using the provided device, attempts to write the provided value to the stack at the provided address.  
**Syntax:** `put device(d?|r?|id) address(r?|num) value(r?|num)`

#### putd
**Description:** Seeks directly for the provided device id, attempts to write the provided value to the stack at the provided address.  
**Syntax:** `putd id(r?|id) address(r?|num) value(r?|num)`

### Key Insights for Compiler

1. **peek has no address argument** - only reads from sp
2. **To read from arbitrary stack address:** Must use `get db address` (device stack access)
3. **poke can write to arbitrary address** without modifying sp
4. **push always writes to sp** and increments sp
5. **Device stack operations** (get/put) can access arbitrary addresses on device stacks

---

## Variant Stack Layout Design

### Core Principle

**The stack pointer (`sp`) is set once during ref creation and NEVER modified afterwards.**

- **Reading**: Use `get r? db address` to read from device stack without touching `sp`
- **Writing**: Use `poke address value` to write to stack without touching `sp`
- **Stack slots** are pre-allocated for all variant cases and their arguments

### Why This Approach?

The old approach using `move sp` + `peek` caused stack corruption:

```asm
# OLD (BROKEN):
move sp r0      # sp = 0
peek r15        # Read stack[0]
# Later in loop...
push 1          # Writes to stack[0]! (because sp was 0)
                # This OVERWRITES instead of growing the stack
```

**Solution:** Use fixed stack layout with `get db` and `poke`:

```asm
# NEW (FIXED):
get r15 db 0    # Read stack[0] without touching sp
# Later...
poke 0 1        # Write to stack[0] without touching sp
                # sp remains stable, stack integrity maintained
```

### Stack Layout Convention

#### Slot Allocation

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

#### Formulas

Given a variant type with `N` constructors, each supporting up to `M` arguments:

**Total stack slots needed:** `1 + (N * M)`
- 1 slot for the variant tag
- N × M slots for all possible arguments

**Argument address calculation:**
```
stack[variantTag * M + 1 + argIndex]
```

Where:
- `variantTag` = 0, 1, 2, ... (the current variant)
- `M` = maximum arguments per constructor (fixed at compile time)
- `argIndex` = 0, 1, ... (which argument)

#### Visualization

[Excalidraw Diagram](https://excalidraw.com/#json=eoEP3WZFL6GMkwmUvAAgG,sELPVBW5f9Ik2IF9lDjx3A)

### Example: Two-Argument Variants

#### ReScript Code

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

#### Stack Layout

```
stack[0] = variant tag (0=Idle, 1=Fill)
stack[1] = Idle arg0 (pressure)
stack[2] = Idle arg1 (temperature)
stack[3] = Fill arg0 (pressure)
stack[4] = Fill arg1 (temperature)
```

After initialization: **sp = 5** (and never changes)

#### Generated Assembly

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
# Extract arguments from Idle slots
get r15 db 1        # r15 = stack[1] (Idle pressure)
get r14 db 2        # r14 = stack[2] (Idle temperature)

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
# Extract arguments from Fill slots
get r15 db 3        # r15 = stack[3] (Fill pressure)
get r14 db 4        # r14 = stack[4] (Fill temperature)

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

---

## Implementation Strategy

### Compile-Time Decisions

#### Determining Maximum Arguments

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

#### Stack Allocation

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

#### Address Calculation Examples

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

### Implementation in Compiler

#### Ref Creation (StmtGen.res)

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
```

#### Ref Assignment (StmtGen.res)

```rescript
// state := Fill(p + 10, t + 5)

1. Evaluate arguments (results in temp registers):
   add r15 r15 10        # Arg0 = p + 10
   add r14 r14 5         # Arg1 = t + 5
2. Write tag:
   poke 0 1              # stack[0] = 1 (Fill)
3. Write arguments:
   poke 3 r15            # stack[3] = new pressure
   poke 4 r14            # stack[4] = new temperature
```

#### Switch Scrutinee (ExprGen.res)

```rescript
// switch state.contents

1. Read tag:
   get r15 db 0          # r15 = stack[0]
2. Branch on tag:
   beq r15 0 case_idle
   beq r15 1 case_fill
```

#### Pattern Matching with Arguments (ExprGen.res)

```rescript
// | Fill(p, t) => ...

1. Extract args:
   get r15 db 3          # p = stack[3]
   get r14 db 4          # t = stack[4]
2. Use in case body
```

---

## Register Allocation

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

### Benefits

- **Efficient register usage** - maximizes available registers for user variables
- **No register leaks** - temps are implicitly freed at case boundaries
- **Predictable allocation** - variables always start at r0, temps always start at r15
- **Simplifies compiler** - no need to track pattern match variable lifetimes

---

## Summary

✅ **sp is sacred** - set once, never modified  
✅ **Fixed addressing** - predictable slot layout  
✅ **get/poke only** - no peek/pop after init  
✅ **Pre-allocation** - all slots reserved upfront  
✅ **Temp registers** - pattern bindings use r15-n for efficiency  
✅ **Works in loops** - no corruption or overwrites  

This design ensures reliable variant behavior in all contexts, especially loops and nested switches.

---

## References

- [Variant Types Implementation](../implementation/variants.md)
- [IR Design](ir-design.md)
- [IC10 Support Guide](../user-guide/ic10-support.md)
