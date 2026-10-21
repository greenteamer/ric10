// Register allocation: virtual registers -> r0..r15, with spilling to the stack.
//
// 1. Build the interference graph from whole-program liveness.
// 2. Coalesce move-related vregs that do not interfere (removes copies).
// 3. Greedy colouring in program order, preferring a move partner's register.
// 4. If colouring fails, spill one vreg to a stack slot and start over: every
//    definition is followed by `poke slot value`, every use is preceded by
//    `get tmp db slot`. Candidates are ranked by (accesses weighted by loop
//    depth) / (live-range length), so long-lived state such as variant refs
//    and loop-carried refs goes to the stack first while short-lived
//    temporaries stay in registers. Slots are taken from the top of the
//    512-slot stack downwards (`firstSpillSlot`), away from user push/pop.

module IntSet = Belt.Set.Int

let file = "RegAlloc.res"
let registerCount = 16
let stackSize = 512
let firstSpillSlot = stackSize - 1
let maxSpills = 64

type result = {
  ir: IR.t, // the program after spill rewriting
  colorOf: IR.vreg => int,
  registersUsed: int,
  spills: int,
}

// Physical registers referenced by %raw(...) code are never allocated
let reservedRegisters = (ir: IR.t): array<int> => {
  let out = []
  ir->Array.forEach(b =>
    b.instructions->Array.forEach(i =>
      switch i {
      | Raw(text) =>
        let re = /\br(1[0-5]|[0-9])\b/g
        let rec loop = () =>
          switch RegExp.exec(re, text) {
          | Some(m) =>
            switch m[1] {
            | Some(Some(d)) =>
              switch Int.fromString(d) {
              | Some(r) if !(out->Array.includes(r)) => out->Array.push(r)
              | _ => ()
              }
            | _ => ()
            }
            loop()
          | None => ()
          }
        loop()
      | _ => ()
      }
    )
  )
  out
}

let key = Int.toString

// Loop nesting depth of every instruction in the flattened program: a
// backward jump at index j to a label at index t encloses [t, j].
let loopDepths = (live: Liveness.t): array<int> => {
  let n = Array.length(live.instrs)
  let depth = Array.make(~length=n, 0)
  let labelAt = Dict.make()
  live.instrs->Array.forEachWithIndex((i, idx) =>
    switch i {
    | Label(l) => labelAt->Dict.set(l, idx)
    | _ => ()
    }
  )
  live.instrs->Array.forEachWithIndex((i, idx) =>
    switch IR.branchTarget(i)->Option.flatMap(l => labelAt->Dict.get(l)) {
    | Some(t) if t <= idx =>
      for k in t to idx {
        depth->Array.setUnsafe(k, depth->Array.getUnsafe(k) + 1)
      }
    | _ => ()
    }
  )
  depth
}

type graph = {
  order: array<IR.vreg>, // vregs in order of first appearance
  neighbors: IR.vreg => IntSet.t,
  moves: array<(IR.vreg, IR.vreg)>, // (dst, src) of register-to-register moves
  pressureAt: int, // instruction index with the most live values
}

let buildGraph = (live: Liveness.t): graph => {
  let adj: Dict.t<IntSet.t> = Dict.make()
  let order = []
  let touch = v =>
    if adj->Dict.get(key(v)) == None {
      order->Array.push(v)
      adj->Dict.set(key(v), IntSet.empty)
    }
  let neighbors = v => adj->Dict.get(key(v))->Option.getOr(IntSet.empty)
  let addEdge = (a, b) =>
    if a != b {
      touch(a)
      touch(b)
      adj->Dict.set(key(a), neighbors(a)->IntSet.add(b))
      adj->Dict.set(key(b), neighbors(b)->IntSet.add(a))
    }
  let moves = []
  let worst = ref(0)
  live.instrs->Array.forEachWithIndex((instr, idx) => {
    IR.uses(instr)->Array.forEach(touch)
    let out = live.liveOut->Array.getUnsafe(idx)
    if IntSet.size(out) > IntSet.size(live.liveOut->Array.getUnsafe(worst.contents)) {
      worst := idx
    }
    switch IR.def(instr) {
    | Some(d) =>
      touch(d)
      let exempt = switch instr {
      | Move(_, VReg(s)) =>
        moves->Array.push((d, s))
        Some(s)
      | _ => None
      }
      out->IntSet.forEach(v =>
        if Some(v) != exempt {
          addEdge(d, v)
        }
      )
    | None => ()
    }
  })
  // values live at program start (read before written) are mutually live
  let entry = live.liveIn[0]->Option.getOr(IntSet.empty)->IntSet.toArray
  entry->Array.forEach(a => entry->Array.forEach(b => addEdge(a, b)))
  {order, neighbors, moves, pressureAt: worst.contents}
}

// Greedy colouring; None when some vreg cannot get a register
let colorWith = (g: graph, ~reserved: array<int>, ~coalesce: bool): option<Dict.t<int>> => {
  let parent = Dict.make()
  let rec find = v =>
    switch parent->Dict.get(key(v)) {
    | Some(p) if p != v =>
      let r = find(p)
      parent->Dict.set(key(v), r)
      r
    | _ => v
    }
  let gAdj: Dict.t<IntSet.t> = Dict.make()
  g.order->Array.forEach(v => gAdj->Dict.set(key(v), g.neighbors(v)))
  let gNeighbors = v => gAdj->Dict.get(key(v))->Option.getOr(IntSet.empty)
  if coalesce {
    g.moves->Array.forEach(((d, s)) => {
      let a = find(d)
      let b = find(s)
      if a != b && !(gNeighbors(a)->IntSet.has(b)) {
        parent->Dict.set(key(b), a)
        gAdj->Dict.set(key(a), IntSet.union(gNeighbors(a), gNeighbors(b)))
        gNeighbors(b)->IntSet.forEach(nb => {
          gAdj->Dict.set(key(nb), gNeighbors(nb)->IntSet.remove(b)->IntSet.add(a))
        })
      }
    })
  }
  let partners = Dict.make()
  g.moves->Array.forEach(((d, s)) => {
    let a = find(d)
    let b = find(s)
    if a != b {
      partners->Dict.set(key(a), Array.concat(partners->Dict.get(key(a))->Option.getOr([]), [b]))
      partners->Dict.set(key(b), Array.concat(partners->Dict.get(key(b))->Option.getOr([]), [a]))
    }
  })
  let color = Dict.make()
  let ok = ref(true)
  g.order->Array.forEach(v => {
    let r = find(v)
    if ok.contents && color->Dict.get(key(r)) == None {
      let taken = gNeighbors(r)->IntSet.toArray->Array.filterMap(nb => color->Dict.get(key(find(nb))))
      let free = c => !(taken->Array.includes(c)) && !(reserved->Array.includes(c))
      let preferred =
        partners
        ->Dict.get(key(r))
        ->Option.getOr([])
        ->Array.filterMap(p => color->Dict.get(key(find(p))))
        ->Array.find(free)
      let chosen = switch preferred {
      | Some(c) => Some(c)
      | None =>
        let c = ref(None)
        for i in registerCount - 1 downto 0 {
          if free(i) {
            c := Some(i)
          }
        }
        c.contents
      }
      switch chosen {
      | Some(c) => color->Dict.set(key(r), c)
      | None => ok := false
      }
    }
  })
  if ok.contents {
    let final = Dict.make()
    g.order->Array.forEach(v => final->Dict.set(key(v), color->Dict.get(key(find(v)))->Option.getOr(0)))
    Some(final)
  } else {
    None
  }
}

// Pick the vreg whose eviction frees the most pressure per access
let chooseSpill = (live: Liveness.t, g: graph, ~available: int, ~noSpill: Dict.t<bool>): option<
  IR.vreg,
> => {
  let depth = loopDepths(live)
  let accesses = Dict.make()
  let first = Dict.make()
  let last = Dict.make()
  let note = (v, idx, w) => {
    accesses->Dict.set(key(v), accesses->Dict.get(key(v))->Option.getOr(0.) +. w)
    if first->Dict.get(key(v)) == None {
      first->Dict.set(key(v), idx)
    }
    last->Dict.set(key(v), idx)
  }
  live.instrs->Array.forEachWithIndex((i, idx) => {
    let w = Math.pow(10., ~exp=Int.toFloat(Math.Int.min(depth->Array.getUnsafe(idx), 3)))
    IR.uses(i)->Array.forEach(v => note(v, idx, w))
    IR.def(i)->Option.forEach(v => note(v, idx, w))
  })
  // live-range length: number of instructions where v is live-out
  let span = Dict.make()
  live.liveOut->Array.forEach(s =>
    s->IntSet.forEach(v => span->Dict.set(key(v), span->Dict.get(key(v))->Option.getOr(0) + 1))
  )
  let cost = v =>
    accesses->Dict.get(key(v))->Option.getOr(0.) /.
      Int.toFloat(Math.Int.max(1, span->Dict.get(key(v))->Option.getOr(1)))
  let candidates =
    g.order->Array.filter(v =>
      noSpill->Dict.get(key(v)) == None &&
      span->Dict.get(key(v))->Option.getOr(0) > 1 &&
      IntSet.size(g.neighbors(v)) >= available
    )
  let candidates = if Array.length(candidates) > 0 {
    candidates
  } else {
    g.order->Array.filter(v =>
      noSpill->Dict.get(key(v)) == None && span->Dict.get(key(v))->Option.getOr(0) > 1
    )
  }
  candidates->Array.reduce(None, (best, v) =>
    switch best {
    | Some(b) if cost(b) <= cost(v) => best
    | _ => Some(v)
    }
  )
}

// Rewrite the program so that `v` lives in stack slot `slot`
let spillVReg = (ir: IR.t, v: IR.vreg, slot: int, ~fresh: unit => IR.vreg, ~temps: Dict.t<bool>): IR.t =>
  ir->Array.map(b => {
    ...b,
    instructions: b.instructions->Array.flatMap(i => {
      let usesV = IR.uses(i)->Array.includes(v)
      let defsV = IR.def(i) == Some(v)
      if !usesV && !defsV {
        [i]
      } else {
        let out = []
        let i = if usesV {
          let t = fresh()
          temps->Dict.set(key(t), true)
          out->Array.push(IR.Native("get", Some(t), [ADev("db"), AOp(Num(Int.toFloat(slot)))], false))
          IR.mapUses(i, op => op == VReg(v) ? VReg(t) : op)
        } else {
          i
        }
        if defsV {
          let t = fresh()
          temps->Dict.set(key(t), true)
          out->Array.push(IR.mapDef(i, t))
          out->Array.push(IR.Native("poke", None, [AOp(Num(Int.toFloat(slot))), AOp(VReg(t))], true))
        } else {
          out->Array.push(i)
        }
        out
      }
    }),
  })

let allocate = (ir: IR.t, ~names: Dict.t<string>): result => {
  let reserved = reservedRegisters(ir)
  let available = registerCount - Array.length(reserved)
  let nextVReg = ref(IR.maxVReg(ir) + 1)
  let fresh = () => {
    let v = nextVReg.contents
    nextVReg := v + 1
    v
  }
  let temps = Dict.make()
  let current = ref(ir)
  let spills = ref(0)
  let finished = ref(None)
  while finished.contents == None {
    let live = Liveness.analyze(current.contents)
    let g = buildGraph(live)
    let colors = switch colorWith(g, ~reserved, ~coalesce=true) {
    | Some(c) => Some(c)
    | None => colorWith(g, ~reserved, ~coalesce=false)
    }
    switch colors {
    | Some(c) =>
      let used = c->Dict.valuesToArray->Array.reduce(0, (m, x) => Math.Int.max(m, x + 1))
      finished :=
        Some({
          ir: current.contents,
          colorOf: v => c->Dict.get(key(v))->Option.getOr(0),
          registersUsed: used,
          spills: spills.contents,
        })
    | None =>
      let victim = spills.contents < maxSpills ? chooseSpill(live, g, ~available, ~noSpill=temps) : None
      switch victim {
      | Some(v) =>
        let slot = firstSpillSlot - spills.contents
        spills := spills.contents + 1
        switch names->Dict.get(key(v)) {
        | Some(n) => names->Dict.set(key(v), n) // keep the name for diagnostics
        | None => ()
        }
        current := spillVReg(current.contents, v, slot, ~fresh, ~temps)
      | None =>
        let liveSet = live.liveOut->Array.getUnsafe(g.pressureAt)
        let described =
          liveSet
          ->IntSet.toArray
          ->Array.map(v => names->Dict.get(key(v))->Option.getOr("temporary"))
        let counts = Dict.make()
        described->Array.forEach(n => counts->Dict.set(n, counts->Dict.get(n)->Option.getOr(0) + 1))
        let summary =
          counts
          ->Dict.toArray
          ->Array.map(((n, c)) => c > 1 ? `${n} (x${Int.toString(c)})` : n)
          ->Array.join(", ")
        Errors.fail(
          ~file,
          ~fn="allocate",
          `program needs more than ${Int.toString(available)} registers even after spilling: ${Int.toString(
              IntSet.size(liveSet),
            )} values are alive at once (${summary})`,
          ~hint="shorten variable lifetimes or split the program across chips",
        )
      }
    }
  }
  finished.contents->Option.getOrThrow
}
