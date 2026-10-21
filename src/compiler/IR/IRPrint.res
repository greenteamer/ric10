// IR pretty printer (debugging): IC10-like syntax with virtual registers.

let print = (ir: IR.t): string =>
  ir
  ->Array.map(b =>
    `# block ${b.name}\n` ++
    IRToIC10.print([b], ~reg=v => `v${Int.toString(v)}`)->Array.join("\n")
  )
  ->Array.join("\n")
