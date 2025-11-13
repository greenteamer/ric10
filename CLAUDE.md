# Claude AI Assistant Guide

> **For AI assistants working with this codebase**

## Quick Start

1. **📖 Read First**: [docs/README.md](docs/README.md) - Complete documentation hub
2. **🏗️ Architecture**: [docs/architecture/compiler-overview.md](docs/architecture/compiler-overview.md) - Detailed project structure
3. **📝 Language Guide**: [docs/user-guide/language-reference.md](docs/user-guide/language-reference.md) - ReScript subset documentation

## Project Summary

**ReScript to IC10 Compiler** - A VSCode extension that compiles a subset of ReScript to IC10 assembly language for the Stationeers game.

- **Core Compiler**: ReScript (`src/compiler/`)
- **VSCode Extension**: TypeScript (`src/extension.ts`)
- **Target**: IC10 assembly with 16 registers (r0-r15)

## Working with This Codebase

### ⚠️ Important Rules

**DO NOT run these commands** (build processes are managed by the developer):
- `npm run res:build`
- `npm run res:dev`
- `npm run compile`
- `npm run watch`

**You CAN run**:
- `npm test` - Run test suites
- `npm run res:build` - Only to verify correctness after changes

### File Modifications

✅ **ONLY modify**:
- ReScript files in `src/compiler/` (*.res)
- Test files in `tests/` (*.test.js)
- Documentation in `docs/`

❌ **NEVER modify**:
- TypeScript files (`src/extension.ts`)
- Generated files (`*.res.js`, `*.gen.ts`)
- Configuration files (unless explicitly requested)

### Error Message Format

All error messages follow this pattern:
```rescript
Error("[FileName.res][functionName]: descriptive message")
Error("[FileName.res][functionName]<-" ++ propagatedMessage)  // For propagated errors
```

## Code Structure

```
src/compiler/
├── Compiler.res       # Main compilation orchestrator
├── Lexer.res          # Tokenization
├── Parser.res         # AST generation
├── AST.res           # AST type definitions
├── Optimizer.res      # AST-level optimizations
├── CodegenTypes.res   # Shared compiler option types
├── RegisterAlloc.res  # Register management utilities
├── StackAlloc.res     # Stack allocation utilities
└── IR/                # Intermediate representation (IR pipeline)
    ├── IR.res         # IR type definitions
    ├── IRGen.res      # AST → IR conversion
    ├── IRPrint.res    # IR pretty printer
    ├── IRToIC10.res   # IR → IC10 conversion
    └── IROptimizer.res # IR-level optimizations
```

**Note:** The compiler uses a two-phase IR pipeline exclusively.

## Key Concepts

### IR Architecture (Intermediate Representation)
- **Two-phase compilation**: AST → IR (unlimited vregs) → IC10 (r0-r15)
- **Virtual registers**: IR uses v0, v1, v2... without physical limits
- **Physical allocation**: IRToIC10 maps virtual → physical registers
- **Operand types**:
  - `VReg(n)` - Virtual register reference
  - `Num(n)` - Immediate integer value
  - `Name(s)` - Named constant reference (for `define` statements)
- **Optimizations**: Dead code elimination, constant propagation, peephole
- **See**: `docs/architecture/ir-reference.md` for complete IR documentation

### Register Allocation
- **IR Phase**: Unlimited virtual registers (v0, v1, v2...)
- **IC10 Phase**: r0-r15 physical registers
- **Constraint**: Maximum 16 physical registers
- Register allocation happens during IR → IC10 conversion

### Variant Types
- Fixed stack layout: `stack[0]` = tag, rest = arguments
- Stack pointer set once, never modified
- Use `get db address` and `poke address value` for access
- Stack operations via StackAlloc, StackPoke, StackGet instructions

### Code Generation
- **Compilation pipeline**: Lexer → Parser → Optimizer → IRGen → IROptimizer → IRToIC10
- **Peephole optimization**: Fuses Compare+Bnez → direct branches
- **Constant folding**: Both AST and IR level optimizations
- **Dead code elimination**: Removes unused instructions
- **Register reuse**: Variable shadowing optimized during allocation

## Finding Information

| Need | Location |
|------|----------|
| Language features | `docs/user-guide/language-reference.md` |
| Architecture details | `docs/architecture/` |
| IR documentation | `docs/architecture/ir-reference.md` |
| Implementation guides | `docs/implementation/` |
| Test examples | `tests/*.test.js` |
| Historical context | `docs/archive/` |

## Common Tasks

### Adding a Feature
1. Read relevant docs in `docs/implementation/`
2. Modify compiler in `src/compiler/`
3. Add tests in `tests/`
4. Update documentation in `docs/`

### Fixing a Bug
1. Check `docs/archive/` for similar issues
2. Read architecture docs to understand the system
3. Add a failing test case
4. Fix the code
5. Verify all tests pass

### Understanding Code
1. Start with `docs/README.md`
2. Read `docs/architecture/compiler-overview.md` for big picture
3. Check implementation guides for specific features
4. Look at test cases for examples

## Testing

```bash
npm test              # Run all tests (40+ test cases)
npm test -- loops     # Run specific test suite
```

Test categories: basic, comparisons, complex, scoping, control-flow, variants, errors

## Resources

- **Documentation Hub**: `docs/README.md`
- **Stationeers IC10**: https://stationeers-wiki.com/IC10
- **ReScript Docs**: https://rescript-lang.org

---

**Remember**: Always check `docs/README.md` first for comprehensive navigation to all project documentation!
