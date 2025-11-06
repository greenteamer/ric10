// Code Generator for ReScript → IC10 compiler
// Orchestrates the compilation pipeline from AST to IC10 assembly

// Code generation state (shared type definition in CodegenTypes.res)
type codegenState = CodegenTypes.codegenState

// Create initial codegen state
let create = (options: CodegenTypes.compilerOptions): codegenState => {
  {
    allocator: RegisterAlloc.create(),
    stackAllocator: StackAlloc.create(),
    instructions: Array.make(~length=0, ""),
    labelCounter: 0,
    variantTypes: Belt.Map.String.empty,
    variantTags: Belt.Map.String.empty,
    defines: Belt.Map.String.empty,
    defineOrder: [],
    options,
  }
}

// Generate IC10 code for a program
let generate = (program: AST.program, options: CodegenTypes.compilerOptions): result<
  string,
  string,
> => {
  // First, optimize the AST
  Console.log2(">>> Original Program: ", program)
  let optimizedProgram = Optimizer.optimizeProgram(program)

  // Generate code for each statement
  let state = create(options)
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
    Console.log2(">>> finalState : ", finalState)
    let defineInstructions = Array.map(finalState.defineOrder, ((name, value)) => {
      let valueStr = switch value {
      | CodegenTypes.HashExpr(str) => "HASH(\"" ++ str ++ "\")"
      | CodegenTypes.NumberValue(num) => Int.toString(num)
      }
      "define " ++ name ++ " " ++ valueStr
    })

    let allInstructions = if Array.length(defineInstructions) > 0 {
      Array.concat(defineInstructions, finalState.instructions)
    } else {
      finalState.instructions
    }

    let code = Array.join(allInstructions, "\n")
    Ok(code)
  }
}
