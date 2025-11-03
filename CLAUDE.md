# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a VSCode extension that compiles a subset of ReScript to IC10 assembly language for the Stationeers game. The project uses a hybrid architecture:

- **ReScript**: Core compiler logic (lexer, parser, AST, codegen, register allocation)
- **TypeScript**: VSCode extension integration layer

The compiler transforms ReScript source into IC10 assembly, managing register allocation for the target platform's 16-register constraint (r0-r15).

## ⚠️ IMPORTANT: Command Restrictions

**DO NOT run the following commands:**

- `npm run res:build` - ReScript is already running in watch mode
- `npm run res:dev` - ReScript watch mode is already active
- `npm run compile` - TypeScript compilation is handled separately by the developer
- `npm run watch` - TypeScript watch mode is handled separately
- `npm run dev` - Combined watch mode is already running

**The developer is managing the build process manually.** Claude should:

- ✅ **ONLY** modify ReScript files in `src/compiler/`
- ✅ Focus on compiler logic, AST transformations, and code generation
- ❌ **NEVER** run build or watch commands
- ❌ **NEVER** modify TypeScript files (extension.ts)
- ❌ **NEVER** concern itself with compilation status

The ReScript compiler is always running in watch mode in the background. Changes to `.res` files will automatically trigger recompilation.

## Build Commands (For Reference Only - DO NOT RUN)

### Development Setup

```bash
npm install                 # Install dependencies
npm run res:build          # Compile ReScript to JavaScript
npm run compile            # Compile TypeScript extension code
```

### Development Workflow

```bash
npm run res:dev            # Watch mode for ReScript (auto-recompile)
npm run watch              # Watch mode for TypeScript
npm run dev                # Combined watch mode for both
```

### Testing the Extension

1. Open project in VSCode
2. Press `F5` to launch Extension Development Host
3. Open a `.res` file (e.g., `testing/test.res`)
4. Run command: "Compile ReScript to IC10" via Command Palette

## Architecture

### Core Components

**Lexer** (`src/compiler/Lexer.res`): Tokenizes ReScript source code into a stream of tokens for parsing.

**Parser** (`src/compiler/Parser.res`): Hand-written recursive descent parser that consumes tokens and builds an AST. Supports variable declarations, binary operations, conditionals, and block statements.

**AST** (`src/compiler/AST.res`): Defines the abstract syntax tree types using ReScript variants. Key types include `astNode`, `expr`, `binaryOp`, and `program`.

**Register Allocator** (`src/compiler/RegisterAlloc.res`): Manages IC10's limited 16 registers (r0-r15) using linear allocation strategy. Tracks variable-to-register mappings and temporary register allocation/deallocation.

**Code Generator** (`src/compiler/Codegen.res`): Transforms AST into IC10 assembly instructions. Implements optimizations like constant folding and direct register operations to minimize instruction count.

**Compiler API** (`src/compiler/Compiler.res`): Main entry point that orchestrates the compilation pipeline from source code to IC10 assembly.

**VSCode Extension** (`src/extension.ts`): TypeScript integration layer that interfaces with VSCode APIs, provides the compile command, and displays results. **DO NOT MODIFY - TypeScript is out of scope.**

### Language Support

**ReScript Subset**: Variable declarations (`let`), arithmetic operations (`+`, `-`, `*`, `/`), comparisons (`>`, `<`, `==`), conditionals (`if/else`), block statements, integer literals, and identifiers. Supports variable scoping and shadowing in nested blocks.

**IC10 Target**: Assembly language for Stationeers with 16 registers, no stack, and instructions like `move`, `add`, `sub`, `mul`, `div`, direct branch instructions (`blt`, `bgt`, `beq`), and `j`.

### Key Constraints

- **16 registers maximum** (r0-r15) - exceeding this causes compilation errors
- **Integer-only arithmetic** - no floating point support
- **No functions or loops** - simple linear code generation only
- **No arrays or complex data structures** - primitive types only

## File Structure

```
src/
├── extension.ts              # TypeScript VSCode extension (DO NOT MODIFY)
└── compiler/                 # ReScript compiler components (WORK HERE)
    ├── AST.res              # Abstract syntax tree definitions
    ├── Lexer.res            # Source code tokenization
    ├── Parser.res           # Recursive descent parser with if/else support
    ├── Register.res         # Register type and utilities
    ├── RegisterAlloc.res    # Register allocation with variable shadowing
    ├── Codegen.res          # IC10 code generation with direct branch optimization
    └── Compiler.res         # Main compilation API

tests/                        # Comprehensive test suite (40 tests)
├── basic.test.js            # Variable declarations and arithmetic
├── comparisons.test.js      # Comparison operations and if/else
├── complex.test.js          # Complex expressions and mixed operations
├── scoping.test.js          # Variable scoping and block statements
├── errors.test.js           # Error cases and edge conditions
└── if.test.js               # Original if statement test
```

## Development Notes

- ReScript files are compiled to CommonJS modules with `.res.js` suffix
- GenType creates TypeScript definitions (`.gen.ts`) for ReScript modules
- The compiler uses pattern matching extensively for AST traversal
- Error handling uses ReScript's `result` type throughout the pipeline
- Register allocation failure triggers compilation errors
- Code generation includes constant folding and register reuse optimizations
- **Watch mode is always running** - your changes will be automatically compiled
- Variable shadowing is supported through register reuse
- Direct branch instructions are used for optimal IC10 assembly generation
- Comprehensive test coverage ensures compiler correctness (40 tests)

## Common Patterns

**Variable Declaration**: `let x = 5` → `move r0 5`
**Binary Operation**: `x + y` → `add r2 r0 r1`
**If-Only Statement**: `if x < 5 { a }` → `bge r0 5 label0; [then code]; label0:` (inverted branch skips on false)
**If-Else Statement**: `if x < y { a } else { b }` → `blt r0 r1 label1; [else code]; j label0; label1: [then code]; label0:`
**Variable Shadowing**: `let x = 10; if true { let x = 20 }` → Reuses same register for efficiency
**Constant Folding**: `2 + 3` → `move r0 5`
**Literal Optimization**: `x + 5` → `add r1 r0 5` (direct literal instead of register)

## Testing

The project includes a comprehensive test suite with 40 tests covering:

- **Basic functionality** (8 tests): Variable declarations, arithmetic operations, constant folding
- **Comparisons** (7 tests): All comparison operators (`<`, `>`, `==`) with if/else statements
- **Complex expressions** (7 tests): Operator precedence, mixed arithmetic and comparisons
- **Scoping** (7 tests): Variable shadowing, nested blocks, consecutive if statements
- **Error handling** (10 tests): Syntax errors, register exhaustion, edge cases
- **If statements** (1 test): Original failing test case for if-else functionality

Run tests with: `npm test` (Jest framework)

All tests pass and validate the compiler's correctness across different scenarios.

## Recent Changes

### Inverted Branch Logic Fix (Latest)
- **Fixed critical bug**: If-only statements were executing then blocks regardless of condition
- Added `generateInvertedBranch` function for correct if-only code generation
- **If-only**: Uses inverted branches (`bge`, `ble`, `bne`) to jump to end when condition is FALSE
- **If-else**: Branches to then label when condition is TRUE, else block falls through
- Updated all 40 test expectations to reflect correct assembly output
- Example: `if a < b { c }` now generates `bge r0 r1 label0; [then]; label0:` (was incorrectly `blt r0 r1 label0; label0: [then]`)

### If Statement Implementation
- Added `If` and `Else` tokens to lexer
- Implemented recursive descent parsing for if/else statements with mutual recursion
- Added variable scoping and shadowing support in register allocator
- Optimized code generation to use direct IC10 branch instructions (`blt`, `bgt`, `beq`)
- Eliminated inefficient `slt`/`beqz` patterns in favor of single branch instructions
- Created comprehensive test coverage for all language features

### Key Optimizations
- **Inverted Branches for If-Only**: `if x < 5 { a }` generates `bge r0 5 label0; [then]; label0:` (skip then block when false)
- **Direct Branch Instructions**: Single instruction branches instead of `slt`/`beqz` patterns
- **Variable Shadowing**: Reuses registers when variables are shadowed in inner scopes
- **Literal Operations**: Uses immediate values in arithmetic operations when possible

## Claude's Role

When working on this project, Claude should:

1. **Focus exclusively on ReScript compiler logic** in `src/compiler/`
2. **Never run build commands** - the developer handles compilation
3. **Never modify TypeScript files** - extension integration is out of scope
4. **Provide code improvements, bug fixes, and new features** for the compiler
5. **Explain changes clearly** with reference to IC10 assembly output
6. **Consider register allocation constraints** in all code generation changes
7. **Run tests after changes** to ensure correctness (`npm test`)
8. **Update test expectations** when modifying compiler behavior

