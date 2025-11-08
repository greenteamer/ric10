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
  | BNE

type instr =
  | DefInt(string, int)
  | DefHash(string, string)
  | Move(vreg, operand)
  | Load(vreg, device, deviceParam, option<bulkOption>)
  | Save(device, deviceParam, vreg)
  | Unary(unOp, vreg, operand)
  | Binary(binOp, vreg, operand, operand)
  | Goto(string)
  | Label(string)
  | Branch(branchOp, operand, operand, string)

type block = {
  name: string,
  instructions: list<instr>,
}

type t = list<block>
