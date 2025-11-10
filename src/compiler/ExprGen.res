// ExprGen - Expression code generation
// Handles generation of expressions into registers with optimizations

// Type alias for codegen state (shared with other modules)
type codegenState = CodegenTypes.codegenState

module Utils = {
  let getDefineOrRegister = (state: codegenState, name) =>
    switch Belt.Map.String.get(state.defines, name) {
    | Some(CodegenTypes.NumberValue(numValue)) => Ok(Int.toString(numValue)) // Numeric define
    | Some(CodegenTypes.HashExpr(_)) => Error("Variable '" ++ name ++ "can not be a hash")
    | None =>
      // Try to get it as a register variable
      switch RegisterAlloc.getRegister(state.allocator, name) {
      | None => Error("Variable '" ++ name ++ "' not found")
      | Some(valueReg) => Ok(Register.toString(valueReg))
      }
    }
}

// Helper to get max args for a variant type
let getMaxArgsForVariantType = (constructors: array<AST.variantConstructor>): int => {
  Array.reduce(constructors, 0, (maxArgs, constructor) => {
    if constructor.argCount > maxArgs {
      constructor.argCount
    } else {
      maxArgs
    }
  })
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

// Add an instruction with a comment (conditional based on options)
let addInstructionWithComment = (
  state: codegenState,
  instruction: string,
  comment: string,
): codegenState => {
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
    | Some({register: _, isRef: false}) => Error(refName ++ " is not a ref - cannot use .contents")
    | Some({register, isRef: true}) =>
      // Ref's register already contains the value
      // No IC10 instruction needed - just return the register
      Ok((state, register))
    }

  | AST.StringLiteral(_str) =>
    // String literals shouldn't appear as standalone expressions in IC10
    // They're only used as arguments to IC10 functions
    Error("String literals can only be used as IC10 function arguments")

  | AST.Identifier(name) =>
    // Check if this is a constant
    switch Belt.Map.String.get(state.defines, name) {
    | Some(CodegenTypes.NumberValue(value)) =>
      // Integer constant - allocate temp register and load the value
      switch RegisterAlloc.allocateTempRegister(state.allocator) {
      | Error(msg) => Error(msg)
      | Ok((allocator, reg)) =>
        let newState = {...state, allocator}
        let instr = "move " ++ Register.toString(reg) ++ " " ++ name
        let comment = Int.toString(value)
        Ok((addInstructionWithComment(newState, instr, comment), reg))
      }
    | Some(CodegenTypes.HashExpr(_)) =>
      // HASH constant - can't be used as runtime value in expressions
      Error(
        name ++ " is a HASH constant and cannot be used in arithmetic expressions. Use it only in IC10 functions like lb() or sb().",
      )
    | None =>
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
        // Not a constructor or constant, treat as variable reference
        switch RegisterAlloc.getRegister(state.allocator, name) {
        | None => Error("Variable not found: " ++ name)
        | Some(reg) => Ok((state, reg))
        }
      }
    }

  | AST.FunctionCall(funcName, args) =>
    // Handle IC10 device I/O functions
    let parsedFuncName = funcName->String.split("")->List.fromArray
    Console.log2("[ExprGen] Function call parsedFuncName: ", parsedFuncName)
    switch parsedFuncName {
    // Load functions must be used in direct variable assignments only
    | list{"l"}
    | list{"l", "b"}
    | list{"l", "b", "n"} =>
      Error(
        "IC10 load functions (l/lb/lbn) must be used in direct variable assignments, not in complex expressions. " ++
        "Example: let temp = " ++
        funcName ++ "(...) instead of using it in an expression.",
      )

    // Store functions can be used as standalone statements
    | list{"s"} =>
      // s device property value
      let input = (args[0], args[1], args[2])

      switch input {
      | (
          Some(AST.ArgDevice(deviceName)),
          Some(AST.ArgString(property)),
          Some(AST.ArgExpr(valueExpr)),
        ) =>
        switch valueExpr {
        | AST.Literal(value) =>
          let inst = `s ${deviceName} ${property} ${Int.toString(value)}`
          let state1 = addInstruction(state, inst)
          // Return dummy register for statement context
          switch RegisterAlloc.allocateTempRegister(state1.allocator) {
          | Error(msg) => Error(msg)
          | Ok((allocator, dummyReg)) => Ok(({...state1, allocator}, dummyReg))
          }
        | AST.Identifier(valueName) =>
          Utils.getDefineOrRegister(state, valueName)
          ->Result.map(valueStr => `s ${deviceName} ${property} ${valueStr}`)
          ->Result.map(addInstruction(state, _))
          ->Result.flatMap(state1 => {
            // Return dummy register for statement context
            switch RegisterAlloc.allocateTempRegister(state1.allocator) {
            | Error(msg) => Error(msg)
            | Ok((allocator, dummyReg)) => Ok(({...state1, allocator}, dummyReg))
            }
          })
        | _ =>
          // For complex expressions, generate into a temp register first
          switch generate(state, valueExpr) {
          | Error(msg) => Error(msg)
          | Ok((state1, valueReg)) =>
            let inst = `s ${deviceName} ${property} ${Register.toString(valueReg)}`
            let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, valueReg)
            let state2 = addInstruction({...state1, allocator}, inst)
            // Return dummy register for statement context
            switch RegisterAlloc.allocateTempRegister(state2.allocator) {
            | Error(msg) => Error(msg)
            | Ok((allocator, dummyReg)) => Ok(({...state2, allocator}, dummyReg))
            }
          }
        }
      | _ => Error("s() expects arguments: (device_identifier, \"property\", value)")
      }

    | list{"s", "b"} =>
      // sb hash property value mode
      let input = (args[0], args[1], args[2], args[3])

      switch input {
      | (
          Some(AST.ArgExpr(AST.Identifier(hashName))),
          Some(AST.ArgString(property)),
          Some(AST.ArgExpr(AST.Identifier(valueName))),
          Some(AST.ArgMode(modeExpr)),
        ) =>
        // Verify hash is a define constant
        switch Belt.Map.String.get(state.defines, hashName) {
        | None => Error(hashName ++ " is not a HASH constant - use hash() to define it")
        | Some(_) =>
          let modeStr = Mode.toString(modeExpr)
          Utils.getDefineOrRegister(state, valueName)
          ->Result.map(valueStr => `sb ${hashName} ${property} ${valueStr} ${modeStr}`)
          ->Result.map(addInstruction(state, _))
          ->Result.flatMap(state1 => {
            // Return dummy register for statement context
            switch RegisterAlloc.allocateTempRegister(state1.allocator) {
            | Error(msg) => Error(msg)
            | Ok((allocator, dummyReg)) => Ok(({...state1, allocator}, dummyReg))
            }
          })
        }
      | _ =>
        Error(
          "sb() expects arguments: (hash_constant, \"property\", variable, mode) - hash must be a define constant, value must be a variable",
        )
      }

    | list{"s", "b", "n"} =>
      // sbn hash hash property value
      let input = (args[0], args[1], args[2], args[3])

      switch input {
      | (
          Some(AST.ArgExpr(AST.Identifier(typeHash))),
          Some(AST.ArgExpr(AST.Identifier(nameHash))),
          Some(AST.ArgString(property)),
          Some(AST.ArgExpr(valueExpr)),
        ) =>
        // Verify hashes are define constants
        switch (
          Belt.Map.String.get(state.defines, typeHash),
          Belt.Map.String.get(state.defines, nameHash),
        ) {
        | (None, _)
        | (_, None) =>
          Error(`${typeHash} or ${nameHash} is not a HASH constant - use hash() to define it"`)
        | _ =>
          switch valueExpr {
          | AST.Literal(value) =>
            let inst = `sbn ${typeHash} ${nameHash} ${property} ${Int.toString(value)}`
            let state1 = addInstruction(state, inst)
            // Return dummy register for statement context
            switch RegisterAlloc.allocateTempRegister(state1.allocator) {
            | Error(msg) => Error(msg)
            | Ok((allocator, dummyReg)) => Ok(({...state1, allocator}, dummyReg))
            }
          | AST.Identifier(valueName) =>
            Utils.getDefineOrRegister(state, valueName)
            ->Result.map(valueStr => `sbn ${typeHash} ${nameHash} ${property} ${valueStr}`)
            ->Result.map(addInstruction(state, _))
            ->Result.flatMap(state1 => {
              // Return dummy register for statement context
              switch RegisterAlloc.allocateTempRegister(state1.allocator) {
              | Error(msg) => Error(msg)
              | Ok((allocator, dummyReg)) => Ok(({...state1, allocator}, dummyReg))
              }
            })
          | _ =>
            // For complex expressions, generate into a temp register first
            switch generate(state, valueExpr) {
            | Error(msg) => Error(msg)
            | Ok((state1, valueReg)) =>
              let inst = `sbn ${typeHash} ${nameHash} ${property} ${Register.toString(valueReg)}`
              let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, valueReg)
              let state2 = addInstruction({...state1, allocator}, inst)
              // Return dummy register for statement context
              switch RegisterAlloc.allocateTempRegister(state2.allocator) {
              | Error(msg) => Error(msg)
              | Ok((allocator, dummyReg)) => Ok(({...state2, allocator}, dummyReg))
              }
            }
          }
        }
      | _ =>
        Error(
          "sbn() expects arguments: (hash_constant, hash_constant, \"property\", value) - both hashes must be define constants",
        )
      }

    | _ => Error("Unknown IC10 function: " ++ funcName)
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

  | AST.VariantConstructor(constructorName, arguments) =>
    // Look up constructor tag
    switch Belt.Map.String.get(state.variantTags, constructorName) {
    | None => Error("Unknown variant constructor: " ++ constructorName)
    | Some(tag) =>
      // Push tag onto stack
      let instr1 = "push " ++ Int.toString(tag)
      let comment1 = constructorName ++ " variant tag"
      let state1 = addInstructionWithComment(state, instr1, comment1)

      // Generate and push all arguments
      let rec pushArgs = (state: codegenState, args: array<AST.expr>, index: int): codegenState => {
        if index >= Array.length(args) {
          state
        } else {
          // Get argument at index
          switch Belt.Array.get(args, index) {
          | None => state // shouldn't happen
          | Some(argExpr) =>
            // Generate argument into a temporary register
            switch generate(state, argExpr) {
            | Error(_msg) => state // fallback - shouldn't happen
            | Ok((state2, argReg)) =>
              let instr = "push " ++ Register.toString(argReg)
              let comment = constructorName ++ " arg" ++ Int.toString(index)
              let state3 = addInstructionWithComment(state2, instr, comment)

              // Free temp register if it was temporary
              let allocator = RegisterAlloc.freeTempIfTemp(state3.allocator, argReg)
              let state4 = {...state3, allocator}

              // Push next argument
              pushArgs(state4, args, index + 1)
            }
          }
        }
      }

      let state2 = pushArgs(state1, arguments, 0)

      // Allocate register to hold stack base address
      switch RegisterAlloc.allocateTempRegister(state2.allocator) {
      | Error(msg) => Error(msg)
      | Ok((allocator, baseReg)) =>
        // Generate: move baseReg sp; sub baseReg baseReg slots
        let slotsUsed = 1 + Array.length(arguments) // tag + arguments

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

  | AST.SwitchExpression(_scrutinee, _cases) =>
    // For switch expressions, we need case body generation
    // This creates a dependency cycle if we call StmtGen directly
    // Instead, generateSwitch is called from StmtGen with a callback
    Error("Switch expressions must be generated via generateSwitchWithBody")

  | AST.VariableDeclaration(_, _) => Error("VariableDeclaration in expression context")
  | AST.TypeDeclaration(_, _) => Error("TypeDeclaration in expression context")
  | AST.IfStatement(_, _, _) => Error("IfStatement in expression context")
  | AST.WhileLoop(_, _) => Error("WhileLoop in expression context")
  | AST.BlockStatement(_) => Error("BlockStatement in expression context")
  | AST.RefAssignment(_, _) => Error("RefAssignment in expression context")
  | AST.RawInstruction(_) => Error("RawInstruction in expression context")
  }
}

// Generate switch expression with callback for body generation
// This breaks the circular dependency between ExprGen and StmtGen
let generateSwitchWithBody = (
  state: codegenState,
  scrutinee: AST.expr,
  cases: array<AST.matchCase>,
  generateCaseBody: (codegenState, AST.blockStatement) => result<codegenState, string>,
): result<(codegenState, Register.t), string> => {
  // Check if this is a variant ref switch
  let variantTypeOpt = switch scrutinee {
  | AST.RefAccess(refName) => Belt.Map.String.get(state.variantRefTypes, refName)
  | _ => None
  }

  switch variantTypeOpt {
  | Some(typeName) =>
    // This is a variant ref - use fixed stack approach with get db
    // Get variant type info
    switch Belt.Map.String.get(state.variantTypes, typeName) {
    | None => Error("Variant type not found: " ++ typeName)
    | Some(constructors) =>
      let maxArgs = getMaxArgsForVariantType(constructors)

      // Allocate temp register to read the tag
      switch RegisterAlloc.allocateTempRegister(state.allocator) {
      | Error(msg) => Error(msg)
      | Ok((allocator, tagReg)) =>
        // Use get db 0 to read tag from stack[0] without touching sp
        let instr = "get " ++ Register.toString(tagReg) ++ " db 0"
        let comment = "read variant tag from stack[0]"
        let state2 = addInstructionWithComment({...state, allocator}, instr, comment)

        // Allocate result register for match expression result
        switch RegisterAlloc.allocateTempRegister(state2.allocator) {
        | Error(msg) => Error(msg)
        | Ok((allocator3, resultReg)) =>
          let state3 = {...state2, allocator: allocator3}

          // Generate labels for each case and end label
          let matchEndLabel = "match_end_" ++ Int.toString(state3.labelCounter)
          let state4 = {...state3, labelCounter: state3.labelCounter + 1}

          // Generate branch instructions for each case
          let (state5, caseLabels) = Array.reduceWithIndex(cases, (state4, []), (
            (state, labels),
            matchCase,
            _idx,
          ) => {
            // Look up constructor tag
            switch Belt.Map.String.get(state.variantTags, matchCase.constructorName) {
            | None => (state, labels) // Skip unknown constructors
            | Some(tag) =>
              let caseLabel = "match_case_" ++ Int.toString(state.labelCounter)
              let newState = {...state, labelCounter: state.labelCounter + 1}
              // Generate: beq tagReg tag caseLabel
              let branchInstr =
                "beq " ++ Register.toString(tagReg) ++ " " ++ Int.toString(tag) ++ " " ++ caseLabel
              let comment = "match " ++ matchCase.constructorName
              (
                addInstructionWithComment(newState, branchInstr, comment),
                Array.concat(labels, [(caseLabel, matchCase, tag)]),
              )
            }
          })

          // Free tag register after branches
          let allocator4 = RegisterAlloc.freeTempIfTemp(state5.allocator, tagReg)
          let state6 = {...state5, allocator: allocator4}

          // Jump to end if no case matched (fallthrough - shouldn't happen with exhaustive match)
          let state7 = addInstructionWithComment(state6, "j " ++ matchEndLabel, "no match")

          // Generate code for each case body
          let stateAfterCases = Array.reduce(caseLabels, state7, (
            state,
            (label, matchCase, tag),
          ) => {
            // Add case label
            let comment = "case " ++ matchCase.constructorName
            let state1 = addInstructionWithComment(state, label ++ ":", comment)

            // If case has argument bindings, extract them from stack using get db
            let state2 = if Array.length(matchCase.argumentBindings) == 0 {
              state1
            } else {
              // Extract all argument bindings using temp registers
              let rec extractArgs = (
                state: codegenState,
                bindings: array<string>,
                index: int,
              ): codegenState => {
                if index >= Array.length(bindings) {
                  state
                } else {
                  switch Belt.Array.get(bindings, index) {
                  | None => state
                  | Some(argName) =>
                    // Allocate normal register for argument binding (not temp!)
                    switch RegisterAlloc.allocateNormal(state.allocator, argName) {
                    | Error(_) => state // Fallback - allocation failed
                    | Ok((allocator, argReg)) =>
                      // Calculate address: tag * maxArgs + 1 + index
                      let address = tag * maxArgs + 1 + index

                      // Use get db to extract value from fixed stack position
                      let instr =
                        "get " ++ Register.toString(argReg) ++ " db " ++ Int.toString(address)
                      let comment = "extract " ++ argName
                      let state2 = addInstructionWithComment({...state, allocator}, instr, comment)

                      // Extract next argument
                      extractArgs(state2, bindings, index + 1)
                    }
                  }
                }
              }

              extractArgs(state1, matchCase.argumentBindings, 0)
            }

            // Generate case body using the provided callback
            let state3 = switch generateCaseBody(state2, matchCase.body) {
            | Error(_) => state2 // Fallback - keep state if body fails
            | Ok(newState) => newState
            }

            // Jump to match end
            addInstructionWithComment(state3, "j " ++ matchEndLabel, "end case")
          })

          // Add match end label
          let stateFinal = addInstructionWithComment(
            stateAfterCases,
            matchEndLabel ++ ":",
            "end match",
          )

          Ok((stateFinal, resultReg))
        }
      }
    }

  | None =>
    // Not a variant ref - use old approach with move sp; peek
    // Generate scrutinee expression
    switch generate(state, scrutinee) {
    | Error(msg) => Error(msg)
    | Ok((state1, scrutineeReg)) =>
      // Allocate tag register
      switch RegisterAlloc.allocateTempRegister(state1.allocator) {
      | Error(msg) => Error(msg)
      | Ok((allocator2, tagReg)) =>
        // Extract tag: move sp scrutineeReg; peek tagReg
        let instr1 = "move sp " ++ Register.toString(scrutineeReg)
        let comment1 = "position to variant"
        let instr2 = "peek " ++ Register.toString(tagReg)
        let comment2 = "read tag"

        let state2 = addInstructionWithComment({...state1, allocator: allocator2}, instr1, comment1)
        let state3 = addInstructionWithComment(state2, instr2, comment2)

        // Keep scrutinee register for payload extraction in case bodies
        let state4 = state3

        // Allocate result register for match expression result
        switch RegisterAlloc.allocateTempRegister(state4.allocator) {
        | Error(msg) => Error(msg)
        | Ok((allocator3, resultReg)) =>
          let state5 = {...state4, allocator: allocator3}

          // Generate labels for each case and end label
          let matchEndLabel = "match_end_" ++ Int.toString(state5.labelCounter)
          let state6 = {...state5, labelCounter: state5.labelCounter + 1}

          // Generate branch instructions for each case
          let (state7, caseLabels) = Array.reduceWithIndex(cases, (state6, []), (
            (state, labels),
            matchCase,
            _idx,
          ) => {
            // Look up constructor tag
            switch Belt.Map.String.get(state.variantTags, matchCase.constructorName) {
            | None => (state, labels) // Skip unknown constructors
            | Some(tag) =>
              let caseLabel = "match_case_" ++ Int.toString(state.labelCounter)
              let newState = {...state, labelCounter: state.labelCounter + 1}
              // Generate: beq tagReg tag caseLabel
              let branchInstr =
                "beq " ++ Register.toString(tagReg) ++ " " ++ Int.toString(tag) ++ " " ++ caseLabel
              let comment = "match " ++ matchCase.constructorName
              (
                addInstructionWithComment(newState, branchInstr, comment),
                Array.concat(labels, [(caseLabel, matchCase)]),
              )
            }
          })

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

            // If case has argument bindings, extract them from stack
            let state2 = if Array.length(matchCase.argumentBindings) == 0 {
              state1
            } else {
              // Extract all argument bindings
              let rec extractArgs = (
                state: codegenState,
                bindings: array<string>,
                index: int,
              ): codegenState => {
                if index >= Array.length(bindings) {
                  state
                } else {
                  switch Belt.Array.get(bindings, index) {
                  | None => state
                  | Some(argName) =>
                    // Allocate register for argument (not a ref)
                    switch RegisterAlloc.allocateNormal(state.allocator, argName) {
                    | Error(_) => state // Fallback - allocation failed
                    | Ok((allocator, argReg)) =>
                      // Set stack pointer to payload position (base + 1 + index)
                      let offset = 1 + index
                      let instr1 =
                        "add sp " ++ Register.toString(scrutineeReg) ++ " " ++ Int.toString(offset)
                      let comment1 = "position to arg" ++ Int.toString(index)
                      let state2 = addInstructionWithComment(
                        {...state, allocator},
                        instr1,
                        comment1,
                      )

                      // Extract payload into bound variable
                      let instr2 = "peek " ++ Register.toString(argReg)
                      let comment2 = "extract " ++ argName
                      let state3 = addInstructionWithComment(state2, instr2, comment2)

                      // Extract next argument
                      extractArgs(state3, bindings, index + 1)
                    }
                  }
                }
              }

              extractArgs(state1, matchCase.argumentBindings, 0)
            }

            // Generate case body using the provided callback
            let state3 = switch generateCaseBody(state2, matchCase.body) {
            | Error(_) => state2 // Fallback - keep state if body fails
            | Ok(newState) => newState
            }

            // Jump to match end
            addInstructionWithComment(state3, "j " ++ matchEndLabel, "end case")
          })

          // Free scrutinee register after all cases processed
          let allocatorAfterScrutinee = RegisterAlloc.freeTempIfTemp(
            stateAfterCases.allocator,
            scrutineeReg,
          )
          let stateAfterScrutinee = {...stateAfterCases, allocator: allocatorAfterScrutinee}

          // Add match end label
          let stateFinal = addInstructionWithComment(
            stateAfterScrutinee,
            matchEndLabel ++ ":",
            "end match",
          )

          Ok((stateFinal, resultReg))
        }
      }
    }
  }
}

// Generate expression directly into a target register
  // More efficient when the target register is known in advance (e.g., variable declarations)
  let rec generateInto = (state: codegenState, expr: AST.expr, targetReg: Register.t): result<
    codegenState,
    string,
  > => {
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
      | Some(tag) =>
        // This is a tag-only variant constructor - generate directly into target (optimization)
        // Push tag onto stack
        let instr1 = "push " ++ Int.toString(tag)
        let comment1 = name ++ " variant tag"
        let state1 = addInstructionWithComment(state, instr1, comment1)

        // Generate directly into target register: move targetReg sp; sub targetReg targetReg 1
        let instr2 = "move " ++ Register.toString(targetReg) ++ " sp"
        let comment2 = "get stack pointer"
        let instr3 =
          "sub " ++ Register.toString(targetReg) ++ " " ++ Register.toString(targetReg) ++ " 1"
        let comment3 = "adjust to variant address"

        let state2 = addInstructionWithComment(state1, instr2, comment2)
        let state3 = addInstructionWithComment(state2, instr3, comment3)

        Ok(state3)

      | None =>
        // Check if this is a constant
        switch Belt.Map.String.get(state.defines, name) {
        | Some(CodegenTypes.NumberValue(_)) =>
          // Integer constant - load into target register
          let instr = "move " ++ Register.toString(targetReg) ++ " " ++ name
          let comment = name
          Ok(addInstructionWithComment(state, instr, comment))
        | Some(CodegenTypes.HashExpr(_)) =>
          // HASH constant - can't be used as runtime value
          Error(
            name ++ " is a HASH constant and cannot be used in arithmetic expressions. Use it only in IC10 functions like lb() or sb().",
          )
        | None =>
          // Not a constructor or constant, copy from source variable to target register (if different)
          switch RegisterAlloc.getRegister(state.allocator, name) {
          | None => Error("Variable not found: " ++ name)
          | Some(sourceReg) =>
            if sourceReg == targetReg {
              Ok(state) // Already in target register
            } else {
              let instr =
                "move " ++ Register.toString(targetReg) ++ " " ++ Register.toString(sourceReg)
              let comment = name
              Ok(addInstructionWithComment(state, instr, comment))
            }
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
      | (nonLiteral, AST.Literal(literalVal)) if op == AST.Add || op == AST.Mul =>
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

      | (AST.Literal(literalVal), nonLiteral) if op == AST.Add || op == AST.Mul =>
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
      | (nonLiteral, AST.Literal(literalVal)) if op == AST.Sub || op == AST.Div =>
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

    | AST.VariantConstructor(constructorName, arguments) =>
      // Generate variant directly into target register (optimization)
      // Look up constructor tag
      switch Belt.Map.String.get(state.variantTags, constructorName) {
      | None => Error("Unknown variant constructor: " ++ constructorName)
      | Some(tag) =>
        // Push tag onto stack
        let instr1 = "push " ++ Int.toString(tag)
        let comment1 = constructorName ++ " variant tag"
        let state1 = addInstructionWithComment(state, instr1, comment1)

        // Generate and push all arguments
        let rec pushArgs = (
          state: codegenState,
          args: array<AST.expr>,
          index: int,
        ): codegenState => {
          if index >= Array.length(args) {
            state
          } else {
            // Get argument at index
            switch Belt.Array.get(args, index) {
            | None => state // shouldn't happen
            | Some(argExpr) =>
              // Generate argument into a temporary register
              switch generate(state, argExpr) {
              | Error(_msg) => state // fallback - shouldn't happen
              | Ok((state2, argReg)) =>
                let instr = "push " ++ Register.toString(argReg)
                let comment = constructorName ++ " arg" ++ Int.toString(index)
                let state3 = addInstructionWithComment(state2, instr, comment)

                // Free temp register if it was temporary
                let allocator = RegisterAlloc.freeTempIfTemp(state3.allocator, argReg)
                let state4 = {...state3, allocator}

                // Push next argument
                pushArgs(state4, args, index + 1)
              }
            }
          }
        }

        let state2 = pushArgs(state1, arguments, 0)

        // Calculate slots used
        let slotsUsed = 1 + Array.length(arguments) // tag + arguments

        // Generate directly into target register: move targetReg sp; sub targetReg targetReg slots
        let instr3 = "move " ++ Register.toString(targetReg) ++ " sp"
        let comment3 = "get stack pointer"
        let instr4 =
          "sub " ++
          Register.toString(targetReg) ++
          " " ++
          Register.toString(targetReg) ++
          " " ++
          Int.toString(slotsUsed)
        let comment4 = "adjust to variant address"

        let state3 = addInstructionWithComment(state2, instr3, comment3)
        let state4 = addInstructionWithComment(state3, instr4, comment4)

        Ok(state4)
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

    | AST.StringLiteral(_) => Error("String literals can only be used as IC10 function arguments")
    | AST.FunctionCall(funcName, args) =>
      // For function calls, use generate then move to target if needed
      // OPTIMIZATION: Handle value-returning IC10 functions directly
      let parsedFuncName = funcName->String.split("")->List.fromArray
      Console.log2("[ExprGen generateInto] Function call parsedFuncName: ", parsedFuncName)
      switch parsedFuncName {
      | list{"l"} =>
        if Array.length(args) != 2 {
          Error("l() expects 2 arguments: device and property")
        } else {
          switch (args[0], args[1]) {
          | (Some(AST.ArgDevice(deviceName)), Some(AST.ArgString(property))) =>
            let instr = "l " ++ Register.toString(targetReg) ++ " " ++ deviceName ++ " " ++ property
            let comment = "load " ++ property
            Ok(addInstructionWithComment(state, instr, comment))
          | _ => Error("l() expects arguments: (device_identifier, \"property\")")
          }
        }
      | list{"l", "b"} =>
        // lb resultReg hash property
        // args: [ArgExpr(hash), ArgString(property), ArgMode(mode)]
        let input = (args[0], args[1], args[2])

        switch input {
        | (
            Some(AST.ArgExpr(AST.Identifier(hashName))),
            Some(AST.ArgString(property)),
            Some(AST.ArgMode(modeExpr)),
          ) =>
          // Verify hash is a define constant
          switch Belt.Map.String.get(state.defines, hashName) {
          | None => Error(hashName ++ " is not a HASH constant - use hash() to define it")
          | Some(_) =>
            // Get value - check if it's a define constant or a register variable

            let inst = `lb ${Register.toString(targetReg)} ${hashName} ${property} ${Mode.toString(
                modeExpr,
              )}`

            Ok(addInstruction(state, inst))
          }
        | _ =>
          Error(
            "lb() expects arguments: (hash_constant, \"property\", variable, mode) - hash must be a define constant, value must be a variable",
          )
        }

      | list{"l", "b", "n"} =>
        let input = (args[0], args[1], args[2], args[3])

        switch input {
        | (
            Some(AST.ArgExpr(AST.Identifier(typeHash))),
            Some(AST.ArgExpr(AST.Identifier(nameHash))),
            Some(AST.ArgString(property)),
            Some(AST.ArgMode(modeExpr)),
          ) =>
          // Verify hash is a define constant
          switch (
            Belt.Map.String.get(state.defines, typeHash),
            Belt.Map.String.get(state.defines, nameHash),
          ) {
          | (None, _)
          | (_, None) =>
            Error(`${typeHash} or ${nameHash} is not a HASH constant - use hash() to define it"`)
          | _ =>
            let regStr = Register.toString(targetReg)
            let modeStr = Mode.toString(modeExpr)
            let inst = `lbn ${regStr} ${typeHash} ${nameHash} ${property} ${modeStr}`

            Ok(addInstruction(state, inst))
          }
        | _ =>
          Error(
            "lbn() expects arguments: (hash_constant, hash_constant, \"property\", mode) - both hashes must be define constants",
          )
        }

      | list{"s"} =>
        // s device property value
        let input = (args[0], args[1], args[2])

        switch input {
        | (
            Some(AST.ArgDevice(deviceName)),
            Some(AST.ArgString(property)),
            Some(AST.ArgExpr(valueExpr)),
          ) =>
          switch valueExpr {
          | AST.Literal(value) =>
            let inst = `s ${deviceName} ${property} ${Int.toString(value)}`
            Ok(addInstruction(state, inst))
          | AST.Identifier(valueName) =>
            Utils.getDefineOrRegister(state, valueName)
            ->Result.map(valueStr => `s ${deviceName} ${property} ${valueStr}`)
            ->Result.map(addInstruction(state, _))
          | _ =>
            // For complex expressions, generate into a temp register first
            switch generate(state, valueExpr) {
            | Error(msg) => Error(msg)
            | Ok((state1, valueReg)) =>
              let inst = `s ${deviceName} ${property} ${Register.toString(valueReg)}`
              let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, valueReg)
              Ok(addInstruction({...state1, allocator}, inst))
            }
          }
        | _ => Error("s() expects arguments: (device_identifier, \"property\", value)")
        }

      | list{"s", "b"} =>
        // sb hash property value mode
        let input = (args[0], args[1], args[2], args[3])

        switch input {
        | (
            Some(AST.ArgExpr(AST.Identifier(hashName))),
            Some(AST.ArgString(property)),
            Some(AST.ArgExpr(AST.Identifier(valueName))),
            Some(AST.ArgMode(modeExpr)),
          ) =>
          // Verify hash is a define constant
          switch Belt.Map.String.get(state.defines, hashName) {
          | None => Error(hashName ++ " is not a HASH constant - use hash() to define it")
          | Some(_) =>
            let modeStr = Mode.toString(modeExpr)
            Utils.getDefineOrRegister(state, valueName)
            ->Result.map(valueStr => `sb ${hashName} ${property} ${valueStr} ${modeStr}`)
            ->Result.map(addInstruction(state, _))
          }
        | _ =>
          Error(
            "sb() expects arguments: (hash_constant, \"property\", variable, mode) - hash must be a define constant, value must be a variable",
          )
        }

      | list{"s", "b", "n"} =>
        // sbn HASH("type") HASH("name") property value
        let input = (args[0], args[1], args[2], args[3])

        switch input {
        | (
            Some(AST.ArgExpr(AST.Identifier(typeHash))),
            Some(AST.ArgExpr(AST.Identifier(nameHash))),
            Some(AST.ArgString(property)),
            Some(AST.ArgExpr(valueExpr)),
          ) =>
          // Verify hashes are define constants
          switch (
            Belt.Map.String.get(state.defines, typeHash),
            Belt.Map.String.get(state.defines, nameHash),
          ) {
          | (None, _)
          | (_, None) =>
            Error(`${typeHash} or ${nameHash} is not a HASH constant - use hash() to define it"`)
          | _ =>
            switch valueExpr {
            | AST.Literal(value) =>
              let inst = `sbn ${typeHash} ${nameHash} ${property} ${Int.toString(value)}`
              Ok(addInstruction(state, inst))
            | AST.Identifier(valueName) =>
              Utils.getDefineOrRegister(state, valueName)
              ->Result.map(valueStr => `sbn ${typeHash} ${nameHash} ${property} ${valueStr}`)
              ->Result.map(addInstruction(state, _))
            | _ =>
              // For complex expressions, generate into a temp register first
              switch generate(state, valueExpr) {
              | Error(msg) => Error(msg)
              | Ok((state1, valueReg)) =>
                let inst = `sbn ${typeHash} ${nameHash} ${property} ${Register.toString(valueReg)}`
                let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, valueReg)
                Ok(addInstruction({...state1, allocator}, inst))
              }
            }
          }
        | _ =>
          Error(
            "sbn() expects arguments: (hash_constant, hash_constant, \"property\", value) - both hashes must be define constants",
          )
        }

      | _ =>
        // Fallback for other functions
        switch generate(state, expr) {
        | Error(msg) => Error(msg)
        | Ok((state1, resultReg)) =>
          if resultReg == targetReg {
            Ok(state1)
          } else {
            let instr =
              "move " ++ Register.toString(targetReg) ++ " " ++ Register.toString(resultReg)
            let allocator = RegisterAlloc.freeTempIfTemp(state1.allocator, resultReg)
            Ok(addInstruction({...state1, allocator}, instr))
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
