// StmtGen - Statement code generation
// Orchestrates expression and branch generation for statements

// Type alias for codegen state (shared with other modules)
type codegenState = CodegenTypes.codegenState

// Add an instruction with a comment (conditional based on options)
let addInstructionWithComment = (
  state: codegenState,
  instruction: string,
  comment: string,
): codegenState => {
  let fullInstruction = if state.options.includeComments {
    instruction ++ "  # " ++ comment
  } else {
    instruction
  }
  let len = Array.length(state.instructions)
  let newInstructions = Array.make(~length=len + 1, "")
  for i in 0 to len - 1 {
    switch state.instructions[i] {
    | Some(v) => newInstructions[i] = v
    | None => ()
    }
  }
  newInstructions[len] = fullInstruction
  {...state, instructions: newInstructions}
}

// Helper: Calculate maximum arguments across all constructors in a variant type
let getMaxArgsForVariantType = (constructors: array<AST.variantConstructor>): int => {
  Array.reduce(constructors, 0, (maxArgs, constructor) => {
    if constructor.argCount > maxArgs {
      constructor.argCount
    } else {
      maxArgs
    }
  })
}

// Helper: Get variant type name from constructor name
let getVariantTypeName = (state: codegenState, constructorName: string): option<string> => {
  // Search through variantTypes to find which type contains this constructor
  Belt.Map.String.findFirstBy(state.variantTypes, (_typeName, constructors) => {
    Array.some(constructors, constructor => constructor.name == constructorName)
  })->Option.map(((typeName, _)) => typeName)
}

// Generate IC10 code for a statement
let rec generate = (state: codegenState, stmt: AST.astNode): result<codegenState, string> => {
  Console.log2("[StmtGen] Generating statement: ", stmt)
  switch stmt {
  | AST.TypeDeclaration(typeName, constructors) =>
    // Type declarations are compile-time only - populate variant maps
    let rec buildVariantTags = (
      tags: Belt.Map.String.t<int>,
      constructors: array<AST.variantConstructor>,
      index: int,
    ): Belt.Map.String.t<int> => {
      if index >= Array.length(constructors) {
        tags
      } else {
        switch constructors[index] {
        | Some(constructor) =>
          let newTags = Belt.Map.String.set(tags, constructor.name, index)
          buildVariantTags(newTags, constructors, index + 1)
        | None => buildVariantTags(tags, constructors, index + 1)
        }
      }
    }

    let newVariantTags = buildVariantTags(state.variantTags, constructors, 0)
    let newVariantTypes = Belt.Map.String.set(state.variantTypes, typeName, constructors)

    Ok({...state, variantTags: newVariantTags, variantTypes: newVariantTypes})

  | AST.VariableDeclaration(varName, expr) =>
    // Check if this is a constant (literal or HASH)
    switch expr {
    | AST.Literal(value) =>
      // Integer constant - add to defines
      let defineValue = CodegenTypes.NumberValue(value)
      let newDefines = Belt.Map.String.set(state.defines, varName, defineValue)
      let newDefineOrder = Array.concat(state.defineOrder, [(varName, defineValue)])
      Ok({...state, defines: newDefines, defineOrder: newDefineOrder})

    | AST.FunctionCall("hash", args) =>
      // HASH constant - add to defines
      if Array.length(args) != 1 {
        Error("hash() expects 1 argument: string")
      } else {
        switch args[0] {
        | Some(AST.ArgString(str)) =>
          let defineValue = CodegenTypes.HashExpr(str)
          let newDefines = Belt.Map.String.set(state.defines, varName, defineValue)
          let newDefineOrder = Array.concat(state.defineOrder, [(varName, defineValue)])
          Ok({...state, defines: newDefines, defineOrder: newDefineOrder})
        | _ => Error("hash() expects a string argument")
        }
      }

    | AST.RefCreation(valueExpr) =>
      // Mutable ref variable - allocate register
      switch RegisterAlloc.allocateRef(state.allocator, varName) {
      | Error(msg) => Error(msg)
      | Ok((allocator, refReg)) =>
        let state1 = {...state, allocator}

        // Check if this is a variant constructor - use fixed stack layout
        switch valueExpr {
        | AST.Identifier(name) =>
          // Check if this identifier is a zero-arg variant constructor
          switch getVariantTypeName(state1, name) {
          | Some(typeName) =>
            // This is a zero-arg variant constructor - treat like VariantConstructor with no args
            let constructorName = name
            let arguments = []

            // Continue with variant ref creation logic
            switch Belt.Map.String.get(state1.variantTypes, typeName) {
            | None => Error("Variant type not found: " ++ typeName)
            | Some(constructors) =>
              let maxArgs = getMaxArgsForVariantType(constructors)
              let numConstructors = Array.length(constructors)

              // Get the tag for this constructor
              switch Belt.Map.String.get(state1.variantTags, constructorName) {
              | None => Error("Constructor tag not found: " ++ constructorName)
              | Some(tag) =>
                // Step 1: Push tag
                let state2 = addInstructionWithComment(
                  state1,
                  "push " ++ Int.toString(tag),
                  "variant tag (" ++ constructorName ++ ")",
                )

                // Step 2: Push all slots (all placeholders for zero-arg constructor)
                let rec pushSlots = (state: codegenState, slotIndex: int): result<
                  codegenState,
                  string,
                > => {
                  if slotIndex >= numConstructors * maxArgs {
                    Ok(state)
                  } else {
                    let state3 = addInstructionWithComment(
                      state,
                      "push 0",
                      "placeholder slot " ++ Int.toString(slotIndex),
                    )
                    pushSlots(state3, slotIndex + 1)
                  }
                }

                switch pushSlots(state2, 0) {
                | Error(msg) => Error(msg)
                | Ok(state3) =>
                  // Step 3: Set ref register to point to stack[0]
                  let state4 = addInstructionWithComment(
                    state3,
                    "move " ++ Register.toString(refReg) ++ " 0",
                    "ref points to stack[0]",
                  )

                  // Track that this ref holds this variant type
                  let newVariantRefTypes = Belt.Map.String.set(
                    state4.variantRefTypes,
                    varName,
                    typeName,
                  )

                  Ok({...state4, variantRefTypes: newVariantRefTypes})
                }
              }
            }

          | None =>
            // Not a variant constructor - error
            Error(
              "Cannot assign identifier to variable. Use 'let x = ref(y)' for mutable copy, or use constants (let x = 500 or let x = HASH(\"...\")).",
            )
          }

        | AST.VariantConstructor(constructorName, arguments) =>
          // This is a variant ref - use fixed stack layout
          switch getVariantTypeName(state1, constructorName) {
          | None => Error("Unknown variant constructor: " ++ constructorName)
          | Some(typeName) =>
            // Look up the full type definition
            switch Belt.Map.String.get(state1.variantTypes, typeName) {
            | None => Error("Variant type not found: " ++ typeName)
            | Some(constructors) =>
              let maxArgs = getMaxArgsForVariantType(constructors)
              let numConstructors = Array.length(constructors)
              let totalSlots = 1 + numConstructors * maxArgs // tag + (N * M)

              // Get the tag for this constructor
              switch Belt.Map.String.get(state1.variantTags, constructorName) {
              | None => Error("Constructor tag not found: " ++ constructorName)
              | Some(tag) =>
                // Step 1: Push tag
                let state2 = addInstructionWithComment(
                  state1,
                  "push " ++ Int.toString(tag),
                  "variant tag (" ++ constructorName ++ ")",
                )

                // Step 2: Push all slots (initialized or placeholder)
                let rec pushSlots = (state: codegenState, slotIndex: int): result<
                  codegenState,
                  string,
                > => {
                  if slotIndex >= numConstructors * maxArgs {
                    Ok(state)
                  } else {
                    // Calculate which constructor and arg this slot belongs to
                    let constructorIndex = slotIndex / maxArgs
                    let argIndex = mod(slotIndex, maxArgs)

                    // Check if this is the active constructor's argument
                    if constructorIndex == tag && argIndex < Array.length(arguments) {
                      // Generate the actual argument value
                      switch Belt.Array.get(arguments, argIndex) {
                      | None => pushSlots(state, slotIndex + 1) // shouldn't happen
                      | Some(argExpr) =>
                        // Generate argument value into temp register
                        switch ExprGen.generate(state, argExpr) {
                        | Error(msg) => Error(msg)
                        | Ok((state3, argReg)) =>
                          let state4 = addInstructionWithComment(
                            state3,
                            "push " ++ Register.toString(argReg),
                            constructorName ++ " arg" ++ Int.toString(argIndex),
                          )
                          // Free temp register
                          let allocator = RegisterAlloc.freeTempIfTemp(state4.allocator, argReg)
                          pushSlots({...state4, allocator}, slotIndex + 1)
                        }
                      }
                    } else {
                      // Placeholder slot (not used by active constructor)
                      let state3 = addInstructionWithComment(
                        state,
                        "push 0",
                        "placeholder slot " ++ Int.toString(slotIndex),
                      )
                      pushSlots(state3, slotIndex + 1)
                    }
                  }
                }

                switch pushSlots(state2, 0) {
                | Error(msg) => Error(msg)
                | Ok(state3) =>
                  // Step 3: Set ref register to point to stack[0] (always 0)
                  let state4 = addInstructionWithComment(
                    state3,
                    "move " ++ Register.toString(refReg) ++ " 0",
                    "ref points to stack[0]",
                  )

                  // Track that this ref holds this variant type
                  let newVariantRefTypes = Belt.Map.String.set(
                    state4.variantRefTypes,
                    varName,
                    typeName,
                  )

                  Ok({...state4, variantRefTypes: newVariantRefTypes})
                }
              }
            }
          }

        | _ =>
          // Not a variant - use old approach
          switch ExprGen.generateInto(state1, valueExpr, refReg) {
          | Error(msg) => Error(msg)
          | Ok(newState) => Ok(newState)
          }
        }
      }

    | AST.Identifier(_) =>
      // Disallow let x = y pattern (too confusing - use ref or constants)
      Error(
        "Cannot assign identifier to variable. Use 'let x = ref(y)' for mutable copy, or use constants (let x = 500 or let x = HASH(\"...\")).",
      )

    | AST.SwitchExpression(scrutinee, cases) =>
      // Switch expression in variable declaration
      switch RegisterAlloc.allocateNormal(state.allocator, varName) {
      | Error(msg) => Error(msg)
      | Ok((allocator, varReg)) =>
        let state1 = {...state, allocator}
        // Generate switch with body callback, then move result to variable register
        switch ExprGen.generateSwitchWithBody(state1, scrutinee, cases, generateBlock) {
        | Error(msg) => Error(msg)
        | Ok((state2, resultReg)) =>
          if resultReg == varReg {
            Ok(state2)
          } else {
            // Move result to variable register
            let instr = "move " ++ Register.toString(varReg) ++ " " ++ Register.toString(resultReg)
            let allocator = RegisterAlloc.freeTempIfTemp(state2.allocator, resultReg)
            let len = Array.length(state2.instructions)
            let newInstructions = Array.make(~length=len + 1, "")
            for i in 0 to len - 1 {
              switch state2.instructions[i] {
              | Some(v) => newInstructions[i] = v
              | None => ()
              }
            }
            newInstructions[len] = instr
            Ok({...state2, allocator, instructions: newInstructions})
          }
        }
      }

    | _ =>
      // Normal variable (not a constant or ref) - allocate register
      switch RegisterAlloc.allocateNormal(state.allocator, varName) {
      | Error(msg) => Error(msg)
      | Ok((allocator, varReg)) =>
        let state1 = {...state, allocator}
        // Generate expression directly into the variable's register
        switch ExprGen.generateInto(state1, expr, varReg) {
        | Error(msg) => Error(msg)
        | Ok(newState) => Ok(newState)
        }
      }
    }

  | AST.BinaryExpression(_op, _left, _right) =>
    // Standalone expression - generate it
    switch ExprGen.generate(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }

  | AST.IfStatement(condition, thenBlock, elseBlock) =>
    switch condition {
    | AST.BinaryExpression(op, left, right) =>
      switch op {
      | AST.Lt | AST.Gt | AST.Eq =>
        switch elseBlock {
        | None =>
          // If-only statement
          BranchGen.generateIfOnly(state, op, left, right, s => generateBlock(s, thenBlock))

        | Some(elseStatements) =>
          // If-else statement
          BranchGen.generateIfElse(
            state,
            op,
            left,
            right,
            s => generateBlock(s, thenBlock),
            s => generateBlock(s, elseStatements),
          )
        }

      | _ =>
        // Non-comparison binary expression - use fallback
        Error("[ExprGen] Non-comparison binary expression in if statement")
      }

    | _ =>
      // Non-binary-expression condition - use fallback
      Error("[ExprGen] Non-binary-expression condition in if statement")
    }

  | AST.WhileLoop(condition, body) =>
    // Handle while true (infinite loop)
    switch condition {
    | AST.LiteralBool(true) =>
      // Infinite loop: while true { body }
      BranchGen.generateWhileMainLoopReg(state, s => generateBlock(s, body))

    | AST.BinaryExpression(op, leftExpr, rightExpr) =>
      switch (op, leftExpr, rightExpr) {
      | (AST.Lt | AST.Gt | AST.Eq, _leftExpr, _rightExpr) =>
        // Comparison with literal on right
        BranchGen.generateWhileLoop(state, op, _leftExpr, _rightExpr, s => generateBlock(s, body))

      | _ =>
        // Non-comparison binary expression - use fallback
        Error("[StmtGen] Non-comparison binary expression in while loop")
      }

    | _ =>
      // Non-binary-expression condition - use fallback
      Error(
        "[StmtGen] Unsupported while loop condition - use 'while true' for infinite loops or comparison expressions",
      )
    }

  | AST.BlockStatement(statements) => generateBlock(state, statements)

  | AST.Literal(_) =>
    // Standalone literal - generate it
    switch ExprGen.generate(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }

  | AST.Identifier(_) =>
    // Standalone identifier - generate it
    switch ExprGen.generate(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }

  | AST.VariantConstructor(_, _) =>
    // Standalone variant constructor - generate it
    switch ExprGen.generate(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }

  | AST.SwitchExpression(scrutinee, cases) =>
    // Standalone switch expression - generate it with body callback
    switch ExprGen.generateSwitchWithBody(state, scrutinee, cases, generateBlock) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }

  | AST.RefCreation(_) =>
    // Standalone ref creation - generate it
    switch ExprGen.generate(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }

  | AST.RefAccess(_) =>
    // Standalone ref access - generate it
    switch ExprGen.generate(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }

  | AST.RefAssignment(refName, valueExpr) =>
    // Verify ref exists and is actually a ref
    switch RegisterAlloc.getVariableInfo(state.allocator, refName) {
    | None => Error("Undefined variable: " ++ refName)
    | Some({register: _, isRef: false}) =>
      Error(refName ++ " is not a ref - cannot use := operator")
    | Some({register: refReg, isRef: true}) =>
      // Check if this is a variant ref
      switch Belt.Map.String.get(state.variantRefTypes, refName) {
      | Some(typeName) =>
        // This is a variant ref - use poke instructions
        switch valueExpr {
        | AST.Identifier(name) =>
          // Check if this is a zero-arg variant constructor
          switch Belt.Map.String.get(state.variantTags, name) {
          | Some(tag) =>
            // Zero-arg variant constructor - just poke the tag
            let state1 = addInstructionWithComment(
              state,
              "poke 0 " ++ Int.toString(tag),
              "set tag to " ++ name,
            )
            Ok(state1)

          | None => Error("Unknown variant constructor: " ++ name)
          }

        | AST.VariantConstructor(constructorName, arguments) =>
          // Get variant type info
          switch Belt.Map.String.get(state.variantTypes, typeName) {
          | None => Error("Variant type not found: " ++ typeName)
          | Some(constructors) =>
            let maxArgs = getMaxArgsForVariantType(constructors)

            // Get the tag for this constructor
            switch Belt.Map.String.get(state.variantTags, constructorName) {
            | None => Error("Constructor tag not found: " ++ constructorName)
            | Some(tag) =>
              // Step 1: Poke the tag to stack[0]
              let state1 = addInstructionWithComment(
                state,
                "poke 0 " ++ Int.toString(tag),
                "set tag to " ++ constructorName,
              )

              // Step 2: Poke all arguments to their slots
              let rec pokeArgs = (state: codegenState, argIndex: int): result<
                codegenState,
                string,
              > => {
                if argIndex >= Array.length(arguments) {
                  Ok(state)
                } else {
                  switch Belt.Array.get(arguments, argIndex) {
                  | None => pokeArgs(state, argIndex + 1)
                  | Some(argExpr) =>
                    // Generate the argument value into a temp register
                    switch ExprGen.generate(state, argExpr) {
                    | Error(msg) => Error(msg)
                    | Ok((state2, argReg)) =>
                      // Calculate the address: tag * maxArgs + 1 + argIndex
                      let address = tag * maxArgs + 1 + argIndex
                      let state3 = addInstructionWithComment(
                        state2,
                        "poke " ++ Int.toString(address) ++ " " ++ Register.toString(argReg),
                        constructorName ++ " arg" ++ Int.toString(argIndex),
                      )

                      // Free temp register
                      let allocator = RegisterAlloc.freeTempIfTemp(state3.allocator, argReg)
                      pokeArgs({...state3, allocator}, argIndex + 1)
                    }
                  }
                }
              }

              pokeArgs(state1, 0)
            }
          }

        | _ => Error("Variant ref can only be assigned variant constructors")
        }

      | None =>
        // Not a variant ref - use old approach
        switch ExprGen.generateInto(state, valueExpr, refReg) {
        | Error(msg) => Error(msg)
        | Ok(newState) => Ok(newState)
        }
      }
    }

  | AST.RawInstruction(instruction) =>
    // Emit raw IC10 assembly instruction directly
    let len = Array.length(state.instructions)
    let newInstructions = Array.make(~length=len + 1, "")
    for i in 0 to len - 1 {
      switch state.instructions[i] {
      | Some(v) => newInstructions[i] = v
      | None => ()
      }
    }
    newInstructions[len] = instruction
    Ok({...state, instructions: newInstructions})

  | AST.LiteralStr(_) => Error("String literals cannot be used as standalone statements")
  | AST.LiteralBool(_) => Error("Boolean literals cannot be used as standalone statements")

  | AST.FunctionCall(_, _) =>
    // Function calls as statements (e.g., IC10.s(d0, "Setting", 1))
    switch ExprGen.generate(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, reg)) =>
      // Discard result register (function was called for side effects)
      // and free it if it's temporary.
      let allocator = RegisterAlloc.freeTempIfTemp(newState.allocator, reg)
      Ok({...newState, allocator})
    }
  }
}

// Generate while loop with fallback method (evaluate condition to register)
and generateWhileMainLoop = (
  state: codegenState,
  _condition: AST.expr,
  body: AST.blockStatement,
): result<codegenState, string> => {
  Console.log("[StmtGen] generateWhileMainLoop called")
  BranchGen.generateWhileMainLoopReg(state, s => generateBlock(s, body))
}

// Generate IC10 code for a block of statements
and generateBlock = (state: codegenState, statements: AST.blockStatement): result<
  codegenState,
  string,
> => {
  let rec loop = (state: codegenState, i: int): result<codegenState, string> => {
    if i >= Array.length(statements) {
      Ok(state)
    } else {
      switch statements[i] {
      | Some(stmt) =>
        switch generate(state, stmt) {
        | Error(msg) => Error(msg)
        | Ok(newState) => loop(newState, i + 1)
        }
      | None => Ok(state)
      }
    }
  }
  loop(state, 0)
}
