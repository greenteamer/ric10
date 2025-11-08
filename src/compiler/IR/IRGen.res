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
  | Lt | Gt | Eq => Error("Comparison operators not supported in Phase 1")
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
  | Identifier(name) => {
      switch state.varMap->Belt.Map.String.get(name) {
      | Some(sourceVreg) => {
          let (state, vreg) = allocVReg(state)
          let state = emit(state, IR.Move(vreg, IR.VReg(sourceVreg)))
          Ok(state, vreg)
        }
      | None => Error(`Variable '${name}' not found`)
      }
    }

  // BinaryExpression: generate left and right, emit Binary instruction
  | BinaryExpression(op, left, right) => {
      convertBinOp(op)->Result.flatMap(irOp => {
        generateExpr(state, left)->Result.flatMap(((state, leftVreg)) => {
          generateExpr(state, right)->Result.flatMap(((state, rightVreg)) => {
            let (state, resultVreg) = allocVReg(state)
            let state = emit(state, IR.Binary(irOp, resultVreg, IR.VReg(leftVreg), IR.VReg(rightVreg)))
            Ok(state, resultVreg)
          })
        })
      })
    }

  // Phase 1: Only support simple expressions
  | _ => Error("Expression type not supported in Phase 1")
  }
}

// Generate IR for a statement
let generateStmt = (state: state, stmt: AST.stmt): result<state, string> => {
  switch stmt {
  // VariableDeclaration: generate expression, store vreg in varMap
  | VariableDeclaration(name, init) => {
      generateExpr(state, init)->Result.map(((state, vreg)) => {
        {...state, varMap: state.varMap->Belt.Map.String.set(name, vreg)}
      })
    }

  // Phase 1: Only support variable declarations
  | _ => Error("Statement type not supported in Phase 1")
  }
}

// Generate IR for entire program
let generate = (ast: AST.program): result<IR.t, string> => {
  let initialState = createState()

  // Process all statements
  let rec processStmts = (state: state, stmts: array<AST.stmt>, index: int): result<state, string> => {
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
      instructions: instructions,
    }
    list{block}
  })
}
