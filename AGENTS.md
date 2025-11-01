# AGENTS.md

## Project Overview

**Project Name**: ReScript to IC10 Compiler VSCode Extension

**Description**: A Visual Studio Code extension that compiles simplified ReScript code into IC10 assembly language for the game Stationeers. This is a Proof of Concept (POC) to demonstrate the feasibility of using a modern, type-safe language for writing game scripts.

**Status**: 🚧 POC Development Phase

---

## What We're Building

### Core Functionality
A VSCode extension that:
1. Takes ReScript source code as input
2. Parses and analyzes the ReScript syntax
3. Generates equivalent IC10 assembly code
4. Displays the compiled output in VSCode

### Target Languages

#### ReScript (Source)
- Modern, type-safe language that compiles to JavaScript
- OCaml-like syntax
- For this POC: simplified subset focusing on basic operations
- Example:
```rescript
let x = 10
let y = x + 5
if (y > 10) {
  let z = y * 2
}
```

#### IC10 (Target)
- Assembly-like language for Stationeers game
- Stack-based with 16 registers (r0-r15)
- Limited instruction set (move, add, sub, mul, div, branches, etc.)
- Example:
```ic10
move r0 10      # x = 10
add r1 r0 5     # y = x + 5
bgt r1 10 2     # if y > 10
mul r2 r1 2     # z = y * 2
```

---

## Project Architecture

### Directory Structure
```
rescript-ic10-vscode/
├── src/
│   ├── extension.ts           # VSCode extension entry point (TypeScript)
│   ├── compiler/
│   │   ├── Lexer.res          # ReScript lexer (new)
│   │   ├── Parser.res         # ReScript parser (consumes tokens from Lexer.res)
│   │   ├── AST.res            # AST type definitions (ReScript)
│   │   ├── Codegen.res        # IC10 code generator (ReScript)
│   │   ├── RegisterAlloc.res  # Register allocation logic (ReScript)
│   │   ├── Compiler.res       # Main compiler API (ReScript)
│   │   └── Optimizer.res      # (Optional) Code optimization (ReScript)
│   ├── utils/
│   │   ├── logger.ts          # Logging utilities (TypeScript)
│   │   └── errors.ts          # Error handling (TypeScript)
│   └── test/
│       ├── parser.test.ts
│       ├── codegen.test.ts
│       └── fixtures/          # Test ReScript files
├── package.json
├── bsconfig.json              # ReScript configuration
├── tsconfig.json              # TypeScript configuration
├── README.md
└── AGENTS.md                  # This file
```

### Key Components

#### 1. Lexer (`src/compiler/Lexer.res`)
- **Language**: ReScript
- **Purpose**: Convert raw ReScript source text into a stream of tokens for the parser.
- **Input**: ReScript source code (string)
- **Output**: Token stream (identifiers, literals, keywords, operators, punctuation)
- **Why**: Separating lexing simplifies the parser and makes token-level errors clearer for the user.
- **Scope for POC**:
  - Tokens for `let`, identifiers, integer literals
  - Operators: `+`, `-`, `*`, `/`, `>`, `<`, `==`
  - Punctuation: `(`, `)`, `{`, `}`, `;`
  - Basic error reporting for unexpected characters

#### 2. Parser (`src/compiler/Parser.res`)
- **Language**: ReScript
- **Purpose**: Consume tokens produced by Lexer.res and construct an Abstract Syntax Tree (AST)
- **Input**: Token stream (from Lexer.res)
- **Output**: AST nodes representing the program structure
- **Why ReScript**: Pattern matching makes parser code elegant and type-safe
- **Scope for POC**: 
  - Variable declarations (`let`)
  - Binary operations (`+`, `-`, `*`, `/`)
  - Comparisons (`>`, `<`, `==`, etc.)
  - If/else statements
  - Simple function definitions (stretch goal)

#### 3. AST (`src/compiler/AST.res`)
- **Language**: ReScript
- **Purpose**: Define types for all AST nodes using ReScript variants
- **Key Types**:
  ```rescript
  type rec astNode = 
    | VariableDeclaration(string, expr)
    | BinaryExpression(binaryOp, expr, expr)
    | Literal(int)
    | Identifier(string)
    | IfStatement(expr, blockStatement, option<blockStatement>)
    | BlockStatement(array<astNode>)
  
  and binaryOp = Add | Sub | Mul | Div | Gt | Lt | Eq
  
  and expr = astNode
  ```

#### 4. Code Generator (`src/compiler/Codegen.res`)
- **Language**: ReScript
- **Purpose**: Convert AST into IC10 assembly instructions
- **Key Challenges**:
  - Map ReScript variables to IC10 registers
  - Generate correct jump labels for conditionals
  - Maintain stack/register state
- **Why ReScript**: Pattern matching on AST variants makes code generation clean
- **Output**: String containing IC10 assembly code

#### 5. Register Allocator (`src/compiler/RegisterAlloc.res`)
- **Language**: ReScript
- **Purpose**: Intelligently assign IC10 registers to ReScript variables
- **Strategy**: Simple linear allocation for POC (r0, r1, r2, ...)
- **Constraint**: IC10 has only 16 registers (r0-r15)

#### 6. Main Compiler API (`src/compiler/Compiler.res`)
- **Language**: ReScript
- **Purpose**: High-level API that TypeScript extension will call
- **Interface**:
  ```rescript
  // Main entry point for TypeScript
  let compile: string => result<string, string>
  
  // Returns Ok(ic10Code) or Error(errorMessage)
  ```

#### 7. VSCode Extension (`src/extension.ts`)
- **Language**: TypeScript
- **Purpose**: Integrate compiler with VSCode, handle UI/UX
- **Integration with ReScript**:
  ```typescript
  import * as Compiler from './compiler/Compiler.bs.js';
  
  const result = Compiler.compile(sourceCode);
  // Handle result (Ok/Error)
  ```
- **Features**:
  - Command: "Compile ReScript to IC10"
  - Display output in new editor tab
  - Show compilation errors in problems panel
  - (Optional) Real-time compilation on save

---

## Current Scope (POC)

### ✅ Must Have (MVP)
1. Parse basic ReScript syntax:
   - Variable declarations
   - Arithmetic operations
   - Simple conditionals
2. Generate working IC10 code
3. VSCode command to trigger compilation
4. Display IC10 output in editor
5. Basic error handling

### 🎯 Nice to Have
- Syntax highlighting for IC10 output
- Line-by-line mapping (ReScript → IC10)
- Register usage visualization
- Simple optimization (constant folding)

### 🚫 Out of Scope for POC
- Full ReScript language support
- Pattern matching
- Complex type checking
- Loops (while/for)
- Functions/closures
- Stationeers device integration
- Debugging/breakpoints

---

## Technical Decisions

### Language: Hybrid TypeScript + ReScript
- **TypeScript**: VSCode extension layer (API integration)
  - **Why**: Native VSCode support, no bindings needed, all examples available
  - **Scope**: `extension.ts` - commands, UI, VSCode API calls
- **ReScript**: Compiler core (business logic)
  - **Why**: Type safety, pattern matching, immutability - perfect for compiler logic
  - **Scope**: Parser, AST, Code generator, Register allocator
  - **Benefit**: We "eat our own dogfood" - building ReScript compiler in ReScript

### Parsing Strategy: Hand-Written Lexer + Recursive Descent Parser
- **Why**: Full control and simpler error messages for a POC. We now split parsing into two phases:
  1. Lexer.res — tokenizes the input into a predictable stream of tokens.
  2. Parser.res — a hand-written recursive descent parser that consumes tokens and builds the AST.
- **Benefit**: Clear separation of concerns, easier to maintain and test lexing rules independently of grammar logic.

### Register Allocation: Linear Scan
- **Why**: Simple, deterministic, sufficient for POC
- **Limitation**: Doesn't handle register spilling (out of scope)

### Testing: Jest
- **Why**: Standard TypeScript testing framework, easy setup

---

## Example Compilation Flow

### Input (ReScript):
```rescript
let temperature = 25
let pressure = 100
let ratio = pressure / temperature
if (ratio > 3) {
  let alert = 1
}
```

### Output (IC10):
```ic10
# let temperature = 25
move r0 25

# let pressure = 100
move r1 100

# let ratio = pressure / temperature
div r2 r1 r0

# if (ratio > 3)
sgt r3 r2 3
beqz r3 4

# let alert = 1
move r4 1
```

---

## Development Workflow

### 1. Setup
```bash
npm install

# Install ReScript
npm install -D rescript

# Install TypeScript & VSCode types
npm install -D typescript @types/vscode @types/node

# Compile ReScript
npm run res:build

# Compile TypeScript
npm run compile
```

### 2. Development
```bash
# Watch mode for ReScript (auto-recompile on save)
npm run res:watch

# Watch mode for TypeScript
npm run watch

# Or run both in parallel
npm run dev
```

### 3. Testing
```bash
npm test                    # Run all tests
npm test -- parser.test.ts  # Run specific test
```

### 4. Run Extension
- Press F5 in VSCode to open Extension Development Host
- Open a `.res` file
- Run command: "Compile ReScript to IC10"

### 5. Package
```bash
vsce package  # Creates .vsix file
```

---

## Key Constraints & Limitations

### IC10 Constraints
- **16 registers only** (r0-r15)
- **No stack** - must manage registers manually
- **No function calls** - only labels and jumps
- **No strings** - only numbers and device references
- **No dynamic memory** - all allocations static

### ReScript Subset
- Only integer arithmetic
- No floating point (IC10 limitation)
- No arrays/lists
- No pattern matching
- No recursion
- No closures

---

## Resources

### IC10 Reference
- [Stationeers Wiki - IC10](https://stationeers-wiki.com/IC10)
- IC10 instruction set documentation
- Community examples and scripts

### ReScript Reference
- [ReScript Language Manual](https://rescript-lang.org/docs/manual/latest)
- ReScript syntax guide

### VSCode Extension API
- [VSCode Extension API Documentation](https://code.visualstudio.com/api)
- [Extension Samples](https://github.com/microsoft/vscode-extension-samples)

---

## Next Steps

### Phase 1: Core Compiler (Current)
- [ ] Implement basic parser
- [ ] Create AST types
- [ ] Build code generator
- [ ] Add register allocator

### Phase 2: VSCode Integration
- [ ] Create extension boilerplate
- [ ] Add compile command
- [ ] Display output
- [ ] Error handling

### Phase 3: Testing & Polish
- [ ] Write comprehensive tests
- [ ] Add example files
- [ ] Write documentation
- [ ] Package extension

---

## Notes for AI Assistant

### When Helping With Code:
1. **Always consider IC10 limitations** - only 16 registers, no stack
2. **Keep it simple** - this is a POC, not a production compiler
3. **Focus on readability** - other developers should understand the code
4. **Add comments** - explain non-obvious IC10 mappings
5. **Test-driven** - write tests before implementation when possible

### Common Patterns:
- **Variable → Register**: Each ReScript variable gets a unique register
- **Binary Op**: `a + b` → `add r[dest] r[a] r[b]`
- **Conditional**: Use `sgt/slt/seq` + `beqz/bnez` for branches
- **Labels**: Use sequential numbering (label0, label1, ...)

### When Stuck:
- Check IC10 instruction reference
- Look at example IC10 scripts from community
- Simplify the ReScript input
- Add debug logging to trace compilation

---

## Contact & Collaboration

This is a solo POC project. Future collaboration welcome after initial implementation.

**Goal**: Demonstrate that modern, type-safe languages can make game scripting more maintainable and less error-prone.

---

*Last Updated: 2025-11-01*
*Version: 0.1.0-poc*