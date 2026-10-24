# Claude AI Assistant Guide

> **For AI assistants working with this codebase**

## Quick Start

1. **📖 Read First**: [docs/README.md](docs/README.md) - documentation hub
2. **🏗️ Architecture**: [docs/architecture/compiler-overview.md](docs/architecture/compiler-overview.md)
3. **📏 Rules**: [docs/architecture/compiler-development-rules.md](docs/architecture/compiler-development-rules.md)
4. **📝 Language**: [docs/user-guide/language-reference.md](docs/user-guide/language-reference.md)

## Project Summary

**ric10** compiles a subset of ReScript 12 to IC10 assembly for the game Stationeers.
User programs are valid ReScript: the official compiler type-checks them against
`src/compiler/IC10.res`, and ric10 compiles the same file to IC10 (16 registers, 128 lines).

- Compiler: ReScript, `src/compiler/`
- CLI: `scripts/compile.res`, `scripts/init.res`, bundled to `dist/` by esbuild, entry `bin/ric10.js`
- Generated JavaScript is ES modules (`*.res.mjs`)

## Working with This Codebase

### ⚠️ Important Rules

**DO NOT run these commands** (build processes are managed by the developer):
- `npm run res:dev`
- `npm run watch`

**You CAN run**:
- `npm test` - all test suites
- `npm run test:fuzz` - 2000 random programs checked against ReScript
- `npm run res:build` - only to verify correctness after changes (tests import `*.res.mjs`)
- `npm run build:bundle` - rebuild `dist/` to try the CLI (`node bin/ric10.js file.res --stdout`)
- `node scripts/gen-bindings.mjs` - regenerate `Logic`/`Slot`/`Prefab` in `IC10.res`, `IC10.runtime.res` and `PrefabTable.res`

### File Modifications

✅ **Modify**:
- ReScript files in `src/compiler/` and `scripts/`
- Tests in `tests/` (`*.test.mjs`, `tests/support/`)
- Examples in `examples/` (they are type-checked by `npm run res:build`)
- Documentation in `docs/`, `README.md`, `CHANGELOG.md`

❌ **NEVER modify**:
- Generated files (`*.res.mjs`, `dist/`)
- Configuration files (unless explicitly requested)

### Error Message Format

Raise errors through `Errors.fail`, which renders as:
```
[FileName.res][functionName] line:col: descriptive message
  hint: optional hint
```
```rescript
Errors.fail(~file="Parser.res", ~fn="parsePrimary", ~loc, ~hint="...", "message")
```

## Code Structure

```
src/compiler/
├── Compiler.res        # pipeline orchestrator, compile / compileWithDiagnostics
├── Errors.res          # structured diagnostics
├── Lexer.res           # tokens with line:col
├── AST.res             # AST with locations
├── Parser.res          # Pratt parser (ReScript 12 precedence)
├── IC10.res            # bindings for user programs (shipped by `ric10 init`); Logic/Slot section generated
├── CodegenTypes.res    # options, IC10 limits
├── PrefabTable.res     # GENERATED prefab accessor -> hash table
├── NumUtil.res
└── IR/
    ├── IR.res          # IR types + uses/def/isPure/mapUses
    ├── IRGen.res       # AST -> IR (values, variants in registers, calls, builtins)
    ├── IROptimizer.res # passes as data, fixpoint
    ├── Liveness.res    # whole-program liveness with call summaries
    ├── RegAlloc.res    # interference graph, coalescing, colouring
    ├── IRToIC10.res    # final assembly
    └── IRPrint.res     # IR dump
tests/
├── *.test.mjs          # emulator-based suites
├── differential.test.mjs   # ReScript vs ric10 traces, random programs
├── golden/             # expected output of examples/
└── support/            # ic10.mjs (emulator), harness.mjs, progen.mjs, jsChip.mjs, IC10.runtime.res
```

## Key Concepts

- **Values**: every value is a double. Variants are a tag register plus payload registers.
  Refs are cells; `.contents` copies.
- **Functions**: inlined when called once, tiny, or given devices/strings/refs/functions;
  otherwise compiled once and called with `jal`. No recursion.
- **Registers**: unlimited vregs until `RegAlloc`; whole-program liveness makes values that
  survive a call interfere with everything the callee writes.
- **Optimizer**: `IROptimizer.makePasses`; a test pins the order.

## Testing

Behaviour is tested by running output in the IC10 emulator and comparing with the real
ReScript compiler, not by comparing assembly text. See [docs/testing/ic10-tests.md](docs/testing/ic10-tests.md).

```bash
npm test                    # all suites
npm test -- functions       # one suite
npm run golden:update       # after an intended change in examples output
```

## Finding Information

| Need | Location |
|------|----------|
| Language features | `docs/user-guide/language-reference.md` |
| Bindings | `docs/user-guide/ic10-bindings.md` |
| Architecture | `docs/architecture/compiler-overview.md` |
| IR | `docs/architecture/ir-reference.md` |
| Why things are so | `docs/architecture/decisions.md` |
| Old (0.1) design | `docs/archive/2025/` |

## Resources

- **Stationeers IC10**: https://stationeers-wiki.com/IC10
- **ReScript Docs**: https://rescript-lang.org
