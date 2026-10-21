// Register allocation: virtual registers -> r0..r15.
//
// 1. Build the interference graph from whole-program liveness.
// 2. Coalesce move-related vregs that do not interfere (removes copies).
// 3. Greedy colouring in program order, preferring a move partner's register.
// If colouring fails with coalescing, it is retried without it; if it still
// fails the error names the variables alive at the point of highest pressure.

module IntSet = Belt.Set.Int

let file = "RegAlloc.res"
let registerCount = 16

type result = {
  colorOf: IR.vreg => int,
  registersUsed: int,
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

let allocate = (ir: IR.t, ~names: Dict.t<string>): result => {
  let live = Liveness.analyze(ir)
  let reserved = reservedRegisters(ir)

  // --- interference graph -------------------------------------------------
  let adj: Dict.t<IntSet.t> = Dict.make()
  let key = Int.toString
  let order = [] // vregs in order of first appearance
  let seen = Dict.make()
  let touch = v =>
    if seen->Dict.get(key(v)) == None {
      seen->Dict.set(key(v), true)
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
  live.instrs->Array.forEachWithIndex((instr, idx) => {
    IR.uses(instr)->Array.forEach(touch)
    switch IR.def(instr) {
    | Some(d) =>
      touch(d)
      let exempt = switch instr {
      | Move(_, VReg(s)) =>
        moves->Array.push((d, s))
        Some(s)
      | _ => None
      }
      live.liveOut
      ->Array.getUnsafe(idx)
      ->IntSet.forEach(v =>
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

  let colorWith = (~coalesce: bool): option<Dict.t<int>> => {
    // union-find for coalescing
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
    order->Array.forEach(v => gAdj->Dict.set(key(v), neighbors(v)))
    let gNeighbors = v => gAdj->Dict.get(key(v))->Option.getOr(IntSet.empty)
    if coalesce {
      moves->Array.forEach(((d, s)) => {
        let a = find(d)
        let b = find(s)
        if a != b && !(gNeighbors(a)->IntSet.has(b)) {
          // merge b into a
          parent->Dict.set(key(b), a)
          let merged = IntSet.union(gNeighbors(a), gNeighbors(b))
          gAdj->Dict.set(key(a), merged)
          gNeighbors(b)->IntSet.forEach(nb => {
            let s = gNeighbors(nb)->IntSet.remove(b)->IntSet.add(a)
            gAdj->Dict.set(key(nb), s)
          })
        }
      })
    }
    let partners = Dict.make()
    moves->Array.forEach(((d, s)) => {
      let a = find(d)
      let b = find(s)
      if a != b {
        partners->Dict.set(key(a), Array.concat(partners->Dict.get(key(a))->Option.getOr([]), [b]))
        partners->Dict.set(key(b), Array.concat(partners->Dict.get(key(b))->Option.getOr([]), [a]))
      }
    })
    let color = Dict.make()
    let ok = ref(true)
    order->Array.forEach(v => {
      let r = find(v)
      if ok.contents && color->Dict.get(key(r)) == None {
        let taken =
          gNeighbors(r)
          ->IntSet.toArray
          ->Array.filterMap(nb => color->Dict.get(key(find(nb))))
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
      order->Array.forEach(v =>
        final->Dict.set(key(v), color->Dict.get(key(find(v)))->Option.getOr(0))
      )
      Some(final)
    } else {
      None
    }
  }

  let colors = switch colorWith(~coalesce=true) {
  | Some(c) => Some(c)
  | None => colorWith(~coalesce=false)
  }
  switch colors {
  | Some(c) =>
    let used = c->Dict.valuesToArray->Array.reduce(0, (m, x) => Math.Int.max(m, x + 1))
    {
      colorOf: v => c->Dict.get(key(v))->Option.getOr(0),
      registersUsed: used,
    }
  | None =>
    // report the point of highest register pressure
    let worst = ref(0)
    live.liveOut->Array.forEachWithIndex((s, idx) =>
      if IntSet.size(s) > IntSet.size(live.liveOut->Array.getUnsafe(worst.contents)) {
        worst := idx
      }
    )
    let liveSet = live.liveOut->Array.getUnsafe(worst.contents)
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
      `program needs more than ${Int.toString(registerCount - Array.length(reserved))} registers: ${Int.toString(
          IntSet.size(liveSet),
        )} values are alive at once (${summary})`,
      ~hint="shorten variable lifetimes, move values into refs that are reused, or split the program across chips",
    )
  }
}
