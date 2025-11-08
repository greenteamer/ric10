type program = Program(string) | ASTProgram(array<AST.stmt>)

@genType
let compile = (source: string, ~options: option<CodegenTypes.compilerOptions>=?, ()): result<
  program,
  string,
> => {
  Console.log(">>> Starting compilation process...")
  // Default options: comments disabled for backward compatibility
  let defaultOptions: CodegenTypes.compilerOptions = {includeComments: false, debugAST: false}
  let compilerOptions = switch options {
  | Some(opts) => opts
  | None => defaultOptions
  }

  switch compilerOptions.debugAST {
  | true =>
    // Step 1: Lex - tokenize the source code
    source
    ->Lexer.tokenize
    ->Result.flatMap(Parser.parse)
    ->Result.map(res => ASTProgram(res))

  | false =>
    // Step 1: Lex - tokenize the source code
    source
    ->Lexer.tokenize
    ->Result.flatMap(Parser.parse)
    ->Result.flatMap(ast => Codegen.generate(ast, compilerOptions))
    ->Result.map(res => Program(res))
  }
}
