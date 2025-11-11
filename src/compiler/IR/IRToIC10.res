// IR to IC10 Code Generation
// Maps virtual registers to physical registers (r0-r15) and generates IC10 assembly

// State for code generation
type state = {
  vregMap: Belt.Map.Int.t<int>, // vreg → physical register mapping
  nextPhysical: int, // Next available physical register (0-15)
  output: array<string>, // Accumulated IC10 instructions
}

// Create initial state
let createState = (): state => {
  vregMap: Belt.Map.Int.empty,
  nextPhysical: 0,
  output: [],
}

// Allocate a physical register for a virtual register
let allocatePhysicalReg = (state: state, vreg: IR.vreg): result<(state, int), string> => {
  // Check if vreg already has a physical register
  switch state.vregMap->Belt.Map.Int.get(vreg) {
  | Some(physicalReg) => Ok((state, physicalReg))
  | None =>
    // Allocate new physical register
    if state.nextPhysical > 15 {
      Error(`Register allocation failed: exceeded 16 physical registers`)
    } else {
      let physicalReg = state.nextPhysical
      let newState = {
        ...state,
        vregMap: state.vregMap->Belt.Map.Int.set(vreg, physicalReg),
        nextPhysical: state.nextPhysical + 1,
      }
      Ok((newState, physicalReg))
    }
  }
}

// Convert an operand to IC10 format
let convertOperand = (state: state, operand: IR.operand): result<(state, string), string> => {
  switch operand {
  | VReg(vreg) =>
    allocatePhysicalReg(state, vreg)->Result.map(((state, physicalReg)) => {
      (state, `r${Int.toString(physicalReg)}`)
    })
  | Num(n) => Ok((state, Int.toString(n)))
  }
}

// Emit an IC10 instruction
let emit = (state: state, instr: string): state => {
  {...state, output: Array.concat(state.output, [instr])}
}

// Generate IC10 code for a single instruction
let generateInstr = (state: state, instr: IR.instr): result<state, string> => {
  switch instr {
  | Move(vreg, operand) =>
    allocatePhysicalReg(state, vreg)->Result.flatMap(((state, physicalReg)) => {
      convertOperand(state, operand)->Result.map(((state, operandStr)) => {
        emit(state, `move r${Int.toString(physicalReg)} ${operandStr}`)
      })
    })

  | Binary(vreg, op, left, right) => {
      let opStr = switch op {
      | AddOp => "add"
      | SubOp => "sub"
      | MulOp => "mul"
      | DivOp => "div"
      }

      allocatePhysicalReg(state, vreg)->Result.flatMap(((state, resultReg)) => {
        convertOperand(state, left)->Result.flatMap(((state, leftStr)) => {
          convertOperand(state, right)->Result.map(
            ((state, rightStr)) => {
              emit(state, `${opStr} r${Int.toString(resultReg)} ${leftStr} ${rightStr}`)
            },
          )
        })
      })
    }

  | Compare(vreg, op, left, right) => {
      let opStr = switch op {
      | LtOp => "slt"
      | GtOp => "sgt"
      | EqOp => "seq"
      | GeOp => "sge"
      | LeOp => "sle"
      | NeOp => "sne"
      }

      allocatePhysicalReg(state, vreg)->Result.flatMap(((state, resultReg)) => {
        convertOperand(state, left)->Result.flatMap(((state, leftStr)) => {
          convertOperand(state, right)->Result.map(
            ((state, rightStr)) => {
              emit(state, `${opStr} r${Int.toString(resultReg)} ${leftStr} ${rightStr}`)
            },
          )
        })
      })
    }

  | Label(label) => Ok(emit(state, `${label}:`))

  | Goto(label) => Ok(emit(state, `j ${label}`))

  | Bnez(operand, label) =>
    convertOperand(state, operand)->Result.map(((state, regStr)) => {
      emit(state, `bnez ${regStr} ${label}`)
    })

  | DefInt(name, value) => Ok(emit(state, `define ${name} ${Int.toString(value)}`))

  | DefHash(name, value) => Ok(emit(state, `define ${name} HASH("${value}")`))

  // Stack operations for variants
  | StackAlloc(slotCount) =>
    // Optimize: Instead of multiple push 0, directly move the stack pointer
    // This is more efficient: move sp 8 instead of 8x push 0
    Ok(emit(state, `move sp ${Int.toString(slotCount)}`))

  | StackPoke(address, operand) =>
    // poke address value
    convertOperand(state, operand)->Result.map(((state, valueStr)) => {
      emit(state, `poke ${Int.toString(address)} ${valueStr}`)
    })

  | StackGet(vreg, address) =>
    // get r? db address
    allocatePhysicalReg(state, vreg)->Result.map(((state, physicalReg)) => {
      emit(state, `get r${Int.toString(physicalReg)} db ${Int.toString(address)}`)
    })

  | StackPush(operand) =>
    // push value
    convertOperand(state, operand)->Result.map(((state, valueStr)) => {
      emit(state, `push ${valueStr}`)
    })

  // Load: l resultReg device property
  | Load(vreg, device, deviceParam, bulkOpt) =>
    allocatePhysicalReg(state, vreg)->Result.map(((state, physicalReg)) => {
      // Convert device to IC10 format
      let deviceStr = switch device {
      | DevicePin(pin) => `d${Int.toString(pin)}`
      | DeviceReg(deviceVReg) =>
        // Device stored in register - need to allocate physical reg for it
        switch state.vregMap->Belt.Map.Int.get(deviceVReg) {
        | Some(devicePhysReg) => `r${Int.toString(devicePhysReg)}`
        | None => "d0" // Fallback - shouldn't happen
        }
      }

      // Convert deviceParam to property name
      let propertyStr = switch deviceParam {
      | Temperature => "Temperature"
      | Setting => "Setting"
      | Pressure => "Pressure"
      | On => "On"
      | Open => "Open"
      | Mode => "Mode"
      | Lock => "Lock"
      }

      // Build instruction (ignore bulkOpt for now - Phase 1)
      let instr = `l r${Int.toString(physicalReg)} ${deviceStr} ${propertyStr}`
      emit(state, instr)
    })

  // Save: s device property value
  | Save(device, deviceParam, valueOperand) =>
    // Convert device to IC10 format
    let deviceStr = switch device {
    | DevicePin(pin) => `d${Int.toString(pin)}`
    | DeviceReg(deviceVReg) =>
      // Device stored in register - need to allocate physical reg for it
      switch state.vregMap->Belt.Map.Int.get(deviceVReg) {
      | Some(devicePhysReg) => `r${Int.toString(devicePhysReg)}`
      | None => "d0" // Fallback - shouldn't happen
      }
    }

    // Convert deviceParam to property name
    let propertyStr = switch deviceParam {
    | Temperature => "Temperature"
    | Setting => "Setting"
    | Pressure => "Pressure"
    | On => "On"
    | Open => "Open"
    | Mode => "Mode"
    | Lock => "Lock"
    }

    // Convert value operand to string
    convertOperand(state, valueOperand)->Result.map(((state, valueStr)) => {
      // Build instruction: s device property value
      let instr = `s ${deviceStr} ${propertyStr} ${valueStr}`
      emit(state, instr)
    })

  // RawInstruction: emit raw IC10 assembly directly
  | RawInstruction(instruction) => Ok(emit(state, instruction))

  // Phase 1: Not yet implemented
  | Unary(_, _, _) => Error("Unary instruction not yet implemented in Phase 1")
  }
}

// Generate IC10 code for a block with peephole optimization
let generateBlock = (state: state, block: IR.block): result<state, string> => {
  // Process all instructions in the block with lookahead for peephole optimization
  let rec processInstrs = (state: state, instrs: list<IR.instr>): result<state, string> => {
    switch instrs {
    | list{} => Ok(state)

    // Peephole optimization: Multiple StackAlloc → Single move sp instruction
    | list{StackAlloc(count1), ...rest} =>
      // Accumulate consecutive StackAlloc instructions
      let rec accumulateStackAllocs = (total: int, remaining: list<IR.instr>): (
        int,
        list<IR.instr>,
      ) => {
        switch remaining {
        | list{StackAlloc(count), ...rest} => accumulateStackAllocs(total + count, rest)
        | _ => (total, remaining)
        }
      }
      let (totalSlots, remaining) = accumulateStackAllocs(count1, rest)
      // Emit single move sp instruction
      let newState = emit(state, `move sp ${Int.toString(totalSlots)}`)
      processInstrs(newState, remaining)

    // Peephole optimization: Compare + Bnez → Direct branch instruction
    | list{Compare(vreg, op, left, right), Bnez(VReg(condReg), label), ...rest}
      if vreg === condReg =>
      // Pattern detected! Emit direct branch instruction
      let branchOp = switch op {
      | LtOp => "blt"
      | GtOp => "bgt"
      | LeOp => "ble"
      | GeOp => "bge"
      | EqOp => "beq"
      | NeOp => "bne"
      }

      // Convert operands to IC10 format
      convertOperand(state, left)->Result.flatMap(((state, leftStr)) => {
        convertOperand(state, right)->Result.flatMap(((state, rightStr)) => {
          // Emit direct branch instruction
          let newState = emit(state, `${branchOp} ${leftStr} ${rightStr} ${label}`)
          processInstrs(newState, rest)
        })
      })

    // Default case: process instruction normally
    | list{instr, ...rest} =>
      generateInstr(state, instr)->Result.flatMap(state => {
        processInstrs(state, rest)
      })
    }
  }

  processInstrs(state, block.instructions)
}

// Generate IC10 code for entire IR program
let generate = (ir: IR.t): result<string, string> => {
  let initialState = createState()

  // Process all blocks
  let rec processBlocks = (state: state, blocks: list<IR.block>): result<state, string> => {
    switch blocks {
    | list{} => Ok(state)
    | list{block, ...rest} =>
      generateBlock(state, block)->Result.flatMap(state => {
        processBlocks(state, rest)
      })
    }
  }

  processBlocks(initialState, ir)->Result.map(finalState => {
    // Join all instructions with newlines
    Array.join(finalState.output, "\n")
  })
}
