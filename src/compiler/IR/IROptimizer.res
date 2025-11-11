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
      | Save(_, _, vreg) => used->VRegSet.add(vreg)
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

// Optimization 2: Copy Propagation
// Replace v1 = v0; v2 = v1 with v1 = v0; v2 = v0
type copyMap = Belt.Map.Int.t<IR.operand>

let propagateCopies = (instrs: list<IR.instr>): list<IR.instr> => {
  let substituteOperand = (op: IR.operand, copies: copyMap): IR.operand => {
    switch op {
    | VReg(vreg) =>
      switch copies->Belt.Map.Int.get(vreg) {
      | Some(replacement) => {
          Console.log2("[propagateCopies][sustituteOperand] replacement: ", replacement)
          replacement
        }
      | None => op
      }
    | Num(_) => op
    }
  }

  let rec process = (instrs: list<IR.instr>, copies: copyMap): list<IR.instr> => {
    switch instrs {
    | list{} => list{}
    | list{Move(dst, VReg(src)), ...rest} => {
        // This is a copy: dst = src
        // Add to copy map and continue
        let newCopies = copies->Belt.Map.Int.set(dst, VReg(src))
        list{Move(dst, VReg(src)), ...process(rest, newCopies)}
      }
    | list{Move(dst, operand), ...rest} => {
        // Regular move - apply substitution to operand
        let newOperand = substituteOperand(operand, copies)
        // This move invalidates any copies involving dst
        let newCopies = copies->Belt.Map.Int.remove(dst)
        list{Move(dst, newOperand), ...process(rest, newCopies)}
      }
    | list{Binary(dst, op, left, right), ...rest} => {
        // Apply substitution to operands
        let newLeft = substituteOperand(left, copies)
        let newRight = substituteOperand(right, copies)
        // This invalidates any copies involving dst
        let newCopies = copies->Belt.Map.Int.remove(dst)
        list{Binary(dst, op, newLeft, newRight), ...process(rest, newCopies)}
      }
    | list{Compare(dst, op, left, right), ...rest} => {
        // Apply substitution to operands
        let newLeft = substituteOperand(left, copies)
        let newRight = substituteOperand(right, copies)
        // This invalidates any copies involving dst
        let newCopies = copies->Belt.Map.Int.remove(dst)
        list{Compare(dst, op, newLeft, newRight), ...process(rest, newCopies)}
      }
    | list{Bnez(operand, label), ...rest} => {
        // Apply substitution to the condition operand
        let newOperand = substituteOperand(operand, copies)
        list{Bnez(newOperand, label), ...process(rest, copies)}
      }
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

// Apply all optimizations to a block
let optimizeBlock = (block: IR.block): IR.block => {
  let optimized =
    block.instructions
    ->propagateCopies
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
