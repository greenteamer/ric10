# Multi-Variant Type Support in IR Architecture
## Design Document

**Status**: Draft  
**Created**: 2025-11-11  
**Target**: IR Layer Implementation

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Design Decision: One Ref Per Type](#2-design-decision-one-ref-per-type)
3. [Stack Allocation Strategy](#3-stack-allocation-strategy)
4. [IR Layer Architecture](#4-ir-layer-architecture)
5. [Implementation Details](#5-implementation-details)
6. [Code Generation Flow](#6-code-generation-flow)
7. [Testing Strategy](#7-testing-strategy)
8. [Migration Path](#8-migration-path)
9. [Future Enhancements](#9-future-enhancements)

---

## 1. Problem Statement

### 1.1 Current Limitation

The current variant implementation hardcodes all variant refs to use `stack[0]` as their base address. This creates a **critical limitation**: only one variant type can exist in a program.

**Current Code (Old Codegen):**
```rescript
// StmtGen.res:157
"move " ++ Register.toString(refReg) ++ " 0"  // Always points to stack[0]

// StmtGen.res:479
"poke 0 " ++ Int.toString(tag)  // Always writes to stack[0]

// ExprGen.res:510
"get " ++ Register.toString(tagReg) ++ " db 0"  // Always reads from stack[0]
```

### 1.2 The Collision Problem

When multiple variant types are declared:

```rescript
type state = Idle | Active
type mode = Manual | Auto

let s = ref(Idle)   // Allocates stack[0..1]
let m = ref(Manual) // COLLISION! Also tries to use stack[0..1]
```

**What happens:**
1. `s` is initialized with tag=0 (Idle) at `stack[0]`
2. `m` is initialized with tag=0 (Manual) at `stack[0]` - **overwrites s!**
3. Both refs point to address 0
4. Any operation on either ref corrupts the other

**Stack Layout (BROKEN):**
```
stack[0] = ??? (s.tag OR m.tag - whichever was assigned last)
stack[1] = ??? (s args OR m args - corrupted)
```

### 1.3 Current Address Formula

```rescript
// Assumes baseAddr = 0
let address = tag * maxArgs + 1 + argIndex
```

This works for a single variant type but fails when multiple types need their own stack segments.

---

## 2. Design Decision: One Ref Per Type

### 2.1 Restriction

**RULE**: Each variant type can have **at most one ref** in the program.

```rescript
type state = Idle | Active

let s1 = ref(Idle)   // ✅ OK - first ref of type 'state'
let s2 = ref(Active) // ❌ COMPILE ERROR - type 'state' already has a ref
```

### 2.2 Rationale

**Why this restriction makes sense for IC10:**

1. **IC10 is extremely constrained**
   - 128 instruction limit
   - 16 physical registers
   - Programs are small by necessity

2. **Most IC10 programs have singular state machines**
   - One furnace controller state
   - One valve controller state
   - One sorting logic state

3. **Massive compiler simplification**
   - ~50% reduction in complexity
   - Base address stored at type declaration (not per-ref)
   - No dynamic stack segment allocation per ref
   - Simpler IR instructions

4. **Workaround is viable**
   ```rescript
   // Instead of:
   type state = Idle | Active
   let machine1 = ref(Idle)
   let machine2 = ref(Idle)  // ❌ Not allowed
   
   // User can write:
   type state1 = Idle1 | Active1
   type state2 = Idle2 | Active2
   let machine1 = ref(Idle1)  // ✅ OK
   let machine2 = ref(Idle2)  // ✅ OK
   ```

### 2.3 Error Handling

**Compile-time error message:**
```
Error: Type 'state' already has a ref allocated (variable 's1').
IC10 compiler currently supports one ref per variant type.

Workaround: Define a second type with different constructor names:
  type state2 = Idle2 | Active2
  let s2 = ref(Idle2)
```

**Implementation:**
- Track which types have been allocated in `variantTypes`
- Check on ref creation and error if type is already allocated

### 2.4 Trade-offs

| Aspect | One Ref Per Type | Multiple Refs Per Type |
|--------|------------------|------------------------|
| **Complexity** | Low - store baseAddr with type | High - dynamic allocation per ref |
| **Stack Allocation** | At type declaration | At ref creation |
| **Metadata** | `typeName → (constructors, baseAddr, allocated)` | `refName → (typeName, baseAddr)` |
| **Common Use Case** | Fully supported | Rare in IC10 |
| **Workaround** | Simple (duplicate type) | N/A |
| **Future Upgrade** | Possible without breaking changes | N/A |

---

## 3. Stack Allocation Strategy

### 3.1 Allocation Timing

**Type declaration is the allocation point:**

```rescript
type state = Idle(int, int) | Active(int, int)
// At this moment:
// 1. Calculate slots needed: 1 (tag) + 2 (constructors) * 2 (max args) = 5
// 2. Allocate stack segment: stackAllocator.allocate(5) → baseAddr
// 3. Store in metadata: variantTypes["state"] = (constructors, baseAddr, allocated=false)
```

### 3.2 Stack Layout (Multiple Types)

```rescript
type state = Idle(int, int) | Active(int, int)  // Allocates stack[0..4]
type mode = Manual | Auto                        // Allocates stack[5..6]
```

**Stack memory:**
```
# state variant (baseAddr = 0)
stack[0] = state.tag (0=Idle, 1=Active)
stack[1] = Idle.arg0
stack[2] = Idle.arg1
stack[3] = Active.arg0
stack[4] = Active.arg1

# mode variant (baseAddr = 5)
stack[5] = mode.tag (0=Manual, 1=Auto)
stack[6] = (placeholder - no args for either constructor)
```

### 3.3 Address Formula (Updated)

**Old formula (broken):**
```rescript
let address = tag * maxArgs + 1 + argIndex  // Assumes baseAddr = 0
```

**New formula (multi-type):**
```rescript
let address = baseAddr + tag * maxArgs + 1 + argIndex
```

**Example calculation:**
```rescript
// type state = Idle(int, int) | Active(int, int)
// baseAddr = 0, maxArgs = 2

// Active(100, 200) - tag=1, args=[100, 200]
tag_address = baseAddr + 0                    = 0
arg0_address = baseAddr + 1*2 + 1 + 0         = 3
arg1_address = baseAddr + 1*2 + 1 + 1         = 4

// type mode = Manual | Auto  
// baseAddr = 5, maxArgs = 0 (but we allocate 1 slot per constructor for uniformity)

// Manual - tag=0, args=[]
tag_address = baseAddr + 0                    = 5
```

### 3.4 Stack Allocator Integration

The IR layer maintains a stack allocator to track used stack space:

```rescript
type stackAllocator = {
  nextFreeSlot: int,  // Next available stack slot
}

let allocate = (allocator: stackAllocator, slotCount: int): (stackAllocator, int) => {
  let baseAddr = allocator.nextFreeSlot
  let newAllocator = {nextFreeSlot: allocator.nextFreeSlot + slotCount}
  (newAllocator, baseAddr)
}
```

---

## 4. IR Layer Architecture

### 4.1 New IR Instructions

Add stack operation instructions to `IR.res`:

```rescript
type instr =
  // ... existing instructions ...
  
  // Stack operations for variants
  | StackAlloc(int)                    // Allocate N stack slots (reserve space)
  | StackPoke(int, operand)           // poke address value (write to stack)
  | StackGet(vreg, int)               // get vreg db address (read from stack)
  | StackPush(operand)                // push value (write and increment sp)
```

**Rationale:**
- `StackAlloc`: Reserve stack space at type declaration (emits multiple `push 0`)
- `StackPoke`: Write to variant slots during ref assignment
- `StackGet`: Read from variant slots during switch expression
- `StackPush`: Initialize variant data during ref creation

### 4.2 IR State Extensions

Update `IRGen.res` state to track variant type metadata:

```rescript
type variantTypeInfo = {
  constructors: array<AST.variantConstructor>,
  baseAddr: int,        // Stack base address for this type
  maxArgs: int,         // Maximum arguments across all constructors
  allocated: bool,      // Whether a ref has been created for this type
}

type state = {
  nextVReg: int,
  instructions: list<IR.instr>,
  nextLabel: int,
  varMap: Belt.Map.String.t<varInfo>,
  
  // Variant type metadata
  variantTypes: Belt.Map.String.t<variantTypeInfo>,  // typeName → info
  variantTags: Belt.Map.String.t<int>,               // constructorName → tag
  refToTypeName: Belt.Map.String.t<string>,          // refName → typeName
  
  // Stack allocator
  stackAllocator: {nextFreeSlot: int},
}
```

### 4.3 Type Metadata Flow

```
Type Declaration
       ↓
Calculate slot count
       ↓
Allocate stack segment → baseAddr
       ↓
Store (constructors, baseAddr, allocated=false)
       ↓
Emit StackAlloc(slotCount)
```

```
Ref Creation
       ↓
Look up type metadata
       ↓
Check allocated flag → Error if true
       ↓
Mark allocated = true
       ↓
Store refName → typeName mapping
       ↓
Emit StackPush for initial values
```

---

## 5. Implementation Details

### 5.1 IR.res Changes

Add new instruction variants:

```rescript
// src/compiler/IR/IR.res

type instr =
  | DefInt(string, int)
  | DefHash(string, string)
  | Move(vreg, operand)
  | Load(vreg, device, deviceParam, option<bulkOption>)
  | Save(device, deviceParam, vreg)
  | Unary(vreg, unOp, operand)
  | Binary(vreg, binOp, operand, operand)
  | Compare(vreg, compareOp, operand, operand)
  | Goto(string)
  | Label(string)
  | Bnez(operand, string)
  
  // NEW: Stack operations for variants
  | StackAlloc(int)           // Reserve N stack slots
  | StackPoke(int, operand)   // poke address value
  | StackGet(vreg, int)       // get vreg db address
  | StackPush(operand)        // push value
```

### 5.2 IRGen.res Implementation

#### Type Declaration Handling

```rescript
// src/compiler/IR/IRGen.res

let generateStmt = (state: state, stmt: AST.astNode): result<state, string> => {
  switch stmt {
  | TypeDeclaration(typeName, constructors) =>
    // 1. Calculate maximum arguments across all constructors
    let maxArgs = Array.reduce(constructors, 0, (max, constructor) =>
      constructor.argCount > max ? constructor.argCount : max
    )
    
    // 2. Calculate total slots needed
    let numConstructors = Array.length(constructors)
    let slotCount = 1 + numConstructors * maxArgs  // tag + (N * M)
    
    // 3. Allocate stack segment
    let (stackAllocator, baseAddr) = allocateStackSegment(
      state.stackAllocator,
      slotCount
    )
    
    // 4. Build constructor tag mappings
    let variantTags = Array.reduceWithIndex(
      constructors,
      state.variantTags,
      (tags, constructor, index) =>
        Belt.Map.String.set(tags, constructor.name, index)
    )
    
    // 5. Store type metadata
    let typeInfo = {
      constructors,
      baseAddr,
      maxArgs,
      allocated: false,  // No ref created yet
    }
    let variantTypes = Belt.Map.String.set(state.variantTypes, typeName, typeInfo)
    
    // 6. Emit StackAlloc instruction
    let state = emit(state, IR.StackAlloc(slotCount))
    
    Ok({
      ...state,
      stackAllocator,
      variantTypes,
      variantTags,
    })
    
  | _ => // ... other cases
  }
}
```

#### Ref Creation Handling

```rescript
| VariableDeclaration(varName, RefCreation(VariantConstructor(constructorName, args))) =>
  // 1. Determine type name from constructor
  let typeName = getTypeNameFromConstructor(state, constructorName)?
  
  // 2. Get type metadata
  let typeInfo = Belt.Map.String.get(state.variantTypes, typeName)
    ->Option.getExn  // Safe: constructor lookup succeeded
  
  // 3. Check if type already has a ref allocated
  if typeInfo.allocated {
    Error(
      `Type '${typeName}' already has a ref allocated. ` ++
      `IC10 compiler supports one ref per variant type. ` ++
      `Workaround: Define a second type (e.g., 'type ${typeName}2 = ...')`
    )
  } else {
    // 4. Get constructor tag
    let tag = Belt.Map.String.get(state.variantTags, constructorName)
      ->Option.getExn
    
    // 5. Mark type as allocated
    let updatedTypeInfo = {...typeInfo, allocated: true}
    let variantTypes = Belt.Map.String.set(state.variantTypes, typeName, updatedTypeInfo)
    
    // 6. Store ref → type mapping
    let refToTypeName = Belt.Map.String.set(state.refToTypeName, varName, typeName)
    
    // 7. Allocate vreg for ref variable
    let (state, refVReg) = allocVReg(state)
    let varMap = Belt.Map.String.set(
      state.varMap,
      varName,
      {vreg: refVReg, isRef: true}
    )
    
    // 8. Initialize ref to point to base address
    let state = emit(state, IR.Move(refVReg, IR.Num(typeInfo.baseAddr)))
    
    // 9. Initialize variant data on stack
    // 9a. Push tag
    let state = emit(state, IR.StackPush(IR.Num(tag)))
    
    // 9b. Push all slots (initialized for active constructor, placeholders for others)
    let state = pushAllSlots(state, typeInfo, tag, args)?
    
    Ok({...state, variantTypes, refToTypeName, varMap})
  }
```

#### Ref Assignment Handling

```rescript
| RefAssignment(refName, VariantConstructor(constructorName, args)) =>
  // 1. Look up ref's type
  let typeName = Belt.Map.String.get(state.refToTypeName, refName)
    ->Option.getExn  // Safe: ref was validated at creation
  
  // 2. Get type metadata
  let typeInfo = Belt.Map.String.get(state.variantTypes, typeName)
    ->Option.getExn
  
  // 3. Get constructor tag
  let tag = Belt.Map.String.get(state.variantTags, constructorName)
    ->Option.getExn
  
  // 4. Poke tag to baseAddr
  let state = emit(
    state,
    IR.StackPoke(typeInfo.baseAddr, IR.Num(tag))
  )
  
  // 5. Poke all arguments
  let state = Array.reduceWithIndex(args, Ok(state), (stateResult, arg, index) => {
    stateResult->Result.flatMap(state => {
      // Generate argument expression
      let (state, argVReg) = generateExpr(state, arg)?
      
      // Calculate address: baseAddr + tag * maxArgs + 1 + index
      let address = typeInfo.baseAddr + tag * typeInfo.maxArgs + 1 + index
      
      // Emit poke
      let state = emit(state, IR.StackPoke(address, IR.VReg(argVReg)))
      Ok(state)
    })
  })?
  
  Ok(state)
```

#### Switch Expression Handling

```rescript
| SwitchExpression(RefAccess(refName), cases) =>
  // 1. Look up ref's type
  let typeName = Belt.Map.String.get(state.refToTypeName, refName)
    ->Option.getExn
  
  // 2. Get type metadata
  let typeInfo = Belt.Map.String.get(state.variantTypes, typeName)
    ->Option.getExn
  
  // 3. Allocate vreg for tag
  let (state, tagVReg) = allocVReg(state)
  
  // 4. Read tag from stack
  let state = emit(
    state,
    IR.StackGet(tagVReg, typeInfo.baseAddr)
  )
  
  // 5. Generate branch for each case
  let (state, caseLabels) = generateCaseBranches(state, tagVReg, cases)?
  
  // 6. Generate each case body
  let state = Array.reduce(caseLabels, state, (state, (label, matchCase, tag)) => {
    // Emit case label
    let state = emit(state, IR.Label(label))
    
    // Extract argument bindings
    let state = extractPatternBindings(
      state,
      typeInfo,
      tag,
      matchCase.argumentBindings
    )?
    
    // Generate case body
    generateBlock(state, matchCase.body)?
  })?
  
  Ok(state)

// Helper: Extract pattern match bindings from stack
let extractPatternBindings = (
  state: state,
  typeInfo: variantTypeInfo,
  tag: int,
  bindings: array<string>
): result<state, string> => {
  Array.reduceWithIndex(bindings, Ok(state), (stateResult, bindingName, index) => {
    stateResult->Result.flatMap(state => {
      // Allocate vreg for binding
      let (state, bindingVReg) = allocVReg(state)
      
      // Calculate address: baseAddr + tag * maxArgs + 1 + index
      let address = typeInfo.baseAddr + tag * typeInfo.maxArgs + 1 + index
      
      // Emit StackGet to read value
      let state = emit(state, IR.StackGet(bindingVReg, address))
      
      // Add to varMap
      let varMap = Belt.Map.String.set(
        state.varMap,
        bindingName,
        {vreg: bindingVReg, isRef: false}
      )
      
      Ok({...state, varMap})
    })
  })
}
```

### 5.3 IRToIC10.res Implementation

Lower IR stack operations to IC10 assembly:

```rescript
// src/compiler/IR/IRToIC10.res

let generateInstr = (state: state, instr: IR.instr): result<state, string> => {
  switch instr {
  // ... existing cases ...
  
  | StackAlloc(slotCount) =>
    // Emit multiple push instructions to reserve slots
    let rec emitPushes = (state: state, remaining: int): state => {
      if remaining <= 0 {
        state
      } else {
        let state = emit(state, "push 0")
        emitPushes(state, remaining - 1)
      }
    }
    Ok(emitPushes(state, slotCount))
  
  | StackPoke(address, operand) =>
    // poke address value
    convertOperand(state, operand)->Result.map(((state, valueStr)) => {
      emit(state, `poke ${Int.toString(address)} ${valueStr}`)
    })
  
  | StackGet(vreg, address) =>
    // get r? db address
    allocatePhysicalReg(state, vreg)->Result.map(((state, physicalReg)) => {
      emit(state, `get r${Int.toString(physicalReg)} db ${Int.toString(address)}`)
    })
  
  | StackPush(operand) =>
    // push value
    convertOperand(state, operand)->Result.map(((state, valueStr)) => {
      emit(state, `push ${valueStr}`)
    })
  }
}
```

---

## 6. Code Generation Flow

### 6.1 Type Declaration

```rescript
type state = Idle(int, int) | Active(int, int)
```

**IR Generation:**
```
1. Calculate: maxArgs = 2, slotCount = 1 + 2*2 = 5
2. Allocate stack: baseAddr = 0
3. Store metadata: variantTypes["state"] = {constructors, baseAddr=0, maxArgs=2, allocated=false}
4. Emit: StackAlloc(5)
```

**IC10 Output:**
```asm
push 0  # stack[0] reserved
push 0  # stack[1] reserved
push 0  # stack[2] reserved
push 0  # stack[3] reserved
push 0  # stack[4] reserved
# sp = 5
```

### 6.2 Ref Creation

```rescript
let s = ref(Idle(10, 20))
```

**IR Generation:**
```
1. Look up type "state": baseAddr=0, maxArgs=2
2. Check allocated: false ✅
3. Mark allocated: true
4. Get tag: Idle = 0
5. Allocate vreg v0 for ref
6. Emit: Move(v0, Num(0))      # ref points to baseAddr
7. Emit: StackPush(Num(0))      # tag
8. Emit: StackPush(Num(10))     # Idle arg0
9. Emit: StackPush(Num(20))     # Idle arg1
10. Emit: StackPush(Num(0))     # Active arg0 placeholder
11. Emit: StackPush(Num(0))     # Active arg1 placeholder
```

**IC10 Output:**
```asm
move r0 0    # ref points to stack[0]
push 0       # tag (Idle)
push 10      # Idle arg0
push 20      # Idle arg1
push 0       # Active arg0 placeholder
push 0       # Active arg1 placeholder
# sp = 5 (but was already 5 from type declaration!)
```

**NOTE**: This reveals a problem! We're pushing twice. **Solution**: StackAlloc only emits `push 0` during type declaration. Ref creation uses `StackPoke` to initialize values, not `StackPush`.

**CORRECTED Ref Creation:**
```
7. Emit: StackPoke(0, Num(0))      # poke tag to baseAddr
8. Emit: StackPoke(1, Num(10))     # poke Idle arg0
9. Emit: StackPoke(2, Num(20))     # poke Idle arg1
# Active slots remain 0 (already initialized by StackAlloc)
```

**CORRECTED IC10 Output:**
```asm
move r0 0    # ref points to stack[0]
poke 0 0     # stack[0] = Idle tag
poke 1 10    # stack[1] = Idle arg0
poke 2 20    # stack[2] = Idle arg1
# stack[3] and stack[4] remain 0 from StackAlloc
# sp = 5 (unchanged)
```

### 6.3 Ref Assignment

```rescript
s := Active(30, 40)
```

**IR Generation:**
```
1. Look up "s" → type "state": baseAddr=0, maxArgs=2
2. Get tag: Active = 1
3. Generate arg expressions: v1=30, v2=40
4. Emit: StackPoke(0, Num(1))          # tag
5. Emit: StackPoke(3, VReg(v1))        # baseAddr + 1*2 + 1 + 0 = 3
6. Emit: StackPoke(4, VReg(v2))        # baseAddr + 1*2 + 1 + 1 = 4
```

**IC10 Output:**
```asm
move r1 30       # v1 = 30
move r2 40       # v2 = 40
poke 0 1         # stack[0] = Active tag
poke 3 r1        # stack[3] = Active arg0
poke 4 r2        # stack[4] = Active arg1
```

### 6.4 Switch Expression

```rescript
switch s.contents {
| Idle(p, t) => p + t
| Active(p, t) => p - t
}
```

**IR Generation:**
```
1. Look up "s" → type "state": baseAddr=0, maxArgs=2
2. Allocate v3 for tag
3. Emit: StackGet(v3, 0)               # read tag from baseAddr
4. Emit: Compare(v4, EqOp, VReg(v3), Num(0))
5. Emit: Bnez(VReg(v4), "case_idle")
6. Emit: Compare(v5, EqOp, VReg(v3), Num(1))
7. Emit: Bnez(VReg(v5), "case_active")
8. Emit: Label("case_idle")
9. Emit: StackGet(v6, 1)               # p: baseAddr + 0*2 + 1 + 0 = 1
10. Emit: StackGet(v7, 2)              # t: baseAddr + 0*2 + 1 + 1 = 2
11. Emit: Binary(v8, AddOp, VReg(v6), VReg(v7))
12. Emit: Goto("match_end")
13. Emit: Label("case_active")
14. Emit: StackGet(v9, 3)              # p: baseAddr + 1*2 + 1 + 0 = 3
15. Emit: StackGet(v10, 4)             # t: baseAddr + 1*2 + 1 + 1 = 4
16. Emit: Binary(v11, SubOp, VReg(v9), VReg(v10))
17. Emit: Label("match_end")
```

**IC10 Output** (with peephole optimization):
```asm
get r0 db 0              # read tag from stack[0]
beq r0 0 case_idle       # if tag == 0 goto case_idle
beq r0 1 case_active     # if tag == 1 goto case_active

case_idle:
get r1 db 1              # p = stack[1]
get r2 db 2              # t = stack[2]
add r3 r1 r2             # result = p + t
j match_end

case_active:
get r4 db 3              # p = stack[3]
get r5 db 4              # t = stack[4]
sub r6 r4 r5             # result = p - t

match_end:
```

### 6.5 Multiple Variant Types

```rescript
type state = Idle | Active
type mode = Manual | Auto

let s = ref(Idle)
let m = ref(Manual)

s := Active
m := Auto
```

**Stack Layout:**
```
stack[0] = state.tag
stack[1] = (state placeholder - no args)
stack[2] = mode.tag
stack[3] = (mode placeholder - no args)
```

**Type Declaration IR:**
```
# type state
StackAlloc(2)        # Allocates stack[0..1], baseAddr=0

# type mode  
StackAlloc(2)        # Allocates stack[2..3], baseAddr=2
```

**Ref Creation IR:**
```
# let s = ref(Idle)
Move(v0, Num(0))            # ref points to baseAddr=0
StackPoke(0, Num(0))        # tag = Idle (0)

# let m = ref(Manual)
Move(v1, Num(2))            # ref points to baseAddr=2
StackPoke(2, Num(0))        # tag = Manual (0)
```

**Ref Assignment IR:**
```
# s := Active
StackPoke(0, Num(1))        # stack[0] = Active tag

# m := Auto
StackPoke(2, Num(1))        # stack[2] = Auto tag
```

**IC10 Output:**
```asm
# Type declarations
push 0    # stack[0] (state)
push 0    # stack[1]
push 0    # stack[2] (mode)
push 0    # stack[3]

# Refs
move r0 0       # s points to 0
poke 0 0        # s = Idle
move r1 2       # m points to 2
poke 2 0        # m = Manual

# Assignments
poke 0 1        # s = Active
poke 2 1        # m = Auto
```

---

## 7. Testing Strategy

### 7.1 Test Cases

#### Test 1: Single Variant Type (Baseline)
```rescript
type state = Idle(int) | Active(int)
let s = ref(Idle(100))
s := Active(200)
switch s.contents {
| Idle(x) => x + 10
| Active(x) => x - 10
}
```

**Expected**: Works exactly as before, baseAddr=0

#### Test 2: Two Different Variant Types
```rescript
type state = Idle | Active
type mode = Manual | Auto

let s = ref(Idle)
let m = ref(Manual)

s := Active
m := Auto
```

**Expected**: 
- `s` uses stack[0..1]
- `m` uses stack[2..3]
- No collision

#### Test 3: Second Ref of Same Type (Error Case)
```rescript
type state = Idle | Active

let s1 = ref(Idle)
let s2 = ref(Active)  // Should error!
```

**Expected Error**:
```
Type 'state' already has a ref allocated (variable 's1').
IC10 compiler currently supports one ref per variant type.
Workaround: Define a second type (e.g., 'type state2 = Idle2 | Active2')
```

#### Test 4: Complex Multi-Type Switch
```rescript
type state = Idle(int) | Active(int)
type mode = Manual(int) | Auto(int)

let s = ref(Idle(100))
let m = ref(Manual(50))

while true {
  switch s.contents {
  | Idle(x) => s := Active(x + 10)
  | Active(x) => s := Idle(x - 10)
  }
  
  switch m.contents {
  | Manual(y) => m := Auto(y * 2)
  | Auto(y) => m := Manual(y / 2)
  }
  
  yield
}
```

**Expected**: 
- Both switches work correctly
- State machines are independent
- No stack corruption

#### Test 5: Workaround Pattern
```rescript
type machine1 = Idle1 | Active1
type machine2 = Idle2 | Active2

let m1 = ref(Idle1)
let m2 = ref(Idle2)

m1 := Active1
m2 := Active2
```

**Expected**: Works correctly (different types, different base addresses)

### 7.2 Test Implementation

Create test file: `tests/ir-variant-multi-type.test.js`

```javascript
describe('IR Multi-Variant Type Support', () => {
  test('single variant type baseline', () => {
    const code = `
      type state = Idle(int) | Active(int)
      let s = ref(Idle(100))
    `;
    const result = compile(code, {useIR: true});
    expect(result).toContain('push 0');
    expect(result).toContain('poke 0 0');
  });

  test('two different variant types - no collision', () => {
    const code = `
      type state = Idle | Active
      type mode = Manual | Auto
      let s = ref(Idle)
      let m = ref(Manual)
    `;
    const result = compile(code, {useIR: true});
    // Verify separate base addresses
    expect(result).toContain('move r0 0');   // s → baseAddr 0
    expect(result).toContain('move r1 2');   // m → baseAddr 2
  });

  test('second ref of same type - error', () => {
    const code = `
      type state = Idle | Active
      let s1 = ref(Idle)
      let s2 = ref(Active)
    `;
    expect(() => compile(code, {useIR: true}))
      .toThrow(/already has a ref allocated/);
  });

  test('complex multi-type switch', () => {
    const code = `
      type state = Idle(int) | Active(int)
      type mode = Manual(int) | Auto(int)
      let s = ref(Idle(100))
      let m = ref(Manual(50))
      switch s.contents {
      | Idle(x) => x
      | Active(x) => x
      }
      switch m.contents {
      | Manual(y) => y
      | Auto(y) => y
      }
    `;
    const result = compile(code, {useIR: true});
    // Verify both switches use different base addresses
    expect(result).toContain('get r');  // Multiple gets
    expect(result).toContain('db 0');   // state tag read
    expect(result).toContain('db 5');   // mode tag read (or similar offset)
  });
});
```

---

## 8. Migration Path

### 8.1 Implementation Phases

#### Phase 1: IR Foundation ✅ (Already Complete)
- Basic IR types and instructions
- IRGen for simple expressions
- IRToIC10 lowering

#### Phase 2: Add Stack Operations (This Design)
1. Add `StackAlloc`, `StackPoke`, `StackGet`, `StackPush` to IR.res
2. Implement IRToIC10 lowering for stack ops
3. Add tests for new instructions

#### Phase 3: Type Declaration Support
1. Add `variantTypes`, `variantTags`, `stackAllocator` to IRGen state
2. Implement type declaration handling in IRGen
3. Emit StackAlloc for each type
4. Test: Multiple type declarations

#### Phase 4: Ref Creation Support
1. Implement ref creation in IRGen
2. Check and mark `allocated` flag
3. Emit StackPoke for initialization
4. Test: Single ref creation, error on duplicate

#### Phase 5: Ref Assignment Support
1. Implement ref assignment in IRGen
2. Calculate addresses with baseAddr
3. Emit StackPoke for tag and args
4. Test: Assignments to different variant types

#### Phase 6: Switch Expression Support
1. Implement switch expression in IRGen
2. Emit StackGet for tag and arguments
3. Test: Switches on different variant types

#### Phase 7: Integration Testing
1. End-to-end tests with multiple variant types
2. Complex state machine examples
3. Performance testing

### 8.2 Backward Compatibility

**Old codegen (non-IR path):**
- Remains unchanged
- Still has single-variant-type limitation
- Controlled by `useIR: false` option

**New IR path:**
- Enabled with `useIR: true`
- Supports multiple variant types
- One ref per type restriction

**Migration:**
- Users opt-in to IR path via compiler option
- Existing code continues to work (single variant type)
- New code can use multiple types (with restriction)

### 8.3 Documentation Updates

Update these files:
1. **VARIANT_STACK_LAYOUT.md**: Add section on multi-type support
2. **IR_IMPLEMENTATION_PLAN.md**: Add Phase for variants
3. **CLAUDE.md**: Document the one-ref-per-type restriction
4. **README**: Add examples with multiple variant types

---

## 9. Future Enhancements

### 9.1 Lift One-Ref-Per-Type Restriction

If demand exists, upgrade to full dynamic allocation:

**Changes needed:**
1. Move baseAddr from type metadata to ref metadata
2. Allocate stack segment at ref creation (not type declaration)
3. Change `variantTypes` structure:
   ```rescript
   // Current (simple):
   variantTypes: Map<typeName, (constructors, baseAddr, allocated)>
   
   // Future (dynamic):
   variantTypes: Map<typeName, constructors>
   refMetadata: Map<refName, (typeName, baseAddr)>
   ```

**Backward compatibility**: Existing code continues to work unchanged.

### 9.2 Stack Compaction

Currently, all constructor slots are pre-allocated. Optimization opportunity:

**Current:**
```
type state = Idle | Active(int, int, int)
# Allocates: 1 + 2*3 = 7 slots
# Idle uses only 1 slot but reserves 3
```

**Optimized:**
```
# Only allocate slots actually needed per constructor
# Variable-length encoding with metadata
```

**Trade-off**: More complex addressing logic vs. smaller stack footprint.

### 9.3 Nested Variants

Support variants containing other variants:

```rescript
type inner = A(int) | B(int)
type outer = X(inner) | Y(inner)
```

**Challenge**: How to represent nested stack structures in IR.

### 9.4 Variant Pattern Matching Optimization

Current approach:
- Linear search through tags (`beq r0 0`, `beq r0 1`, ...)

Optimization:
- Jump table for dense tag ranges
- Binary search for sparse tags

---

## Appendix A: Key Files

### Files to Create
- None (all modifications to existing IR files)

### Files to Modify
1. `src/compiler/IR/IR.res` - Add stack instruction types
2. `src/compiler/IR/IRGen.res` - Implement variant codegen
3. `src/compiler/IR/IRToIC10.res` - Lower stack ops to IC10
4. `tests/ir-variant-multi-type.test.js` - New test suite

### Files to Reference
- `VARIANT_STACK_LAYOUT.md` - Original variant design
- `IC10_STACK_INSTRUCTIONS.md` - IC10 stack reference
- `IR_IMPLEMENTATION_PLAN.md` - Overall IR plan

---

## Appendix B: Decision Log

| Decision | Rationale | Date |
|----------|-----------|------|
| One ref per type | Simplifies compiler for IC10 constraints | 2025-11-11 |
| Allocate at type declaration | Enables static baseAddr storage | 2025-11-11 |
| Use StackPoke for init | Avoids double-push problem | 2025-11-11 |
| Add 4 new IR instructions | Clean abstraction for stack ops | 2025-11-11 |
| Store baseAddr with type | Simpler than per-ref tracking | 2025-11-11 |

---

## Appendix C: Example End-to-End

**Input ReScript:**
```rescript
type state = Idle(int) | Active(int)
type mode = Manual | Auto

let s = ref(Idle(100))
let m = ref(Manual)

s := Active(200)

switch s.contents {
| Idle(x) => x + 10
| Active(x) => x - 10
}
```

**IR Output:**
```
# Type declarations
StackAlloc(5)              # state: baseAddr=0
StackAlloc(2)              # mode: baseAddr=5

# Ref creations
Move(v0, Num(0))           # s → baseAddr 0
StackPoke(0, Num(0))       # tag = Idle
StackPoke(1, Num(100))     # Idle arg0
Move(v1, Num(5))           # m → baseAddr 5
StackPoke(5, Num(0))       # tag = Manual

# Assignment
StackPoke(0, Num(1))       # tag = Active
StackPoke(3, Num(200))     # Active arg0

# Switch
StackGet(v2, 0)            # read tag
Compare(v3, EqOp, VReg(v2), Num(0))
Bnez(VReg(v3), "case_idle")
Compare(v4, EqOp, VReg(v2), Num(1))
Bnez(VReg(v4), "case_active")

Label("case_idle")
StackGet(v5, 1)            # x = stack[1]
Binary(v6, AddOp, VReg(v5), Num(10))
Goto("match_end")

Label("case_active")
StackGet(v7, 3)            # x = stack[3]
Binary(v8, SubOp, VReg(v7), Num(10))

Label("match_end")
```

**IC10 Output:**
```asm
# Type declarations
push 0
push 0
push 0
push 0
push 0
push 0
push 0

# Refs
move r0 0
poke 0 0
poke 1 100
move r1 5
poke 5 0

# Assignment
poke 0 1
poke 3 200

# Switch
get r2 db 0
beq r2 0 case_idle
beq r2 1 case_active

case_idle:
get r3 db 1
add r4 r3 10
j match_end

case_active:
get r5 db 3
sub r6 r5 10

match_end:
```

---

**End of Design Document**
