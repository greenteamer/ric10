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

**ReScript Subset**: Variable declarations (`let`), arithmetic operations (`+`, `-`, `*`, `/`), comparisons (`>`, `<`, `==`), conditionals (`if/else`), block statements, integer literals, and identifiers.

**IC10 Target**: Assembly language for Stationeers with 16 registers, no stack, and instructions like `move`, `add`, `sub`, `mul`, `div`, `sgt`, `slt`, `seq`, `beqz`, `bnez`, and `j`.

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
    ├── Parser.res           # Recursive descent parser
    ├── Register.res         # Register type and utilities
    ├── RegisterAlloc.res    # Register allocation and management
    ├── Codegen.res          # IC10 code generation with optimizations
    └── Compiler.res         # Main compilation API
```

## Development Notes

- ReScript files are compiled to CommonJS modules with `.res.js` suffix
- GenType creates TypeScript definitions (`.gen.ts`) for ReScript modules
- The compiler uses pattern matching extensively for AST traversal
- Error handling uses ReScript's `result` type throughout the pipeline
- Register allocation failure triggers compilation errors
- Code generation includes constant folding and register reuse optimizations
- **Watch mode is always running** - your changes will be automatically compiled

## Common Patterns

**Variable Declaration**: `let x = 5` → `move r0 5`
**Binary Operation**: `x + y` → `add r2 r0 r1`
**Conditional**: `if (x > 5)` → `sgt r3 r0 5; beqz r3 label0`
**Constant Folding**: `2 + 3` → `move r0 5`

## Claude's Role

When working on this project, Claude should:

1. **Focus exclusively on ReScript compiler logic** in `src/compiler/`
2. **Never run build commands** - the developer handles compilation
3. **Never modify TypeScript files** - extension integration is out of scope
4. **Provide code improvements, bug fixes, and new features** for the compiler
5. **Explain changes clearly** with reference to IC10 assembly output
6. **Consider register allocation constraints** in all code generation changes

