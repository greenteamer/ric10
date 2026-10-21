// IR optimizer. Passes are data: `passes` lists them in execution order and the
// whole list runs to a fixpoint. A test pins the order (`passNames`).

module IntSet = Belt.Set.Int

type pass = {
  name: string,
  run: IR.t => IR.t,
}

let mapBlocks = (ir: IR.t, f: array<IR.instr> => array<IR.instr>): IR.t =>
  ir->Array.map(b => {...b, instructions: f(b.instructions)})

// IC10 arithmetic semantics shared with the test emulator
let ic10Mod = (a, b) => a -. b *. Math.floor(a /. b)

let isSmallInt = x => NumUtil.isInteger(x) && x >= -2147483648. && x < 2147483648.

// ---------------------------------------------------------------------------
// Constant folding and algebraic identities

let defineValues = (ir: IR.t): Dict.t<float> => {
  let d = Dict.make()
  ir->Array.forEach(b =>
    b.instructions->Array.forEach(i =>
      switch i {
      | DefNum(name, v) => d->Dict.set(name, v)
      | _ => ()
      }
    )
  )
  d
}

let foldConstants = (ir: IR.t): IR.t => {
  let defines = defineValues(ir)
  let known = (op: IR.operand) =>
    switch op {
    | Num(n) => Some(n)
    | Name(n) => defines->Dict.get(n)
    | _ => None
    }
  let evalBin = (op: IR.binOp, a, b): option<float> =>
    switch op {
    | Add => Some(a +. b)
    | Sub => Some(a -. b)
    | Mul => Some(a *. b)
    | Div => b == 0. ? None : Some(a /. b)
    | Mod => b == 0. ? None : Some(ic10Mod(a, b))
    | Min => Some(Math.min(a, b))
    | Max => Some(Math.max(a, b))
    | And if isSmallInt(a) && isSmallInt(b) =>
      Some(Int.toFloat(Int.bitwiseAnd(Float.toInt(a), Float.toInt(b))))
    | Or if isSmallInt(a) && isSmallInt(b) =>
      Some(Int.toFloat(Int.bitwiseOr(Float.toInt(a), Float.toInt(b))))
    | Xor if isSmallInt(a) && isSmallInt(b) =>
      Some(Int.toFloat(Int.bitwiseXor(Float.toInt(a), Float.toInt(b))))
    | And | Or | Xor | Sll | Srl | Sra | Atan2 => None
    }
  let evalUn = (op: IR.unOp, a): option<float> =>
    switch op {
    | Abs => Some(Math.abs(a))
    | Floor => Some(Math.floor(a))
    | Ceil => Some(Math.ceil(a))
    | Trunc => Some(Math.trunc(a))
    | Sqrt => a >= 0. ? Some(Math.sqrt(a)) : None
    | Round | Sin | Cos | Tan | Asin | Acos | Atan | Exp | Log | BitNot => None
    }
  let foldInstr = (i: IR.instr): option<IR.instr> =>
    switch i {
    | Binary(d, op, a, b) =>
      switch (known(a), known(b)) {
      | (Some(x), Some(y)) =>
        switch evalBin(op, x, y) {
        | Some(r) => Some(Move(d, Num(r)))
        | None => Some(i)
        }
      | (_, Some(0.)) if op == Add || op == Sub => Some(Move(d, a))
      | (Some(0.), _) if op == Add => Some(Move(d, b))
      | (_, Some(1.)) if op == Mul || op == Div => Some(Move(d, a))
      | (Some(1.), _) if op == Mul => Some(Move(d, b))
      | (_, Some(0.)) | (Some(0.), _) if op == Mul => Some(Move(d, Num(0.)))
      | _ => Some(i)
      }
    | Unary(d, op, a) =>
      switch known(a)->Option.flatMap(x => evalUn(op, x)) {
      | Some(r) => Some(Move(d, Num(r)))
      | None => Some(i)
      }
    | Compare(d, op, a, b) =>
      switch (known(a), known(b)) {
      | (Some(x), Some(y)) => Some(Move(d, Num(IR.evalCmp(op, x, y) ? 1. : 0.)))
      | _ => Some(i)
      }
    | Select(d, c, a, b) =>
      switch known(c) {
      | Some(x) => Some(Move(d, x != 0. ? a : b))
      | None => a == b ? Some(Move(d, a)) : Some(i)
      }
    | Branch(op, a, b, l) =>
      switch (known(a), known(b)) {
      | (Some(x), Some(y)) => IR.evalCmp(op, x, y) ? Some(Goto(l)) : None
      | _ => Some(i)
      }
    | Move(d, VReg(s)) if d == s => None
    | _ => Some(i)
    }
  ir->mapBlocks(instrs => instrs->Array.filterMap(foldInstr))
}

// ---------------------------------------------------------------------------
// Local (basic block) constant and copy propagation

let propagateCopies = (ir: IR.t): IR.t =>
  ir->mapBlocks(instrs => {
    let env = ref(Belt.Map.Int.empty)
    instrs->Array.map(i => {
      let i = switch i {
      | Label(_) | Call(_) | Raw(_) =>
        env := Belt.Map.Int.empty
        i
      | _ =>
        IR.mapUses(i, op =>
          switch op {
          | VReg(v) => env.contents->Belt.Map.Int.get(v)->Option.getOr(op)
          | _ => op
          }
        )
      }
      switch IR.def(i) {
      | Some(d) =>
        env :=
          env.contents
          ->Belt.Map.Int.remove(d)
          ->Belt.Map.Int.keep((_, op) => op != IR.VReg(d))
        switch i {
        | Move(_, VReg(s)) if s == d => ()
        | Move(_, (VReg(_) | Num(_) | Name(_) | Hash(_)) as src) =>
          env := env.contents->Belt.Map.Int.set(d, src)
        | _ => ()
        }
      | None => ()
      }
      i
    })
  })

// ---------------------------------------------------------------------------
// Dead code elimination (whole-program liveness)

let eliminateDeadCode = (ir: IR.t): IR.t => {
  let live = Liveness.analyze(ir)
  let keep = live.instrs->Array.mapWithIndex((i, idx) =>
    switch IR.def(i) {
    | Some(d) if IR.isPure(i) => live.liveOut->Array.getUnsafe(idx)->IntSet.has(d)
    | _ => true
    }
  )
  ir->Array.mapWithIndex((b, bi) => {
    let start = live.blockStart->Array.getUnsafe(bi)
    {
      ...b,
      instructions: b.instructions->Array.filterWithIndex((_, j) => keep->Array.getUnsafe(start + j)),
    }
  })
}

// ---------------------------------------------------------------------------
// Control flow cleanup

let referencedLabels = (ir: IR.t): Dict.t<bool> => {
  let refs = Dict.make()
  ir->Array.forEach(b =>
    b.instructions->Array.forEach(i =>
      switch i {
      | Goto(l) | Branch(_, _, _, l) | Call(l) => refs->Dict.set(l, true)
      | _ => ()
      }
    )
  )
  refs
}

let simplifyBlock = (instrs: array<IR.instr>): array<IR.instr> => {
  let labelAt = Dict.make()
  instrs->Array.forEachWithIndex((i, idx) =>
    switch i {
    | Label(l) => labelAt->Dict.set(l, idx)
    | _ => ()
    }
  )
  // first non-label instruction at or after idx
  let rec skipLabels = idx =>
    switch instrs[idx] {
    | Some(Label(_)) => skipLabels(idx + 1)
    | Some(_) => Some(idx)
    | None => None
    }
  // follow chains of `L: j M`
  let rec resolve = (l, depth) =>
    if depth > 16 {
      l
    } else {
      switch labelAt->Dict.get(l)->Option.flatMap(idx => skipLabels(idx)) {
      | Some(idx) =>
        switch instrs->Array.getUnsafe(idx) {
        | Goto(m) if m != l => resolve(m, depth + 1)
        | _ => l
        }
      | None => l
      }
    }
  let retargeted = instrs->Array.map(i =>
    switch i {
    | Goto(l) => IR.Goto(resolve(l, 0))
    | Branch(op, a, b, l) => Branch(op, a, b, resolve(l, 0))
    | _ => i
    }
  )
  // labels that follow position idx with only labels in between
  let fallsInto = (arr: array<IR.instr>, idx, l) => {
    let rec go = j =>
      switch arr[j] {
      | Some(Label(x)) => x == l ? true : go(j + 1)
      | _ => false
      }
    go(idx + 1)
  }
  let out = []
  let n = Array.length(retargeted)
  let i = ref(0)
  while i.contents < n {
    let cur = retargeted->Array.getUnsafe(i.contents)
    switch (cur, retargeted[i.contents + 1], retargeted[i.contents + 2]) {
    // bXX a b L1; j L2; L1:  ->  bNXX a b L2; L1:
    | (Branch(op, a, b, l1), Some(Goto(l2)), Some(Label(l3))) if l1 == l3 =>
      out->Array.push(IR.Branch(IR.invertCmp(op), a, b, l2))
      i := i.contents + 2
    | ((Goto(l) | Branch(_, _, _, l)), _, _) if fallsInto(retargeted, i.contents, l) =>
      i := i.contents + 1
    | _ =>
      out->Array.push(cur)
      i := i.contents + 1
    }
  }
  out
}

let simplifyJumps = (ir: IR.t): IR.t => {
  let ir = ir->mapBlocks(simplifyBlock)
  let refs = referencedLabels(ir)
  ir->Array.mapWithIndex((b, bi) => {
    let instrs = b.instructions
    // a function's entry label is always kept; main has no entry label
    // drop unreachable code and unreferenced labels
    let reachable = ref(true)
    let instructions = instrs->Array.filterWithIndex((i, idx) =>
      switch i {
      | Label(l) =>
        if (idx == 0 && bi > 0) || refs->Dict.get(l) != None {
          reachable := true
          true
        } else {
          false
        }
      | _ =>
        let keep = reachable.contents
        if IR.isTerminator(i) {
          reachable := false
        }
        keep
      }
    )
    {...b, instructions}
  })
}

// ---------------------------------------------------------------------------
// Whole-program cleanup

let removeUnusedFunctions = (ir: IR.t): IR.t => {
  let byName = Dict.make()
  ir->Array.forEach(b => byName->Dict.set(b.name, b))
  let reached = Dict.make()
  let rec visit = (b: IR.block) =>
    if reached->Dict.get(b.name) == None {
      reached->Dict.set(b.name, true)
      b.instructions->Array.forEach(i =>
        switch i {
        | Call(f) => byName->Dict.get(f)->Option.forEach(visit)
        | _ => ()
        }
      )
    }
  ir[0]->Option.forEach(visit)
  ir->Array.filterWithIndex((b, i) => i == 0 || reached->Dict.get(b.name) != None)
}

let removeUnusedDefines = (ir: IR.t): IR.t => {
  let used = Dict.make()
  let mark = (op: IR.operand) =>
    switch op {
    | Name(n) => used->Dict.set(n, true)
    | _ => ()
    }
  let rawText = []
  ir->Array.forEach(b =>
    b.instructions->Array.forEach(i => {
      let _ = IR.mapUses(i, op => {
        mark(op)
        op
      })
      switch i {
      | Raw(t) => rawText->Array.push(t)
      | _ => ()
      }
    })
  )
  let raw = rawText->Array.join("\n")
  let usedInRaw = name => RegExp.test(RegExp.fromString(`\\b${name}\\b`), raw)
  ir->mapBlocks(instrs =>
    instrs->Array.filter(i =>
      switch i {
      | DefNum(n, _) | DefHash(n, _) => used->Dict.get(n) != None || usedInRaw(n)
      | _ => true
      }
    )
  )
}

let passes: array<pass> = [
  {name: "foldConstants", run: foldConstants},
  {name: "propagateCopies", run: propagateCopies},
  {name: "eliminateDeadCode", run: eliminateDeadCode},
  {name: "simplifyJumps", run: simplifyJumps},
  {name: "removeUnusedFunctions", run: removeUnusedFunctions},
  {name: "removeUnusedDefines", run: removeUnusedDefines},
]

let passNames = passes->Array.map(p => p.name)

let optimize = (ir: IR.t): IR.t => {
  let current = ref(ir)
  let changed = ref(true)
  let rounds = ref(0)
  while changed.contents && rounds.contents < 20 {
    let next = passes->Array.reduce(current.contents, (acc, p) => p.run(acc))
    changed := next != current.contents
    current := next
    rounds := rounds.contents + 1
  }
  current.contents
}
