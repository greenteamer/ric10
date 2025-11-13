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
      | Move(_, Name(_)) => used
      | Move(_, Hash(_)) => used
      | Binary(_, _, VReg(left), VReg(right)) => used->VRegSet.add(left)->VRegSet.add(right)
      | Binary(_, _, VReg(left), Num(_)) => used->VRegSet.add(left)
      | Binary(_, _, VReg(left), Name(_)) => used->VRegSet.add(left)
      | Binary(_, _, VReg(left), Hash(_)) => used->VRegSet.add(left)
      | Binary(_, _, Num(_), VReg(right)) => used->VRegSet.add(right)
      | Binary(_, _, Num(_), Num(_)) => used
      | Binary(_, _, Num(_), Name(_)) => used
      | Binary(_, _, Num(_), Hash(_)) => used
      | Binary(_, _, Name(_), VReg(right)) => used->VRegSet.add(right)
      | Binary(_, _, Name(_), Num(_)) => used
      | Binary(_, _, Name(_), Name(_)) => used
      | Binary(_, _, Name(_), Hash(_)) => used
      | Binary(_, _, Hash(_), VReg(right)) => used->VRegSet.add(right)
      | Binary(_, _, Hash(_), Num(_)) => used
      | Binary(_, _, Hash(_), Name(_)) => used
      | Binary(_, _, Hash(_), Hash(_)) => used
      | Compare(_, _, VReg(left), VReg(right)) => used->VRegSet.add(left)->VRegSet.add(right)
      | Compare(_, _, VReg(left), Num(_)) => used->VRegSet.add(left)
      | Compare(_, _, VReg(left), Name(_)) => used->VRegSet.add(left)
      | Compare(_, _, VReg(left), Hash(_)) => used->VRegSet.add(left)
      | Compare(_, _, Num(_), VReg(right)) => used->VRegSet.add(right)
      | Compare(_, _, Num(_), Num(_)) => used
      | Compare(_, _, Num(_), Name(_)) => used
      | Compare(_, _, Num(_), Hash(_)) => used
      | Compare(_, _, Name(_), VReg(right)) => used->VRegSet.add(right)
      | Compare(_, _, Name(_), Num(_)) => used
      | Compare(_, _, Name(_), Name(_)) => used
      | Compare(_, _, Name(_), Hash(_)) => used
      | Compare(_, _, Hash(_), VReg(right)) => used->VRegSet.add(right)
      | Compare(_, _, Hash(_), Num(_)) => used
      | Compare(_, _, Hash(_), Name(_)) => used
      | Compare(_, _, Hash(_), Hash(_)) => used
      | Bnez(VReg(vreg), _) => used->VRegSet.add(vreg)
      | Bnez(Num(_), _) => used
      | Bnez(Name(_), _) => used
      | Bnez(Hash(_), _) => used
      | DeviceStore(_, _, VReg(vreg)) => used->VRegSet.add(vreg)
      | DeviceStore(_, _, Num(_)) => used
      | DeviceStore(_, _, Name(_)) => used
      | DeviceStore(_, _, Hash(_)) => used
      | Unary(_, _, VReg(vreg)) => used->VRegSet.add(vreg)
      | Unary(_, _, Num(_)) => used
      | Unary(_, _, Name(_)) => used
      | Unary(_, _, Hash(_)) => used
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
    | Name(_) => op
    | Hash(_) => op
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

    | list{IR.DeviceLoad(dst, device, property, bulkOpt), ...rest} =>
      let newCopies = copies->Belt.Map.Int.remove(dst)
      list{IR.DeviceLoad(dst, device, property, bulkOpt), ...process(rest, newCopies)}

    | list{IR.StackGet(dst, address), ...rest} =>
      let newCopies = copies->Belt.Map.Int.remove(dst)
      list{IR.StackGet(dst, address), ...process(rest, newCopies)}

    // Instructions that USE registers
    | list{IR.Bnez(operand, label), ...rest} =>
      let newOperand = substituteOperand(operand, copies)
      list{IR.Bnez(newOperand, label), ...process(rest, copies)}

    | list{IR.DeviceStore(device, property, operand), ...rest} =>
      let newOperand = substituteOperand(operand, copies)
      list{IR.DeviceStore(device, property, newOperand), ...process(rest, copies)}

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

// Optimization 5: Unreachable Code Elimination
// Remove instructions after unconditional control flow (Goto, Return) until the next Label
let eliminateUnreachableCode = (instrs: list<IR.instr>): list<IR.instr> => {
  let rec process = (instrs: list<IR.instr>, afterUnconditional: bool): list<IR.instr> => {
    switch instrs {
    | list{} => list{}

    // After an unconditional jump, skip instructions until we hit a label
    | list{Label(_) as label, ...rest} =>
      list{label, ...process(rest, false)}

    | list{instr, ...rest} if afterUnconditional =>
      // Skip this unreachable instruction
      process(rest, afterUnconditional)

    // Unconditional control flow instructions
    | list{Goto(_) as goto, ...rest} =>
      list{goto, ...process(rest, true)}

    | list{Return as ret, ...rest} =>
      list{ret, ...process(rest, true)}

    // All other instructions
    | list{instr, ...rest} =>
      list{instr, ...process(rest, false)}
    }
  }

  process(instrs, false)
}

// Optimization 6: Empty Basic Block Elimination
// Redirect jumps to labels that immediately jump elsewhere
let eliminateEmptyBlocks = (instrs: list<IR.instr>): list<IR.instr> => {
  // First pass: build a map of labels that immediately jump to other labels
  let rec buildRedirectMap = (instrs: list<IR.instr>, currentLabel: option<string>, redirects: Belt.Map.String.t<string>): Belt.Map.String.t<string> => {
    switch instrs {
    | list{} => redirects

    // Label followed immediately by Goto → record this redirect
    | list{Label(label), Goto(target), ...rest} =>
      buildRedirectMap(list{Goto(target), ...rest}, Some(label), redirects->Belt.Map.String.set(label, target))

    // Label followed by something other than Goto → not empty
    | list{Label(label), ...rest} =>
      buildRedirectMap(rest, Some(label), redirects)

    // Other instructions
    | list{_, ...rest} =>
      buildRedirectMap(rest, currentLabel, redirects)
    }
  }

  let redirectMap = buildRedirectMap(instrs, None, Belt.Map.String.empty)

  // Follow redirect chain to find final target
  let rec followRedirects = (label: string, visited: Belt.Set.String.t): string => {
    if visited->Belt.Set.String.has(label) {
      // Circular redirect, stop here
      label
    } else {
      switch redirectMap->Belt.Map.String.get(label) {
      | Some(target) => followRedirects(target, visited->Belt.Set.String.add(label))
      | None => label
      }
    }
  }

  // Second pass: redirect all jumps and remove empty blocks
  let rec process = (instrs: list<IR.instr>): list<IR.instr> => {
    switch instrs {
    | list{} => list{}

    // Redirect Goto instructions
    | list{Goto(target), ...rest} =>
      let newTarget = followRedirects(target, Belt.Set.String.empty)
      list{Goto(newTarget), ...process(rest)}

    // Redirect Bnez instructions
    | list{Bnez(operand, target), ...rest} =>
      let newTarget = followRedirects(target, Belt.Set.String.empty)
      list{Bnez(operand, newTarget), ...process(rest)}

    // Remove empty blocks (Label immediately followed by Goto)
    | list{Label(label), Goto(target), ...rest} =>
      // Skip this empty block entirely
      process(rest)

    // Keep all other instructions
    | list{instr, ...rest} =>
      list{instr, ...process(rest)}
    }
  }

  process(instrs)
}

// Optimization 7: Fall-through Optimization
// Remove Goto instructions that jump to the immediately following label
let eliminateFallthroughJumps = (instrs: list<IR.instr>): list<IR.instr> => {
  let rec process = (instrs: list<IR.instr>): list<IR.instr> => {
    switch instrs {
    | list{} => list{}

    // Goto immediately followed by its target label → remove Goto
    | list{Goto(target), Label(label), ...rest} if target === label =>
      list{Label(label), ...process(rest)}

    // Keep all other instructions
    | list{instr, ...rest} =>
      list{instr, ...process(rest)}
    }
  }

  process(instrs)
}

// Type definitions for define substitution
type defineValue =
  | DefNum(int)
  | DefHashStr(string)

type defineMap = Belt.Map.String.t<defineValue>

// Apply all optimizations to a block (without define substitution)
let optimizeBlockWithoutDefines = (block: IR.block): IR.block => {
  let optimized =
    block.instructions
    ->foldConstants
    ->propagateConstantsAndCopies
    ->eliminateRedundantMoves
    // ->eliminateDeadCode  // Disabled for now - tests expect all code to be kept
    ->eliminateUnreachableCode
    ->eliminateEmptyBlocks
    ->eliminateFallthroughJumps

  {...block, instructions: optimized}
}

// Global define substitution across all blocks
// Collects defines from all blocks, then substitutes in all blocks
let globalDefineSubstitution = (blocks: list<IR.block>): list<IR.block> => {
  // First pass: collect defines from ALL blocks
  let collectDefinesFromBlocks = (blocks: list<IR.block>): defineMap => {
    blocks->List.reduce(Belt.Map.String.empty, (defines, block) => {
      block.instructions->List.reduce(defines, (defines, instr) => {
        switch instr {
        | DefInt(name, value) => defines->Belt.Map.String.set(name, DefNum(value))
        | DefHash(name, hashValue) => defines->Belt.Map.String.set(name, DefHashStr(hashValue))
        | _ => defines
        }
      })
    })
  }

  let globalDefines = collectDefinesFromBlocks(blocks)

  // Helper to substitute a single operand using global defines
  let substituteOperand = (op: IR.operand): IR.operand => {
    switch op {
    | Name(name) =>
      switch globalDefines->Belt.Map.String.get(name) {
      | Some(DefNum(value)) => Num(value)
      | Some(DefHashStr(hashStr)) => Hash(hashStr)
      | None => op
      }
    | other => other
    }
  }

  // Helper to substitute device types using global defines
  let substituteDevice = (device: IR.device): IR.device => {
    switch device {
    | DeviceType(name) =>
      switch globalDefines->Belt.Map.String.get(name) {
      | Some(DefHashStr(hashStr)) => DeviceType(`HASH("${hashStr}")`)
      | _ => device
      }
    | DeviceNamed(typeName, nameName) =>
      let newTypeName = switch globalDefines->Belt.Map.String.get(typeName) {
      | Some(DefHashStr(hashStr)) => `HASH("${hashStr}")`
      | _ => typeName
      }
      let newNameName = switch globalDefines->Belt.Map.String.get(nameName) {
      | Some(DefHashStr(hashStr)) => `HASH("${hashStr}")`
      | _ => nameName
      }
      DeviceNamed(newTypeName, newNameName)
    | other => other
    }
  }

  // Second pass: substitute in all blocks but KEEP define instructions
  let substituteInBlock = (block: IR.block): IR.block => {
    let rec process = (instrs: list<IR.instr>): list<IR.instr> => {
      switch instrs {
      | list{} => list{}

      // KEEP DefInt and DefHash instructions (don't remove them)
      | list{DefInt(_, _) as defInstr, ...rest} => list{defInstr, ...process(rest)}
      | list{DefHash(_, _) as defInstr, ...rest} => list{defInstr, ...process(rest)}

      // Substitute in instructions with operands
      | list{Move(dst, operand), ...rest} =>
        list{Move(dst, substituteOperand(operand)), ...process(rest)}

      | list{Binary(dst, op, left, right), ...rest} =>
        list{Binary(dst, op, substituteOperand(left), substituteOperand(right)), ...process(rest)}

      | list{Compare(dst, op, left, right), ...rest} =>
        list{Compare(dst, op, substituteOperand(left), substituteOperand(right)), ...process(rest)}

      | list{Unary(dst, op, operand), ...rest} =>
        list{Unary(dst, op, substituteOperand(operand)), ...process(rest)}

      | list{Bnez(operand, label), ...rest} =>
        list{Bnez(substituteOperand(operand), label), ...process(rest)}

      | list{DeviceLoad(dst, device, property, bulkOpt), ...rest} =>
        list{DeviceLoad(dst, substituteDevice(device), property, bulkOpt), ...process(rest)}

      | list{DeviceStore(device, property, operand), ...rest} =>
        list{DeviceStore(substituteDevice(device), property, substituteOperand(operand)), ...process(rest)}

      | list{StackPoke(address, operand), ...rest} =>
        list{StackPoke(address, substituteOperand(operand)), ...process(rest)}

      | list{StackPush(operand), ...rest} =>
        list{StackPush(substituteOperand(operand)), ...process(rest)}

      // Other instructions are left alone
      | list{instr, ...rest} => list{instr, ...process(rest)}
      }
    }

    {...block, instructions: process(block.instructions)}
  }

  blocks->List.map(substituteInBlock)
}

// Apply optimizations to entire program
// Run multiple passes until no more changes
let optimize = (ir: IR.t): IR.t => {
  // First, do global define substitution across all blocks
  let afterDefineSubst = globalDefineSubstitution(ir)

  let rec optimizePass = (blocks: list<IR.block>, prevSize: int): list<IR.block> => {
    let optimized = blocks->List.map(optimizeBlockWithoutDefines)

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

  // Calculate initial size (after define substitution)
  let initialSize = afterDefineSubst->List.reduce(0, (acc, block) => {
    acc + List.length(block.instructions)
  })

  optimizePass(afterDefineSubst, initialSize)
}
