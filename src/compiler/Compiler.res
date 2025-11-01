@genType
let compile = (source: string): result<string, string> => {
  // Step 1: Lex - tokenize the source code
  switch Lexer.tokenize(source) {
  | Error(msg) => Error("Lexer error: " ++ msg)
  | Ok(tokens) =>
    // Step 2: Parse - build AST from tokens
    switch Parser.parse(tokens) {
    | Error(msg) => Error("Parser error: " ++ msg)
    | Ok(_ast) =>
      // Step 3: Code generation (TODO: implement Codegen)
      // For now, return success message
      Ok("Successfully parsed! (Code generation coming next)")
    }
  }
}
