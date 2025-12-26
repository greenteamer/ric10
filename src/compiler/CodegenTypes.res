// Shared types for compiler options

type backend =
  | IC10  // Default: IC10 assembly
  | WASM  // WebAssembly text format

type compilerOptions = {
  debugAST: bool,
  includeComments: bool,
  backend: backend,
}
