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
  | On
  | Open
  | Mode
  | Lock

type device =
  | DevicePin(int) // d0, d1, d2, etc.
  | DeviceReg(vreg) // device stored in register

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
  | Save(device, deviceParam, operand)
  | Unary(vreg, unOp, operand)
  | Binary(vreg, binOp, operand, operand)
  | Compare(vreg, compareOp, operand, operand)
  | Goto(string)
  | Label(string)
  | Bnez(operand, string)
  // Stack operations for variant support
  | StackAlloc(int) // Reserve N stack slots (emit N × push 0)
  | StackPoke(int, operand) // poke address value (write to stack without changing sp)
  | StackGet(vreg, int) // get vreg db address (read from stack without changing sp)
  | StackPush(operand) // push value (write and increment sp)
  // Raw IC10 assembly
  | RawInstruction(string) // Emit raw IC10 assembly directly (e.g., yield)

type block = {
  name: string,
  instructions: list<instr>,
}

type t = list<block>
