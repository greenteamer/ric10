# Loop Implementation Document

## Overview

This document outlines the implementation plan for adding loop constructs to the ReScript to IC10 compiler. Loops are essential for repetitive operations and will significantly expand the language's capabilities.

## Objectives

Add support for `while` loops, compiling them to efficient IC10 assembly using labels and jump instructions.

**Note**: This is the first iteration focusing on while loops only. For loops can be added in a future iteration once while loops are proven to work.

## Loop Types

### 1. While Loops

**Syntax**: `while condition { body }`

**Example**:
```rescript
let counter = 0
while counter < 10 {
  counter = counter + 1
}
```

**IC10 Assembly Pattern**:
```assembly
move r0 0                    # counter = 0
loop_0_start:
  bge r0 10 loop_0_end      # if counter >= 10, exit loop
  add r0 r0 1               # counter = counter + 1
  j loop_0_start            # jump back to start
loop_0_end:
```

## Implementation Components

### 1. Lexer Changes (`Lexer.res`)

**Add new token**:
```rescript
| While
```

**Keyword to recognize**:
- `while` → `While`

### 2. AST Changes (`AST.res`)

**Add new AST node type**:

```rescript
type astNode =
  | ...existing variants...
  | WhileLoop({condition: expr, body: list<astNode>})
```

### 3. Parser Changes (`Parser.res`)

**Add while loop parsing function**:

```rescript
// Parse while loop: while condition { body }
let rec parseWhileLoop = (tokens: list<token>): result<(astNode, list<token>), string> => {
  // Expect: While token
  // Parse: condition expression
  // Expect: LBrace
  // Parse: block body
  // Expect: RBrace
  // Return: WhileLoop AST node
}
```

**Update `parseStatement` to handle while keyword**:
```rescript
let rec parseStatement = (tokens: list<token>): result<(astNode, list<token>), string> => {
  switch tokens {
  | list{While, ..._} => parseWhileLoop(tokens)
  | ...existing cases...
  }
}
```

### 4. Register Allocator Changes (`RegisterAlloc.res`)

**Loop-specific considerations**:

1. **Loop variable persistence**: Variables used across loop iterations must retain their register assignments
2. **Scope management**: Variables declared inside the loop body should be scoped to the loop
3. **Nested loop support**: Each loop needs its own scope frame

**Recommended approach**:
- Enter new scope at loop start
- Allocate registers for loop variables as they are declared
- Process body with loop scope active
- Exit scope at loop end (but maintain outer scope variables)

**No major API changes needed** - existing scope management should handle loops naturally.

### 5. Code Generator Changes (`Codegen.res`)

**Add label generation**:

```rescript
// State to track loop nesting level for unique labels
type codegenState = {
  loopCounter: int,
  // ...existing state...
}

// Generate unique loop labels
let getLoopLabels = (state: codegenState): (string, string, codegenState) => {
  let startLabel = `loop_${Int.toString(state.loopCounter)}_start`
  let endLabel = `loop_${Int.toString(state.loopCounter)}_end`
  let newState = {...state, loopCounter: state.loopCounter + 1}
  (startLabel, endLabel, newState)
}
```

**While loop codegen**:

```rescript
let generateWhileLoop = (
  condition: expr,
  body: list<astNode>,
  allocState: allocState,
  state: codegenState
): result<(list<string>, allocState, codegenState), string> => {
  // 1. Get unique labels
  let (startLabel, endLabel, state) = getLoopLabels(state)

  // 2. Emit start label
  let instructions = list{startLabel ++ ":"}

  // 3. Generate condition evaluation
  let (condCode, condReg, allocState, state) = generateExpr(condition, allocState, state)?

  // 4. Generate inverted branch to end (exit loop if condition false)
  let branchInstruction = generateInvertedBranch(condition, condReg, endLabel)

  // 5. Generate body code
  let (bodyCode, allocState, state) = generateBlock(body, allocState, state)?

  // 6. Jump back to start
  let jumpInstruction = `j ${startLabel}`

  // 7. Emit end label
  let endLabelInstruction = endLabel ++ ":"

  // 8. Combine all instructions
  Ok((
    List.concat(list{
      instructions,
      condCode,
      list{branchInstruction},
      bodyCode,
      list{jumpInstruction, endLabelInstruction}
    }),
    allocState,
    state
  ))
}
```

**Update main `generateNode` function**:
```rescript
let rec generateNode = (node: astNode, allocState: allocState, state: codegenState) => {
  switch node {
  | WhileLoop({condition, body}) => generateWhileLoop(condition, body, allocState, state)
  | ...existing cases...
  }
}
```

## Implementation Order

1. **Phase 1: Basic While Loops**
   - Add `While` token to lexer
   - Add `WhileLoop` AST node
   - Implement `parseWhileLoop` in parser
   - Add loop counter to codegen state
   - Implement `generateWhileLoop` in codegen
   - Write tests for basic while loops

2. **Phase 2: Advanced While Loop Features**
   - Test nested while loops
   - Test loops with complex conditions
   - Test loops with variable shadowing
   - Test register exhaustion in loops
   - Test edge cases (empty bodies, always-false conditions)
   - Write error case tests

## Testing Strategy

### Basic While Loop Tests
```rescript
// Test 1: Simple while loop
let x = 0
while x < 5 {
  x = x + 1
}

// Test 2: While with multiple statements
let counter = 0
while counter < 3 {
  let temp = counter * 2
  counter = counter + 1
}

// Test 3: While with complex condition
let a = 10
let b = 0
while a > b {
  b = b + 2
}
```

### Nested While Loop Tests
```rescript
// Test 4: Nested while loops
let i = 0
while i < 3 {
  let j = 0
  while j < 2 {
    j = j + 1
  }
  i = i + 1
}
```

### Edge Cases
```rescript
// Test 5: Empty loop body
while false {}

// Test 6: Loop with condition always false
let x = 10
while x < 5 {
  x = x + 1
}
```

### Error Cases
```rescript
// Test 7: Register exhaustion in loop
let i = 0
while i < 20 {
  let a = 1
  let b = 2
  // ...declare 16+ variables...
  i = i + 1
}

// Test 8: Missing loop condition
while { }

// Test 9: Invalid while syntax (using parentheses - not ReScript syntax)
while (x < 5) { }
```

## IC10 Constraints & Considerations

### Instruction Limits
- IC10 has a maximum program size (varies by device)
- Deeply nested loops can quickly exhaust instruction space
- Consider warning users about loop complexity

### Register Pressure
- With only 16 registers, loops can easily exhaust available registers
- Loop variables persist across iterations, reducing available registers
- Nested loops compound this problem
- May need to implement register spilling in the future (but not initially)

### Performance
- Each loop iteration involves at least 2 jumps (condition check + back jump)
- Tight loops should be optimized where possible
- Consider loop unrolling for small, fixed iteration counts (future optimization)

### Label Management
- Each loop needs 2 unique labels (start and end)
- Nested loops need properly scoped labels
- Use counter-based naming: `loop_0_start`, `loop_0_end`, `loop_1_start`, etc.

## Future Enhancements

1. **For Loops (Range-Based)**
   - `for (i in 0..10) { }` syntax for iterating over ranges
   - Implicit increment and bounds checking
   - Simpler syntax for common iteration patterns

2. **Break/Continue Statements**
   - `break` - exit loop immediately
   - `continue` - skip to next iteration
   - Requires tracking loop context in codegen

3. **Loop Unrolling**
   - For small, fixed iteration counts, unroll loops for performance
   - Example: `while` loop with constant iterations could be unrolled

4. **Register Spilling**
   - When registers are exhausted, temporarily store values in IC10 memory
   - Required for complex nested loops

5. **Optimization Pass**
   - Detect infinite loops at compile time
   - Optimize loop conditions (constant folding)
   - Remove unreachable code after loops

6. **Additional Loop Types**
   - `do-while` loops (condition at end)
   - `loop { }` infinite loops (with break statements)

## Success Criteria

- ✅ While loops compile to correct IC10 assembly
- ✅ Loop variables are properly scoped
- ✅ Nested while loops generate unique labels and work correctly
- ✅ Loops work with existing language features (if/else, arithmetic, comparisons)
- ✅ Register allocation handles loop variables correctly
- ✅ Comprehensive test coverage (9+ tests)
- ✅ Clear error messages for invalid loop constructs
- ✅ Documentation updated with loop examples

## Example: Complete While Loop Compilation

**Input**:
```rescript
let sum = 0
let i = 0
while i < 5 {
  sum = sum + i
  i = i + 1
}
```

**Expected IC10 Output**:
```assembly
move r0 0              # sum = 0
move r1 0              # i = 0
loop_0_start:
  bge r1 5 loop_0_end  # if i >= 5, exit loop
  add r0 r0 r1         # sum = sum + i
  add r1 r1 1          # i = i + 1
  j loop_0_start       # jump back to start
loop_0_end:
```

---

## Implementation Checklist

- [ ] Add `While` token to lexer
- [ ] Add `WhileLoop` AST node
- [ ] Implement `parseWhileLoop` in parser
- [ ] Add loop counter to codegen state
- [ ] Implement `generateWhileLoop` in codegen
- [ ] Write basic while loop tests (Tests 1-3)
- [ ] Write nested while loop test (Test 4)
- [ ] Write edge case tests (Tests 5-6)
- [ ] Write error case tests (Tests 7-9)
- [ ] Update CLAUDE.md with loop documentation
- [ ] Verify all tests pass

---

**Document Version**: 1.1 (While Loops Only)
**Date**: 2025-11-04
**Author**: Implementation Planning Document
