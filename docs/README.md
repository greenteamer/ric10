# ric10 documentation

ric10 compiles a subset of ReScript 12 to IC10 assembly for Stationeers.

## Using ric10

- [Language reference](user-guide/language-reference.md): what you can write and how it compiles
- [IC10 bindings](user-guide/ic10-bindings.md): devices, batch operations, stack, math
- [Changelog](../CHANGELOG.md)

## Working on ric10

- [Compiler overview](architecture/compiler-overview.md): pipeline, modules, IRGen, optimizer, allocation
- [IR reference](architecture/ir-reference.md): operands, instructions, analyses
- [Development rules](architecture/compiler-development-rules.md): invariants and the merge checklist
- [Technical decisions](architecture/decisions.md): why things are the way they are, known limitations
- [Testing](testing/ic10-tests.md): emulator, differential tests, fuzzing, golden files

## History

Documents describing the 0.1 compiler (stack-based variants, the WASM backend, the IR
migration) are in [archive/2025](archive/2025/). They do not describe the current code.
