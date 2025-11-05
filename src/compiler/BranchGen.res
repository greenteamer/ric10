// BranchGen - Branch instruction generation for if/else statements
// Eliminates code duplication by providing reusable branching logic

// Type alias for codegen state (shared with other modules)
type codegenState = CodegenTypes.codegenState

module Utils = {
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

  // Generate a unique label
  let generateLabel = (state: codegenState): (codegenState, string) => {
    let label = "label" ++ Int.toString(state.labelCounter)
    let newState = {...state, labelCounter: state.labelCounter + 1}
    (newState, label)
  }

  let binaryOperandsToString = (state: codegenState, left, right) => {
    // Helper: Get string representation of an operand (constant or register)
    let operandToString = (state: codegenState, expr) => {
      switch expr {
      | AST.Literal(val) => Ok((state, Int.toString(val)))
      | AST.Identifier(name) =>
        // Check if it's a constant
        switch Belt.Map.String.get(state.defines, name) {
        | Some(_) => Ok((state, name))
        | None =>
          // It's a variable - generate it
          switch ExprGen.generate(state, expr) {
          | Error(msg) => Error(msg)
          | Ok((s, reg)) => Ok((s, Register.toString(reg)))
          }
        }
      | _ =>
        // Complex expression - generate it
        switch ExprGen.generate(state, expr) {
        | Error(msg) => Error(msg)
        | Ok((s, reg)) => Ok((s, Register.toString(reg)))
        }
      }
    }

    operandToString(state, left)->Result.flatMap(((s1, leftVal)) =>
      operandToString(s1, right)->Result.map(((s2, rightVal)) => (s2, leftVal, rightVal))
    )
  }

  // Generate direct branch instruction for binary comparison
  // Jumps to label when condition is TRUE
  let generateDirectBranch = (
    op: AST.binaryOp,
    leftValue: string,
    rightValue: string,
    label: string,
  ): string => {
    switch op {
    | AST.Lt => "blt " ++ leftValue ++ " " ++ rightValue ++ " " ++ label
    | AST.Gt => "bgt " ++ leftValue ++ " " ++ rightValue ++ " " ++ label
    | AST.Eq => "beq " ++ leftValue ++ " " ++ rightValue ++ " " ++ label
    | _ => "" // Not a comparison operator
    }
  }

  // Generate inverted branch instruction for binary comparison
  // Jumps to label when condition is FALSE
  let generateInvertedBranch = (
    op: AST.binaryOp,
    leftValue: string,
    rightValue: string,
    label: string,
  ): string => {
    switch op {
    | AST.Lt => "bge " ++ leftValue ++ " " ++ rightValue ++ " " ++ label // >= (not <)
    | AST.Gt => "ble " ++ leftValue ++ " " ++ rightValue ++ " " ++ label // <= (not >)
    | AST.Eq => "bne " ++ leftValue ++ " " ++ rightValue ++ " " ++ label // != (not ==)
    | _ => "" // Not a comparison operator
    }
  }
}

// Generate if-only statement (no else block)
// Strategy: Use inverted branch to skip then block when condition is FALSE
let generateIfOnly = (
  state: codegenState,
  op: AST.binaryOp,
  leftExpr: AST.expr,
  rightExpr: AST.expr,
  generateThenBlock: codegenState => result<codegenState, string>,
): result<codegenState, string> => {
  // Generate end label
  let (state1, endLabel) = Utils.generateLabel(state)

  Utils.binaryOperandsToString(state1, leftExpr, rightExpr)
  ->Result.map(((newState, leftValue, rightValue)) => {
    // Branch to then block when condition is TRUE
    let branchInstr = Utils.generateInvertedBranch(op, leftValue, rightValue, endLabel)
    Utils.addInstruction(newState, branchInstr)
  })
  ->Result.flatMap(generateThenBlock)
  ->Result.map(s => Utils.addInstruction(s, endLabel ++ ":"))
}

// Generate if-else statement
// Strategy: Branch to then label when TRUE, else block falls through, jump to end after else
let generateIfElse = (
  state: codegenState,
  op: AST.binaryOp,
  leftExpr: AST.expr,
  rightExpr: AST.expr,
  generateThenBlock: codegenState => result<codegenState, string>,
  generateElseBlock: codegenState => result<codegenState, string>,
): result<codegenState, string> => {
  // Generate labels
  let (state1, endLabel) = Utils.generateLabel(state)
  let (state2, thenLabel) = Utils.generateLabel(state1)

  Utils.binaryOperandsToString(state2, leftExpr, rightExpr)
  ->Result.map(((newState, leftValue, rightValue)) => {
    // Branch to then block when condition is TRUE
    let branchInstr = Utils.generateDirectBranch(op, leftValue, rightValue, thenLabel)
    Utils.addInstruction(newState, branchInstr)
  })
  ->Result.flatMap(generateElseBlock)
  ->Result.map(s => Utils.addInstruction(s, "j " ++ endLabel))
  ->Result.map(s => Utils.addInstruction(s, thenLabel ++ ":"))
  ->Result.flatMap(generateThenBlock)
  ->Result.map(s => Utils.addInstruction(s, endLabel ++ ":"))
}

// Generate while loop with direct comparison optimization
// Strategy: Evaluate condition on each iteration, use inverted branch to exit when FALSE
let generateWhileLoop = (
  state: codegenState,
  op: AST.binaryOp,
  leftExpr: AST.expr,
  rightExpr: AST.expr,
  generateBody: codegenState => result<codegenState, string>,
): result<codegenState, string> => {
  // Generate labels (start label first so it gets lower number)
  Console.log("[BranchGen] generateWhileLoop")
  let (state1, startLabel) = Utils.generateLabel(state)
  let (state2, endLabel) = Utils.generateLabel(state1)

  // Emit start label
  let state3 = Utils.addInstruction(state2, startLabel ++ ":")

  Utils.binaryOperandsToString(state3, leftExpr, rightExpr)
  ->Result.map(((newState, leftValue, rightValue)) => {
    // Generate inverted branch: jump to end when condition is FALSE
    let branchInstr = Utils.generateInvertedBranch(op, leftValue, rightValue, endLabel)

    Utils.addInstruction(newState, branchInstr)
  })
  ->Result.flatMap(generateBody)
  ->Result.map(s => Utils.addInstruction(s, "j " ++ startLabel))
  ->Result.map(s => Utils.addInstruction(s, endLabel ++ ":"))
}

// Generate while loop using condition register (for non-comparison conditions)
let generateWhileMainLoopReg = (
  state: codegenState,
  generateBody: codegenState => result<codegenState, string>,
): result<codegenState, string> => {
  Console.log("[BranchGen] generateWhileMainLoopReg")
  let (state1, label) = Utils.generateLabel(state)
  state1
  ->Utils.addInstruction(label ++ ":")
  ->generateBody
  ->Result.map(s => Utils.addInstruction(s, "j " ++ label))
}
