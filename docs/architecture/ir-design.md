# IR Layer Implementation Plan - Incremental Migration

## Overview

Incrementally migrate the compiler from direct AST → IC10 to AST → IR → IC10, starting with simple constructs and expanding gradually. The IR will use virtual registers (unlimited) with a separate physical register allocation pass (vreg → r0-r15).

**Key Decisions:**
- **Approach**: Incremental migration (simple constructs first, expand gradually)
- **Tests**: Allow temporary failures during transition, fix in Phase 4
- **Branching Strategy**: Uniform `Compare` + `Bnez` pattern (simple IR, optimize later)
- **Optimizations**: Phase 2 generates 2-instruction branches; future peephole optimization will fuse to 1
- **Register Allocation**: Virtual registers in IR → Physical allocation as separate pass

---

## Phase 1: Foundation (Simple Expressions & Variables)

**Goal**: Get basic IR generation working with simple constructs

### 1.1 Implement IRGen.res basics

Create the IR generation module that converts AST to IR.

**State type:**
```rescript
type state = {
  nextVReg: int,              // Counter for virtual register allocation
  instructions: list<IR.instr>, // Accumulated IR instructions
  nextLabel: int,             // Counter for label generation
  varMap: Map.String.t<int>,  // Variable name → virtual register mapping
}
```

**Core functions:**

1. **`generateExpr(state, expr) → (state, vreg)`**
   - `Literal(n)` → Allocate vreg, emit `Move(vreg, Num(n))`
   - `Identifier(name)` → Lookup vreg in varMap, emit `Move(newVreg, VReg(sourceVreg))`
   - `BinaryExpression(left, op, right)` → Generate left/right, emit `Binary(resultVreg, op, leftOperand, rightOperand)`
     - Only handle: Add, Sub, Mul, Div initially
     - Convert AST binary ops to IR binary ops

2. **`generateStmt(state, stmt) → state`**
   - `VariableDeclaration(name, init)` → Generate init expr, store vreg in varMap
   - Skip refs, variants for now (Phase 3)

3. **`generate(ast: AST.program) → result<IR.t, string>`**
   - Entry point: initialize state, loop through statements, return IR program

### 1.2 Create IRPrint.res

Pretty-printer for IR debugging and visualization.

**Function:**
```rescript
let print: IR.t → string
```

**Format:**
- Virtual registers as `v0`, `v1`, `v2`, etc.
- Instructions with proper indentation
- Labels on their own line
- Example output:
  ```
  move v0 5
  move v1 3
  add v2 v0 v1
  ```

### 1.3 Implement IRToIC10.res

Convert IR (with virtual registers) to IC10 assembly (with physical registers r0-r15).

**State type:**
```rescript
type state = {
  vregMap: Map.Int.t<Register.t>,  // vreg → physical register mapping
  nextPhysical: int,                // Next available physical register (0-15)
  output: array<string>,            // Accumulated IC10 instructions
}
```

**Core functions:**

1. **`allocatePhysicalReg(state, vreg) → result<(state, Register.t), string>`**
   - Check if vreg already mapped → return existing
   - Allocate next physical register (r0, r1, ..., r15)
   - Error if >16 registers needed: "Register allocation failed: exceeded 16 physical registers"

2. **`convertOperand(state, operand) → result<(state, string), string>`**
   - `VReg(v)` → Allocate physical, return "rN"
   - `Num(n)` → Return string of number
   - `Name(name)` → Return name directly (for constant references)

3. **`generateInstr(state, instr) → result<state, string>`**
   - `Move(vreg, operand)` → Allocate physical for vreg, emit `move rN <operand>`
   - `Binary(vreg, op, left, right)` → Allocate physical for vreg, convert operands, emit `<op> rN <left> <right>`
     - Map IR ops to IC10: AddOp→"add", SubOp→"sub", MulOp→"mul", DivOp→"div"

4. **`generate(ir: IR.t) → result<string, string>`**
   - Loop through all blocks and instructions
   - Convert to IC10 assembly
   - Join with newlines

### 1.4 Add compiler flag in Compiler.res

Add branching logic to enable IR pipeline.

**Modifications:**

1. Add `useIR: bool` to `compilerOptions` type (default `false`)

2. Update `compile()` function:
   ```rescript
   let optimizedAst = ast->Optimizer.optimizeProgram

   if compilerOptions.useIR {
     optimizedAst
       ->IRGen.generate
       ->Result.flatMap(ir => {
         // Optional: print IR for debugging
         if compilerOptions.debugAST {
           Js.Console.log("=== IR ===")
           Js.Console.log(IRPrint.print(ir))
         }
         IRToIC10.generate(ir)
       })
       ->Result.map(code => Program(code))
   } else {
     // Existing codegen path
     Codegen.generate(optimizedAst, compilerOptions)
       ->Result.map(res => Program(res))
   }
   ```

### 1.5 Test with simple examples

**Test cases to verify:**

1. Simple literal assignment:
   ```rescript
   let x = 5
   ```
   - IR: `Move(v0, Num(5))`
   - IC10: `move r0 5`

2. Variable reference:
   ```rescript
   let x = 5
   let y = x
   ```
   - IR: `Move(v0, Num(5))`, `Move(v1, VReg(v0))`
   - IC10: `move r0 5`, `move r1 r0`

3. Binary operation:
   ```rescript
   let y = x + 3
   ```
   - IR: `Binary(v1, AddOp, VReg(v0), Num(3))`
   - IC10: `add r1 r0 3`

4. Operator precedence:
   ```rescript
   let z = a + b * c
   ```
   - Verify AST structure preserved in IR
   - Verify correct instruction ordering

**Success criteria:** All simple expression tests produce correct IC10 output matching current codegen behavior.

---

## Phase 2: Control Flow (If/Else)

**Goal**: Implement uniform branching with `Compare` + `Bnez` pattern

**Strategy**: Generate simple 2-instruction branches (Compare → Bnez) in Phase 2. Future peephole optimization will fuse these into single IC10 branch instructions.

### 2.1 Extend IR with comparison and branch instructions

Add new instruction types to `IR.res`:

**New types:**
```rescript
type compareOp = LtOp | GtOp | EqOp | GeOp | LeOp | NeOp

type instr =
  | Move(int, operand)
  | Binary(binaryOp, int, operand, operand)
  | Compare(int, compareOp, operand, operand)  // dest = (left op right) ? 1 : 0
  | Bnez(operand, string)                       // if operand != 0, jump to label
  | Label(string)                               // jump target
  | Goto(string)                                // unconditional jump
  // ... other existing instructions
```

**Note**: We use only `Bnez` (not `Beqz`) for simplicity. If-only uses inverted comparison operators.

### 2.2 Add comparison operator helpers

Create helper functions in `IRGen.res`:

```rescript
let invertCompareOp = (op: AST.binaryOp): IR.compareOp => {
  switch op {
  | Lt => GeOp  // NOT(a < b) is (a >= b)
  | Gt => LeOp  // NOT(a > b) is (a <= b)
  | Eq => NeOp  // NOT(a == b) is (a != b)
  | _ => failwith("Not a comparison operator")
  }
}

let normalCompareOp = (op: AST.binaryOp): IR.compareOp => {
  switch op {
  | Lt => LtOp
  | Gt => GtOp
  | Eq => EqOp
  | _ => failwith("Not a comparison operator")
  }
}
```

### 2.3 Extend generateExpr for comparisons

**Modifications to `generateExpr()`:**

Handle comparison operators by emitting `Compare` instruction:

```rescript
| BinaryExpression(left, (Lt | Gt | Eq as cmpOp), right) => {
    // Generate left operand
    let (state, leftVreg) = generateExpr(state, left)
    // Generate right operand
    let (state, rightVreg) = generateExpr(state, right)
    // Allocate result vreg
    let resultVreg = state.nextVReg
    let state = {...state, nextVReg: state.nextVReg + 1}
    // Map AST comparison to IR compareOp
    let irOp = normalCompareOp(cmpOp)  // Use normal (not inverted) here
    // Emit Compare instruction
    let state = emitInstr(state, Compare(resultVreg, irOp, VReg(leftVreg), VReg(rightVreg)))
    // Return state with result vreg
    (state, resultVreg)
  }
```

### 2.4 Implement if-only statement generation

**New function:**

```rescript
let generateIfOnly = (state, condition, thenBlock) => {
  // 1. Extract comparison operator and operands from condition
  // 2. Generate left and right operands
  let (state, leftVreg) = generateExpr(state, leftExpr)
  let (state, rightVreg) = generateExpr(state, rightExpr)

  // 3. Allocate result vreg and emit INVERTED comparison
  let resultVreg = state.nextVReg
  let state = {...state, nextVReg: state.nextVReg + 1}
  let invertedOp = invertCompareOp(op)  // Lt → GeOp, etc.
  let state = emitInstr(state, Compare(resultVreg, invertedOp, VReg(leftVreg), VReg(rightVreg)))

  // 4. Allocate end label
  let endLabel = `label${state.nextLabel}`
  let state = {...state, nextLabel: state.nextLabel + 1}

  // 5. Emit Bnez - if inverted condition is true (original is false), skip then block
  let state = emitInstr(state, Bnez(VReg(resultVreg), endLabel))

  // 6. Generate then block
  let state = generateBlock(state, thenBlock)

  // 7. Emit end label
  let state = emitInstr(state, Label(endLabel))

  state
}
```

### 2.5 Implement if-else statement generation

**New function:**

```rescript
let generateIfElse = (state, condition, thenBlock, elseBlock) => {
  // 1. Extract comparison and generate operands
  let (state, leftVreg) = generateExpr(state, leftExpr)
  let (state, rightVreg) = generateExpr(state, rightExpr)

  // 2. Allocate result vreg and emit NORMAL comparison
  let resultVreg = state.nextVReg
  let state = {...state, nextVReg: state.nextVReg + 1}
  let normalOp = normalCompareOp(op)  // Lt → LtOp, etc.
  let state = emitInstr(state, Compare(resultVreg, normalOp, VReg(leftVreg), VReg(rightVreg)))

  // 3. Allocate labels
  let thenLabel = `label${state.nextLabel}`
  let endLabel = `label${state.nextLabel + 1}`
  let state = {...state, nextLabel: state.nextLabel + 2}

  // 4. Emit Bnez - if condition is true, jump to then
  let state = emitInstr(state, Bnez(VReg(resultVreg), thenLabel))

  // 5. Generate else block (falls through)
  let state = generateBlock(state, elseBlock)

  // 6. Jump over then block
  let state = emitInstr(state, Goto(endLabel))

  // 7. Then block label
  let state = emitInstr(state, Label(thenLabel))

  // 8. Generate then block
  let state = generateBlock(state, thenBlock)

  // 9. End label
  let state = emitInstr(state, Label(endLabel))

  state
}
```

### 2.6 Update generateStmt for IfStatement

Add case to `generateStmt()`:

```rescript
| IfStatement(condition, thenBlock, elseBlock) => {
    switch elseBlock {
    | None => generateIfOnly(state, condition, thenBlock)
    | Some(block) => generateIfElse(state, condition, thenBlock, block)
    }
  }
```

### 2.7 Extend IRToIC10 for new instructions

Add handlers in `generateInstr()`:

```rescript
| Compare(vreg, op, left, right) => {
    let (state, destReg) = allocatePhysicalReg(state, vreg)
    let (state, leftStr) = convertOperand(state, left)
    let (state, rightStr) = convertOperand(state, right)

    let ic10Op = switch op {
    | LtOp => "slt"
    | GtOp => "sgt"
    | EqOp => "seq"
    | GeOp => "sge"
    | LeOp => "sle"
    | NeOp => "sne"
    }

    emitInstruction(state, `${ic10Op} ${destReg} ${leftStr} ${rightStr}`)
  }

| Bnez(operand, label) => {
    let (state, opStr) = convertOperand(state, operand)
    emitInstruction(state, `bnez ${opStr} ${label}`)
  }

| Label(name) => {
    emitInstruction(state, `${name}:`)
  }

| Goto(label) => {
    emitInstruction(state, `j ${label}`)
  }
```

### 2.8 Update IRPrint for new instructions

Add pretty-printing:

```rescript
| Compare(vreg, op, left, right) =>
    `${compareOpToString(op)} v${vreg} ${operandToString(left)} ${operandToString(right)}`
| Bnez(operand, label) =>
    `bnez ${operandToString(operand)} ${label}`
| Label(name) =>
    `${name}:`
| Goto(label) =>
    `j ${label}`
```

### 2.9 Test if/else patterns

**Test cases:**

1. **If-only with inverted comparison:**
   ```rescript
   if a < b {
     let c = 1
   }
   ```
   - IR: `Compare(v2, GeOp, VReg(v0), VReg(v1))`, `Bnez(VReg(v2), label0)`, `Move(v3, Num(1))`, `Label(label0)`
   - IC10 (unoptimized): `sge r2 r0 r1`, `bnez r2 label0`, `move r3 1`, `label0:`
   - Future optimized: `bge r0 r1 label0`, `move r2 1`, `label0:`

2. **If-else with normal comparison:**
   ```rescript
   if a < b {
     let c = 1
   } else {
     let c = 2
   }
   ```
   - IR: `Compare(v2, LtOp, VReg(v0), VReg(v1))`, `Bnez(VReg(v2), label1)`, `Move(v3, Num(2))`, `Goto(label0)`, `Label(label1)`, `Move(v4, Num(1))`, `Label(label0)`
   - IC10 (unoptimized): `slt r2 r0 r1`, `bnez r2 label1`, `move r3 2`, `j label0`, `label1:`, `move r4 1`, `label0:`
   - Future optimized: `blt r0 r1 label1`, `move r2 2`, `j label0`, `label1:`, `move r3 1`, `label0:`

3. Nested if statements
4. Multiple consecutive if statements

**Success criteria:**
- All if/else tests generate correct 2-instruction IC10 branches
- Logic is correct (proper condition evaluation)
- Labels are unique and correctly placed

---

## Phase 2.5: Peephole Optimization (Future Enhancement)

**Goal**: Optimize Compare + Bnez sequences into single IC10 branch instructions

**When**: After Phase 4 is complete and all tests pass

**Approach**: Add peephole optimization pass in IRToIC10 or create new `IC10Optimizer.res` module

### Optimization Patterns

Detect and fuse these patterns:

```
slt rTemp rLeft rRight  +  bnez rTemp label  →  blt rLeft rRight label
sgt rTemp rLeft rRight  +  bnez rTemp label  →  bgt rLeft rRight label
seq rTemp rLeft rRight  +  bnez rTemp label  →  beq rLeft rRight label
sge rTemp rLeft rRight  +  bnez rTemp label  →  bge rLeft rRight label
sle rTemp rLeft rRight  +  bnez rTemp label  →  ble rLeft rRight label
sne rTemp rLeft rRight  +  bnez rTemp label  →  bne rLeft rRight label
```

### Implementation Strategy

1. **Pattern matching**: Scan consecutive IC10 instructions
2. **Register liveness check**: Verify temp register is only used for branch
3. **Dead code elimination**: Remove temp register allocation if only used for fused branch
4. **Instruction fusion**: Replace 2 instructions with 1 direct branch

### Benefits

- **Same output as current compiler**: Matches existing codegen efficiency
- **Zero-cost abstraction**: Simple IR, optimized output
- **Toggleable**: Can disable for debugging
- **Measurable**: Compare instruction counts before/after

### Future Opportunities

- Constant folding in comparisons
- Branch target optimization
- Dead code elimination after branches

---

## Phase 3: Remaining Features

**Goal**: Full feature parity with current codegen

### 3.1 While loops

Add loop support with inverted exit branches.

**IRGen changes:**
- `generateWhileLoop(state, condition, body) → state`
  - Allocate labels: `loopLabel`, `endLabel`
  - Emit `Label(loopLabel)`
  - Generate condition with inverted branch to `endLabel`
  - Generate body instructions
  - Emit `Goto(loopLabel)`
  - Emit `Label(endLabel)`

**IRToIC10:** Already supports needed instructions (Branch, Label, Goto)

### 3.2 Variants and refs (Complex - may defer)

Add support for variant types and mutable references.

**IR changes needed:**
- Add `DefHash(name, value)` instruction handling
- Add `Load`/`Save` instruction variants for device I/O
- Add stack allocation tracking (fixed layouts)
- Handle variant constructor tag/arg operations

**Complexity:** High - involves stack management, poke instructions, tag extraction. Consider deferring until Phases 1-2 are stable.

### 3.3 Switch expressions

Pattern matching with tag extraction and branching.

**IRGen changes:**
- Generate tag extraction from stack
- Generate series of comparisons and branches
- Handle pattern matching with guards

### 3.4 Function calls (device I/O)

Map device I/O operations to IR instructions.

**IR already has:**
- `Load(register, device, field)` → `l rN dN field`
- `Save(device, field, value)` → `s dN field value`
- Bulk operations: `LoadBulk`, `SaveBulk`

**IRGen:** Map AST function calls to IR Load/Save instructions

### 3.5 Raw instructions

Pass-through for raw IC10 assembly.

**IR change:** Add `RawIC10(string)` instruction variant
**IRToIC10:** Emit string directly

---

## Phase 4: Migration & Cleanup

**Goal**: Complete transition to IR-based compiler

### 4.1 Switch default to `useIR: true`

Change default in `compilerOptions` to enable IR pipeline by default.

### 4.2 Update test expectations

1. Run all 40 tests with IR pipeline enabled
2. Analyze differences in assembly output
   - Register allocation may differ (different assignment strategy)
   - Instruction ordering may differ (but semantics must match)
3. Update expected outputs in test files
4. Verify all tests pass

### 4.3 Remove old codegen

Once IR pipeline is proven stable:

1. Delete deprecated modules:
   - `src/compiler/StmtGen.res`
   - `src/compiler/ExprGen.res`
   - `src/compiler/BranchGen.res`
2. Simplify `Codegen.res` (or delete if fully replaced)
3. Remove `useIR` flag (IR is now the only path)
4. Update CLAUDE.md to reflect new architecture

### 4.4 Performance validation

Verify compiled code quality:

1. **Register utilization**: Compare register usage between old/new codegen
2. **Instruction count**: Ensure IR doesn't generate more instructions
3. **Optimization opportunities**: Identify future IR-level optimization potential
4. **Compilation speed**: Measure compilation time (should be similar or faster)

---

## Key Architectural Points

### Virtual Register Allocation

- **IRGen phase**: Uses unlimited virtual registers (v0, v1, v2, ...)
- **IRToIC10 phase**: Maps virtual → physical (r0-r15) during codegen
- **Benefits**:
  - Separates concerns (IR generation doesn't worry about physical limits)
  - Enables future optimizations (register coalescing, live range analysis)
  - Clearer error messages (can identify which variable caused spill)

### IR Instruction Design

- **Matches IC10 closely**: Move, Binary ops, Branch, Load/Save
- **Operands are flexible**: Can be virtual registers, immediate values, OR named constants
  - `VReg(vreg)` - Virtual register reference
  - `Num(int)` - Immediate integer value
  - `Name(string)` - Named constant reference (e.g., defined via `define`)
- **Labels are explicit**: Not implicit like current codegen
- **Benefits**:
  - Easy to reason about (1:1 or 1:few mapping to IC10)
  - Enables future analysis passes
  - Clear representation of control flow
  - Named constants allow referencing `define` statements

### Backward Compatibility

- **Keep `useIR` flag**: Toggle between pipelines during development
- **Maintain old codegen**: Keep until Phase 4 completion
- **Benefits**:
  - Can compare outputs during development
  - Safety net if IR has bugs
  - Can revert if needed

### Testing Strategy

- **Phases 1-3**: Tests will fail (expected behavior)
- **Phase 4**: Fix all tests when IR is feature-complete
- **Expected changes**:
  - Register allocation may differ (v0→r0 vs old strategy)
  - Label numbering may differ
  - Instruction ordering may differ slightly
- **Semantic equivalence**: Output must be functionally identical

---

## Success Metrics

### Phase 1 Success
- [ ] IRGen generates IR for simple expressions
- [ ] IRPrint produces readable output
- [ ] IRToIC10 converts IR to IC10 assembly
- [ ] Simple test cases produce correct output
- [ ] No register allocation failures for simple programs

### Phase 2 Success
- [ ] If-only statements use inverted comparisons with `Bnez` correctly
- [ ] If-else statements use normal comparisons with `Bnez` correctly
- [ ] Compare instructions emit correct IC10 (`slt`, `sgt`, `seq`, etc.)
- [ ] Bnez instructions work properly
- [ ] Label generation works properly (unique labels)
- [ ] Nested conditionals compile correctly
- [ ] 2-instruction branches are semantically correct (will be optimized in Phase 2.5)

### Phase 3 Success
- [ ] All language features supported (loops, variants, refs, etc.)
- [ ] Complex programs compile successfully

### Phase 4 Success
- [ ] All 40 tests pass with IR pipeline
- [ ] Old codegen removed
- [ ] Documentation updated
- [ ] Performance metrics acceptable

---

## Timeline Estimate

- **Phase 1**: 2-3 hours (foundation)
- **Phase 2**: 1-2 hours (control flow)
- **Phase 3**: 3-4 hours (remaining features, especially variants/refs)
- **Phase 4**: 1-2 hours (cleanup and validation)

**Total**: ~8-11 hours of focused development

---

## Notes

- Start with Phase 1, validate thoroughly before moving to Phase 2
- Use IRPrint extensively for debugging
- Compare IR output against current codegen output to ensure correctness
- Don't optimize prematurely - match current behavior exactly first
- Future optimization opportunities can be identified and implemented after Phase 4
