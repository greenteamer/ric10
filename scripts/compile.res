// ric10 CLI: compile a ReScript file to IC10 assembly.
//
//   ric10 <file.res> [-o out.ic10] [--stdout] [--debug]
//   ric10 watch [dir]   recompile every .res in dir (default src) on save

@scope("process") @val external argv: array<string> = "argv"
@scope("process") @val external exit: int => unit = "exit"
@module("fs") external readFileSync: (string, string) => string = "readFileSync"
@module("fs") external writeFileSync: (string, string, string) => unit = "writeFileSync"
@module("fs") external existsSync: string => bool = "existsSync"
@module("fs")
external readdirSync: (string, {"recursive": bool}) => array<string> = "readdirSync"
@module("fs")
external watchDir: (string, {"recursive": bool}, (string, Nullable.t<string>) => unit) => unit =
  "watch"
@module("path") external join: (string, string) => string = "join"
type child
@module("child_process")
external spawn: (string, array<string>, {"stdio": string, "shell": bool}) => child = "spawn"
@send external kill: child => unit = "kill"
@scope("process") @val external onExit: (@as("exit") _, unit => unit) => unit = "on"
@scope("process") @val external onSignal: (string, unit => unit) => unit = "on"

let usage = () => {
  Console.log(`Usage: ric10 <source.res> [options]

Options:
  -o <file>   output file (default: <source>.ic10)
  --stdout    print the assembly instead of writing a file
  --debug     print the IR before and after optimization
  --alias     emit alias lines for named devices (labels the housing screws in game)

Examples:
  ric10 furnace.res
  ric10 furnace.res -o furnace.ic10
  ric10 furnace.res --stdout
  ric10 watch                 recompile src/*.res on save (and run rescript watch)`)
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

let compileFile = (src: string, ~dest=?, ~toStdout=false) => {
  let source = readFileSync(src, "utf8")
  let d = Compiler.compileWithDiagnostics(
    source,
    ~options={debug: flag("--debug"), aliases: flag("--alias")},
  )
  d.warnings->Array.forEach(w => Console.error(`warning: ${Errors.format(w)}`))
  if d.ok {
    if toStdout {
      Console.log(d.code)
    } else {
      let dest = dest->Option.getOr(defaultDest(src))
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
  }
  d.ok
}

// Programs are the .res files of the directory; the bindings themselves are not one.
let isProgram = (file: string) =>
  file->String.endsWith(".res") && !(file->String.endsWith("IC10.res"))

let watch = (dir: string) => {
  if !existsSync(dir) {
    Console.error(`✗ directory '${dir}' not found`)
    exit(1)
  }
  // The local ReScript compiler keeps type errors (and the editor's LSP) up to date.
  let rescript = join("node_modules", join(".bin", "rescript"))
  if existsSync(rescript) && !flag("--no-rescript") {
    let child = spawn(rescript, ["watch"], {"stdio": "inherit", "shell": true})
    onExit(() => kill(child))
    ["SIGINT", "SIGTERM"]->Array.forEach(sig => onSignal(sig, () => exit(0)))
  }
  readdirSync(dir, {"recursive": true})
  ->Array.filter(isProgram)
  ->Array.forEach(f => compileFile(join(dir, f))->ignore)
  // Editors fire several events per save: compile once they settle.
  let pending = Dict.make()
  watchDir(dir, {"recursive": true}, (_, file) =>
    switch file->Nullable.toOption {
    | Some(f) if isProgram(f) =>
      let path = join(dir, f)
      pending->Dict.get(path)->Option.forEach(clearTimeout)
      pending->Dict.set(
        path,
        setTimeout(() => {
          pending->Dict.delete(path)
          if existsSync(path) {
            compileFile(path)->ignore
          }
        }, 100),
      )
    | _ => ()
    }
  )
  Console.log(`watching ${dir} for changes (Ctrl+C to stop)`)
}

switch positional[0] {
| None => usage()
| Some("watch") => watch(positional[1]->Option.getOr("src"))
| Some(src) =>
  if !compileFile(src, ~dest=?output, ~toStdout=flag("--stdout")) {
    exit(1)
  }
}
