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

type compareOp =
  | GtOp
  | LtOp
  | EqOp
  | GeOp
  | LeOp
  | NeOp

type unOp = Abs

type instr =
  | DefInt(string, int)
  | DefHash(string, string)
  | Move(vreg, operand)
  | Load(vreg, device, deviceParam, option<bulkOption>)
  | Save(device, deviceParam, vreg)
  | Unary(vreg, unOp, operand)
  | Binary(vreg, binOp, operand, operand)
  | Goto(string)
  | Label(string)
  | Bnez(operand, string)

type block = {
  name: string,
  instructions: list<instr>,
}

type t = list<block>
