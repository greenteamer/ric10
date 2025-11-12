// IR Pretty Printer for debugging and visualization

// Format a virtual register
let printVReg = (vreg: IR.vreg): string => {
  `v${Int.toString(vreg)}`
}

// Format an operand
let printOperand = (operand: IR.operand): string => {
  switch operand {
  | VReg(vreg) => printVReg(vreg)
  | Num(n) => Int.toString(n)
  | Name(name) => name
  }
}

// Format a binary operator
let printBinOp = (op: IR.binOp): string => {
  switch op {
  | AddOp => "add"
  | SubOp => "sub"
  | MulOp => "mul"
  | DivOp => "div"
  }
}

// Format a comparison operator
let printCompareOp = (op: IR.compareOp): string => {
  switch op {
  | LtOp => "slt"
  | GtOp => "sgt"
  | EqOp => "seq"
  | GeOp => "sge"
  | LeOp => "sle"
  | NeOp => "sne"
  }
}

// Format a device
let printDevice = (device: IR.device): string => {
  switch device {
  | DevicePin(deviceRef) => deviceRef // deviceRef is already a string like "d0" or "db"
  | DeviceReg(vreg) => printVReg(vreg)
  | DeviceType(typeHash) => `type(${typeHash})`
  | DeviceNamed(typeHash, nameHash) => `named(${typeHash}, ${nameHash})`
  }
}

// Format an instruction
let printInstr = (instr: IR.instr): string => {
  switch instr {
  | DefInt(name, value) => `define ${name} ${Int.toString(value)}`
  | DefHash(name, value) => `define ${name} HASH("${value}")`
  | Move(vreg, operand) => `move ${printVReg(vreg)} ${printOperand(operand)}`
  | DeviceLoad(vreg, device, property, bulkOpt) => {
      let deviceStr = printDevice(device)
      let bulkStr = switch bulkOpt {
      | Some(bulk) => ` ${bulk}`
      | None => ""
      }
      `load ${printVReg(vreg)} ${deviceStr} ${property}${bulkStr}`
    }
  | DeviceStore(device, property, operand) => {
      let deviceStr = printDevice(device)
      `store ${deviceStr} ${property} ${printOperand(operand)}`
    }
  | Unary(vreg, op, operand) => {
      let opStr = switch op {
      | Abs => "abs"
      }
      `${opStr} ${printVReg(vreg)} ${printOperand(operand)}`
    }
  | Binary(vreg, op, left, right) =>
    `${printBinOp(op)} ${printVReg(vreg)} ${printOperand(left)} ${printOperand(right)}`
  | Compare(vreg, op, left, right) =>
    `${printCompareOp(op)} ${printVReg(vreg)} ${printOperand(left)} ${printOperand(right)}`
  | Goto(label) => `j ${label}`
  | Label(label) => `${label}:`
  | Bnez(operand, label) => `bnez ${printOperand(operand)} ${label}`
  | Call(label) => `jal ${label}`
  | Return => `j ra`
  | StackAlloc(count) => `stack_alloc ${Int.toString(count)}`
  | StackPoke(addr, operand) => `stack_poke ${Int.toString(addr)} ${printOperand(operand)}`
  | StackGet(vreg, addr) => `stack_get ${printVReg(vreg)} ${Int.toString(addr)}`
  | StackPush(operand) => `stack_push ${printOperand(operand)}`
  | RawInstruction(instruction) => instruction
  }
}

// Format a block
let printBlock = (block: IR.block): string => {
  let header = `# Block: ${block.name}\n`
  let instrs =
    block.instructions
    ->List.toArray
    ->Array.map(printInstr)
    ->Array.join("\n")
  header ++ instrs
}

// Format the entire IR program
let print = (ir: IR.t): string => {
  ir
  ->List.toArray
  ->Array.map(printBlock)
  ->Array.join("\n\n")
}
