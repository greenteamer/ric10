// Code Generator for ReScript → IC10 compiler
// Converts AST nodes into IC10 assembly instructions

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

// Add an instruction to the output
let addInstruction = (state: codegenState, instruction: string): codegenState => {
  let len = Array.length(state.instructions)
  let newInstructions = Array.make(~length=len + 1, "")
  for i in 0 to len - 1 {
    switch Array.get(state.instructions, i) {
    | Some(v) => newInstructions[i] = v
    | None => ()
    }
  }
  newInstructions[len] = instruction
  {...state, instructions: newInstructions}
}

// Generate a unique label
let generateLabel = (state: codegenState): (codegenState, string) => {
  let label = "label" ++ Int.toString(state.labelCounter)
  let newState = {...state, labelCounter: state.labelCounter + 1}
  (newState, label)
}

// Generate IC10 code for an expression
let rec generateExpression = (state: codegenState, expr: AST.expr): result<(codegenState, int), string> => {
  switch expr {
  | AST.Literal(value) =>
    // For literal, allocate a temporary register
    switch RegisterAlloc.allocate(state.allocator, "") {
    | Error(msg) => Error(msg)
    | Ok((allocator, reg)) =>
      let newState = {...state, allocator}
      let instr = "move " ++ RegisterAlloc.registerName(reg) ++ " " ++ Int.toString(value)
      Ok((addInstruction(newState, instr), reg))
    }
  | AST.Identifier(name) =>
    // For identifier, get or allocate register
    switch RegisterAlloc.getOrAllocate(state.allocator, name) {
    | Error(msg) => Error(msg)
    | Ok((allocator, reg)) =>
      Ok(({...state, allocator}, reg))
    }
  | AST.BinaryExpression(op, left, right) =>
    // Generate code for left and right, then apply operation
    switch generateExpression(state, left) {
    | Error(msg) => Error(msg)
    | Ok((state1, leftReg)) =>
      switch generateExpression(state1, right) {
      | Error(msg) => Error(msg)
      | Ok((state2, rightReg)) =>
        // Allocate result register
        switch RegisterAlloc.allocate(state2.allocator, "") {
        | Error(msg) => Error(msg)
        | Ok((allocator, resultReg)) =>
          let newState = {...state2, allocator}
          // Generate appropriate IC10 instruction based on operator
          let opStr = switch op {
          | AST.Add => "add"
          | AST.Sub => "sub"
          | AST.Mul => "mul"
          | AST.Div => "div"
          | AST.Gt => "sgt"
          | AST.Lt => "slt"
          | AST.Eq => "seq"
          }
          let instr = opStr ++ " " ++ RegisterAlloc.registerName(resultReg) ++ " " ++ RegisterAlloc.registerName(leftReg) ++ " " ++ RegisterAlloc.registerName(rightReg)
          Ok((addInstruction(newState, instr), resultReg))
        }
      }
    }
  | AST.VariableDeclaration(name, value) =>
    // This shouldn't happen in expression context
    Error("VariableDeclaration found in expression context")
  | AST.IfStatement(condition, thenBlock, elseBlock) =>
    // This shouldn't happen in expression context
    Error("IfStatement found in expression context")
  | AST.BlockStatement(statements) =>
    // This shouldn't happen in expression context
    Error("BlockStatement found in expression context")
  }
}

// Generate IC10 code for a statement
let rec generateStatement = (state: codegenState, stmt: AST.astNode): result<codegenState, string> => {
  switch stmt {
  | AST.VariableDeclaration(name, expr) =>
    // Generate code for expression
    switch generateExpression(state, expr) {
    | Error(msg) => Error(msg)
    | Ok((state1, exprReg)) =>
      // Allocate register for variable
      switch RegisterAlloc.allocate(state1.allocator, name) {
      | Error(msg) => Error(msg)
      | Ok((allocator, varReg)) =>
        let newState = {...state1, allocator}
        // If expression register is different, move it
        if exprReg != varReg {
          let instr = "move " ++ RegisterAlloc.registerName(varReg) ++ " " ++ RegisterAlloc.registerName(exprReg)
          Ok(addInstruction(newState, instr))
        } else {
          Ok(newState)
        }
      }
    }
  | AST.BinaryExpression(op, left, right) =>
    // Standalone expression - just generate it
    switch generateExpression(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }
  | AST.IfStatement(condition, thenBlock, elseBlock) =>
    // Generate condition
    switch generateExpression(state, condition) {
    | Error(msg) => Error(msg)
    | Ok((state1, condReg)) =>
      // Generate labels
      switch generateLabel(state1) {
      | (state2, elseLabel) =>
        switch generateLabel(state2) {
        | (state3, endLabel) =>
          // Branch if condition is false (jump to else or end)
          let jumpLabel = switch elseBlock {
          | Some(_) => elseLabel
          | None => endLabel
          }
          let branchInstr = "beqz " ++ RegisterAlloc.registerName(condReg) ++ " " ++ jumpLabel
          let state4 = addInstruction(state3, branchInstr)
          // Generate then block
          switch generateBlock(state4, thenBlock) {
          | Error(msg) => Error(msg)
          | Ok(state5) =>
            // Generate else block if present
            switch elseBlock {
            | Some(elseStatements) =>
              // Jump to end after then block
              let jumpEndInstr = "j " ++ endLabel
              let state6 = addInstruction(state5, jumpEndInstr)
              // Add else label
              let state7 = addInstruction(state6, elseLabel ++ ":")
              switch generateBlock(state7, elseStatements) {
              | Error(msg) => Error(msg)
              | Ok(state8) =>
                // Add end label
                Ok(addInstruction(state8, endLabel ++ ":"))
              }
            | None =>
              // Add end label after then block
              Ok(addInstruction(state5, endLabel ++ ":"))
            }
          }
        }
      }
    }
  | AST.BlockStatement(statements) =>
    generateBlock(state, statements)
  | AST.Literal(_) =>
    // Standalone literal - generate it
    switch generateExpression(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }
  | AST.Identifier(_) =>
    // Standalone identifier - generate it
    switch generateExpression(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }
  }
}

// Generate IC10 code for a block of statements
and generateBlock = (state: codegenState, statements: AST.blockStatement): result<codegenState, string> => {
  let rec loop = (state: codegenState, i: int): result<codegenState, string> => {
    if i >= Array.length(statements) {
      Ok(state)
    } else {
      switch Array.get(statements, i) {
      | Some(stmt) =>
        switch generateStatement(state, stmt) {
        | Error(msg) => Error(msg)
        | Ok(newState) => loop(newState, i + 1)
        }
      | None => Ok(state)
      }
    }
  }
  loop(state, 0)
}

// Generate IC10 code for a program
let generate = (program: AST.program): result<string, string> => {
  let state = create()
  let rec loop = (state: codegenState, i: int): result<codegenState, string> => {
    if i >= Array.length(program) {
      Ok(state)
    } else {
      switch Array.get(program, i) {
      | Some(stmt) =>
        switch generateStatement(state, stmt) {
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
