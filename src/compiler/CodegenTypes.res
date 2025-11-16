// Shared types for compiler options

@genType
type backend =
  | IC10  // Default: IC10 assembly
  | WASM  // WebAssembly text format

@genType
type compilerOptions = {
  debugAST: bool,
  includeComments: bool,
  backend: backend,
}
