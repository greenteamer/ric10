@scope("process") @val
external argv: array<string> = "argv"

@module("fs") external readFileSync: (string, string) => string = "readFileSync"
@module("fs") external writeFileSync: (string, string, string) => unit = "writeFileSync"

// Compile a ReScript file to the specified backend format
let compileFile = (src: string, dest: string, backend: CodegenTypes.backend) => {
  let content = readFileSync(src, "utf8")
  let options: CodegenTypes.compilerOptions = {
    includeComments: false,
    debugAST: false,
    backend: backend,
  }

  switch Compiler.compile(content, ~options, ()) {
  | Ok(code) => {
      writeFileSync(dest, code, "utf8")
      Console.log(`✓ Success: Generated ${dest}`)
    }
  | Error(message) => {
      Console.log(`✗ Error: ${message}`)
    }
  }
}

// Generate destination filename based on backend
let generateDestPath = (src: string, backend: CodegenTypes.backend) => {
  let baseName = if src->String.endsWith(".res") {
    src->String.slice(~start=0, ~end=String.length(src) - 4)
  } else {
    src
  }

  switch backend {
  | CodegenTypes.IC10 => baseName ++ ".ic10"
  | CodegenTypes.WASM => baseName ++ ".wat"
  }
}

// Parse backend from command line argument
let parseBackend = (arg: string): option<CodegenTypes.backend> => {
  switch arg->String.toLowerCase {
  | "ic10" => Some(CodegenTypes.IC10)
  | "wasm" | "wat" => Some(CodegenTypes.WASM)
  | _ => None
  }
}

// Main CLI logic
switch (argv[2], argv[3]) {
// Two arguments: source file and backend
| (Some(src), Some(backendArg)) =>
  switch parseBackend(backendArg) {
  | Some(backend) => {
      let dest = generateDestPath(src, backend)
      Console.log(`Compiling: ${src} -> ${dest} (backend: ${backendArg})`)
      compileFile(src, dest, backend)
    }
  | None => {
      Console.log(`Error: Unknown backend '${backendArg}'`)
      Console.log(`Usage: node scripts/compile.res.js <source.res> [ic10|wasm]`)
      Console.log(`  ic10 - Compile to IC10 assembly (.ic10)`)
      Console.log(`  wasm - Compile to WebAssembly text format (.wat)`)
    }
  }

// One argument: source file (default to IC10)
| (Some(src), None) => {
    let backend = CodegenTypes.IC10
    let dest = generateDestPath(src, backend)
    Console.log(`Compiling: ${src} -> ${dest} (backend: ic10)`)
    compileFile(src, dest, backend)
  }

// No arguments: show usage
| _ => {
    Console.log(`Usage: node scripts/compile.res.js <source.res> [backend]`)
    Console.log(``)
    Console.log(`Arguments:`)
    Console.log(`  source.res - ReScript source file to compile`)
    Console.log(`  backend    - Target backend (optional, default: ic10)`)
    Console.log(``)
    Console.log(`Backends:`)
    Console.log(`  ic10 - IC10 assembly language (default) -> .ic10`)
    Console.log(`  wasm - WebAssembly text format         -> .wat`)
    Console.log(``)
    Console.log(`Examples:`)
    Console.log(`  node scripts/compile.res.js src/basic.res`)
    Console.log(`  node scripts/compile.res.js src/basic.res ic10`)
    Console.log(`  node scripts/compile.res.js src/basic.res wasm`)
  }
}
