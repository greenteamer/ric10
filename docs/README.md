# ReScript to IC10 Compiler Documentation

**Complete documentation for the ReScript → IC10 assembly compiler**

## Quick Links

- 🚀 [Getting Started](#getting-started)
- 📚 [User Guides](#user-guides)
- 🏗️ [Architecture](#architecture)
- 💻 [Implementation Details](#implementation-details)
- 🧪 [Testing](#testing)
- 📦 [Archive](#archive)

---

## Getting Started

New to the compiler? Start here:

1. **[Compiler Overview](architecture/compiler-overview.md)** - Project structure, architecture, and development workflow
2. **[Language Reference](user-guide/language-reference.md)** - Complete ReScript subset language guide
3. **[IC10 Support](user-guide/ic10-support.md)** - IC10 assembly features and device operations

---

## User Guides

### Language and Usage

| Document | Description |
|----------|-------------|
| [Language Reference](user-guide/language-reference.md) | Complete language syntax and features |
| [IC10 Support](user-guide/ic10-support.md) | IC10 assembly language features |
| [IC10 Bindings](user-guide/ic10-bindings.md) | ReScript bindings for IC10 operations |
| [IC10 Usage Guide](user-guide/ic10-usage-guide.md) | Practical IC10 programming guide |

### Key Features

- ✅ Variables and arithmetic operations
- ✅ Control flow (if/else, while loops)
- ✅ Mutable references
- ✅ Variant types with pattern matching
- ✅ Device I/O operations
- ✅ Raw assembly instructions

---

## Architecture

### Core Design Documents

| Document | Description |
|----------|-------------|
| [Compiler Overview](architecture/compiler-overview.md) | High-level architecture and component design |
| [Stack Layout](architecture/stack-layout.md) | IC10 stack operations and variant storage strategy |
| [IR Design](architecture/ir-design.md) | Intermediate Representation migration plan |
| [IR Reference](architecture/ir-reference.md) | Complete IR types, instructions, and examples |
| [IR Migration Report](architecture/ir-migration-report.md) | Current migration status and progress |
| [Device I/O Operations](architecture/device-io.md) | Platform-agnostic device I/O design for multi-backend support |

### Compiler Pipeline

```
ReScript Source
      ↓
   Lexer.res         → Tokenization
      ↓
   Parser.res        → AST Generation
      ↓
   ┌────────────────┐
   │  Code Generation│
   ├────────────────┤
   │ StmtGen.res    │ → Statement generation
   │ ExprGen.res    │ → Expression generation
   │ BranchGen.res  │ → Control flow
   │ RegisterAlloc  │ → Register management
   └────────────────┘
      ↓
  IC10 Assembly
```

### Architecture Highlights

- **Hybrid ReScript/TypeScript**: Core compiler in ReScript, VSCode extension in TypeScript
- **16 Registers**: r0-r15 with split allocation (variables vs temps)
- **Fixed Stack Layout**: Variant types use pre-allocated stack regions
- **IR Layer**: Optional intermediate representation for optimizations

---

## Implementation Details

### Feature Implementation Guides

| Document | Description |
|----------|-------------|
| [Loops](implementation/loops.md) | While loop implementation and optimizations |
| [Switch Statements](implementation/switch-statements.md) | Pattern matching and variant switches |
| [Variants](implementation/variants.md) | Complete variant type implementation |
| [Implementation Notes](implementation/implementation-notes.md) | General implementation reference |

### Key Implementation Patterns

#### Register Allocation

```rescript
// Variable registers: r0-r13 (low to high)
let x = 5         // → r0
let y = 10        // → r1

// Temp registers: r15-r14 (high to low)
switch state {
| Active(n) => n  // n → r15 (freed after case)
}
```

#### Stack Layout for Variants

```
type state = Idle | Active(int)

stack[0] = tag (0=Idle, 1=Active)
stack[1] = Active arg0
```

#### Branch Generation

```rescript
if x < y { ... }
→ blt r0 r1 then_label  // Direct branch (optimized)
```

---

## Testing

| Document | Description |
|----------|-------------|
| [IC10 Tests](testing/ic10-tests.md) | IC10 feature test coverage |

### Test Categories

- **Basic**: Variables, arithmetic, constant folding
- **Comparisons**: All comparison operators with if/else
- **Complex Expressions**: Operator precedence, mixed operations
- **Scoping**: Variable shadowing, nested blocks
- **Control Flow**: If/else, while loops, infinite loops
- **Variants**: Type declarations, pattern matching, switches
- **Error Handling**: Syntax errors, register exhaustion

### Running Tests

```bash
npm test                    # Run all tests
npm test loops              # Run specific test suite
npm run res:build          # Rebuild ReScript compiler
```

---

## Archive

Historical documents and implementation records:

| Document | Description |
|----------|-------------|
| [Implementation Plan](archive/implementation-plan.md) | Original roadmap and performance analysis |
| [Implementation Complete](archive/implementation-complete.md) | Completion milestone documentation |
| [Switch Bug Investigation](archive/switch-bug-investigation.md) | Stack pointer corruption debugging |
| [Fix Tests](archive/fix-tests.md) | Test suite fixes and updates |

---

## Project Structure

```
rescript-ic10-compiler/
├── src/
│   ├── compiler/           # ReScript compiler core
│   │   ├── Lexer.res      # Tokenization
│   │   ├── Parser.res     # AST generation
│   │   ├── AST.res        # AST definitions
│   │   ├── StmtGen.res    # Statement code generation
│   │   ├── ExprGen.res    # Expression code generation
│   │   ├── BranchGen.res  # Control flow generation
│   │   ├── RegisterAlloc.res # Register management
│   │   ├── Codegen.res    # Main codegen orchestrator
│   │   └── IR/            # Intermediate representation
│   │       ├── IR.res     # IR definitions
│   │       ├── IRGen.res  # AST → IR conversion
│   │       └── IRToIC10.res # IR → IC10 lowering
│   └── extension.ts       # VSCode extension (TypeScript)
├── tests/                 # Jest test suites
├── docs/                  # Documentation (you are here!)
│   ├── user-guide/       # Language and usage guides
│   ├── architecture/     # Design documents
│   ├── implementation/   # Implementation details
│   ├── testing/          # Test documentation
│   └── archive/          # Historical documents
└── testing/              # Test files
    └── test.res         # Sample ReScript code
```

---

## Quick Reference

### Common Tasks

| Task | Command |
|------|---------|
| Compile ReScript | `npm run res:build` |
| Watch mode | `npm run res:dev` |
| Run tests | `npm test` |
| Test in VSCode | Press `F5` → "Compile ReScript to IC10" |

### File Naming Conventions

- **User guides**: `lowercase-with-dashes.md`
- **Architecture**: `descriptive-name.md`
- **Implementation**: `feature-name.md`
- **Archive**: `original-purpose.md`

### Documentation Best Practices

- ✅ Use relative links for cross-referencing
- ✅ Include code examples with expected output
- ✅ Explain both "what" and "why"
- ✅ Keep examples simple and focused
- ✅ Update docs when features change

---

## Contributing

When adding new features or fixing bugs:

1. Update relevant documentation
2. Add test cases
3. Update CLAUDE.md if architecture changes
4. Consider adding examples to user guides

---

## Support & Resources

- **Stationeers IC10 Wiki**: [Official IC10 Documentation](https://stationeers-wiki.com/IC10)
- **ReScript Documentation**: [rescript-lang.org](https://rescript-lang.org)
- **VSCode Extension API**: [code.visualstudio.com/api](https://code.visualstudio.com/api)

---

## Document Index

### By Category

**User Guides**
- Language Reference
- IC10 Support
- IC10 Bindings
- IC10 Usage Guide

**Architecture**
- Compiler Overview
- Stack Layout
- IR Design
- Device I/O Operations

**Implementation**
- Loops
- Switch Statements
- Variants
- Implementation Notes

**Testing**
- IC10 Tests

**Archive**
- Implementation Plan
- Implementation Complete
- Switch Bug Investigation
- Fix Tests

---

**Last Updated**: 2025-11-12  
**Documentation Version**: 2.0  
**Compiler Version**: See package.json
