@genType
let compile = (source: string, ~options: option<CodegenTypes.compilerOptions>=?, ()): result<string, string> => {
  // Default options: comments disabled for backward compatibility
  let defaultOptions = {CodegenTypes.includeComments: false}
  let compilerOptions = switch options {
  | Some(opts) => opts
  | None => defaultOptions
  }

  // Step 1: Lex - tokenize the source code
  switch Lexer.tokenize(source) {
  | Error(msg) => Error("Lexer error: " ++ msg)
  | Ok(tokens) =>
    // Step 2: Parse - build AST from tokens
    switch Parser.parse(tokens) {
    | Error(msg) => Error("Parser error: " ++ msg)
    | Ok(_ast) =>
      // Step 3: Code generation with options
      Codegen.generate(_ast, compilerOptions)
    }
  }
}
