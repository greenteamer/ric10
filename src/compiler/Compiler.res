type program = Program(string) | ASTProgram(array<AST.stmt>)

@genType
let compile = (source: string, ~options: option<CodegenTypes.compilerOptions>=?, ()): result<
  program,
  string,
> => {
  Console.log(">>> Starting compilation process...")
  // Default options: comments disabled for backward compatibility
  let defaultOptions: CodegenTypes.compilerOptions = {
    includeComments: false,
    debugAST: false,
    useIR: false,
  }
  let compilerOptions = switch options {
  | Some(opts) => opts
  | None => defaultOptions
  }

  let {debugAST, useIR} = compilerOptions

  switch (debugAST, useIR) {
  | (true, _) =>
    // Step 1: Lex - tokenize the source code
    source
    ->Lexer.tokenize
    ->Result.flatMap(Parser.parse)
    ->Result.map(res => ASTProgram(res))

  | (_, true) =>
    // Step 1: Lex - tokenize the source code
    source
    ->Lexer.tokenize
    ->Result.flatMap(Parser.parse)
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
    ->Result.flatMap(IRToIC10.generate)
    ->Result.map(res => Program(res))

  | _ =>
    // Step 1: Lex - tokenize the source code
    source
    ->Lexer.tokenize
    ->Result.flatMap(Parser.parse)
    ->Result.flatMap(ast => {
      Codegen.generate(ast, compilerOptions)
    })
    ->Result.map(res => Program(res))
  }
}
