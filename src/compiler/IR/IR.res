type name = string
type label = string
type vreg = int

type operand =
  | VReg(vreg)
  | Num(int)

type bulkOption =
  | Maximum
  | Minimum
  | Average
  | Sum

type deviceParam =
  | Setting
  | Temperature
  | Pressure

type binOp =
  | AddOp
  | SubOp
  | MulOp
  | DivOp

type unOp = Abs

type branchOp =
  | BLT
  | BGT
  | BEQ
  | BLE
  | BGE

type defOperand =
  | DefNum(int)
  | DefHash(name)

type instr =
  | Def(name, defOperand)
  | Move(vreg, operand)
  | Load(vreg, device, deviceParam, option<bulkOption>)
  | Save(device, deviceParam, vreg)
  | Unary(unOp, vreg, operand)
  | Binary(binOp, vreg, operand, operand)
  | Goto(label)
  | Label(label)
  | Branch

type block = {
  name: name,
  instructions: list<instr>,
}

type t = list<block>
