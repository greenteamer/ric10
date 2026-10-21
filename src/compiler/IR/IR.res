// Intermediate representation.
//
// A program is a list of blocks: the main block first, then one block per
// out-of-line function. Instructions use an unlimited number of virtual
// registers (vregs); IRToIC10 maps them onto r0..r15 after register allocation.
//
// The IR is backend-agnostic in spirit but mirrors IC10's value model: every
// value is a double, booleans are 0/1.

type vreg = int

type operand =
  | VReg(vreg)
  | Num(float)
  | Name(string) // reference to a `define`d constant
  | Hash(string) // HASH("...") evaluated by the game
  | Special(string) // physical register that is not allocatable: "ra", "sp"

type device =
  | Pin(string) // d0..d5, db                  -> l / s
  | Batch(operand) // prefab hash               -> lb / sb
  | BatchNamed(operand, operand) // prefab + name hash -> lbn / sbn

type binOp =
  | Add
  | Sub
  | Mul
  | Div
  | Mod
  | Min
  | Max
  | And
  | Or
  | Xor
  | Sll
  | Srl
  | Sra
  | Atan2

type unOp =
  | Abs
  | Sqrt
  | Floor
  | Ceil
  | Round
  | Trunc
  | Sin
  | Cos
  | Tan
  | Asin
  | Acos
  | Atan
  | Exp
  | Log
  | BitNot

type cmpOp =
  | Lt
  | Le
  | Gt
  | Ge
  | Eq
  | Ne

// Argument of a native (table-driven) IC10 instruction
type arg =
  | AOp(operand)
  | ATok(string) // logic type, slot logic type, batch mode, reagent mode
  | ADev(string) // device pin d0..d5/db

type instr =
  | DefNum(string, float) // define name value
  | DefHash(string, string) // define name HASH("...")
  | Move(vreg, operand)
  | Unary(vreg, unOp, operand)
  | Binary(vreg, binOp, operand, operand)
  | Compare(vreg, cmpOp, operand, operand) // slt/sgt/... (sXXz when rhs is 0)
  | Select(vreg, operand, operand, operand) // select dst cond a b
  | Label(string)
  | Goto(string)
  | Branch(cmpOp, operand, operand, string) // blt/bgt/... (bXXz when rhs is 0)
  | Call(string) // jal
  | Return // j ra
  | ReturnVia(vreg) // j rX (ra saved in a register by non-leaf functions)
  | DeviceLoad(vreg, device, string, option<string>) // l/ld/lb/lbn dst dev logicType [batchMode]
  | DeviceStore(device, string, operand) // s/sd/sb/sbn dev logicType value
  | Native(string, option<vreg>, array<arg>, bool) // opcode, dst, args, hasSideEffects
  | Raw(string)

type block = {
  name: string, // "main" or the function label
  instructions: array<instr>,
}

type t = array<block>

// ---------------------------------------------------------------------------
// Analysis helpers shared by the optimizer, liveness and the backends

let operandVRegs = (op: operand): array<vreg> =>
  switch op {
  | VReg(v) => [v]
  | Num(_) | Name(_) | Hash(_) | Special(_) => []
  }

let deviceVRegs = (d: device): array<vreg> =>
  switch d {
  | Pin(_) => []
  | Batch(op) => operandVRegs(op)
  | BatchNamed(a, b) => Array.concat(operandVRegs(a), operandVRegs(b))
  }

// Virtual registers read by an instruction
let uses = (i: instr): array<vreg> =>
  switch i {
  | DefNum(_) | DefHash(_) | Label(_) | Goto(_) | Call(_) | Return | Raw(_) => []
  | Move(_, a) | Unary(_, _, a) => operandVRegs(a)
  | Binary(_, _, a, b) | Compare(_, _, a, b) | Branch(_, a, b, _) =>
    Array.concat(operandVRegs(a), operandVRegs(b))
  | Select(_, c, a, b) => Array.flat([operandVRegs(c), operandVRegs(a), operandVRegs(b)])
  | ReturnVia(v) => [v]
  | DeviceLoad(_, d, _, _) => deviceVRegs(d)
  | DeviceStore(d, _, v) => Array.concat(deviceVRegs(d), operandVRegs(v))
  | Native(_, _, args, _) =>
    args->Array.flatMap(a =>
      switch a {
      | AOp(op) => operandVRegs(op)
      | ATok(_) | ADev(_) => []
      }
    )
  }

// Virtual register written by an instruction
let def = (i: instr): option<vreg> =>
  switch i {
  | Move(d, _)
  | Unary(d, _, _)
  | Binary(d, _, _, _)
  | Compare(d, _, _, _)
  | Select(d, _, _, _)
  | DeviceLoad(d, _, _, _) =>
    Some(d)
  | Native(_, d, _, _) => d
  | DefNum(_)
  | DefHash(_)
  | Label(_)
  | Goto(_)
  | Branch(_)
  | Call(_)
  | Return
  | ReturnVia(_)
  | DeviceStore(_)
  | Raw(_) =>
    None
  }

// Can the instruction be deleted when its result is unused?
let isPure = (i: instr): bool =>
  switch i {
  | Move(_) | Unary(_) | Binary(_) | Compare(_) | Select(_) | DeviceLoad(_) => true
  | Native(_, Some(_), _, hasSideEffects) => !hasSideEffects
  | Native(_, None, _, _)
  | DefNum(_)
  | DefHash(_)
  | Label(_)
  | Goto(_)
  | Branch(_)
  | Call(_)
  | Return
  | ReturnVia(_)
  | DeviceStore(_)
  | Raw(_) => false
  }

// Control never falls through to the next instruction
let isTerminator = (i: instr): bool =>
  switch i {
  | Goto(_) | Return | ReturnVia(_) => true
  | _ => false
  }

let branchTarget = (i: instr): option<string> =>
  switch i {
  | Goto(l) | Branch(_, _, _, l) => Some(l)
  | _ => None
  }

let invertCmp = (op: cmpOp): cmpOp =>
  switch op {
  | Lt => Ge
  | Le => Gt
  | Gt => Le
  | Ge => Lt
  | Eq => Ne
  | Ne => Eq
  }

let evalCmp = (op: cmpOp, a: float, b: float): bool =>
  switch op {
  | Lt => a < b
  | Le => a <= b
  | Gt => a > b
  | Ge => a >= b
  | Eq => a == b
  | Ne => a != b
  }

// Replace every vreg operand read by `i` using `f` (writes are untouched)
let mapUses = (i: instr, f: operand => operand): instr => {
  let mapDev = d =>
    switch d {
    | Pin(_) => d
    | Batch(op) => Batch(f(op))
    | BatchNamed(a, b) => BatchNamed(f(a), f(b))
    }
  switch i {
  | Move(d, a) => Move(d, f(a))
  | Unary(d, op, a) => Unary(d, op, f(a))
  | Binary(d, op, a, b) => Binary(d, op, f(a), f(b))
  | Compare(d, op, a, b) => Compare(d, op, f(a), f(b))
  | Select(d, c, a, b) => Select(d, f(c), f(a), f(b))
  | Branch(op, a, b, l) => Branch(op, f(a), f(b), l)
  | DeviceLoad(d, dev, p, m) => DeviceLoad(d, mapDev(dev), p, m)
  | DeviceStore(dev, p, v) => DeviceStore(mapDev(dev), p, f(v))
  | Native(op, d, args, se) =>
    Native(
      op,
      d,
      args->Array.map(a =>
        switch a {
        | AOp(o) => AOp(f(o))
        | ATok(_) | ADev(_) => a
        }
      ),
      se,
    )
  | DefNum(_) | DefHash(_) | Label(_) | Goto(_) | Call(_) | Return | ReturnVia(_) | Raw(_) => i
  }
}

// Replace the vreg written by `i` (no-op for instructions without a result)
let mapDef = (i: instr, d: vreg): instr =>
  switch i {
  | Move(_, a) => Move(d, a)
  | Unary(_, op, a) => Unary(d, op, a)
  | Binary(_, op, a, b) => Binary(d, op, a, b)
  | Compare(_, op, a, b) => Compare(d, op, a, b)
  | Select(_, c, a, b) => Select(d, c, a, b)
  | DeviceLoad(_, dev, p, m) => DeviceLoad(d, dev, p, m)
  | Native(op, Some(_), args, se) => Native(op, Some(d), args, se)
  | Native(_, None, _, _)
  | DefNum(_)
  | DefHash(_)
  | Label(_)
  | Goto(_)
  | Branch(_)
  | Call(_)
  | Return
  | ReturnVia(_)
  | DeviceStore(_)
  | Raw(_) => i
  }

// Largest vreg number used anywhere (-1 for none)
let maxVReg = (ir: t): int => {
  let m = ref(-1)
  ir->Array.forEach(b =>
    b.instructions->Array.forEach(i => {
      uses(i)->Array.forEach(v => m := Math.Int.max(m.contents, v))
      def(i)->Option.forEach(v => m := Math.Int.max(m.contents, v))
    })
  )
  m.contents
}
