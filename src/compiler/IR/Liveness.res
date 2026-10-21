// Whole-program liveness analysis over the IR.
//
// Calls are handled with summaries instead of call edges:
//   gen(f)      = vregs f may read before writing them (params, globals),
//                 computed with an empty exit set;
//   through(f)  = union of what is live after every call site of f.
// At a call site `Call(f)`: liveIn = liveOut ∪ gen(f).
// Inside f:     live after `Return` = through(f).
// Values that survive a call are therefore live everywhere inside the callee,
// so the register allocator never lets a callee clobber its caller.

module IntSet = Belt.Set.Int

type t = {
  instrs: array<IR.instr>, // all blocks flattened, main first
  blockOfInstr: array<int>,
  blockStart: array<int>,
  liveIn: array<IntSet.t>,
  liveOut: array<IntSet.t>,
}

let fail = (~fn, message) => Errors.fail(~file="Liveness.res", ~fn, message)

let analyze = (ir: IR.t): t => {
  let instrs = []
  let blockOfInstr = []
  let blockStart = []
  ir->Array.forEachWithIndex((b, bi) => {
    blockStart->Array.push(Array.length(instrs))
    b.instructions->Array.forEach(i => {
      instrs->Array.push(i)
      blockOfInstr->Array.push(bi)
    })
  })
  let n = Array.length(instrs)
  let blockEnd = bi =>
    bi + 1 < Array.length(blockStart) ? blockStart->Array.getUnsafe(bi + 1) : n

  // label -> instruction index; function name -> block index
  let labelIndex = Dict.make()
  instrs->Array.forEachWithIndex((i, idx) =>
    switch i {
    | Label(l) => labelIndex->Dict.set(l, idx)
    | _ => ()
    }
  )
  let blockByName = Dict.make()
  ir->Array.forEachWithIndex((b, bi) => blockByName->Dict.set(b.name, bi))

  let target = (l, ~fn) =>
    switch labelIndex->Dict.get(l) {
    | Some(idx) => idx
    | None => fail(~fn, `jump to undefined label '${l}'`)
    }
  let calleeBlock = name =>
    switch blockByName->Dict.get(name) {
    | Some(bi) => bi
    | None => fail(~fn="analyze", `call to undefined function '${name}'`)
    }

  let uses = instrs->Array.map(i => IntSet.fromArray(IR.uses(i)))
  let defs = instrs->Array.map(IR.def)

  let liveIn = Array.make(~length=n, IntSet.empty)
  let liveOut = Array.make(~length=n, IntSet.empty)
  let gens = Array.make(~length=Array.length(ir), IntSet.empty)
  let through = Array.make(~length=Array.length(ir), IntSet.empty)

  // Backward fixpoint over one block with the given exit set
  let solveBlock = (bi, exitSet) => {
    let start = blockStart->Array.getUnsafe(bi)
    let stop = blockEnd(bi)
    let changed = ref(true)
    while changed.contents {
      changed := false
      for idx in stop - 1 downto start {
        let instr = instrs->Array.getUnsafe(idx)
        let next = idx + 1 < stop ? liveIn->Array.getUnsafe(idx + 1) : IntSet.empty
        let out = switch instr {
        | Goto(l) => liveIn->Array.getUnsafe(target(l, ~fn="solveBlock"))
        | Branch(_, _, _, l) | BranchIf(_, _, l) =>
          IntSet.union(next, liveIn->Array.getUnsafe(target(l, ~fn="solveBlock")))
        | Return | ReturnVia(_) => exitSet
        | _ => next
        }
        let killed = switch defs->Array.getUnsafe(idx) {
        | Some(d) => out->IntSet.remove(d)
        | None => out
        }
        let extra = switch instr {
        | Call(name) => gens->Array.getUnsafe(calleeBlock(name))
        | _ => IntSet.empty
        }
        let inn = IntSet.union(uses->Array.getUnsafe(idx), IntSet.union(extra, killed))
        if !IntSet.eq(inn, liveIn->Array.getUnsafe(idx)) || !IntSet.eq(out, liveOut->Array.getUnsafe(idx)) {
          liveIn->Array.setUnsafe(idx, inn)
          liveOut->Array.setUnsafe(idx, out)
          changed := true
        }
      }
    }
  }

  // 1. Function summaries (call graph is acyclic: IRGen rejects recursion)
  let funcs = Array.fromInitializer(~length=Array.length(ir) - 1, i => i + 1)
  let changed = ref(true)
  let rounds = ref(0)
  while changed.contents {
    changed := false
    rounds := rounds.contents + 1
    if rounds.contents > Array.length(ir) + 2 {
      fail(~fn="analyze", "recursive calls detected")
    }
    funcs->Array.forEach(bi => {
      solveBlock(bi, IntSet.empty)
      let g = liveIn->Array.getUnsafe(blockStart->Array.getUnsafe(bi))
      if !IntSet.eq(g, gens->Array.getUnsafe(bi)) {
        gens->Array.setUnsafe(bi, g)
        changed := true
      }
    })
  }

  // 2. Global fixpoint: through(f) from the liveness after each call site
  let changed = ref(true)
  while changed.contents {
    changed := false
    ir->Array.forEachWithIndex((_, bi) => solveBlock(bi, through->Array.getUnsafe(bi)))
    let next = Array.make(~length=Array.length(ir), IntSet.empty)
    instrs->Array.forEachWithIndex((i, idx) =>
      switch i {
      | Call(name) =>
        let callee = calleeBlock(name)
        next->Array.setUnsafe(callee, IntSet.union(next->Array.getUnsafe(callee), liveOut->Array.getUnsafe(idx)))
      | _ => ()
      }
    )
    next->Array.forEachWithIndex((s, bi) =>
      if !IntSet.eq(s, through->Array.getUnsafe(bi)) {
        through->Array.setUnsafe(bi, s)
        changed := true
      }
    )
  }

  {instrs, blockOfInstr, blockStart, liveIn, liveOut}
}
