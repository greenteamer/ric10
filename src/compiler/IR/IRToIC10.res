// IR -> IC10 assembly.
//
// Runs register allocation, drops moves that became `move rX rX`, re-runs jump
// cleanup and prints. Layout: defines, main code, then function bodies. When
// main can fall off its end and functions follow, main jumps to a trailing
// `__end:` label so execution stops exactly like a hand-written script.

type output = {
  code: string,
  registers: int,
  lines: int,
  spills: int,
}

let fmtNum = (n: float): string =>
  if n == 0. {
    "0"
  } else {
    Float.toString(n)
  }

let binOpName = (op: IR.binOp) =>
  switch op {
  | Add => "add"
  | Sub => "sub"
  | Mul => "mul"
  | Div => "div"
  | Mod => "mod"
  | Min => "min"
  | Max => "max"
  | And => "and"
  | Or => "or"
  | Xor => "xor"
  | Sll => "sll"
  | Srl => "srl"
  | Sra => "sra"
  | Atan2 => "atan2"
  }

let unOpName = (op: IR.unOp) =>
  switch op {
  | Abs => "abs"
  | Sqrt => "sqrt"
  | Floor => "floor"
  | Ceil => "ceil"
  | Round => "round"
  | Trunc => "trunc"
  | Sin => "sin"
  | Cos => "cos"
  | Tan => "tan"
  | Asin => "asin"
  | Acos => "acos"
  | Atan => "atan"
  | Exp => "exp"
  | Log => "log"
  | BitNot => "not"
  }

let cmpSuffix = (op: IR.cmpOp) =>
  switch op {
  | Lt => "lt"
  | Le => "le"
  | Gt => "gt"
  | Ge => "ge"
  | Eq => "eq"
  | Ne => "ne"
  }

// a OP b  ==  b (mirror OP) a
let mirrorCmp = (op: IR.cmpOp): IR.cmpOp =>
  switch op {
  | Lt => Gt
  | Le => Ge
  | Gt => Lt
  | Ge => Le
  | Eq => Eq
  | Ne => Ne
  }

let print = (ir: IR.t, ~reg: IR.vreg => string): array<string> => {
  let op = (o: IR.operand) =>
    switch o {
    | VReg(v) => reg(v)
    | Num(n) => fmtNum(n)
    | Name(n) => n
    | Hash(s) => `HASH("${s}")`
    | Special(s) => s
    }
  let dev = (d: IR.device) =>
    switch d {
    | Pin(p) => p
    | Batch(o) => op(o)
    | BatchNamed(a, b) => `${op(a)} ${op(b)}`
    }
  let isZero = (o: IR.operand) =>
    switch o {
    | Num(0.) => true
    | _ => false
    }
  let line = (i: IR.instr): option<string> =>
    switch i {
    | DefNum(n, v) => Some(`define ${n} ${fmtNum(v)}`)
    | DefHash(n, s) => Some(`define ${n} HASH("${s}")`)
    | Move(d, a) => Some(`move ${reg(d)} ${op(a)}`)
    | Unary(d, o, a) => Some(`${unOpName(o)} ${reg(d)} ${op(a)}`)
    | Binary(d, o, a, b) => Some(`${binOpName(o)} ${reg(d)} ${op(a)} ${op(b)}`)
    | Compare(d, c, a, b) =>
      if isZero(b) {
        Some(`s${cmpSuffix(c)}z ${reg(d)} ${op(a)}`)
      } else if isZero(a) {
        Some(`s${cmpSuffix(mirrorCmp(c))}z ${reg(d)} ${op(b)}`)
      } else {
        Some(`s${cmpSuffix(c)} ${reg(d)} ${op(a)} ${op(b)}`)
      }
    | Select(d, c, a, b) => Some(`select ${reg(d)} ${op(c)} ${op(a)} ${op(b)}`)
    | Label(l) => Some(`${l}:`)
    | Goto(l) => Some(`j ${l}`)
    | Branch(c, a, b, l) =>
      if isZero(b) {
        Some(`b${cmpSuffix(c)}z ${op(a)} ${l}`)
      } else if isZero(a) {
        Some(`b${cmpSuffix(mirrorCmp(c))}z ${op(b)} ${l}`)
      } else {
        Some(`b${cmpSuffix(c)} ${op(a)} ${op(b)} ${l}`)
      }
    | Call(l) => Some(`jal ${l}`)
    | Return => Some("j ra")
    | ReturnVia(v) => Some(`j ${reg(v)}`)
    | DeviceLoad(d, device, prop, mode) =>
      let opcode = switch device {
      | Pin(_) => "l"
      | Batch(_) => "lb"
      | BatchNamed(_) => "lbn"
      }
      let m = mode->Option.mapOr("", m => " " ++ m)
      Some(`${opcode} ${reg(d)} ${dev(device)} ${prop}${m}`)
    | DeviceStore(device, prop, v) =>
      let opcode = switch device {
      | Pin(_) => "s"
      | Batch(_) => "sb"
      | BatchNamed(_) => "sbn"
      }
      Some(`${opcode} ${dev(device)} ${prop} ${op(v)}`)
    | Native(opcode, d, args, _) =>
      let parts = [opcode]
      d->Option.forEach(r => parts->Array.push(reg(r)))
      args->Array.forEach(a =>
        parts->Array.push(
          switch a {
          | AOp(o) => op(o)
          | ATok(t) => t
          | ADev(p) => p
          },
        )
      )
      Some(parts->Array.join(" "))
    | Raw(text) => Some(text)
    }
  let lines = []
  ir->Array.forEachWithIndex((b, bi) => {
    b.instructions->Array.forEach(i => line(i)->Option.forEach(l => lines->Array.push(l)))
    if bi == 0 && Array.length(ir) > 1 {
      let fallsOff = switch b.instructions->Array.at(-1) {
      | Some(last) => !IR.isTerminator(last)
      | None => true
      }
      if fallsOff {
        lines->Array.push("j __end")
      }
    }
  })
  if Array.length(ir) > 1 && lines->Array.includes("j __end") {
    lines->Array.push("__end:")
  }
  lines
}

let generate = (ir: IR.t, ~names: Dict.t<string>): output => {
  let alloc = RegAlloc.allocate(ir, ~names)
  let color = alloc.colorOf
  // copies between coalesced registers disappear
  let ir = alloc.ir->IROptimizer.mapBlocks(instrs =>
    instrs->Array.filter(i =>
      switch i {
      | Move(d, VReg(s)) => color(d) != color(s)
      | _ => true
      }
    )
  )
  let ir = IROptimizer.simplifyJumps(IROptimizer.simplifyJumps(ir))
  let lines = print(ir, ~reg=v => `r${Int.toString(color(v))}`)
  {
    code: lines->Array.join("\n"),
    registers: alloc.registersUsed,
    lines: Array.length(lines),
    spills: alloc.spills,
  }
}
