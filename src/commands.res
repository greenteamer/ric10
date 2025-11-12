@scope("process") @val
external argv: array<string> = "argv"

@module("fs") external readFileSync: (string, string) => string = "readFileSync"
@module("fs") external writeFileSync: (string, string, string) => unit = "writeFileSync"

let resToIC10File = (src: string, dest: string) => {
  let content = readFileSync(src, "utf8")
  let options: CodegenTypes.compilerOptions = {
    includeComments: false,
    debugAST: false,
    useIR: true,
  }

  switch Compiler.compile(content, ~options, ()) {
  | Ok(Program(str)) => writeFileSync(dest, str, "utf8")
  | Ok(ASTProgram(ast)) =>
    writeFileSync("dest.ast.json", ast->JSON.stringifyAny->Option.getExn, "utf8")
  | Error(message) => Console.log(message)
  }
}

// Generate destination filename by replacing .res extension with .ic10
let generateDestPath = (src: string) => {
  if src->String.endsWith(".res") {
    src->String.slice(~start=0, ~end=String.length(src) - 4) ++ ".ic10"
  } else {
    src ++ ".ic10"
  }
}

switch argv[2] {
| Some(src) => {
    let dest = generateDestPath(src)
    Console.log(`Compiling: ${src} -> ${dest}`)
    resToIC10File(src, dest)
  }
| None => Console.log("Usage: node src/commands.res.js <source.res>")
}
