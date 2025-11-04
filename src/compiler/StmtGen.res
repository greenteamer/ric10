// StmtGen - Statement code generation
// Orchestrates expression and branch generation for statements

// Type alias for codegen state (shared with other modules)
type codegenState = CodegenTypes.codegenState

// Add an instruction with a comment (conditional based on options)
let addInstructionWithComment = (state: codegenState, instruction: string, comment: string): codegenState => {
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

// Generate IC10 code for a statement
let rec generate = (state: codegenState, stmt: AST.astNode): result<codegenState, string> => {
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

  | AST.VariableDeclaration(name, expr) =>
    // Check if this is a ref declaration
    switch expr {
    | AST.RefCreation(valueExpr) =>
      // Allocate register for ref variable
      switch RegisterAlloc.allocateRef(state.allocator, name) {
      | Error(msg) => Error(msg)
      | Ok((allocator, refReg)) =>
        let state1 = {...state, allocator}
        // Generate the initial value directly into the ref register
        switch ExprGen.generateInto(state1, valueExpr, refReg) {
        | Error(msg) => Error(msg)
        | Ok(newState) => Ok(newState)
        }
      }
    | _ =>
      // Normal variable (not a ref)
      switch RegisterAlloc.allocateNormal(state.allocator, name) {
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

  | AST.BinaryExpression(op, left, right) =>
    // Standalone expression - generate it
    switch ExprGen.generate(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }

  | AST.IfStatement(condition, thenBlock, elseBlock) =>
    // Check if condition is a simple comparison for direct branching
    switch condition {
    | AST.BinaryExpression(op, left, right) =>
      // Try direct branching optimization
      switch (op, left, right) {
      | (AST.Lt | AST.Gt | AST.Eq, leftExpr, AST.Literal(rightVal)) =>
        // Variable-to-literal comparison
        switch ExprGen.generate(state, leftExpr) {
        | Error(msg) => Error(msg)
        | Ok((state1, leftReg)) =>
          let rightValue = Int.toString(rightVal)

          switch elseBlock {
          | None =>
            // If-only statement
            BranchGen.generateIfOnly(
              state1,
              op,
              leftReg,
              rightValue,
              s => generateBlock(s, thenBlock),
            )
          | Some(elseStatements) =>
            // If-else statement
            BranchGen.generateIfElse(
              state1,
              op,
              leftReg,
              rightValue,
              s => generateBlock(s, thenBlock),
              s => generateBlock(s, elseStatements),
            )
          }
        }

      | (AST.Lt | AST.Gt | AST.Eq, leftExpr, rightExpr) =>
        // Variable-to-variable comparison
        switch ExprGen.generate(state, leftExpr) {
        | Error(msg) => Error(msg)
        | Ok((state1, leftReg)) =>
          switch ExprGen.generate(state1, rightExpr) {
          | Error(msg) => Error(msg)
          | Ok((state2, rightReg)) =>
            let rightValue = Register.toString(rightReg)

            // Free temporary registers before branching
            let allocator = RegisterAlloc.freeTempIfTemp(
              RegisterAlloc.freeTempIfTemp(state2.allocator, leftReg),
              rightReg,
            )
            let state3 = {...state2, allocator}

            switch elseBlock {
            | None =>
              // If-only statement
              BranchGen.generateIfOnly(
                state3,
                op,
                leftReg,
                rightValue,
                s => generateBlock(s, thenBlock),
              )
            | Some(elseStatements) =>
              // If-else statement
              BranchGen.generateIfElse(
                state3,
                op,
                leftReg,
                rightValue,
                s => generateBlock(s, thenBlock),
                s => generateBlock(s, elseStatements),
              )
            }
          }
        }

      | _ =>
        // Non-comparison binary expression - use fallback
        generateIfWithCondition(state, condition, thenBlock, elseBlock)
      }

    | _ =>
      // Non-binary-expression condition - use fallback
      generateIfWithCondition(state, condition, thenBlock, elseBlock)
    }

  | AST.WhileLoop(condition, body) =>
    // Optimize binary comparisons to use direct branch instructions
    switch condition {
    | AST.BinaryExpression(op, leftExpr, rightExpr) =>
      switch (op, leftExpr, rightExpr) {
      | (AST.Lt | AST.Gt | AST.Eq, leftExpr, AST.Literal(rightValue)) =>
        // Comparison with literal on right
        BranchGen.generateWhileLoop(
          state,
          op,
          Int.toString(rightValue),
          s =>
            // Allocate a temporary register for the comparison
            switch RegisterAlloc.allocateTempRegister(s.allocator) {
            | Error(msg) => Error(msg)
            | Ok((allocator1, tempReg)) =>
              let state1 = {...s, allocator: allocator1}
              // Generate left expression into the temp register
              switch ExprGen.generateInto(state1, leftExpr, tempReg) {
              | Error(msg) => Error(msg)
              | Ok(state2) =>
                // Free the temp register after use
                let allocator3 = RegisterAlloc.freeTempRegister(state2.allocator, tempReg)
                Ok(({...state2, allocator: allocator3}, tempReg))
              }
            },
          s => generateBlock(s, body),
        )

      | (AST.Lt | AST.Gt | AST.Eq, AST.Literal(leftValue), rightExpr) =>
        // Comparison with literal on left - swap to have literal on right
        let swappedOp = switch op {
        | AST.Lt => AST.Gt // x < y becomes y > x
        | AST.Gt => AST.Lt // x > y becomes y < x
        | AST.Eq => AST.Eq // x == y becomes y == x
        | _ => op
        }
        BranchGen.generateWhileLoop(
          state,
          swappedOp,
          Int.toString(leftValue),
          s =>
            // Allocate a temporary register for the comparison
            switch RegisterAlloc.allocateTempRegister(s.allocator) {
            | Error(msg) => Error(msg)
            | Ok((allocator1, tempReg)) =>
              let state1 = {...s, allocator: allocator1}
              // Generate right expression into the temp register
              switch ExprGen.generateInto(state1, rightExpr, tempReg) {
              | Error(msg) => Error(msg)
              | Ok(state2) =>
                // Free the temp register after use
                let allocator3 = RegisterAlloc.freeTempRegister(state2.allocator, tempReg)
                Ok(({...state2, allocator: allocator3}, tempReg))
              }
            },
          s => generateBlock(s, body),
        )

      | (AST.Lt | AST.Gt | AST.Eq, leftExpr, rightExpr) =>
        // Variable-to-variable comparison - use fallback for now
        generateWhileWithCondition(state, condition, body)

      | _ =>
        // Non-comparison binary expression - use fallback
        generateWhileWithCondition(state, condition, body)
      }

    | _ =>
      // Non-binary-expression condition - use fallback
      generateWhileWithCondition(state, condition, body)
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

  | AST.SwitchExpression(_, _) =>
    // Standalone switch expression - generate it
    switch ExprGen.generate(state, stmt) {
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
      // Generate the new value directly into the ref register
      switch ExprGen.generateInto(state, valueExpr, refReg) {
      | Error(msg) => Error(msg)
      | Ok(newState) => Ok(newState)
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
  }
}

// Generate if statement with fallback method (evaluate condition to register)
and generateIfWithCondition = (
  state: codegenState,
  condition: AST.expr,
  thenBlock: AST.blockStatement,
  elseBlock: option<AST.blockStatement>,
): result<codegenState, string> => {
  switch ExprGen.generate(state, condition) {
  | Error(msg) => Error(msg)
  | Ok((state1, condReg)) =>
    let generateElse = switch elseBlock {
    | Some(statements) => Some(s => generateBlock(s, statements))
    | None => None
    }

    BranchGen.generateIfWithConditionReg(
      state1,
      condReg,
      s => generateBlock(s, thenBlock),
      generateElse,
    )
  }
}

// Generate while loop with fallback method (evaluate condition to register)
and generateWhileWithCondition = (
  state: codegenState,
  condition: AST.expr,
  body: AST.blockStatement,
): result<codegenState, string> => {
  BranchGen.generateWhileLoopWithConditionReg(
    state,
    s => ExprGen.generate(s, condition),
    s => generateBlock(s, body),
  )
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
