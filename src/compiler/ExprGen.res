// ExprGen - Expression code generation
// Handles generation of expressions into registers with optimizations

// Type alias for codegen state
type codegenState = {
  allocator: RegisterAlloc.allocator,
  instructions: array<string>,
  labelCounter: int,
}

// Add an instruction to the state
let addInstruction = (state: codegenState, instruction: string): codegenState => {
  let len = Array.length(state.instructions)
  let newInstructions = Array.make(~length=len + 1, "")
  for i in 0 to len - 1 {
    switch state.instructions[i] {
    | Some(v) => newInstructions[i] = v
    | None => ()
    }
  }
  newInstructions[len] = instruction
  {...state, instructions: newInstructions}
}

// Get operation string for IC10
let getOpString = (op: AST.binaryOp): string => {
  switch op {
  | AST.Add => "add"
  | AST.Sub => "sub"
  | AST.Mul => "mul"
  | AST.Div => "div"
  | AST.Gt => "sgt"
  | AST.Lt => "slt"
  | AST.Eq => "seq"
  }
}

// Generate expression and return the register containing the result
// Allocates temporary registers as needed
let rec generate = (state: codegenState, expr: AST.expr): result<
  (codegenState, Register.t),
  string,
> => {
  switch expr {
  | AST.Literal(value) =>
    // Allocate temporary register for literal
    switch RegisterAlloc.allocateTempRegister(state.allocator) {
    | Error(msg) => Error(msg)
    | Ok((allocator, reg)) =>
      let newState = {...state, allocator}
      let instr = "move " ++ Register.toString(reg) ++ " " ++ Int.toString(value)
      Ok((addInstruction(newState, instr), reg))
    }

  | AST.Identifier(name) =>
    // Return the variable's register directly (no move needed)
    switch RegisterAlloc.getRegister(state.allocator, name) {
    | None => Error("Variable not found: " ++ name)
    | Some(reg) => Ok((state, reg))
    }

  | AST.BinaryExpression(op, left, right) =>
    // Generate left operand
    switch generate(state, left) {
    | Error(msg) => Error(msg)
    | Ok((state1, leftReg)) =>
      // Generate right operand
      switch generate(state1, right) {
      | Error(msg) => Error(msg)
      | Ok((state2, rightReg)) =>
        // Allocate register for result
        switch RegisterAlloc.allocateTempRegister(state2.allocator) {
        | Error(msg) => Error(msg)
        | Ok((allocator, resultReg)) =>
          let state3 = {...state2, allocator}
          let opStr = getOpString(op)

          // Generate operation instruction
          let instr =
            opStr ++
            " " ++
            Register.toString(resultReg) ++
            " " ++
            Register.toString(leftReg) ++
            " " ++
            Register.toString(rightReg)

          let state4 = addInstruction(state3, instr)

          // Free temporary registers
          let allocator2 = RegisterAlloc.freeTempIfTemp(
            RegisterAlloc.freeTempIfTemp(state4.allocator, leftReg),
            rightReg,
          )

          Ok({...state4, allocator: allocator2}, resultReg)
        }
      }
    }

  | AST.VariableDeclaration(_, _) => Error("VariableDeclaration in expression context")
  | AST.IfStatement(_, _, _) => Error("IfStatement in expression context")
  | AST.BlockStatement(_) => Error("BlockStatement in expression context")
  }
}

// Generate expression directly into a target register
// More efficient when the target register is known in advance (e.g., variable declarations)
let rec generateInto = (
  state: codegenState,
  expr: AST.expr,
  targetReg: Register.t,
): result<codegenState, string> => {
  switch expr {
  | AST.Literal(value) =>
    // Write literal directly to target register
    let instr = "move " ++ Register.toString(targetReg) ++ " " ++ Int.toString(value)
    Ok(addInstruction(state, instr))

  | AST.Identifier(name) =>
    // Copy from source variable to target register (if different)
    switch RegisterAlloc.getRegister(state.allocator, name) {
    | None => Error("Variable not found: " ++ name)
    | Some(sourceReg) =>
      if sourceReg == targetReg {
        Ok(state) // Already in target register
      } else {
        let instr = "move " ++ Register.toString(targetReg) ++ " " ++ Register.toString(sourceReg)
        Ok(addInstruction(state, instr))
      }
    }

  | AST.BinaryExpression(op, left, right) =>
    switch (left, right) {
    // ===== CONSTANT FOLDING =====
    | (AST.Literal(leftVal), AST.Literal(rightVal)) =>
      let resultVal = switch op {
      | AST.Add => leftVal + rightVal
      | AST.Sub => leftVal - rightVal
      | AST.Mul => leftVal * rightVal
      | AST.Div => leftVal / rightVal
      | AST.Gt => leftVal > rightVal ? 1 : 0
      | AST.Lt => leftVal < rightVal ? 1 : 0
      | AST.Eq => leftVal == rightVal ? 1 : 0
      }
      let instr = "move " ++ Register.toString(targetReg) ++ " " ++ Int.toString(resultVal)
      Ok(addInstruction(state, instr))

    // ===== LITERAL OPTIMIZATION (Commutative ops: add, mul) =====
    | (nonLiteral, AST.Literal(literalVal)) when op == AST.Add || op == AST.Mul =>
      let opStr = op == AST.Add ? "add" : "mul"
      switch generate(state, nonLiteral) {
      | Error(msg) => Error(msg)
      | Ok((state1, nonLiteralReg)) =>
        let instr =
          opStr ++
          " " ++
          Register.toString(targetReg) ++
          " " ++
          Register.toString(nonLiteralReg) ++
          " " ++
          Int.toString(literalVal)
        let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, nonLiteralReg)
        Ok(addInstruction({...state1, allocator}, instr))
      }

    | (AST.Literal(literalVal), nonLiteral) when op == AST.Add || op == AST.Mul =>
      let opStr = op == AST.Add ? "add" : "mul"
      switch generate(state, nonLiteral) {
      | Error(msg) => Error(msg)
      | Ok((state1, nonLiteralReg)) =>
        let instr =
          opStr ++
          " " ++
          Register.toString(targetReg) ++
          " " ++
          Register.toString(nonLiteralReg) ++
          " " ++
          Int.toString(literalVal)
        let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, nonLiteralReg)
        Ok(addInstruction({...state1, allocator}, instr))
      }

    // ===== LITERAL OPTIMIZATION (Non-commutative ops: sub, div) =====
    | (nonLiteral, AST.Literal(literalVal)) when op == AST.Sub || op == AST.Div =>
      let opStr = op == AST.Sub ? "sub" : "div"
      switch generate(state, nonLiteral) {
      | Error(msg) => Error(msg)
      | Ok((state1, nonLiteralReg)) =>
        let instr =
          opStr ++
          " " ++
          Register.toString(targetReg) ++
          " " ++
          Register.toString(nonLiteralReg) ++
          " " ++
          Int.toString(literalVal)
        let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, nonLiteralReg)
        Ok(addInstruction({...state1, allocator}, instr))
      }

    // ===== DEFAULT: General binary expression =====
    | _ =>
      switch generate(state, left) {
      | Error(msg) => Error(msg)
      | Ok((state1, leftReg)) =>
        switch generate(state1, right) {
        | Error(msg) => Error(msg)
        | Ok((state2, rightReg)) =>
          let opStr = getOpString(op)
          let instr =
            opStr ++
            " " ++
            Register.toString(targetReg) ++
            " " ++
            Register.toString(leftReg) ++
            " " ++
            Register.toString(rightReg)

          let allocator = RegisterAlloc.freeTempIfTemp(
            RegisterAlloc.freeTempIfTemp(state2.allocator, leftReg),
            rightReg,
          )

          Ok(addInstruction({...state2, allocator}, instr))
        }
      }
    }

  | AST.VariableDeclaration(_, _) => Error("VariableDeclaration in expression context")
  | AST.IfStatement(_, _, _) => Error("IfStatement in expression context")
  | AST.BlockStatement(_) => Error("BlockStatement in expression context")
  }
}
