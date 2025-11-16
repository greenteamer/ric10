// IR to WebAssembly Code Generation
// Converts IR with virtual registers to WebAssembly text format (.wat)

// State for code generation
type state = {
  localCount: int, // Total number of local variables needed
  output: array<string>, // Accumulated WASM instructions
  labelMap: Belt.Map.String.t<int>, // label name → label index
  nextLabelId: int, // Next available label ID
  constants: Belt.Map.String.t<string>, // Defined constants (name → value)
  stackPointer: int, // Current stack pointer position
}

// Create initial state
let createState = (): state => {
  localCount: 0,
  output: [],
  labelMap: Belt.Map.String.empty,
  nextLabelId: 0,
  constants: Belt.Map.String.empty,
  stackPointer: 0,
}

// Register a virtual register and update local count
let registerVReg = (state: state, vreg: IR.vreg): state => {
  if vreg >= state.localCount {
    {...state, localCount: vreg + 1}
  } else {
    state
  }
}

// Convert operand to WASM local reference or constant
let convertOperand = (state: state, operand: IR.operand): (state, string) => {
  switch operand {
  | VReg(vreg) =>
    // Ensure vreg is registered
    let newState = registerVReg(state, vreg)
    (newState, `(local.get $v${Int.toString(vreg)})`)
  | Num(n) => (state, `(i32.const ${Int.toString(n)})`)
  | Name(name) =>
    // Look up defined constant
    switch state.constants->Belt.Map.String.get(name) {
    | Some(value) => (state, value)
    | None => (state, `(i32.const 0) ;; undefined constant ${name}`)
    }
  | Hash(hashStr) =>
    // For WASM, we'll compute a simple hash or use a placeholder
    // In real implementation, this should match IC10's HASH() function
    (state, `(i32.const 0) ;; HASH("${hashStr}")`)
  }
}

// Emit a WASM instruction
let emit = (state: state, instr: string): state => {
  {...state, output: Array.concat(state.output, [instr])}
}

// Emit with indentation
let emitIndented = (state: state, instr: string, level: int): state => {
  let indent = String.repeat(" ", level * 2)
  emit(state, indent ++ instr)
}

// Get or create label ID
let getOrCreateLabel = (state: state, label: string): (state, int) => {
  switch state.labelMap->Belt.Map.String.get(label) {
  | Some(id) => (state, id)
  | None =>
    let id = state.nextLabelId
    let newState = {
      ...state,
      labelMap: state.labelMap->Belt.Map.String.set(label, id),
      nextLabelId: state.nextLabelId + 1,
    }
    (newState, id)
  }
}

// Generate WASM code for a single instruction
let generateInstr = (state: state, instr: IR.instr, indent: int): result<state, string> => {
  switch instr {
  | DefInt(name, value) =>
    // Store constant for later reference
    let constantValue = `(i32.const ${Int.toString(value)})`
    Ok({...state, constants: state.constants->Belt.Map.String.set(name, constantValue)})

  | DefHash(name, value) =>
    // Store hash constant
    let constantValue = `(i32.const 0) ;; HASH("${value}")`
    Ok({...state, constants: state.constants->Belt.Map.String.set(name, constantValue)})

  | Move(vreg, operand) =>
    let state = registerVReg(state, vreg)
    let (state, operandStr) = convertOperand(state, operand)
    Ok(emitIndented(state, `${operandStr}`, indent)
      ->emitIndented(`(local.set $v${Int.toString(vreg)})`, indent))

  | Binary(vreg, op, left, right) => {
      let opStr = switch op {
      | AddOp => "i32.add"
      | SubOp => "i32.sub"
      | MulOp => "i32.mul"
      | DivOp => "i32.div_s"
      }

      let state = registerVReg(state, vreg)
      let (state, leftStr) = convertOperand(state, left)
      let (state, rightStr) = convertOperand(state, right)

      Ok(
        emitIndented(state, leftStr, indent)
        ->emitIndented(rightStr, indent)
        ->emitIndented(`(${opStr})`, indent)
        ->emitIndented(`(local.set $v${Int.toString(vreg)})`, indent),
      )
    }

  | Compare(vreg, op, left, right) => {
      let opStr = switch op {
      | LtOp => "i32.lt_s"
      | GtOp => "i32.gt_s"
      | EqOp => "i32.eq"
      | GeOp => "i32.ge_s"
      | LeOp => "i32.le_s"
      | NeOp => "i32.ne"
      }

      let state = registerVReg(state, vreg)
      let (state, leftStr) = convertOperand(state, left)
      let (state, rightStr) = convertOperand(state, right)

      Ok(
        emitIndented(state, leftStr, indent)
        ->emitIndented(rightStr, indent)
        ->emitIndented(`(${opStr})`, indent)
        ->emitIndented(`(local.set $v${Int.toString(vreg)})`, indent),
      )
    }

  | Label(label) =>
    // WASM doesn't have explicit labels in the same way as IC10
    // We'll use block labels for control flow
    let (state, labelId) = getOrCreateLabel(state, label)
    Ok(emitIndented(state, `;; label: ${label} (id: ${Int.toString(labelId)})`, indent))

  | Goto(label) =>
    let (state, labelId) = getOrCreateLabel(state, label)
    // In WASM, we need to use br to break to a specific block
    // This is simplified - proper implementation would need structured control flow
    Ok(emitIndented(state, `(br $${label})`, indent))

  | Bnez(operand, label) =>
    let (state, operandStr) = convertOperand(state, operand)
    let (state, _labelId) = getOrCreateLabel(state, label)
    // Branch if not equal to zero
    Ok(
      emitIndented(state, operandStr, indent)
      ->emitIndented(`(if`, indent)
      ->emitIndented(`(then`, indent + 1)
      ->emitIndented(`(br $${label})`, indent + 2)
      ->emitIndented(`)`, indent + 1)
      ->emitIndented(`)`, indent),
    )

  | Call(label) =>
    // Function call
    Ok(emitIndented(state, `(call $${label})`, indent))

  | Return =>
    // Return from function
    Ok(emitIndented(state, `(return)`, indent))

  | StackAlloc(slotCount) =>
    // Allocate stack space (adjust stack pointer)
    let newSP = state.stackPointer + slotCount
    Ok({...state, stackPointer: newSP}
      ->emitIndented(`;; stack alloc ${Int.toString(slotCount)} slots`, indent))

  | StackPoke(address, operand) =>
    // Store to linear memory
    let (state, valueStr) = convertOperand(state, operand)
    Ok(
      emitIndented(state, `(i32.const ${Int.toString(address * 4)})`, indent)
      ->emitIndented(valueStr, indent)
      ->emitIndented(`(i32.store)`, indent),
    )

  | StackGet(vreg, address) =>
    // Load from linear memory
    let state = registerVReg(state, vreg)
    Ok(
      emitIndented(state, `(i32.const ${Int.toString(address * 4)})`, indent)
      ->emitIndented(`(i32.load)`, indent)
      ->emitIndented(`(local.set $v${Int.toString(vreg)})`, indent),
    )

  | StackPush(operand) =>
    // Push to stack (store and increment SP)
    let (state, valueStr) = convertOperand(state, operand)
    let address = state.stackPointer
    let newState = {...state, stackPointer: state.stackPointer + 1}
    Ok(
      emitIndented(newState, `(i32.const ${Int.toString(address * 4)})`, indent)
      ->emitIndented(valueStr, indent)
      ->emitIndented(`(i32.store)`, indent),
    )

  | DeviceLoad(vreg, _device, _property, _bulkOpt) =>
    // Device operations are IC10-specific, cannot translate to WASM
    let state = registerVReg(state, vreg)
    Ok(emitIndented(state, `;; DeviceLoad not supported in WASM`, indent)
      ->emitIndented(`(i32.const 0)`, indent)
      ->emitIndented(`(local.set $v${Int.toString(vreg)})`, indent))

  | DeviceStore(_device, _property, _valueOperand) =>
    // Device operations are IC10-specific
    Ok(emitIndented(state, `;; DeviceStore not supported in WASM`, indent))

  | RawInstruction(instruction) =>
    // Emit as comment
    Ok(emitIndented(state, `;; raw: ${instruction}`, indent))

  | Unary(vreg, op, operand) =>
    let state = registerVReg(state, vreg)
    let (state, operandStr) = convertOperand(state, operand)
    let opStr = switch op {
    | Abs => "i32.abs"
    }
    Ok(
      emitIndented(state, operandStr, indent)
      ->emitIndented(`(${opStr})`, indent)
      ->emitIndented(`(local.set $v${Int.toString(vreg)})`, indent),
    )
  }
}

// Generate WASM code for a block
let generateBlock = (state: state, block: IR.block, indent: int): result<state, string> => {
  // Emit block label as comment
  let state = emitIndented(state, ``, indent)->emitIndented(`;; Block: ${block.name}`, indent)

  // Process all instructions
  let rec processInstrs = (state: state, instrs: list<IR.instr>): result<state, string> => {
    switch instrs {
    | list{} => Ok(state)
    | list{instr, ...rest} =>
      generateInstr(state, instr, indent)->Result.flatMap(state => {
        processInstrs(state, rest)
      })
    }
  }

  processInstrs(state, block.instructions)
}

// Generate complete WASM module
let generate = (ir: IR.t): result<string, string> => {
  let initialState = createState()

  // First pass: count locals and collect all instructions
  let rec processBlocks = (state: state, blocks: list<IR.block>): result<state, string> => {
    switch blocks {
    | list{} => Ok(state)
    | list{block, ...rest} =>
      generateBlock(state, block, 2)->Result.flatMap(state => {
        processBlocks(state, rest)
      })
    }
  }

  processBlocks(initialState, ir)->Result.map(finalState => {
    // Generate local variable declarations
    let locals = if finalState.localCount > 0 {
      let localDecls = Array.make(~length=finalState.localCount, "")
      for i in 0 to finalState.localCount - 1 {
        localDecls[i] = `    (local $v${Int.toString(i)} i32)`
      }
      Array.join(localDecls, "\n") ++ "\n"
    } else {
      ""
    }

    // Build complete WASM module
    let header = "(module\n  (memory 1)\n  (export \"main\" (func $main))\n  (func $main\n"
    let footer = "  )\n)"

    header ++ locals ++ "\n" ++ Array.join(finalState.output, "\n") ++ "\n" ++ footer
  })
}
