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
  | DevicePin(pin) => `d${Int.toString(pin)}`
  | DeviceReg(vreg) => printVReg(vreg)
  }
}

// Format an instruction
let printInstr = (instr: IR.instr): string => {
  switch instr {
  | DefInt(name, value) => `define ${name} ${Int.toString(value)}`
  | DefHash(name, value) => `define ${name} HASH("${value}")`
  | Move(vreg, operand) => `move ${printVReg(vreg)} ${printOperand(operand)}`
  | Load(vreg, device, param, bulkOpt) => {
      let deviceStr = printDevice(device)
      let paramStr = switch param {
      | Setting => "Setting"
      | Temperature => "Temperature"
      | Pressure => "Pressure"
      | On => "On"
      | Open => "Open"
      | Mode => "Mode"
      | Lock => "Lock"
      }
      let bulkStr = switch bulkOpt {
      | Some(Maximum) => " Maximum"
      | Some(Minimum) => " Minimum"
      | Some(Average) => " Average"
      | Some(Sum) => " Sum"
      | None => ""
      }
      `load ${printVReg(vreg)} ${deviceStr} ${paramStr}${bulkStr}`
    }
  | Save(device, param, operand) => {
      let deviceStr = printDevice(device)
      let paramStr = switch param {
      | Setting => "Setting"
      | Temperature => "Temperature"
      | Pressure => "Pressure"
      | On => "On"
      | Open => "Open"
      | Mode => "Mode"
      | Lock => "Lock"
      }
      `save ${deviceStr} ${paramStr} ${printOperand(operand)}`
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
