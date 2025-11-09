// IR Generation - Convert AST to IR
// Phase 1: Simple expressions and variables only

// State for IR generation
type state = {
  nextVReg: int, // Counter for virtual register allocation
  instructions: list<IR.instr>, // Accumulated IR instructions
  nextLabel: int, // Counter for label generation
  varMap: Belt.Map.String.t<int>, // Variable name → virtual register mapping
}

// Create initial state
let createState = (): state => {
  nextVReg: 0,
  instructions: list{},
  nextLabel: 0,
  varMap: Belt.Map.String.empty,
}

// Allocate a new virtual register
let allocVReg = (state: state): (state, IR.vreg) => {
  let vreg = state.nextVReg
  let newState = {...state, nextVReg: state.nextVReg + 1}
  (newState, vreg)
}

// Emit an instruction
let emit = (state: state, instr: IR.instr): state => {
  {...state, instructions: list{instr, ...state.instructions}}
}

// Convert AST binary operator to IR binary operator
let convertBinOp = (op: AST.binaryOp): result<IR.binOp, string> => {
  switch op {
  | Add => Ok(IR.AddOp)
  | Sub => Ok(IR.SubOp)
  | Mul => Ok(IR.MulOp)
  | Div => Ok(IR.DivOp)
  | Lt | Gt | Eq => Error("Comparison operators should use convertCompareOp")
  }
}

// Convert AST comparison operator to IR comparison operator (normal)
let normalCompareOp = (op: AST.binaryOp): result<IR.compareOp, string> => {
  switch op {
  | Lt => Ok(IR.LtOp)
  | Gt => Ok(IR.GtOp)
  | Eq => Ok(IR.EqOp)
  | _ => Error("Not a comparison operator")
  }
}

// Invert comparison operator for if-only statements
// Used when we want to skip the then-block if condition is FALSE
let invertCompareOp = (op: AST.binaryOp): result<IR.compareOp, string> => {
  switch op {
  | Lt => Ok(IR.GeOp) // NOT(a < b) is (a >= b)
  | Gt => Ok(IR.LeOp) // NOT(a > b) is (a <= b)
  | Eq => Ok(IR.NeOp) // NOT(a == b) is (a != b)
  | _ => Error("Not a comparison operator")
  }
}

// Generate IR for an expression
// Returns (newState, vreg) where vreg contains the result
let rec generateExpr = (state: state, expr: AST.expr): result<(state, IR.vreg), string> => {
  switch expr {
  // Literal: allocate vreg, emit Move with immediate value
  | Literal(n) => {
      let (state, vreg) = allocVReg(state)
      let state = emit(state, IR.Move(vreg, IR.Num(n)))
      Ok(state, vreg)
    }

  // Identifier: lookup variable, allocate new vreg, emit Move from source vreg
  | Identifier(name) => switch state.varMap->Belt.Map.String.get(name) {
    | Some(sourceVreg) => {
        let (state, vreg) = allocVReg(state)
        let state = emit(state, IR.Move(vreg, IR.VReg(sourceVreg)))
        Ok(state, vreg)
      }
    | None => Error(`Variable '${name}' not found`)
    }

  // BinaryExpression: check if arithmetic or comparison
  | BinaryExpression(op, left, right) =>
    // Check if it's a comparison operator
    switch op {
    | Lt | Gt | Eq =>
      // Comparison: emit Compare instruction
      normalCompareOp(op)->Result.flatMap(cmpOp => {
        generateExpr(state, left)->Result.flatMap(((state, leftVreg)) => {
          generateExpr(state, right)->Result.flatMap(((state, rightVreg)) => {
            let (state, resultVreg) = allocVReg(state)
            let state = emit(
              state,
              IR.Compare(resultVreg, cmpOp, IR.VReg(leftVreg), IR.VReg(rightVreg)),
            )
            Ok(state, resultVreg)
          })
        })
      })
    | Add | Sub | Mul | Div =>
      // Arithmetic: emit Binary instruction
      convertBinOp(op)->Result.flatMap(irOp => {
        generateExpr(state, left)->Result.flatMap(((state, leftVreg)) => {
          generateExpr(state, right)->Result.flatMap(((state, rightVreg)) => {
            let (state, resultVreg) = allocVReg(state)
            let state = emit(
              state,
              IR.Binary(resultVreg, irOp, IR.VReg(leftVreg), IR.VReg(rightVreg)),
            )
            Ok(state, resultVreg)
          })
        })
      })
    }

  // Phase 1: Only support simple expressions
  | _ => Error("Expression type not supported in Phase 1")
  }
}

// Generate IR for a block of statements
let rec generateBlock = (state: state, block: AST.blockStatement): result<state, string> => {
  let rec processStmts = (state: state, stmts: array<AST.stmt>, index: int): result<
    state,
    string,
  > => {
    if index >= Array.length(stmts) {
      Ok(state)
    } else {
      switch stmts[index] {
      | Some(stmt) =>
        generateStmt(state, stmt)->Result.flatMap(state => processStmts(state, stmts, index + 1))
      | None => Error("Internal error: array index out of bounds")
      }
    }
  }
  processStmts(state, block, 0)
}

// Generate if-only statement (no else block)
// Uses INVERTED comparison + Bnez to skip then-block when condition is FALSE
and generateIfOnly = (
  state: state,
  condition: AST.expr,
  thenBlock: AST.blockStatement,
): result<state, string> => {
  // Extract comparison from condition
  switch condition {
  | BinaryExpression(op, left, right) =>
    switch op {
    | Lt | Gt | Eq =>
      // Generate left and right operands
      generateExpr(state, left)->Result.flatMap(((state, leftVreg)) => {
        generateExpr(state, right)->Result.flatMap(((state, rightVreg)) => {
          // Use INVERTED comparison
          invertCompareOp(op)->Result.flatMap(invertedOp => {
            let (state, resultVreg) = allocVReg(state)
            let state = emit(
              state,
              IR.Compare(resultVreg, invertedOp, IR.VReg(leftVreg), IR.VReg(rightVreg)),
            )

            // Allocate end label
            let endLabel = `label${Belt.Int.toString(state.nextLabel)}`
            let state = {...state, nextLabel: state.nextLabel + 1}

            // Emit Bnez - if inverted condition is true (original is false), skip then block
            let state = emit(state, IR.Bnez(IR.VReg(resultVreg), endLabel))

            // Generate then block
            generateBlock(state, thenBlock)->Result.flatMap(state => {
              // Emit end label
              let state = emit(state, IR.Label(endLabel))
              Ok(state)
            })
          })
        })
      })
    | _ => Error("If condition must be a comparison expression")
    }
  | _ => Error("If condition must be a comparison expression")
  }
}

// Generate if-else statement
// Uses NORMAL comparison + Bnez to jump to then-block when condition is TRUE
and generateIfElse = (
  state: state,
  condition: AST.expr,
  thenBlock: AST.blockStatement,
  elseBlock: AST.blockStatement,
): result<state, string> => {
  // Extract comparison from condition
  switch condition {
  | BinaryExpression(op, left, right) =>
    switch op {
    | Lt | Gt | Eq =>
      // Generate left and right operands
      generateExpr(state, left)->Result.flatMap(((state, leftVreg)) => {
        generateExpr(state, right)->Result.flatMap(((state, rightVreg)) => {
          // Use NORMAL comparison
          normalCompareOp(op)->Result.flatMap(normalOp => {
            let (state, resultVreg) = allocVReg(state)
            let state = emit(
              state,
              IR.Compare(resultVreg, normalOp, IR.VReg(leftVreg), IR.VReg(rightVreg)),
            )

            // Allocate labels
            let thenLabel = `label${Belt.Int.toString(state.nextLabel)}`
            let endLabel = `label${Belt.Int.toString(state.nextLabel + 1)}`
            let state = {...state, nextLabel: state.nextLabel + 2}

            // Emit Bnez - if condition is true, jump to then
            let state = emit(state, IR.Bnez(IR.VReg(resultVreg), thenLabel))

            // Generate else block (falls through)
            generateBlock(state, elseBlock)->Result.flatMap(state => {
              // Jump over then block
              let state = emit(state, IR.Goto(endLabel))

              // Then block label
              let state = emit(state, IR.Label(thenLabel))

              // Generate then block
              generateBlock(state, thenBlock)->Result.flatMap(state => {
                // End label
                let state = emit(state, IR.Label(endLabel))
                Ok(state)
              })
            })
          })
        })
      })
    | _ => Error("If condition must be a comparison expression")
    }
  | _ => Error("If condition must be a comparison expression")
  }
}

// Generate IR for a statement
and generateStmt = (state: state, stmt: AST.stmt): result<state, string> => {
  switch stmt {
  // VariableDeclaration: generate expression, store vreg in varMap
  | VariableDeclaration(name, init) => generateExpr(state, init)->Result.map(((state, vreg)) => {
      {...state, varMap: state.varMap->Belt.Map.String.set(name, vreg)}
    })

  // IfStatement: handle if-only and if-else
  | IfStatement(condition, thenBlock, elseBlock) =>
    switch elseBlock {
    | None => generateIfOnly(state, condition, thenBlock)
    | Some(block) => generateIfElse(state, condition, thenBlock, block)
    }

  // Phase 2: Support variable declarations and if statements
  | _ => Error("Statement type not supported in Phase 2")
  }
}

// Generate IR for entire program
let generate = (ast: AST.program): result<IR.t, string> => {
  let initialState = createState()

  // Process all statements
  let rec processStmts = (state: state, stmts: array<AST.stmt>, index: int): result<
    state,
    string,
  > => {
    if index >= Array.length(stmts) {
      Ok(state)
    } else {
      switch stmts[index] {
      | Some(stmt) =>
        generateStmt(state, stmt)->Result.flatMap(state => {
          processStmts(state, stmts, index + 1)
        })
      | None => Error("Internal error: array index out of bounds")
      }
    }
  }

  processStmts(initialState, ast, 0)->Result.map(finalState => {
    // Create a single block with all instructions (reversed to correct order)
    let instructions = finalState.instructions->List.reverse
    let block: IR.block = {
      name: "main",
      instructions,
    }
    list{block}
  })
}
