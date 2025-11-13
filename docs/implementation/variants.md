# Variant Types Implementation

## Overview

This document describes the complete implementation of ReScript variant types in the IC10 compiler, including stack layout design, multi-type support, and IR architecture.

## Table of Contents

1. [Stack Layout Design](#stack-layout-design)
2. [Multi-Type Support](#multi-type-support)
3. [IR Architecture](#ir-architecture)
4. [Implementation Details](#implementation-details)
5. [Code Generation Flow](#code-generation-flow)

---

## Stack Layout Design

### Core Principle

**The stack pointer (`sp`) is set once during ref creation and NEVER modified afterwards.**

- Reading: Use `get r? db address` to read from device stack without touching `sp`
- Writing: Use `poke address value` to write to stack without touching `sp`
- Stack slots are pre-allocated for all variant cases and their arguments

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

### Example

For a variant type:
```rescript
type action = Idle | Move(int, int) | Attack(int)
```

Parameters:
- N = 3 constructors (Idle, Move, Attack)
- M = 2 arguments (maximum from Move)
- Total slots = 1 + (3 * 2) = 7 slots

Stack layout:
```
stack[0] = tag (0=Idle, 1=Move, 2=Attack)
stack[1] = Move arg0 (x)
stack[2] = Move arg1 (y)
stack[3] = Attack arg0 (target)
stack[4] = (unused)
stack[5] = (unused - Idle has no args)
stack[6] = (unused - Idle has no args)
```

---

## Multi-Type Support

### Problem Statement

The original variant implementation hardcoded all variant refs to use `stack[0]` as their base address. This created a critical limitation: only one variant type could exist in a program.

### The Collision Problem

When multiple variant types are declared:

```rescript
type state = Idle | Active
type mode = Manual | Auto

let s = ref(Idle)   // Would allocate stack[0..1]
let m = ref(Manual) // Would ALSO try to use stack[0..1] - COLLISION!
```

Both refs would point to the same stack location, causing data corruption.

### Solution: One Ref Per Type

**Design Decision**: Each variant ref gets its own dedicated stack region.

```rescript
type state = Idle | Active      // 1 + (2 * 0) = 1 slot
type mode = Manual | Auto       // 1 + (2 * 0) = 1 slot
type action = Move(int, int)    // 1 + (1 * 2) = 3 slots

let s = ref(Idle)    // stack[0]     (baseAddr = 0)
let m = ref(Manual)  // stack[1]     (baseAddr = 1)
let a = ref(Move(5, 10)) // stack[2..4] (baseAddr = 2)
```

### Stack Allocation Strategy

**Fixed-size allocation** at compile time:

1. **Parse all type declarations** to determine slot requirements
2. **Allocate stack regions** sequentially for each type
3. **Track base addresses** in variant type metadata
4. **Generate code** using computed base addresses

Example allocation:
```
Type: state  -> slots needed: 1, baseAddr: 0, range: [0]
Type: mode   -> slots needed: 1, baseAddr: 1, range: [1]
Type: action -> slots needed: 3, baseAddr: 2, range: [2, 3, 4]
```

---

## IR Architecture

### Type Metadata Storage

The IR generator maintains variant type information in state:

```rescript
type variantTypeInfo = {
  constructors: array<AST.variantConstructor>,
  baseAddr: int,  // Stack base address for this type
  totalSlots: int // Total stack slots needed
}

type state = {
  // ... other fields
  variantTypes: Belt.Map.String.t<variantTypeInfo>,  // Type name -> metadata
  variantTags: Belt.Map.String.t<int>,               // Constructor -> tag
  variantRefTypes: Belt.Map.String.t<string>,        // Ref name -> type name
  nextStackAddr: int,                                // Next available stack address
}
```

### IR Instructions for Stack Operations

New IR instructions for variant manipulation:

```rescript
type instruction =
  | ...
  | StackPush(value)           // push value
  | StackPop(vreg)             // pop r?
  | StackPeek(vreg, offset)    // get r? db offset
  | StackPoke(offset, value)   // poke offset value
```

### Code Generation Flow

1. **Type Declaration Processing**:
   ```rescript
   type state = Idle | Active
   ```
   - Calculate slots needed: 1 + (2 * 0) = 1
   - Assign baseAddr: nextStackAddr (e.g., 0)
   - Store metadata in variantTypes map
   - Update nextStackAddr += totalSlots

2. **Ref Creation**:
   ```rescript
   let s = ref(Idle)
   ```
   - Push tag to stack: `push 0`
   - Store ref's base address in vreg: `move r0 sp`
   - Associate ref with type in variantRefTypes map

3. **Ref Assignment**:
   ```rescript
   s := Active
   ```
   - Look up baseAddr from variantRefTypes + variantTypes
   - Generate: `poke baseAddr 1`  // Write new tag

4. **Switch Expression**:
   ```rescript
   switch s.contents {
   | Idle => ...
   | Active => ...
   }
   ```
   - Look up baseAddr
   - Read tag: `get r? db baseAddr`
   - Generate branches based on tag value

---

## Implementation Details

### Phase 1: Type Declaration Processing

Located in `IRGen.res:generateStmt`:

```rescript
| TypeDeclaration(typeName, constructors) =>
  // Calculate max arguments
  let maxArgs = Array.reduce(constructors, 0, (max, c) => 
    if c.argCount > max { c.argCount } else { max }
  )
  
  // Calculate total slots
  let numConstructors = Array.length(constructors)
  let totalSlots = 1 + (numConstructors * maxArgs)
  
  // Assign base address
  let baseAddr = state.nextStackAddr
  
  // Store type metadata
  let variantTypes = Belt.Map.String.set(
    state.variantTypes,
    typeName,
    {constructors, baseAddr, totalSlots}
  )
  
  // Update next available address
  let nextStackAddr = state.nextStackAddr + totalSlots
  
  // Store constructor tags
  let (variantTags, _) = Array.reduce(constructors, (state.variantTags, 0),
    ((tags, tagNum), constructor) => {
      let tags = Belt.Map.String.set(tags, constructor.name, tagNum)
      (tags, tagNum + 1)
    }
  )
  
  Ok({...state, variantTypes, variantTags, nextStackAddr})
```

### Phase 2: Ref Variable Creation

Located in `IRGen.res:generateStmt`:

```rescript
| VariableDeclaration(name, RefCreation(VariantConstructor(constructorName, args))) =>
  // Look up which type this constructor belongs to
  switch getVariantTypeName(state, constructorName) {
  | None => Error("Unknown variant constructor")
  | Some(typeName) =>
    switch Belt.Map.String.get(state.variantTypes, typeName) {
    | None => Error("Variant type not found")
    | Some(typeInfo) =>
      // Allocate vreg for the ref
      let (state, refVreg) = allocVReg(state)
      
      // Push variant data to stack
      // 1. Push tag
      let tag = Belt.Map.String.get(state.variantTags, constructorName)->Option.getExn
      let state = emit(state, IR.StackPush(IR.Num(tag)))
      
      // 2. Push all argument slots (even if unused)
      let state = pushAllSlots(state, typeInfo.totalSlots - 1)
      
      // 3. Store base address in ref vreg
      let state = emit(state, IR.Move(refVreg, IR.StackAddr(typeInfo.baseAddr)))
      
      // Track ref-to-type mapping
      let variantRefTypes = Belt.Map.String.set(state.variantRefTypes, name, typeName)
      
      Ok({...state, variantRefTypes, varMap: Belt.Map.String.set(state.varMap, name, {vreg: refVreg, isRef: true})})
    }
  }
```

### Phase 3: Ref Assignment

Located in `IRGen.res:generateStmt`:

```rescript
| RefAssignment(name, VariantConstructor(constructorName, args)) =>
  // Look up ref's type
  switch Belt.Map.String.get(state.variantRefTypes, name) {
  | None => Error("Not a variant ref")
  | Some(typeName) =>
    switch Belt.Map.String.get(state.variantTypes, typeName) {
    | None => Error("Variant type not found")
    | Some(typeInfo) =>
      // Get constructor tag
      let tag = Belt.Map.String.get(state.variantTags, constructorName)->Option.getExn
      
      // Poke tag to baseAddr
      let state = emit(state, IR.StackPoke(typeInfo.baseAddr, IR.Num(tag)))
      
      // Poke all arguments
      let state = pokeArgs(state, typeInfo, tag, args)
      
      Ok(state)
    }
  }
```

### Phase 4: Switch Expression

Located in `IRGen.res:generateExpr`:

```rescript
| SwitchExpression(RefAccess(refName), cases) =>
  // Look up ref's type
  switch Belt.Map.String.get(state.variantRefTypes, refName) {
  | None => Error("Not a variant ref")
  | Some(typeName) =>
    switch Belt.Map.String.get(state.variantTypes, typeName) {
    | None => Error("Variant type not found")
    | Some(typeInfo) =>
      // Read tag from stack
      let (state, tagVreg) = allocVReg(state)
      let state = emit(state, IR.StackPeek(tagVreg, typeInfo.baseAddr))
      
      // Generate case branches
      generateSwitchCases(state, tagVreg, cases, typeInfo)
    }
  }
```

---

## Code Generation Flow

### Complete Example

ReScript source:
```rescript
type state = Idle | Active(int)
type mode = Manual | Auto

let s = ref(Idle)
let m = ref(Manual)

s := Active(100)

switch s.contents {
| Idle => 0
| Active(x) => x
}
```

Generated IC10 assembly:
```asm
# Type declarations (no code generated, metadata stored)

# let s = ref(Idle)
push 0          # tag for Idle
push 0          # placeholder slot for Active's arg
move r0 0       # s points to stack[0]

# let m = ref(Manual)
push 0          # tag for Manual
move r1 2       # m points to stack[2]

# s := Active(100)
poke 0 1        # write Active tag to stack[0]
poke 1 100      # write arg to stack[1]

# switch s.contents
get r2 db 0     # read tag from stack[0]
beq r2 0 label0 # if tag == 0 (Idle), jump to label0
  # Active case
  get r3 db 1   # read arg from stack[1]
  move r4 r3    # result = x
  j label1
label0:
  # Idle case
  move r4 0     # result = 0
label1:
  # r4 contains final result
```

---

## Testing Strategy

### Test Cases

1. **Single Variant Type** - Basic functionality
2. **Multiple Variant Types** - No collisions
3. **Nested Variants** - Complex structures
4. **Switch with Arguments** - Argument binding
5. **Multiple Refs Same Type** - Shared metadata, different addresses

### Example Test

```rescript
// tests/variants.test.js
test('multiple variant types do not collide', () => {
  const code = `
    type state = Idle | Active
    type mode = Manual | Auto
    
    let s = ref(Idle)
    let m = ref(Manual)
    
    s := Active
    m := Auto
    
    let result = switch (s.contents, m.contents) {
    | (Active, Auto) => 1
    | _ => 0
    }
  `
  
  const output = compile(code)
  expect(output).toContain('poke 0 1')  // s := Active (baseAddr=0)
  expect(output).toContain('poke 1 1')  // m := Auto (baseAddr=1)
})
```

---

## Migration Path

### From Old Codegen to IR

1. **Phase 1**: IR generator supports variant types
2. **Phase 2**: IRToIC10 lowers stack operations
3. **Phase 3**: Old codegen kept for backward compatibility
4. **Phase 4**: Tests migrated to IR path
5. **Phase 5**: Old codegen deprecated

### Compatibility Notes

- Stack layout remains identical
- Assembly output is functionally equivalent
- Performance characteristics unchanged
- Tests pass with both implementations

---

## Future Enhancements

### Potential Optimizations

1. **Stack Slot Reuse** - Reuse slots from unused variants
2. **Packed Layouts** - More efficient memory usage
3. **Dynamic Allocation** - Runtime stack management
4. **Type Inference** - Automatic variant type detection

### Limitations

- Fixed stack size at compile time
- No runtime type checking
- Limited to integer arguments
- No nested variant support (yet)

---

## References

- Stack Layout Diagram: https://excalidraw.com/#json=eoEP3WZFL6GMkwmUvAAgG,sELPVBW5f9Ik2IF9lDjx3A
- IC10 Assembly Reference: [ic10-support.md](../user-guide/ic10-support.md)
- IR Architecture: [ir-design.md](../architecture/ir-design.md)
