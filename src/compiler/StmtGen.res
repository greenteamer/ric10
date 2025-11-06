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
    // Check if this is a constant (literal or HASH)
    switch expr {
    | AST.Literal(value) =>
      // Integer constant - add to defines
      let defineValue = CodegenTypes.NumberValue(value)
      let newDefines = Belt.Map.String.set(state.defines, name, defineValue)
      let newDefineOrder = Array.concat(state.defineOrder, [(name, defineValue)])
      Ok({...state, defines: newDefines, defineOrder: newDefineOrder})

    | AST.FunctionCall("hash", args) =>
      // HASH constant - add to defines
      if Array.length(args) != 1 {
        Error("hash() expects 1 argument: string")
      } else {
        switch args[0] {
        | Some(AST.ArgString(str)) =>
          let defineValue = CodegenTypes.HashExpr(str)
          let newDefines = Belt.Map.String.set(state.defines, name, defineValue)
          let newDefineOrder = Array.concat(state.defineOrder, [(name, defineValue)])
          Ok({...state, defines: newDefines, defineOrder: newDefineOrder})
        | _ => Error("hash() expects a string argument")
        }
      }

    | AST.RefCreation(valueExpr) =>
      // Mutable ref variable - allocate register
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

    | AST.Identifier(_) =>
      // Disallow let x = y pattern (too confusing - use ref or constants)
      Error(
        "Cannot assign identifier to variable. Use 'let x = ref(y)' for mutable copy, or use constants (let x = 500 or let x = HASH(\"...\")).",
      )

    | _ =>
      // Normal variable (not a constant or ref) - allocate register
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
    // Optimize binary comparisons to use direct branch instructions
    switch condition {
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
      Console.log("[StmtGen] Non-binary-expression condition in while loop - using fallback")
      BranchGen.generateWhileMainLoopReg(state, s => generateBlock(s, body)) // s => ExprGen.generate(s, condition),
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

  | AST.StringLiteral(_) => Error("String literals cannot be used as standalone statements")

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
