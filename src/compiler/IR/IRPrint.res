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

// Format a branch operator
let printBranchOp = (op: IR.branchOp): string => {
  switch op {
  | BLT => "blt"
  | BGT => "bgt"
  | BEQ => "beq"
  | BLE => "ble"
  | BGE => "bge"
  | BNE => "bne"
  }
}

// Format an instruction
let printInstr = (instr: IR.instr): string => {
  switch instr {
  | DefInt(name, value) => `define ${name} ${Int.toString(value)}`
  | DefHash(name, value) => `define ${name} HASH("${value}")`
  | Move(vreg, operand) => `move ${printVReg(vreg)} ${printOperand(operand)}`
  | Load(vreg, device, param, bulkOpt) => {
      let deviceStr = `d${Int.toString(device)}`
      let paramStr = switch param {
      | Setting => "Setting"
      | Temperature => "Temperature"
      | Pressure => "Pressure"
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
  | Save(device, param, vreg) => {
      let deviceStr = `d${Int.toString(device)}`
      let paramStr = switch param {
      | Setting => "Setting"
      | Temperature => "Temperature"
      | Pressure => "Pressure"
      }
      `save ${deviceStr} ${paramStr} ${printVReg(vreg)}`
    }
  | Unary(op, vreg, operand) => {
      let opStr = switch op {
      | Abs => "abs"
      }
      `${opStr} ${printVReg(vreg)} ${printOperand(operand)}`
    }
  | Binary(op, vreg, left, right) =>
    `${printBinOp(op)} ${printVReg(vreg)} ${printOperand(left)} ${printOperand(right)}`
  | Goto(label) => `j ${label}`
  | Label(label) => `${label}:`
  | Branch(op, left, right, label) =>
    `${printBranchOp(op)} ${printOperand(left)} ${printOperand(right)} ${label}`
  }
}

// Format a block
let printBlock = (block: IR.block): string => {
  let header = `# Block: ${block.name}\n`
  let instrs = block.instructions
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
