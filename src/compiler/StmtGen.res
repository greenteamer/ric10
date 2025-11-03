// StmtGen - Statement code generation
// Orchestrates expression and branch generation for statements

// Type alias for codegen state (shared with other modules)
type codegenState = CodegenTypes.codegenState

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
    // Allocate register for the variable
    switch RegisterAlloc.allocate(state.allocator, name) {
    | Error(msg) => Error(msg)
    | Ok((allocator, varReg)) =>
      let state1 = {...state, allocator}
      // Generate expression directly into the variable's register
      switch ExprGen.generateInto(state1, expr, varReg) {
      | Error(msg) => Error(msg)
      | Ok(newState) => Ok(newState)
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

  | AST.MatchExpression(_, _) =>
    // Standalone match expression - generate it
    switch ExprGen.generate(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }
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
