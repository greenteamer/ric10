// ric10 CLI: compile a ReScript file to IC10 assembly.
//
//   ric10 <file.res> [-o out.ic10] [--stdout] [--debug]

@scope("process") @val external argv: array<string> = "argv"
@scope("process") @val external exit: int => unit = "exit"
@module("fs") external readFileSync: (string, string) => string = "readFileSync"
@module("fs") external writeFileSync: (string, string, string) => unit = "writeFileSync"

let usage = () => {
  Console.log(`Usage: ric10 <source.res> [options]

Options:
  -o <file>   output file (default: <source>.ic10)
  --stdout    print the assembly instead of writing a file
  --debug     print the IR before and after optimization

Examples:
  ric10 furnace.res
  ric10 furnace.res -o furnace.ic10
  ric10 furnace.res --stdout`)
}

let defaultDest = (src: string) =>
  if src->String.endsWith(".res") {
    src->String.slice(~start=0, ~end=String.length(src) - 4) ++ ".ic10"
  } else {
    src ++ ".ic10"
  }

let args = argv->Array.sliceToEnd(~start=2)
let flag = name => args->Array.includes(name)
let output = switch args->Array.findIndex(a => a == "-o") {
| -1 => None
| i => args[i + 1]
}
let positional = args->Array.filterWithIndex((a, i) =>
  !(a->String.startsWith("-")) && (i == 0 || args[i - 1] != Some("-o"))
)

switch positional[0] {
| None => usage()
| Some(src) =>
  let source = readFileSync(src, "utf8")
  let d = Compiler.compileWithDiagnostics(source, ~options={debug: flag("--debug")})
  d.warnings->Array.forEach(w => Console.error(`warning: ${Errors.format(w)}`))
  if d.ok {
    if flag("--stdout") {
      Console.log(d.code)
    } else {
      let dest = output->Option.getOr(defaultDest(src))
      writeFileSync(dest, d.code ++ "\n", "utf8")
      let spills = d.stats.spills > 0 ? `, ${Int.toString(d.stats.spills)} values on the stack` : ""
      Console.log(
        `✓ ${src} -> ${dest} (${Int.toString(d.stats.lines)} lines, ${Int.toString(
            d.stats.registers,
          )} registers${spills})`,
      )
    }
  } else {
    d.errors->Array.forEach(e => Console.error(`✗ ${src}: ${Errors.format(e)}`))
    exit(1)
  }
}
