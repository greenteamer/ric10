// ExprGen - Expression code generation
// Handles generation of expressions into registers with optimizations

// Type alias for codegen state (shared with other modules)
type codegenState = CodegenTypes.codegenState

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

// Add an instruction with a comment (conditional based on options)
let addInstructionWithComment = (state: codegenState, instruction: string, comment: string): codegenState => {
  if state.options.includeComments {
    let fullInstruction = instruction ++ "  # " ++ comment
    addInstruction(state, fullInstruction)
  } else {
    addInstruction(state, instruction)
  }
}

// Get variable name from register, or return register name
let getRegisterName = (state: codegenState, reg: Register.t): string => {
  switch RegisterAlloc.getVariableName(state.allocator, reg) {
  | Some(name) if !String.startsWith(name, "_temp_") => name
  | _ => Register.toString(reg)
  }
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

// Get operation symbol for comments
let getOpSymbol = (op: AST.binaryOp): string => {
  switch op {
  | AST.Add => "+"
  | AST.Sub => "-"
  | AST.Mul => "*"
  | AST.Div => "/"
  | AST.Gt => ">"
  | AST.Lt => "<"
  | AST.Eq => "=="
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
      let comment = Int.toString(value)
      Ok((addInstructionWithComment(newState, instr, comment), reg))
    }

  | AST.RefCreation(valueExpr) =>
    // Generate the initial value expression
    // Note: Ref register allocation happens in StmtGen for VariableDeclaration
    // This case handles ref(expr) when it appears in expression position
    // For Phase 1, just return the value (caller will handle allocation)
    generate(state, valueExpr)

  | AST.RefAccess(refName) =>
    // Look up the ref's register
    switch RegisterAlloc.getVariableInfo(state.allocator, refName) {
    | None => Error("Undefined variable: " ++ refName)
    | Some({register, isRef: false}) =>
      Error(refName ++ " is not a ref - cannot use .contents")
    | Some({register, isRef: true}) =>
      // Ref's register already contains the value
      // No IC10 instruction needed - just return the register
      Ok((state, register))
    }

  | AST.Identifier(name) =>
    // Check if this is a variant constructor (tag-only, no argument)
    switch Belt.Map.String.get(state.variantTags, name) {
    | Some(tag) =>
      // This is a tag-only variant constructor
      // Push tag onto stack
      let instr1 = "push " ++ Int.toString(tag)
      let comment1 = name ++ " variant tag"
      let state1 = addInstructionWithComment(state, instr1, comment1)

      // Allocate register to hold stack base address
      switch RegisterAlloc.allocateTempRegister(state1.allocator) {
      | Error(msg) => Error(msg)
      | Ok((allocator, baseReg)) =>
        // Generate: move baseReg sp; sub baseReg baseReg 1
        let instr2 = "move " ++ Register.toString(baseReg) ++ " sp"
        let comment2 = "get stack pointer"
        let instr3 =
          "sub " ++ Register.toString(baseReg) ++ " " ++ Register.toString(baseReg) ++ " 1"
        let comment3 = "adjust to variant address"

        let state2 = addInstructionWithComment({...state1, allocator}, instr2, comment2)
        let state3 = addInstructionWithComment(state2, instr3, comment3)

        Ok((state3, baseReg))
      }

    | None =>
      // Not a constructor, treat as variable reference
      switch RegisterAlloc.getRegister(state.allocator, name) {
      | None => Error("Variable not found: " ++ name)
      | Some(reg) => Ok((state, reg))
      }
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

          // Generate comment showing the operation
          let leftName = getRegisterName(state3, leftReg)
          let rightName = getRegisterName(state3, rightReg)
          let opSymbol = getOpSymbol(op)
          let comment = leftName ++ " " ++ opSymbol ++ " " ++ rightName

          let state4 = addInstructionWithComment(state3, instr, comment)

          // Free temporary registers
          let allocator2 = RegisterAlloc.freeTempIfTemp(
            RegisterAlloc.freeTempIfTemp(state4.allocator, leftReg),
            rightReg,
          )

          Ok({...state4, allocator: allocator2}, resultReg)
        }
      }
    }

  | AST.VariantConstructor(constructorName, argumentOpt) =>
    // Look up constructor tag
    switch Belt.Map.String.get(state.variantTags, constructorName) {
    | None => Error("Unknown variant constructor: " ++ constructorName)
    | Some(tag) =>
      // Push tag onto stack
      let instr1 = "push " ++ Int.toString(tag)
      let comment1 = constructorName ++ " variant tag"
      let state1 = addInstructionWithComment(state, instr1, comment1)

      // If has argument, generate and push it
      let state2 = switch argumentOpt {
      | None => state1
      | Some(argExpr) =>
        // Generate argument into a temporary register
        switch generate(state1, argExpr) {
        | Error(msg) => state1 // fallback - shouldn't happen
        | Ok((state2, argReg)) =>
          let instr2 = "push " ++ Register.toString(argReg)
          let comment2 = constructorName ++ " payload"
          let state3 = addInstructionWithComment(state2, instr2, comment2)

          // Free temp register if it was temporary
          let allocator = RegisterAlloc.freeTempIfTemp(state3.allocator, argReg)
          {...state3, allocator}
        }
      }

      // Allocate register to hold stack base address
      switch RegisterAlloc.allocateTempRegister(state2.allocator) {
      | Error(msg) => Error(msg)
      | Ok((allocator, baseReg)) =>
        // Generate: move baseReg sp; sub baseReg baseReg slots
        let slotsUsed = switch argumentOpt {
        | None => 1
        | Some(_) => 2
        }

        let instr3 = "move " ++ Register.toString(baseReg) ++ " sp"
        let comment3 = "get stack pointer"
        let instr4 =
          "sub " ++
          Register.toString(baseReg) ++
          " " ++
          Register.toString(baseReg) ++
          " " ++
          Int.toString(slotsUsed)
        let comment4 = "adjust to variant address"

        let state3 = addInstructionWithComment({...state2, allocator}, instr3, comment3)
        let state4 = addInstructionWithComment(state3, instr4, comment4)

        Ok((state4, baseReg))
      }
    }

  | AST.SwitchExpression(scrutinee, cases) =>
    // Generate code for scrutinee - get register pointing to variant's stack base
    switch generate(state, scrutinee) {
    | Error(msg) => Error(msg)
    | Ok((state1, scrutineeReg)) =>
      // Allocate temp register to read the tag
      switch RegisterAlloc.allocateTempRegister(state1.allocator) {
      | Error(msg) => Error(msg)
      | Ok((allocator, tagReg)) =>
        // Generate: move sp scrutineeReg; peek tagReg
        let instr1 = "move sp " ++ Register.toString(scrutineeReg)
        let comment1 = "set stack pointer to variant"
        let instr2 = "peek " ++ Register.toString(tagReg)
        let comment2 = "read variant tag"
        let state2 = addInstructionWithComment({...state1, allocator}, instr1, comment1)
        let state3 = addInstructionWithComment(state2, instr2, comment2)

        // Free scrutinee register if temp
        let allocator2 = RegisterAlloc.freeTempIfTemp(state3.allocator, scrutineeReg)
        let state4 = {...state3, allocator: allocator2}

        // Allocate result register for match expression result
        switch RegisterAlloc.allocateTempRegister(state4.allocator) {
        | Error(msg) => Error(msg)
        | Ok((allocator3, resultReg)) =>
          let state5 = {...state4, allocator: allocator3}

          // Generate labels for each case and end label
          let matchEndLabel = "match_end_" ++ Int.toString(state5.labelCounter)
          let state6 = {...state5, labelCounter: state5.labelCounter + 1}

          // Generate branch instructions for each case
          let (state7, caseLabels) = Array.reduceWithIndex(
            cases,
            (state6, []),
            ((state, labels), matchCase, idx) => {
              // Look up constructor tag
              switch Belt.Map.String.get(state.variantTags, matchCase.constructorName) {
              | None => (state, labels) // Skip unknown constructors
              | Some(tag) =>
                let caseLabel = "match_case_" ++ Int.toString(state.labelCounter)
                let newState = {...state, labelCounter: state.labelCounter + 1}
                // Generate: beq tagReg tag caseLabel
                let branchInstr =
                  "beq " ++
                  Register.toString(tagReg) ++
                  " " ++
                  Int.toString(tag) ++
                  " " ++
                  caseLabel
                let comment = "match " ++ matchCase.constructorName
                (addInstructionWithComment(newState, branchInstr, comment), Array.concat(labels, [(caseLabel, matchCase)]))
              }
            },
          )

          // Free tag register after branches
          let allocator4 = RegisterAlloc.freeTempIfTemp(state7.allocator, tagReg)
          let state8 = {...state7, allocator: allocator4}

          // Jump to end if no case matched (fallthrough - shouldn't happen with exhaustive match)
          let state9 = addInstructionWithComment(state8, "j " ++ matchEndLabel, "no match")

          // Generate code for each case body
          let stateAfterCases = Array.reduce(caseLabels, state9, (state, (label, matchCase)) => {
            // Add case label
            let comment = "case " ++ matchCase.constructorName
            let state1 = addInstructionWithComment(state, label ++ ":", comment)

            // If case has argument binding, extract it from stack
            let state2 = switch matchCase.argumentBinding {
            | None => state1
            | Some(argName) =>
              // Allocate register for argument (not a ref)
              switch RegisterAlloc.allocateNormal(state1.allocator, argName) {
              | Error(_) => state1 // Fallback
              | Ok((allocator, argReg)) =>
                // Generate: add sp scrutineeReg 1; peek argReg
                // Note: scrutineeReg may have been freed, we need to recalculate
                // For now, we'll use a simplified approach
                let state2 = {...state1, allocator}
                // TODO: This needs scrutinee register - for now skip
                state2
              }
            }

            // Generate case body
            // TODO: Implement proper body generation to avoid dependency cycle
            // For now, skip body generation
            let state3 = state2

            // Jump to match end
            addInstructionWithComment(state3, "j " ++ matchEndLabel, "end case")
          })

          // Add match end label
          let stateFinal = addInstructionWithComment(stateAfterCases, matchEndLabel ++ ":", "end match")

          Ok((stateFinal, resultReg))
        }
      }
    }

  | AST.VariableDeclaration(_, _) => Error("VariableDeclaration in expression context")
  | AST.TypeDeclaration(_, _) => Error("TypeDeclaration in expression context")
  | AST.IfStatement(_, _, _) => Error("IfStatement in expression context")
  | AST.WhileLoop(_, _) => Error("WhileLoop in expression context")
  | AST.BlockStatement(_) => Error("BlockStatement in expression context")
  | AST.RefAssignment(_, _) => Error("RefAssignment in expression context")
  | AST.RawInstruction(_) => Error("RawInstruction in expression context")
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
    let comment = Int.toString(value)
    Ok(addInstructionWithComment(state, instr, comment))

  | AST.RefCreation(valueExpr) =>
    // Generate value directly into target register
    generateInto(state, valueExpr, targetReg)

  | AST.RefAccess(refName) =>
    // Look up ref's register and copy to target if different
    switch RegisterAlloc.getVariableInfo(state.allocator, refName) {
    | None => Error("Undefined variable: " ++ refName)
    | Some({register: _, isRef: false}) =>
      Error(refName ++ " is not a ref - cannot use .contents")
    | Some({register: refReg, isRef: true}) =>
      if refReg == targetReg {
        Ok(state) // Already in target
      } else {
        let instr = "move " ++ Register.toString(targetReg) ++ " " ++ Register.toString(refReg)
        let comment = refName ++ ".contents"
        Ok(addInstructionWithComment(state, instr, comment))
      }
    }

  | AST.RefAssignment(_, _) =>
    // RefAssignment is a statement, not an expression
    Error("RefAssignment cannot be used as an expression")

  | AST.Identifier(name) =>
    // Check if this is a variant constructor (tag-only)
    switch Belt.Map.String.get(state.variantTags, name) {
    | Some(_) =>
      // This is a tag-only variant constructor, use generate then move
      switch generate(state, AST.Identifier(name)) {
      | Error(msg) => Error(msg)
      | Ok((state1, resultReg)) =>
        if resultReg == targetReg {
          Ok(state1)
        } else {
          let instr = "move " ++ Register.toString(targetReg) ++ " " ++ Register.toString(resultReg)
          let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, resultReg)
          Ok(addInstruction({...state1, allocator}, instr))
        }
      }

    | None =>
      // Not a constructor, copy from source variable to target register (if different)
      switch RegisterAlloc.getRegister(state.allocator, name) {
      | None => Error("Variable not found: " ++ name)
      | Some(sourceReg) =>
        if sourceReg == targetReg {
          Ok(state) // Already in target register
        } else {
          let instr = "move " ++ Register.toString(targetReg) ++ " " ++ Register.toString(sourceReg)
          let comment = name
          Ok(addInstructionWithComment(state, instr, comment))
        }
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
      let opSymbol = getOpSymbol(op)
      let comment = Int.toString(leftVal) ++ " " ++ opSymbol ++ " " ++ Int.toString(rightVal)
      Ok(addInstructionWithComment(state, instr, comment))

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
        let leftName = getRegisterName(state1, nonLiteralReg)
        let opSymbol = getOpSymbol(op)
        let comment = leftName ++ " " ++ opSymbol ++ " " ++ Int.toString(literalVal)
        let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, nonLiteralReg)
        Ok(addInstructionWithComment({...state1, allocator}, instr, comment))
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
        let rightName = getRegisterName(state1, nonLiteralReg)
        let opSymbol = getOpSymbol(op)
        let comment = Int.toString(literalVal) ++ " " ++ opSymbol ++ " " ++ rightName
        let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, nonLiteralReg)
        Ok(addInstructionWithComment({...state1, allocator}, instr, comment))
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
        let leftName = getRegisterName(state1, nonLiteralReg)
        let opSymbol = getOpSymbol(op)
        let comment = leftName ++ " " ++ opSymbol ++ " " ++ Int.toString(literalVal)
        let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, nonLiteralReg)
        Ok(addInstructionWithComment({...state1, allocator}, instr, comment))
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

          let leftName = getRegisterName(state2, leftReg)
          let rightName = getRegisterName(state2, rightReg)
          let opSymbol = getOpSymbol(op)
          let comment = leftName ++ " " ++ opSymbol ++ " " ++ rightName

          let allocator = RegisterAlloc.freeTempIfTemp(
            RegisterAlloc.freeTempIfTemp(state2.allocator, leftReg),
            rightReg,
          )

          Ok(addInstructionWithComment({...state2, allocator}, instr, comment))
        }
      }
    }

  | AST.VariantConstructor(_, _) =>
    // For variant constructors in generateInto, use generate then move result
    switch generate(state, expr) {
    | Error(msg) => Error(msg)
    | Ok((state1, resultReg)) =>
      if resultReg == targetReg {
        Ok(state1)
      } else {
        let instr = "move " ++ Register.toString(targetReg) ++ " " ++ Register.toString(resultReg)
        let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, resultReg)
        Ok(addInstruction({...state1, allocator}, instr))
      }
    }

  | AST.SwitchExpression(_, _) =>
    // For switch expressions in generateInto, use generate then move result
    switch generate(state, expr) {
    | Error(msg) => Error(msg)
    | Ok((state1, resultReg)) =>
      if resultReg == targetReg {
        Ok(state1)
      } else {
        let instr = "move " ++ Register.toString(targetReg) ++ " " ++ Register.toString(resultReg)
        let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, resultReg)
        Ok(addInstruction({...state1, allocator}, instr))
      }
    }

  | AST.VariableDeclaration(_, _) => Error("VariableDeclaration in expression context")
  | AST.TypeDeclaration(_, _) => Error("TypeDeclaration in expression context")
  | AST.IfStatement(_, _, _) => Error("IfStatement in expression context")
  | AST.WhileLoop(_, _) => Error("WhileLoop in expression context")
  | AST.BlockStatement(_) => Error("BlockStatement in expression context")
  | AST.RefAssignment(_, _) => Error("RefAssignment in expression context")
  | AST.RawInstruction(_) => Error("RawInstruction in expression context")
  }
}
