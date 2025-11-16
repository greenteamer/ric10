@genType
let compile = (source: string, ~options: option<CodegenTypes.compilerOptions>=?, ()): result<
  string,
  string,
> => {
  Console.log(">>> Starting compilation process...")
  // Default options: IC10 backend, comments disabled for backward compatibility
  let defaultOptions: CodegenTypes.compilerOptions = {
    includeComments: false,
    debugAST: false,
    backend: IC10,
  }
  let compilerOptions = switch options {
  | Some(opts) => opts
  | None => defaultOptions
  }

  // Standard compilation pipeline: Lex -> Parse -> AST Optimize -> IR -> IR Optimize -> Backend
  source
  ->Lexer.tokenize
  ->Result.flatMap(Parser.parse)
  ->Result.map(Optimizer.optimizeProgram)
  ->Result.flatMap(IRGen.generate)
  ->Result.map(ir => {
    Console.log("=== IR (Before Optimization) ===")
    Console.log(IRPrint.print(ir))
    ir
  })
  ->Result.map(IROptimizer.optimize)
  ->Result.map(ir => {
    Console.log("\n=== IR (After Optimization) ===")
    Console.log(IRPrint.print(ir))
    ir
  })
  ->Result.flatMap(ir => {
    // Select backend based on compiler options
    switch compilerOptions.backend {
    | IC10 =>
      Console.log("\n=== Generating IC10 Assembly ===")
      IRToIC10.generate(ir)
    | WASM =>
      Console.log("\n=== Generating WebAssembly ===")
      IRToWASM.generate(ir)
    }
  })
}
