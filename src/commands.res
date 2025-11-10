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

switch (argv[0], argv[1]) {
| (Some(src), Some(dest)) => resToIC10File(src, dest)
| (None, Some(_)) => Console.log("Missing src file arg: (src: string, dest: string) => unit")
| (Some(_), None) => Console.log("Missing dest file arg: (src: string, dest: string) => unit")
| _ => Console.log("Missing src and dest file args: (src: string, dest: string) => unit")
}
