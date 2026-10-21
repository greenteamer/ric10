# WebAssembly Backend

The WebAssembly (WASM) backend compiles ReScript code to WebAssembly text format (.wat).

## Overview

The WASM backend translates the intermediate representation (IR) to WebAssembly text format, enabling ReScript code to run in WebAssembly environments.

### Architecture

```
Source Code → Lexer → Parser → AST → Optimizer → IR → IROptimizer → IRToWASM → .wat
```

### Key Features

- **Virtual Register Mapping**: IR virtual registers (v0, v1, v2...) map to WASM local variables
- **Stack-based Execution**: Leverages WASM's stack machine model
- **Linear Memory**: Stack operations use WASM linear memory
- **Integer Operations**: Full support for i32 arithmetic and comparisons

## Usage

### Compiler Options

```javascript
const result = Compiler.compile(sourceCode, {
  includeComments: false,
  debugAST: false,
  backend: "WASM"  // Use WASM backend
});
```

### ReScript

```rescript
let options: CodegenTypes.compilerOptions = {
  includeComments: false,
  debugAST: false,
  backend: WASM,
}

let result = Compiler.compile(sourceCode, ~options, ())
```

## Supported Features

### Arithmetic Operations
- Addition (`+`) → `i32.add`
- Subtraction (`-`) → `i32.sub`
- Multiplication (`*`) → `i32.mul`
- Division (`/`) → `i32.div_s`

### Comparison Operations
- Less than (`<`) → `i32.lt_s`
- Greater than (`>`) → `i32.gt_s`
- Equal (`==`) → `i32.eq`
- Not equal (`!=`) → `i32.ne`
- Less or equal (`<=`) → `i32.le_s`
- Greater or equal (`>=`) → `i32.ge_s`

### Control Flow
- `if` statements → WASM `if/then/else` blocks
- `while` loops → WASM labels and branches
- Labels and jumps → WASM block structures

### Variables
- Constants → Stored in constant map, inlined where possible
- Local variables → WASM local variables with automatic allocation

### Stack Operations
- `StackAlloc` → Comments (memory allocated but not used)
- `StackPoke` → `i32.store` (write to linear memory)
- `StackGet` → `i32.load` (read from linear memory)
- `StackPush` → `i32.store` with stack pointer management

## Limitations

### Unsupported Features

1. **Device Operations**: IC10-specific device operations (`l`, `s`, `lb`, `sb`, etc.) are not supported in WASM
   - These are converted to comments in the output
   - Placeholder values (0) are used for loads

2. **Hash Function**: `HASH()` function returns placeholder (0)
   - IC10's hash function is game-specific

3. **Raw Instructions**: Raw IC10 assembly is emitted as comments

4. **Advanced Control Flow**:
   - Unstructured jumps may not translate perfectly
   - WASM requires structured control flow

## Output Format

The WASM backend generates WebAssembly text format (.wat):

```wat
(module
  (memory 1)
  (export "main" (func $main))
  (func $main
    (local $v0 i32)
    (local $v1 i32)
    (local $v2 i32)

    (i32.const 5)
    (local.set $v0)
    (i32.const 3)
    (local.set $v1)
    (local.get $v0)
    (local.get $v1)
    (i32.add)
    (local.set $v2)
  )
)
```

## Example

### Input (ReScript subset)
```rescript
let x = 10
let y = 20
let sum = x + y
let isLess = x < y
```

### Output (WASM)
```wat
(module
  (memory 1)
  (export "main" (func $main))
  (func $main
    (local $v0 i32)
    (local $v1 i32)
    (local $v2 i32)

    ;; Block: main

    (i32.const 10)
    (local.set $v0)
    (i32.const 20)
    (local.set $v1)
    (i32.const 10)
    (i32.const 20)
    (i32.add)
    (local.set $v2)
    (i32.const 10)
    (i32.const 20)
    (i32.lt_s)
    (local.set $v3)
  )
)
```

## Implementation Details

### File: `src/compiler/IR/IRToWASM.res`

The WASM backend implementation includes:

- **State Management**: Tracks local variable count, output instructions, label mappings
- **Operand Conversion**: Translates IR operands to WASM format
- **Instruction Generation**: Maps each IR instruction to WASM equivalents
- **Module Generation**: Wraps output in WASM module structure

### Key Functions

- `generate`: Main entry point, generates complete WASM module
- `generateBlock`: Processes an IR block
- `generateInstr`: Converts single IR instruction to WASM
- `convertOperand`: Translates IR operands (VReg, Num, Name, Hash)
- `registerVReg`: Ensures virtual registers are allocated as locals

## Testing

Run WASM backend tests:

```bash
npm test -- wasm
```

Test coverage includes:
- Basic arithmetic and comparisons
- Control flow (if, while)
- Variable declarations and operations
- Device operation handling (comments)
- Stack operations
- Nested expressions

## Future Improvements

1. **Structured Control Flow**: Better translation of loops and branches
2. **Function Calls**: Support for WASM function calls
3. **Type System**: Leverage WASM's type system more effectively
4. **Optimizations**: WASM-specific optimizations
5. **Memory Management**: Better stack/heap management
6. **Hash Function**: Implement proper hash function for constants

## See Also

- [IR Reference](../architecture/ir-reference.md) - IR instruction documentation
- [Compiler Overview](../architecture/compiler-overview.md) - Overall compilation pipeline
- [IC10 Backend](IC10.md) - IC10 assembly backend (default)
