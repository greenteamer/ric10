# IR Layer Implementation Plan - Incremental Migration

## Overview

Incrementally migrate the compiler from direct AST → IC10 to AST → IR → IC10, starting with simple constructs and expanding gradually. The IR will use virtual registers (unlimited) with a separate physical register allocation pass (vreg → r0-r15).

**Key Decisions:**
- **Approach**: Incremental migration (simple constructs first, expand gradually)
- **Tests**: Allow temporary failures during transition, fix in Phase 4
- **Optimizations**: Match current functionality exactly (no new optimizations yet)
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

**Goal**: Match current branching behavior with inverted/direct branch logic

### 2.1 Extend IRGen for conditionals

Add support for comparison operations and if/else statements.

**Modifications to `generateExpr()`:**
- Add comparison operations: `Lt`, `Gt`, `Eq`
- These don't allocate registers, they're used directly in Branch instructions

**New functions:**

1. **`generateIfOnly(state, condition, thenBlock) → state`**
   - Generate comparison (extract left, right, op)
   - Allocate end label: `endLabel = j$"label{nextLabel}"`
   - Emit inverted branch: `Branch(invertedOp, leftVreg, rightVreg, endLabel)`
     - `Lt` → `BGE` (branch if greater-or-equal, skip then block)
     - `Gt` → `BLE` (branch if less-or-equal, skip then block)
     - `Eq` → `BNE` (branch if not-equal, skip then block)
   - Generate then block instructions
   - Emit `Label(endLabel)`

2. **`generateIfElse(state, condition, thenBlock, elseBlock) → state`**
   - Generate comparison (extract left, right, op)
   - Allocate labels: `thenLabel`, `endLabel`
   - Emit direct branch: `Branch(op, leftVreg, rightVreg, thenLabel)`
     - `Lt` → `BLT` (branch to then if less-than)
     - `Gt` → `BGT` (branch to then if greater-than)
     - `Eq` → `BEQ` (branch to then if equal)
   - Generate else block instructions
   - Emit `Goto(endLabel)`
   - Emit `Label(thenLabel)`
   - Generate then block instructions
   - Emit `Label(endLabel)`

3. **Update `generateStmt()` to handle `IfStatement`**

### 2.2 Extend IRToIC10 for branches

Add codegen for control flow instructions.

**New instruction handlers in `generateInstr()`:**

1. **`Branch(op, leftOperand, rightOperand, label)`**
   - Convert operands to IC10 format
   - Map IR branch ops to IC10:
     - `BLT` → `blt`
     - `BGT` → `bgt`
     - `BEQ` → `beq`
     - `BGE` → `bge`
     - `BLE` → `ble`
     - `BNE` → `bne`
   - Emit: `<op> <left> <right> <label>`

2. **`Label(name)`**
   - Emit: `<name>:`

3. **`Goto(label)`**
   - Emit: `j <label>`

### 2.3 Test if/else patterns

**Test cases:**

1. If-only with inverted branch:
   ```rescript
   if a < b {
     c = 1
   }
   ```
   - IR: `Branch(BGE, vA, vB, label0)`, `Move(vC, Num(1))`, `Label(label0)`
   - IC10: `bge r0 r1 label0`, `move r2 1`, `label0:`

2. If-else with direct branch:
   ```rescript
   if a < b {
     c = 1
   } else {
     c = 2
   }
   ```
   - IR: `Branch(BLT, vA, vB, label1)`, `Move(vC, Num(2))`, `Goto(label0)`, `Label(label1)`, `Move(vC, Num(1))`, `Label(label0)`
   - IC10: `blt r0 r1 label1`, `move r2 2`, `j label0`, `label1:`, `move r2 1`, `label0:`

3. Nested if statements
4. If with block scope (variable shadowing)

**Success criteria:** All if/else tests produce correct IC10 output with proper branch logic.

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
- **Operands are flexible**: Can be virtual registers OR immediate values
- **Labels are explicit**: Not implicit like current codegen
- **Benefits**:
  - Easy to reason about (1:1 or 1:few mapping to IC10)
  - Enables future analysis passes
  - Clear representation of control flow

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
- [ ] If-only statements use inverted branches correctly
- [ ] If-else statements use direct branches correctly
- [ ] Label generation works properly
- [ ] Nested conditionals compile correctly

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
