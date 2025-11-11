// IR Optimization Layer
// Applies optimizations at the IR level before physical register allocation

// Track which virtual registers are actually used
module VRegSet = Belt.Set.Int

// Analysis: find all virtual registers that are used (read from)
let rec findUsedVRegs = (instrs: list<IR.instr>, used: VRegSet.t): VRegSet.t => {
  switch instrs {
  | list{} => used
  | list{instr, ...rest} => {
      let newUsed = switch instr {
      | Move(_, VReg(vreg)) => used->VRegSet.add(vreg)
      | Move(_, Num(_)) => used
      | Binary(_, _, VReg(left), VReg(right)) => used->VRegSet.add(left)->VRegSet.add(right)
      | Binary(_, _, VReg(left), Num(_)) => used->VRegSet.add(left)
      | Binary(_, _, Num(_), VReg(right)) => used->VRegSet.add(right)
      | Binary(_, _, Num(_), Num(_)) => used
      | Compare(_, _, VReg(left), VReg(right)) => used->VRegSet.add(left)->VRegSet.add(right)
      | Compare(_, _, VReg(left), Num(_)) => used->VRegSet.add(left)
      | Compare(_, _, Num(_), VReg(right)) => used->VRegSet.add(right)
      | Compare(_, _, Num(_), Num(_)) => used
      | Bnez(VReg(vreg), _) => used->VRegSet.add(vreg)
      | Bnez(Num(_), _) => used
      | Save(_, _, VReg(vreg)) => used->VRegSet.add(vreg)
      | Save(_, _, Num(_)) => used
      | Unary(_, _, VReg(vreg)) => used->VRegSet.add(vreg)
      | Unary(_, _, Num(_)) => used
      | _ => used
      }
      findUsedVRegs(rest, newUsed)
    }
  }
}

// Optimization 1: Dead Code Elimination
// Remove Move instructions where the destination vreg is never used
let eliminateDeadCode = (instrs: list<IR.instr>): list<IR.instr> => {
  let usedVRegs = findUsedVRegs(instrs, VRegSet.empty)

  let rec filter = (instrs: list<IR.instr>): list<IR.instr> => {
    switch instrs {
    | list{} => list{}
    | list{Move(vreg, _) as instr, ...rest} =>
      if usedVRegs->VRegSet.has(vreg) {
        list{instr, ...filter(rest)}
      } else {
        // Dead move - vreg is never used
        filter(rest)
      }
    | list{instr, ...rest} => list{instr, ...filter(rest)}
    }
  }

  filter(instrs)
}

// Optimization 2: Constant and Copy Propagation
// Replaces variables with their known constant or copy values.
type copyMap = Belt.Map.Int.t<IR.operand>

let propagateConstantsAndCopies = (instrs: list<IR.instr>): list<IR.instr> => {
  let substituteOperand = (op: IR.operand, copies: copyMap): IR.operand => {
    switch op {
    | VReg(vreg) =>
      switch copies->Belt.Map.Int.get(vreg) {
      | Some(replacement) => replacement
      | None => op
      }
    | Num(_) => op
    }
  }

  let rec process = (instrs: list<IR.instr>, copies: copyMap): list<IR.instr> => {
    switch instrs {
    | list{} => list{}

    // Instructions that DEFINE a register
    | list{IR.Move(dst, operand), ...rest} =>
      let substitutedOperand = substituteOperand(operand, copies)
      let newInstr = IR.Move(dst, substitutedOperand)
      let newCopies = copies->Belt.Map.Int.remove(dst)->Belt.Map.Int.set(dst, substitutedOperand)
      list{newInstr, ...process(rest, newCopies)}

    | list{IR.Binary(dst, op, left, right), ...rest} =>
      let newLeft = substituteOperand(left, copies)
      let newRight = substituteOperand(right, copies)
      let newInstr = IR.Binary(dst, op, newLeft, newRight)
      let newCopies = copies->Belt.Map.Int.remove(dst)
      list{newInstr, ...process(rest, newCopies)}

    | list{IR.Compare(dst, op, left, right), ...rest} =>
      let newLeft = substituteOperand(left, copies)
      let newRight = substituteOperand(right, copies)
      let newInstr = IR.Compare(dst, op, newLeft, newRight)
      let newCopies = copies->Belt.Map.Int.remove(dst)
      list{newInstr, ...process(rest, newCopies)}

    | list{IR.Unary(dst, op, operand), ...rest} =>
      let newOperand = substituteOperand(operand, copies)
      let newInstr = IR.Unary(dst, op, newOperand)
      let newCopies = copies->Belt.Map.Int.remove(dst)
      list{newInstr, ...process(rest, newCopies)}

    | list{IR.Load(dst, device, deviceParam, bulkOpt), ...rest} =>
      let newCopies = copies->Belt.Map.Int.remove(dst)
      list{IR.Load(dst, device, deviceParam, bulkOpt), ...process(rest, newCopies)}

    | list{IR.StackGet(dst, address), ...rest} =>
      let newCopies = copies->Belt.Map.Int.remove(dst)
      list{IR.StackGet(dst, address), ...process(rest, newCopies)}

    // Instructions that USE registers
    | list{IR.Bnez(operand, label), ...rest} =>
      let newOperand = substituteOperand(operand, copies)
      list{IR.Bnez(newOperand, label), ...process(rest, copies)}

    | list{IR.Save(device, field, operand), ...rest} =>
      let newOperand = substituteOperand(operand, copies)
      list{IR.Save(device, field, newOperand), ...process(rest, copies)}

    | list{IR.StackPoke(address, operand), ...rest} =>
      let newOperand = substituteOperand(operand, copies)
      list{IR.StackPoke(address, newOperand), ...process(rest, copies)}

    | list{IR.StackPush(operand), ...rest} =>
      let newOperand = substituteOperand(operand, copies)
      list{IR.StackPush(newOperand), ...process(rest, copies)}

    // Other instructions are left alone
    | list{instr, ...rest} => list{instr, ...process(rest, copies)}
    }
  }

  process(instrs, Belt.Map.Int.empty)
}

// Optimization 3: Redundant Move Elimination
// Remove moves like v0 = v0
let eliminateRedundantMoves = (instrs: list<IR.instr>): list<IR.instr> => {
  let rec filter = (instrs: list<IR.instr>): list<IR.instr> => {
    switch instrs {
    | list{} => list{}
    | list{Move(dst, VReg(src)), ...rest} if dst === src => filter(rest) // v0 = v0 is redundant
    | list{instr, ...rest} => list{instr, ...filter(rest)}
    }
  }

  filter(instrs)
}

// Optimization 4: Constant Folding
// Evaluate constant expressions at compile time
let foldConstants = (instrs: list<IR.instr>): list<IR.instr> => {
  let rec process = (instrs: list<IR.instr>): list<IR.instr> => {
    switch instrs {
    | list{} => list{}
    | list{Binary(dst, op, Num(left), Num(right)), ...rest} =>
      let result = switch op {
      | AddOp => left + right
      | SubOp => left - right
      | MulOp => left * right
      | DivOp =>
        if right == 0 {
          // Division by zero, cannot fold
          -1 // Or some other sentinel, or don't fold
        } else {
          left / right
        }
      }
      list{Move(dst, Num(result)), ...process(rest)}

    | list{Compare(dst, op, Num(left), Num(right)), ...rest} =>
      let result = switch op {
      | LtOp => left < right
      | GtOp => left > right
      | EqOp => left == right
      | GeOp => left >= right
      | LeOp => left <= right
      | NeOp => left != right
      }
      list{Move(dst, Num(result ? 1 : 0)), ...process(rest)}

    | list{instr, ...rest} => list{instr, ...process(rest)}
    }
  }
  process(instrs)
}

// Apply all optimizations to a block
let optimizeBlock = (block: IR.block): IR.block => {
  let optimized =
    block.instructions
    ->foldConstants
    ->propagateConstantsAndCopies
    ->eliminateRedundantMoves
    ->eliminateDeadCode

  {...block, instructions: optimized}
}

// Apply optimizations to entire program
// Run multiple passes until no more changes
let optimize = (ir: IR.t): IR.t => {
  let rec optimizePass = (blocks: list<IR.block>, prevSize: int): list<IR.block> => {
    let optimized = blocks->List.map(optimizeBlock)

    // Count total instructions
    let currentSize = optimized->List.reduce(0, (acc, block) => {
      acc + List.length(block.instructions)
    })

    // If size changed, run another pass
    if currentSize < prevSize {
      optimizePass(optimized, currentSize)
    } else {
      optimized
    }
  }

  // Calculate initial size
  let initialSize = ir->List.reduce(0, (acc, block) => {
    acc + List.length(block.instructions)
  })

  optimizePass(ir, initialSize)
}
