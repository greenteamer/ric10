# ReScript to IC10 Compiler - Implementation Plan

**Status**: Ready | **Effort**: 28-39 hours | **Performance Gain**: 10-100x

## Critical Issues Summary

1. **O(n²) Performance** - Array accumulation in Lexer.res & Parser.res
2. **Broken Scoping** - Variable shadowing overwrites instead of creating new bindings
3. **Code Duplication** - If-statement logic repeated 4 times in Codegen.res

---

## Priority 1: Performance Fixes ⚡ (4-6 hours) 🔴 CRITICAL

### Problem
O(n²) array accumulation creates and copies entire array for every token/statement.

**Affected**: `Lexer.res:172-198`, `Parser.res:287-298,325-336`

### Solution
Replace array accumulation with List (O(1) cons) + reverse:

```rescript
// Current (BAD): Creates new array each iteration
let newArr = Array.make(~length=len + 1, Let)
for i in 0 to len - 1 { ... }  // Copies entire array!

// Fixed (GOOD): Use List
let rec loop = (lexer, acc) => {
  let (lexer', token) = nextToken(lexer)
  switch token {
  | EOF => Ok(List.toArray(List.reverse(acc)))
  | _ => loop(lexer', list{token, ...acc})  // O(1)
  }
}
```

### Steps
1. **Lexer.res** (1-2h): Replace `tokenize` with List-based accumulation
2. **Parser.res** (2h): Fix `parseStatements` and `parseBlockStatement`
3. **RegisterAlloc.res** (1h): Replace linear search with `Belt.Map.String` for O(log n) lookups

```rescript
// RegisterAlloc.res fix
type variableMap = Belt.Map.String.t<Register.t>  // was: list<(string, Register.t)>
let lookup = (map, key) => Belt.Map.String.get(map, key)
```

### Success Criteria
- [ ] All 40 tests pass
- [ ] 100-line program compiles in <100ms
- [ ] 10-100x performance improvement

---

## Priority 2: Scope Management 🔧 (8-12 hours) 🔴 MAJOR BUG

### Problem
Variable shadowing reuses same register, **overwrites outer variable**:

```rescript
let x = 10  // r0 = 10
if true { let x = 20 }  // r0 = 20 (WRONG! Should be r1)
// x is now 20, should be 10
```

**Root Cause**: `RegisterAlloc.res:45-71` - shadows reuse same register

### Solution: Scope Stack

```rescript
type scope = {
  bindings: Belt.Map.String.t<Register.t>,
  parent: option<scope>,
  registersInUse: Belt.Set.Int.t,
}

type allocator = {
  currentScope: scope,
  nextRegister: int,
  nextTempRegister: int,
}

let enterScope = (allocator) => {
  ...allocator,
  currentScope: {
    bindings: Belt.Map.String.empty,
    parent: Some(allocator.currentScope),
    registersInUse: Belt.Set.Int.empty,
  }
}

let exitScope = (allocator) => {
  switch allocator.currentScope.parent {
  | None => Error("Cannot exit root scope")
  | Some(parent) => Ok({...allocator, currentScope: parent})
  }
}

let lookupVariable = (scope, name) => {
  // Search current scope, then parent chain
  switch Belt.Map.String.get(scope.bindings, name) {
  | Some(reg) => Some(reg)
  | None => Option.flatMap(scope.parent, p => lookupVariable(p, name))
  }
}
```

### Steps
1. **RegisterAlloc.res** (5h): Add scope type, implement enterScope/exitScope/lookupVariable
2. **Codegen.res** (3h): Call enterScope/exitScope at block boundaries
3. **Tests** (2h): Add scoping tests, verify shadowing works correctly
4. **Docs** (1h): Update CLAUDE.md

### Success Criteria
- [ ] Shadowing creates NEW bindings (different registers)
- [ ] Outer variables restored after scope exit
- [ ] All new + existing tests pass

---

## Priority 3: Code Organization 📦 (6-8 hours) 🟡 REFACTOR

### Problem
- Codegen.res: 547 lines, `generateStatement`: 224 lines
- If-statement logic duplicated 4x (lines 312-408)
- Optimization mixed with generation

### Solution: Split into Modules

```
src/compiler/Codegen/
├── Optimizer.res      # Constant folding, algebraic identities
├── ExprGen.res        # Expression generation
├── StmtGen.res        # Statement generation
├── BranchGen.res      # If/else logic (eliminates 4x duplication)
└── Codegen.res        # Orchestration (simplified to ~50 lines)
```

### Key Extractions

**Optimizer.res** - Separate pass:
```rescript
let rec optimize = (node: AST.astNode) => {
  switch node {
  | BinaryExpression(Add, Literal(a), Literal(b)) => Literal(a + b)
  | BinaryExpression(Add, expr, Literal(0)) => optimize(expr)
  | BinaryExpression(Mul, expr, Literal(1)) => optimize(expr)
  // ... all optimizations ...
  }
}
```

**BranchGen.res** - DRY if/else:
```rescript
let generateIfOnly = (state, condition, thenBlock, endLabel) => { ... }
let generateIfElse = (state, condition, thenBlock, elseBlock) => { ... }
```

### Steps
1. Create Optimizer.res (2h)
2. Create BranchGen.res (2h)
3. Create ExprGen.res (1h)
4. Create StmtGen.res (1h)
5. Simplify main Codegen.res (1h)

### Success Criteria
- [ ] No code duplication
- [ ] Each module <200 lines
- [ ] All tests pass

---

## Priority 4: Error Reporting 📍 (8-10 hours) 🟢 ENHANCEMENT

### Current vs Desired

**Current**: `Parser error: Unexpected token`

**Desired**:
```
Parser error at line 5, column 12:
  let x = 10 +
              ^
Unexpected end of expression
```

### Solution: Add Position Tracking

```rescript
// Position.res
type position = {line: int, column: int, offset: int}
type span = {start: position, end_: position}

// Update token/AST types
type token = {kind: tokenKind, span: span}
type astNode = {kind: astNodeKind, span: span}

// Error.res
type compileError = {
  kind: errorKind,
  message: string,
  span: option<span>,
  source: option<string>,
}
```

### Steps
1. Create Position.res (1h)
2. Create Error.res (1h)
3. Update Lexer for position tracking (2-3h)
4. Update Parser to propagate positions (2-3h)
5. Update error handling throughout (2h)
6. Add error tests (1h)

### Success Criteria
- [ ] All errors show line/column
- [ ] Source context with caret displayed
- [ ] Structured error types

---

## Priority 5: Documentation 📝 (2-3 hours) 🟢 MAINTENANCE

### Tasks
1. **Standardize comments** (1h): Replace Russian with English
   - `Codegen.res`: lines 63, 70, 80, 152
   - `RegisterAlloc.res`: lines 137-141, 167

2. **Module docs** (1h): Add headers to all modules
3. **Update CLAUDE.md** (30m): New architecture, patterns
4. **Document optimizations** (30m): Explain techniques

---

## Testing Strategy

### After Each Priority
- **Unit tests**: Module-specific functionality
- **Integration tests**: End-to-end compilation
- **Regression tests**: All 40 existing tests
- **Performance benchmarks**: Compare before/after

### Key Test Examples
```javascript
// Scoping test (Priority 2)
test('variable shadowing preserves outer scope', () => {
  const source = `let x = 10
    if true { let x = 20 }
    let z = x`;
  expect(compile(source)).toContain('move r0 10');
  expect(compile(source)).toContain('move r1 20');  // Different register!
  expect(compile(source)).toContain('move r2 r0');  // Uses outer x
});

// Performance test (Priority 1)
test('100-line program compiles fast', () => {
  const start = Date.now();
  compile(generate100Lines());
  expect(Date.now() - start).toBeLessThan(100);
});
```

---

## Timeline & Workflow

### Suggested Schedule
| Week | Priority | Hours | Status |
|------|----------|-------|--------|
| 1 | Priority 1 | 4-6 | Performance fixes |
| 2-3 | Priority 2 | 8-12 | Scope management |
| 4-5 | Priority 3 | 6-8 | Code organization |
| 6-7 | Priority 4 | 8-10 | Error reporting |
| 8 | Priority 5 | 2-3 | Documentation |

**Total**: 8 weeks part-time / 2 weeks full-time

### Git Workflow
```bash
git checkout -b feature/priority-1-performance
# Make changes, test frequently
npm test  # After each step
git commit -m "Fix O(n²) in Lexer"
git merge feature/priority-1-performance
```

### Quick Wins
If limited time:
1. Priority 1 (performance) - Immediate impact, low risk
2. Priority 2 partial (fix worst scoping bugs)
3. Priority 5 (document current state)

---

## Success Metrics

### Performance
- [ ] 10-100x faster compilation
- [ ] O(n) tokenization/parsing
- [ ] O(log n) variable lookups

### Correctness
- [ ] Proper variable scoping
- [ ] 60+ tests passing (40 existing + 20 new)

### Maintainability
- [ ] No file >300 lines
- [ ] No function >50 lines
- [ ] No code duplication
- [ ] English-only comments

### Extensibility
- [ ] New operators: <30 min
- [ ] New statements: <2 hours
- [ ] New optimizations: No codegen changes needed

---

## Future Enhancements

Post-completion ideas:
- Functions (declarations, calls)
- Loops (while, for)
- Type checking
- Advanced optimizations (dead code, CSE)
- Source maps
- LSP server

---

## Rollback Plan

Each priority is independent:
```bash
git revert <commit>  # Or:
git checkout main -- src/compiler/RegisterAlloc.res
```

**Breaking changes**: Only Priority 2 (scoping) - intentional bug fix

---

**Version**: 1.0 | **Author**: Claude Code Analysis | **Date**: 2025-11-03
