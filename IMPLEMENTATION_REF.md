# Mutable References (ref) Implementation

## Overview

This document describes the implementation of ReScript's mutable reference (`ref`) system in the ReScript → IC10 compiler. The ref system provides **explicit, unambiguous mutation** that avoids the shadowing confusion common with implicit mutability.

### Motivation

The ref system solves a critical usability issue:

```rescript
// Without refs - ambiguous shadowing
let x = 0
if condition {
  let x = 10  // Is this mutation or shadowing? Unclear!
}

// With refs - explicit mutation
let x = ref(0)
if condition {
  x := 10  // ✅ Clearly mutating outer x
}
```

### Alignment with ReScript

This implementation follows **standard ReScript semantics** for refs, ensuring:
- ✅ ReScript LSP compatibility
- ✅ Tree-sitter syntax highlighting works correctly
- ✅ Familiar to ReScript developers
- ✅ No custom syntax invention

---

## Syntax Specification

### Creating Refs

```rescript
let counter = ref(0)
let temperature = ref(100)
let state = ref(Idle)  // Future: refs can hold variants
```

**Syntax**: `ref(expr)`
- Creates a mutable reference initialized with `expr`
- The ref itself is bound immutably to the variable name
- The contents can be mutated

### Reading Refs

```rescript
let counter = ref(10)
let value = counter.contents        // Read using .contents
let doubled = counter.contents * 2  // Use in expressions
```

**Syntax**: `identifier.contents`
- Accesses the current value stored in the ref
- Can be used anywhere an expression is expected

### Mutating Refs

```rescript
let counter = ref(0)
counter := 5                    // Mutation operator
counter := counter.contents + 1 // Read and update
```

**Syntax**: `identifier := expr`
- The `:=` operator assigns a new value to the ref
- Visually distinct from `=` (binding) to prevent confusion
- Right-hand side is evaluated first, then stored

### Complete Example

```rescript
let counter = ref(0)
let limit = 100

if counter.contents < limit {
  counter := counter.contents + 1
}

// counter.contents is now 1
```

---

## Language Design

### Type System

**Initial implementation (Phase 1)**:
- Refs can only hold `int` values
- Type: `ref<int>` (conceptually, not enforced yet)

**Future extensions**:
- `ref<variant>` - refs holding variant values
- Requires careful memory management (variants are stack-allocated)

### Scoping Rules

```rescript
let x = ref(0)

if condition {
  x := 10            // ✅ Mutates outer x
  let x = ref(20)    // ✅ Shadows outer x (new ref)
  x := 30            // Mutates inner x
}

// Outer x is 10 (if condition was true)
```

**Rules**:
1. Refs follow normal lexical scoping
2. Shadowing is **allowed** - creates a new ref with the same name
3. Mutation always affects the ref in the current scope

### Restrictions (Phase 1)

**Not supported initially**:
```rescript
// ❌ Cannot return refs from if/switch expressions
let x = if condition { ref(1) } else { ref(2) }

// ❌ Cannot reassign ref itself (only contents)
let x = ref(0)
x = ref(10)  // Error: x is not mutable

// ❌ Cannot have refs as variant arguments
type state = Holding(ref<int>)  // Error (Phase 1)
```

**Supported**:
```rescript
// ✅ Refs in any statement position
let counter = ref(0)

// ✅ Reading refs in expressions
let value = counter.contents + 10

// ✅ Mutating inside if/switch bodies
if condition {
  counter := 5
}

// ✅ Multiple refs
let x = ref(1)
let y = ref(2)
```

---

## Implementation Details

### AST Changes (`src/compiler/AST.res`)

Add new node types:

```rescript
type rec astNode =
  | ... // existing nodes
  | RefCreation(expr)                    // ref(expr)
  | RefAccess(string)                    // identifier.contents
  | RefAssignment(string, expr)          // identifier := expr

// Add to statement list as well
and stmt = astNode
```

**Helper functions**:
```rescript
let createRefCreation = (value: expr): astNode => {
  RefCreation(value)
}

let createRefAccess = (name: string): astNode => {
  RefAccess(name)
}

let createRefAssignment = (name: string, value: expr): astNode => {
  RefAssignment(name, value)
}
```

### Lexer Changes (`src/compiler/Lexer.res`)

Add new tokens:

```rescript
type token =
  | ... // existing tokens
  | Ref          // keyword: ref
  | ColonEqual   // operator: :=
  | Dot          // operator: . (for field access)
  | Contents     // identifier: contents (special field name)
```

**Token recognition**:
```rescript
// In keyword recognition
| "ref" => (lexer, Ref)

// In operator recognition
| ':' =>
  switch peek(lexer) {
  | Some('=') =>
    advance(lexer)
    (lexer, ColonEqual)
  | _ => error("Unexpected character ':'")
  }

| '.' => (lexer, Dot)
```

**Note**: `contents` is recognized as a regular identifier, but has special meaning after `.`

### Parser Changes (`src/compiler/Parser.res`)

#### 1. Parse ref creation in primary expressions

```rescript
let parsePrimaryExpression = (parser: parser): result<(parser, AST.expr), string> => {
  switch peek(parser) {
  | Some(Lexer.Ref) => parseRefCreation(parser)
  | ... // existing cases
  }
}

let parseRefCreation = (parser: parser): result<(parser, AST.expr), string> => {
  // Expect "ref"
  switch expect(parser, Lexer.Ref) {
  | Error(e) => Error(e)
  | Ok(parser) =>
    // Expect "("
    switch expect(parser, Lexer.LeftParen) {
    | Error(e) => Error(e)
    | Ok(parser) =>
      // Parse inner expression
      switch parseExpression(parser) {
      | Error(e) => Error(e)
      | Ok((parser, expr)) =>
        // Expect ")"
        switch expect(parser, Lexer.RightParen) {
        | Error(e) => Error(e)
        | Ok(parser) =>
          Ok((parser, AST.createRefCreation(expr)))
        }
      }
    }
  }
}
```

#### 2. Parse field access (`.contents`)

```rescript
// In parsePostfixExpression (new function)
let rec parsePostfixExpression = (parser: parser, base: AST.expr): result<(parser, AST.expr), string> => {
  switch peek(parser) {
  | Some(Lexer.Dot) =>
    // Consume dot
    let parser = advance(parser)
    // Expect "contents" identifier
    switch peek(parser) {
    | Some(Lexer.Identifier) =>
      let (parser, fieldName) = expectIdentifier(parser)
      if fieldName == "contents" {
        // Must be a simple identifier base
        switch base {
        | AST.Identifier(refName) =>
          Ok((parser, AST.createRefAccess(refName)))
        | _ =>
          Error("Only simple identifiers can be dereferenced with .contents")
        }
      } else {
        Error("Only .contents field is supported for refs")
      }
    | _ =>
      Error("Expected field name after '.'")
    }
  | _ =>
    Ok((parser, base))  // No postfix, return base
  }
}
```

#### 3. Parse ref assignment as statement

```rescript
let parseStatement = (parser: parser): result<(parser, AST.stmt), string> => {
  switch peek(parser) {
  | Some(Lexer.Identifier) =>
    // Look ahead for := operator
    let nextToken = peekNext(parser)
    switch nextToken {
    | Some(Lexer.ColonEqual) =>
      parseRefAssignment(parser)
    | _ =>
      // Try other statement types
      parseLetDeclaration(parser)
    }
  | ... // existing cases
  }
}

let parseRefAssignment = (parser: parser): result<(parser, AST.stmt), string> => {
  // Get identifier name
  switch expectIdentifier(parser) {
  | Error(e) => Error(e)
  | Ok((parser, name)) =>
    // Expect ":="
    switch expect(parser, Lexer.ColonEqual) {
    | Error(e) => Error(e)
    | Ok(parser) =>
      // Parse expression
      switch parseExpression(parser) {
      | Error(e) => Error(e)
      | Ok((parser, expr)) =>
        Ok((parser, AST.createRefAssignment(name, expr)))
      }
    }
  }
}
```

### Register Allocation (`src/compiler/RegisterAlloc.res`)

Refs require special handling to **persist across mutations**:

```rescript
// Existing environment tracks variable → register mappings
// Refs need to be marked as "persistent" so they're never deallocated

type variableInfo = {
  register: Register.t,
  isRef: bool,        // NEW: Track if variable is a ref
}

// When allocating for ref creation
let allocateRef = (state: state, name: string): result<(state, Register.t), string> => {
  switch allocateRegister(state) {
  | Error(e) => Error(e)
  | Ok((state, reg)) =>
    // Mark as ref in environment
    let state = {
      ...state,
      env: Map.set(state.env, name, {register: reg, isRef: true})
    }
    Ok((state, reg))
  }
}

// Refs are NEVER deallocated when going out of scope
let deallocateVariable = (state: state, name: string): state => {
  switch Map.get(state.env, name) {
  | Some({isRef: true, _}) =>
    // Don't deallocate ref registers
    state
  | Some({register, _}) =>
    // Deallocate normal variables
    deallocateRegister(state, register)
  | None =>
    state
  }
}
```

**Key insight**: Ref registers stay allocated until end of function/program.

### Code Generation (`src/compiler/ExprGen.res` and `src/compiler/StmtGen.res`)

#### 1. Generate ref creation

```rescript
// In ExprGen.res
let generate = (state: state, expr: AST.expr): result<(state, Register.t), string> => {
  switch expr {
  | AST.RefCreation(valueExpr) =>
    // Evaluate initial value
    switch generate(state, valueExpr) {
    | Error(e) => Error(e)
    | Ok((state, valueReg)) =>
      // Allocate persistent register for ref
      switch RegisterAlloc.allocateRef(state, refName) {
      | Error(e) => Error(e)
      | Ok((state, refReg)) =>
        // Move value into ref register
        let state = emit(state, `move ${Register.toString(refReg)} ${Register.toString(valueReg)}`)
        // Deallocate temporary value register
        let state = RegisterAlloc.deallocateRegister(state, valueReg)
        Ok((state, refReg))
      }
    }
  }
}
```

**Note**: Need variable name - may need to pass through from statement context.

#### 2. Generate ref access

```rescript
// In ExprGen.res
let generate = (state: state, expr: AST.expr): result<(state, Register.t), string> => {
  switch expr {
  | AST.RefAccess(refName) =>
    // Look up ref's register
    switch RegisterAlloc.lookupVariable(state, refName) {
    | None => Error(`Undefined variable: ${refName}`)
    | Some({register, isRef: false}) =>
      Error(`${refName} is not a ref`)
    | Some({register, isRef: true}) =>
      // Ref's register already contains the value - just return it
      Ok((state, register))
    }
  }
}
```

**Key optimization**: No actual IC10 instruction needed! The register already has the value.

#### 3. Generate ref assignment

```rescript
// In StmtGen.res
let generate = (state: state, stmt: AST.stmt): result<state, string> => {
  switch stmt {
  | AST.RefAssignment(refName, valueExpr) =>
    // Verify ref exists
    switch RegisterAlloc.lookupVariable(state, refName) {
    | None => Error(`Undefined variable: ${refName}`)
    | Some({register: refReg, isRef: false}) =>
      Error(`${refName} is not a ref - cannot use := operator`)
    | Some({register: refReg, isRef: true}) =>
      // Generate value expression
      switch ExprGen.generate(state, valueExpr) {
      | Error(e) => Error(e)
      | Ok((state, valueReg)) =>
        // Move new value into ref register
        let state = emit(state, `move ${Register.toString(refReg)} ${Register.toString(valueReg)}`)
        // Deallocate temporary value register
        let state = RegisterAlloc.deallocateRegister(state, valueReg)
        Ok(state)
      }
    }
  }
}
```

---

## IC10 Assembly Mapping

### Example 1: Basic ref operations

**ReScript source**:
```rescript
let counter = ref(0)
counter := 5
let value = counter.contents
```

**IC10 assembly**:
```asm
move r0 0        # counter = ref(0) - allocate r0 for counter
move r0 5        # counter := 5 - overwrite r0
move r1 r0       # value = counter.contents - copy r0 to r1
```

**Register allocation**:
- `r0`: Persistent ref `counter` (never deallocated)
- `r1`: Variable `value`

### Example 2: Mutation in if statement

**ReScript source**:
```rescript
let counter = ref(0)
if counter.contents < 10 {
  counter := counter.contents + 1
}
```

**IC10 assembly**:
```asm
move r0 0        # counter = ref(0)
bge r0 10 label0 # if counter.contents < 10 (inverted)
add r0 r0 1      # counter := counter.contents + 1 (r0 += 1)
label0:
```

**Note**: Mutation directly updates `r0` in place - very efficient!

### Example 3: Multiple refs

**ReScript source**:
```rescript
let x = ref(10)
let y = ref(20)
let sum = x.contents + y.contents
y := sum
```

**IC10 assembly**:
```asm
move r0 10       # x = ref(10)
move r1 20       # y = ref(20)
add r2 r0 r1     # sum = x.contents + y.contents
move r1 r2       # y := sum (update y's register)
```

**Register allocation**:
- `r0`: Persistent ref `x`
- `r1`: Persistent ref `y`
- `r2`: Variable `sum` (can be deallocated later)

### Example 4: Shadowing refs

**ReScript source**:
```rescript
let x = ref(0)
x := 5

if true {
  let x = ref(10)  # Shadows outer x
  x := 20          # Mutates inner x
}

# Outer x is still 5
```

**IC10 assembly**:
```asm
move r0 0        # Outer x = ref(0)
move r0 5        # Outer x := 5
# if true (always execute)
move r1 10       # Inner x = ref(10) (NEW register)
move r1 20       # Inner x := 20
# End of inner scope - r1 can be reused
# r0 still contains 5
```

**Register allocation**:
- `r0`: Outer ref `x` (persistent)
- `r1`: Inner ref `x` (also persistent, but deallocated after scope)

---

## Edge Cases and Restrictions

### Phase 1 Restrictions

**Not implemented initially**:

1. **Refs in expressions** (only as statements):
   ```rescript
   let x = ref(if cond { 0 } else { 1 })  # ❌ Not supported
   ```

2. **Refs holding variants**:
   ```rescript
   let state = ref(Idle)  # ❌ Error: refs can only hold int
   ```
   *Reason*: Variants are stack-allocated with different sizes - complex mutation semantics

3. **Refs as variant arguments**:
   ```rescript
   type holder = Holder(ref<int>)  # ❌ Not supported
   ```

4. **Passing refs around**:
   ```rescript
   let x = ref(0)
   let y = x  # ❌ Cannot alias refs
   ```

### Validation Rules

**Parser/semantic checks**:

1. **`:=` only works on refs**:
   ```rescript
   let x = 10
   x := 20  # ❌ Error: x is not a ref
   ```

2. **`.contents` only works on refs**:
   ```rescript
   let x = 10
   let y = x.contents  # ❌ Error: x is not a ref
   ```

3. **Cannot reassign ref variable**:
   ```rescript
   let x = ref(0)
   x = ref(10)  # ❌ Error: cannot reassign immutable binding
   ```

### Memory Considerations

**Register pressure**:
- Each ref consumes one register **permanently** (until out of scope)
- With 16 registers, careful allocation is critical
- Error if too many refs: `Error: Out of registers`

**Best practices**:
- Use refs sparingly - only for truly mutable state
- Prefer immutable bindings when possible
- Be aware of ref count in nested scopes

---

## Test Plan

### Test Suite: `tests/refs.test.js`

#### Basic Operations
1. **Create ref with literal**
   ```rescript
   let x = ref(42)
   ```
   Expected: `move r0 42`

2. **Create ref with expression**
   ```rescript
   let x = ref(10 + 20)
   ```
   Expected: `add r0 10 20`

3. **Read ref contents**
   ```rescript
   let x = ref(10)
   let y = x.contents
   ```
   Expected: `move r0 10` + `move r1 r0`

4. **Mutate ref**
   ```rescript
   let x = ref(0)
   x := 5
   ```
   Expected: `move r0 0` + `move r0 5`

#### Complex Operations
5. **Increment pattern**
   ```rescript
   let counter = ref(0)
   counter := counter.contents + 1
   ```
   Expected: `move r0 0` + `add r0 r0 1`

6. **Mutation in if statement**
   ```rescript
   let x = ref(0)
   if x.contents < 10 {
     x := x.contents + 1
   }
   ```

7. **Multiple refs**
   ```rescript
   let x = ref(1)
   let y = ref(2)
   let sum = x.contents + y.contents
   ```

8. **Shadowing refs**
   ```rescript
   let x = ref(0)
   x := 5
   if true {
     let x = ref(10)
     x := 20
   }
   ```

#### Error Cases
9. **`:=` on non-ref**
   ```rescript
   let x = 10
   x := 20
   ```
   Expected: Compilation error

10. **`.contents` on non-ref**
    ```rescript
    let x = 10
    let y = x.contents
    ```
    Expected: Compilation error

11. **Reassign ref binding**
    ```rescript
    let x = ref(0)
    x = ref(10)
    ```
    Expected: Compilation error

12. **Out of registers**
    ```rescript
    let r0 = ref(0)
    let r1 = ref(1)
    ...
    let r15 = ref(15)
    let r16 = ref(16)  # Should fail
    ```
    Expected: "Out of registers" error

---

## Implementation Phases

### Phase 1: Basic refs with int (Current)
- ✅ `ref(int)` creation
- ✅ `.contents` access
- ✅ `:=` mutation
- ✅ Scoping and shadowing
- ✅ Basic test coverage

### Phase 2: Enhanced refs (Future)
- Refs holding variants: `ref<variant>`
- Better error messages
- Optimization: eliminate redundant moves

### Phase 3: Advanced features (Future)
- Ref equality checking
- Refs in data structures
- First-class refs (passing as values)

---

## Summary

The ref system provides **explicit, unambiguous mutation** that:
- ✅ Prevents shadowing confusion
- ✅ Uses standard ReScript syntax
- ✅ Maps efficiently to IC10 assembly
- ✅ Integrates with existing LSP/tree-sitter tooling
- ✅ Keeps mutable state visible and controlled

By following ReScript semantics exactly, we maintain compatibility while solving the usability issues around implicit mutation.
