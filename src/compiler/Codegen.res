// Code Generator for ReScript → IC10 compiler
// Orchestrates the compilation pipeline from AST to IC10 assembly

// Code generation state
type codegenState = {
  allocator: RegisterAlloc.allocator,
  instructions: array<string>, // Generated IC10 instructions
  labelCounter: int, // Counter for generating unique labels
}

// Create initial codegen state
let create = (): codegenState => {
  {
    allocator: RegisterAlloc.create(),
    instructions: Array.make(~length=0, ""),
    labelCounter: 0,
  }
}

// Generate IC10 code for a program
let generate = (program: AST.program): result<string, string> => {
  // First, optimize the AST
  let optimizedProgram = Optimizer.optimizeProgram(program)

  // Generate code for each statement
  let state = create()
  let rec loop = (state: codegenState, i: int): result<codegenState, string> => {
    if i >= Array.length(optimizedProgram) {
      Ok(state)
    } else {
      switch optimizedProgram[i] {
      | Some(stmt) =>
        switch StmtGen.generate(state, stmt) {
        | Error(msg) => Error(msg)
        | Ok(newState) => loop(newState, i + 1)
        }
      | None => Ok(state)
      }
    }
  }

  switch loop(state, 0) {
  | Error(msg) => Error("Code generation error: " ++ msg)
  | Ok(finalState) =>
    // Join instructions with newlines
    let code = Array.join(finalState.instructions, "\n")
    Ok(code)
  }
}
