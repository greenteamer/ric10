// BranchGen - Branch instruction generation for if/else statements
// Eliminates code duplication by providing reusable branching logic

// Type alias for codegen state (avoid circular dependency)
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

// Generate a unique label
let generateLabel = (state: codegenState): (codegenState, string) => {
  let label = "label" ++ Int.toString(state.labelCounter)
  let newState = {...state, labelCounter: state.labelCounter + 1}
  (newState, label)
}

// Generate direct branch instruction for binary comparison
// Jumps to label when condition is TRUE
let generateDirectBranch = (
  op: AST.binaryOp,
  leftReg: Register.t,
  rightValue: string,
  label: string,
): string => {
  switch op {
  | AST.Lt => "blt " ++ Register.toString(leftReg) ++ " " ++ rightValue ++ " " ++ label
  | AST.Gt => "bgt " ++ Register.toString(leftReg) ++ " " ++ rightValue ++ " " ++ label
  | AST.Eq => "beq " ++ Register.toString(leftReg) ++ " " ++ rightValue ++ " " ++ label
  | _ => "" // Not a comparison operator
  }
}

// Generate inverted branch instruction for binary comparison
// Jumps to label when condition is FALSE
let generateInvertedBranch = (
  op: AST.binaryOp,
  leftReg: Register.t,
  rightValue: string,
  label: string,
): string => {
  switch op {
  | AST.Lt => "bge " ++ Register.toString(leftReg) ++ " " ++ rightValue ++ " " ++ label // >= (not <)
  | AST.Gt => "ble " ++ Register.toString(leftReg) ++ " " ++ rightValue ++ " " ++ label // <= (not >)
  | AST.Eq => "bne " ++ Register.toString(leftReg) ++ " " ++ rightValue ++ " " ++ label // != (not ==)
  | _ => "" // Not a comparison operator
  }
}

// Generate if-only statement (no else block)
// Strategy: Use inverted branch to skip then block when condition is FALSE
let generateIfOnly = (
  state: codegenState,
  op: AST.binaryOp,
  leftReg: Register.t,
  rightValue: string,
  generateThenBlock: codegenState => result<codegenState, string>,
): result<codegenState, string> => {
  // Generate end label
  let (state1, endLabel) = generateLabel(state)

  // Generate inverted branch: jump to end when condition is FALSE
  let branchInstr = generateInvertedBranch(op, leftReg, rightValue, endLabel)
  let state2 = addInstruction(state1, branchInstr)

  // Generate then block (executed when condition is TRUE)
  switch generateThenBlock(state2) {
  | Error(msg) => Error(msg)
  | Ok(state3) =>
    // Add end label
    Ok(addInstruction(state3, endLabel ++ ":"))
  }
}

// Generate if-else statement
// Strategy: Branch to then label when TRUE, else block falls through, jump to end after else
let generateIfElse = (
  state: codegenState,
  op: AST.binaryOp,
  leftReg: Register.t,
  rightValue: string,
  generateThenBlock: codegenState => result<codegenState, string>,
  generateElseBlock: codegenState => result<codegenState, string>,
): result<codegenState, string> => {
  // Generate labels
  let (state1, endLabel) = generateLabel(state)
  let (state2, thenLabel) = generateLabel(state1)

  // Branch to then block when condition is TRUE
  let branchInstr = generateDirectBranch(op, leftReg, rightValue, thenLabel)
  let state3 = addInstruction(state2, branchInstr)

  // Generate else block (falls through when condition is FALSE)
  switch generateElseBlock(state3) {
  | Error(msg) => Error(msg)
  | Ok(state4) =>
    // Jump to end after else block
    let state5 = addInstruction(state4, "j " ++ endLabel)

    // Add then label and generate then block
    let state6 = addInstruction(state5, thenLabel ++ ":")
    switch generateThenBlock(state6) {
    | Error(msg) => Error(msg)
    | Ok(state7) =>
      // Add end label
      Ok(addInstruction(state7, endLabel ++ ":"))
    }
  }
}

// Fallback: Generate if statement using condition register (for non-comparison conditions)
let generateIfWithConditionReg = (
  state: codegenState,
  condReg: Register.t,
  generateThenBlock: codegenState => result<codegenState, string>,
  elseBlock: option<codegenState => result<codegenState, string>>,
): result<codegenState, string> => {
  // Generate labels
  let (state1, endLabel) = generateLabel(state)

  switch elseBlock {
  | None =>
    // If-only: jump to end when condition is zero (false)
    let branchInstr = "beqz " ++ Register.toString(condReg) ++ " " ++ endLabel
    let state2 = addInstruction(state1, branchInstr)

    // Generate then block
    switch generateThenBlock(state2) {
    | Error(msg) => Error(msg)
    | Ok(state3) =>
      // Add end label
      Ok(addInstruction(state3, endLabel ++ ":"))
    }

  | Some(generateElseBlock) =>
    // If-else: need else label too
    let (state2, elseLabel) = generateLabel(state1)

    // Jump to else when condition is zero (false)
    let branchInstr = "beqz " ++ Register.toString(condReg) ++ " " ++ elseLabel
    let state3 = addInstruction(state2, branchInstr)

    // Generate then block
    switch generateThenBlock(state3) {
    | Error(msg) => Error(msg)
    | Ok(state4) =>
      // Jump to end after then block
      let state5 = addInstruction(state4, "j " ++ endLabel)

      // Add else label and generate else block
      let state6 = addInstruction(state5, elseLabel ++ ":")
      switch generateElseBlock(state6) {
      | Error(msg) => Error(msg)
      | Ok(state7) =>
        // Add end label
        Ok(addInstruction(state7, endLabel ++ ":"))
      }
    }
  }
}
