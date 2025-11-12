# IR (Intermediate Representation) Reference

**Last Updated:** 2025-11-12

This document provides a comprehensive reference for the Intermediate Representation (IR) layer used in the ReScript to IC10 compiler.

## Overview

The IR layer sits between the AST (Abstract Syntax Tree) and IC10 assembly generation:

```
ReScript Source → Lexer → Parser → AST → IRGen → IR → IRToIC10 → IC10 Assembly
                                              ↓
                                         IROptimizer
```

## Core Types

### Virtual Registers

```rescript
type vreg = int
```

Virtual registers are unlimited during IR generation. They are mapped to physical registers (r0-r15) during the IRToIC10 phase.

**Examples:**
- `v0`, `v1`, `v2`, ... (printed format)
- Internally represented as integers: `0`, `1`, `2`, ...

### Operands

```rescript
type operand =
  | VReg(vreg)       // Virtual register reference
  | Num(int)         // Immediate integer value
  | Name(string)     // Named constant reference (e.g., from define)
```

**Operand Types:**

1. **`VReg(vreg)`** - Reference to a virtual register
   - Example: `VReg(0)` → prints as `v0` in IR → converts to `r0` (or other physical register) in IC10
   - Used for: Variable values, temporary computation results

2. **`Num(int)`** - Immediate integer value
   - Example: `Num(42)` → prints as `42` → stays as `42` in IC10
   - Used for: Literal values, constant expressions after folding

3. **`Name(string)`** - Named constant reference
   - Example: `Name("maxTemp")` → prints as `maxTemp` → stays as `maxTemp` in IC10
   - Used for: References to `define` constants, hash values
   - Added in: 2025-11-12 to support constant references

**Conversion to IC10:**
- `VReg(5)` → `r2` (if vreg 5 maps to physical register r2)
- `Num(100)` → `100`
- `Name("furnaceHash")` → `furnaceHash`

### Device References

```rescript
type device =
  | DevicePin(string)              // "d0", "d1", "db", etc. → l/s
  | DeviceReg(vreg)                // device stored in register → l/s
  | DeviceType(string)             // type hash → lb/sb
  | DeviceNamed(string, string)    // type hash + name hash → lbn/sbn
```

**Device Types:**

1. **`DevicePin(string)`** - Direct device pin reference
   - Example: `DevicePin("d0")`, `DevicePin("db")`
   - Used for: `l(0, "Temperature")` → `DevicePin("d0")`

2. **`DeviceReg(vreg)`** - Device stored in a register
   - Example: `DeviceReg(3)` where v3 contains a device reference
   - Used for: Dynamic device selection

3. **`DeviceType(string)`** - Device type hash for batch operations
   - Example: `DeviceType("furnaceHash")`
   - Used for: `lb(furnaceHash, "Temperature", "Maximum")`

4. **`DeviceNamed(typeHash, nameHash)`** - Type and name hash for specific batch operations
   - Example: `DeviceNamed("furnaceType", "furnaceName")`
   - Used for: `lbn(furnaceType, furnaceName, "Temperature", "Maximum")`

## Instructions

### Definition Instructions

#### DefInt - Define Integer Constant
```rescript
DefInt(name: string, value: int)
```
**Purpose:** Define a named integer constant
**IR Example:** `DefInt("maxTemp", 1000)`
**IC10 Output:** `define maxTemp 1000`

#### DefHash - Define Hash Constant
```rescript
DefHash(name: string, value: string)
```
**Purpose:** Define a named hash constant
**IR Example:** `DefHash("furnaceType", "StructureAdvancedFurnace")`
**IC10 Output:** `define furnaceType HASH("StructureAdvancedFurnace")`

### Data Movement Instructions

#### Move - Move Value to Register
```rescript
Move(dest: vreg, source: operand)
```
**Purpose:** Copy a value to a virtual register
**IR Example:** `Move(0, Num(42))`
**IC10 Output:** `move r0 42`

### Arithmetic Instructions

#### Binary - Binary Arithmetic Operation
```rescript
Binary(dest: vreg, op: binOp, left: operand, right: operand)

type binOp = AddOp | SubOp | MulOp | DivOp
```
**Purpose:** Perform arithmetic operations
**IR Examples:**
- `Binary(2, AddOp, VReg(0), VReg(1))` → `add r2 r0 r1`
- `Binary(3, MulOp, VReg(1), Num(5))` → `mul r3 r1 5`

#### Unary - Unary Operation
```rescript
Unary(dest: vreg, op: unOp, operand: operand)

type unOp = Abs
```
**Purpose:** Perform unary operations
**IR Example:** `Unary(1, Abs, VReg(0))` → `abs r1 r0`

### Comparison Instructions

#### Compare - Comparison Operation
```rescript
Compare(dest: vreg, op: compareOp, left: operand, right: operand)

type compareOp = LtOp | GtOp | EqOp | GeOp | LeOp | NeOp
```
**Purpose:** Compare two operands, store boolean result (0 or 1)
**IR Example:** `Compare(2, LtOp, VReg(0), VReg(1))`
**IC10 Output:** `slt r2 r0 r1`

**Comparison Operators:**
- `LtOp` → `slt` (set if less than)
- `GtOp` → `sgt` (set if greater than)
- `EqOp` → `seq` (set if equal)
- `GeOp` → `sge` (set if greater or equal)
- `LeOp` → `sle` (set if less or equal)
- `NeOp` → `sne` (set if not equal)

### Control Flow Instructions

#### Label - Branch Target
```rescript
Label(name: string)
```
**Purpose:** Mark a location for jumps
**IR Example:** `Label("loop_start")`
**IC10 Output:** `loop_start:`

#### Goto - Unconditional Jump
```rescript
Goto(label: string)
```
**Purpose:** Unconditionally jump to a label
**IR Example:** `Goto("loop_start")`
**IC10 Output:** `j loop_start`

#### Bnez - Branch if Not Equal to Zero
```rescript
Bnez(condition: operand, label: string)
```
**Purpose:** Jump to label if condition is non-zero
**IR Example:** `Bnez(VReg(2), "then_block")`
**IC10 Output:** `bnez r2 then_block`

**Note:** The IR uses only `Bnez` for all conditional branches. Inverted comparisons are used for if-only statements.

#### Call - Function Call
```rescript
Call(label: string)
```
**Purpose:** Call a function (jump and link)
**IR Example:** `Call("setup")`
**IC10 Output:** `jal setup`

**Note:** Stores return address in `ra` register (r17 in IC10) so the function can return.

#### Return - Return from Function
```rescript
Return
```
**Purpose:** Return from a function call
**IR Example:** `Return`
**IC10 Output:** `j ra`

**Note:** Jumps back to the address stored in the `ra` register.

### Device I/O Instructions

#### DeviceLoad - Load from Device
```rescript
DeviceLoad(dest: vreg, device: device, property: string, bulkOpt: option<string>)
```
**Purpose:** Read a property from a device
**IR Examples:**
- `DeviceLoad(0, DevicePin("d0"), "Temperature", None)` → `l r0 d0 Temperature`
- `DeviceLoad(1, DeviceType("furnaceHash"), "Pressure", Some("Maximum"))` → `lb r1 furnaceHash Pressure Maximum`

#### DeviceStore - Store to Device
```rescript
DeviceStore(device: device, property: string, value: operand)
```
**Purpose:** Write a value to a device property
**IR Examples:**
- `DeviceStore(DevicePin("d0"), "Setting", Num(100))` → `s d0 Setting 100`
- `DeviceStore(DeviceType("furnaceHash"), "On", VReg(2))` → `sb furnaceHash On r2`

### Stack Instructions (for Variant Support)

#### StackAlloc - Allocate Stack Space
```rescript
StackAlloc(slotCount: int)
```
**Purpose:** Reserve N stack slots for variant storage
**IR Example:** `StackAlloc(8)`
**IC10 Output:** `move sp 8` (optimized from 8× `push 0`)

#### StackPoke - Write to Stack
```rescript
StackPoke(address: int, value: operand)
```
**Purpose:** Write a value to a specific stack address
**IR Example:** `StackPoke(0, Num(1))`
**IC10 Output:** `poke 0 1`

#### StackGet - Read from Stack
```rescript
StackGet(dest: vreg, address: int)
```
**Purpose:** Read a value from a specific stack address
**IR Example:** `StackGet(5, 0)`
**IC10 Output:** `get r5 db 0`

#### StackPush - Push to Stack
```rescript
StackPush(value: operand)
```
**Purpose:** Push a value onto the stack
**IR Example:** `StackPush(VReg(0))`
**IC10 Output:** `push r0`

### Raw Instruction

#### RawInstruction - Pass-through Assembly
```rescript
RawInstruction(instruction: string)
```
**Purpose:** Emit raw IC10 assembly directly
**IR Example:** `RawInstruction("yield")`
**IC10 Output:** `yield`

## IR Modules

### IRGen.res - IR Generation from AST

**Purpose:** Convert AST to IR with virtual registers

**Key Functions:**
- `generate(ast: AST.program) → result<IR.t, string>` - Main entry point
- `generateExpr(state, expr) → result<(state, vreg), string>` - Generate expression
- `generateStmt(state, stmt) → result<state, string>` - Generate statement

**Features:**
- Unlimited virtual registers
- Constant tracking (Name operands)
- Device mapping
- Variant type metadata
- Stack allocation
- Function block separation and ordering

#### Function Block Ordering

IRGen separates function definitions from main code to ensure correct execution order in IC10:

**Problem:** In ReScript, functions must be declared before use. But in IC10, execution starts at the first line, so functions placed first would execute incorrectly.

**Solution:** IRGen creates separate blocks:
1. **Main block** - Contains main execution code
2. **Function blocks** - One block per function definition

**Output Order:**
```
main block:
  [main code]
  j __end      # Safety: prevent falling into functions
  __end:
  j __end

function blocks:
  functionName:
  [function body]
  j ra
```

**Example:**

ReScript:
```rescript
let increment = () => {
  %raw("add r0 r0 1")
}

while true {
  increment()
}
```

IR Output:
```
# Block: main
label0:
jal increment
j label0
j __end
__end:
j __end

# Block: increment
increment:
add r0 r0 1
j ra
```

This ensures the while loop executes first, preventing execution from falling through into the function definition.

### IRPrint.res - IR Pretty Printer

**Purpose:** Format IR for debugging and visualization

**Key Function:**
- `print(ir: IR.t) → string` - Convert IR to human-readable format

**Output Format:**
```
move v0 5
move v1 3
add v2 v0 v1
```

**Recent Updates (2025-11-12):**
- Added support for `Name(name)` operand printing

### IRToIC10.res - IR to IC10 Code Generation

**Purpose:** Convert IR with virtual registers to IC10 with physical registers

**Key Functions:**
- `generate(ir: IR.t) → result<string, string>` - Main entry point
- `allocatePhysicalReg(state, vreg) → result<(state, int), string>` - Map vreg → r0-r15
- `convertOperand(state, operand) → result<(state, string), string>` - Convert operand to IC10 format

**Features:**
- Physical register allocation (r0-r15)
- Register spill detection
- Peephole optimization (Compare + Bnez → direct branch)

**Recent Updates (2025-11-12):**
- Added support for `Name(name)` operand conversion

### IROptimizer.res - IR-Level Optimizations

**Purpose:** Optimize IR before physical register allocation

**Optimizations:**
1. **Dead Code Elimination** - Remove unused Move instructions
2. **Constant Propagation** - Replace variables with known constant values
3. **Redundant Move Elimination** - Remove moves like `v0 = v0`
4. **Constant Folding** - Evaluate constant expressions at compile time

**Key Functions:**
- `optimize(ir: IR.t) → IR.t` - Apply all optimizations
- `eliminateDeadCode(instrs) → instrs` - Remove dead instructions
- `propagateConstantsAndCopies(instrs) → instrs` - Propagate constants
- `foldConstants(instrs) → instrs` - Fold constant expressions

**Recent Updates (2025-11-12):**
- Added support for `Name(_)` operand in dead code analysis
- Added support for `Name(_)` operand in constant propagation

## Implementation Status

### ✅ Completed Features

- Virtual register allocation
- Basic arithmetic operations (Add, Sub, Mul, Div)
- Comparison operations (all 6 comparison ops)
- Control flow (if/else, while loops)
- Variant types with stack-based storage
- Mutable references (refs)
- Switch expressions with pattern matching
- Device I/O (l, s, lb, sb, lbn, sbn)
- Hash constants
- Integer constants
- Raw IC10 instructions
- IR-level optimizations
- Peephole optimization (Compare + Bnez fusion)
- Named constant support (Name operand)

### 🔧 Recent Fixes

**2025-11-13: Function Block Ordering**
- **Critical Bug Fix:** Functions are now placed after main code, not before
- IRGen separates function declarations into separate blocks
- Main code executes first, followed by safety jump, then function definitions
- Prevents IC10 from executing function bodies on program start
- Added `__end` infinite loop to prevent falling through into functions

**2025-11-12: Pattern Matching Warnings Fixed**
- All IR modules now properly handle the `Name` operand variant
  - `IRPrint.res` - prints name directly
  - `IRToIC10.res` - passes name through to IC10
  - `IROptimizer.res` - handles in dead code and constant propagation analysis

### 🚧 Known Limitations

1. **Constant Optimization Gap:** IR doesn't always emit `define` statements for simple constants
   - Old codegen: `let x = 42` → `define x 42`
   - IR: `let x = 42` → `move r0 42` (less optimal but correct)

2. **One Ref Per Variant Type:** IC10 stack-based variant storage limits one ref per type
   - Enforced by IRGen with clear error messages
   - Workaround: Define duplicate types (e.g., `type State2 = ...`)

## Examples

### Simple Variable Assignment

**ReScript:**
```rescript
let x = 5
let y = x + 3
```

**IR:**
```
move v0 5
move v1 v0
move v2 3
add v3 v1 v2
```

**IC10:**
```
move r0 5
move r1 r0
move r2 3
add r3 r1 r2
```

### If-Else Statement

**ReScript:**
```rescript
if a < b {
  let c = 1
} else {
  let c = 2
}
```

**IR:**
```
slt v2 v0 v1
bnez v2 label1
move v3 2
j label0
label1:
move v4 1
label0:
```

**IC10 (with peephole optimization):**
```
blt r0 r1 label1
move r2 2
j label0
label1:
move r3 1
label0:
```

### Device I/O with Constants

**ReScript:**
```rescript
let furnaceType = hash("StructureAdvancedFurnace")
let temp = lb(furnaceType, "Temperature", "Maximum")
s(0, "Setting", temp)
```

**IR:**
```
define furnaceType HASH("StructureAdvancedFurnace")
load v0 type(furnaceType) Temperature Maximum
store d0 Setting v0
```

**IC10:**
```
define furnaceType HASH("StructureAdvancedFurnace")
lb r0 furnaceType Temperature Maximum
s d0 Setting r0
```

### Function Declarations and Calls

**ReScript:**
```rescript
let configure = () => {
  %raw("move r0 100")
}

configure()
```

**IR:**
```
# Block: main
jal configure
j __end
__end:
j __end

# Block: configure
configure:
move v0 100
j ra
```

**IC10:**
```
jal configure
j __end
__end:
j __end
configure:
move r0 100
j ra
```

**Key Points:**
- Main code (function call) executes first
- Safety jump prevents falling into function
- Function definition comes after main code
- `jal` stores return address in `ra` register
- `j ra` returns to the calling code

## See Also

- [IR Design Plan](ir-design.md) - Original design and migration plan
- [IR Migration Report](ir-migration-report.md) - Current migration status
- [Compiler Overview](compiler-overview.md) - Overall compiler architecture
