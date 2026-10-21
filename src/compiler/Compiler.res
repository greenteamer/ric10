// Compiler entry point.
//
// Pipeline: Lexer -> Parser -> IRGen -> IROptimizer (passes as data) ->
// IRToIC10 (register allocation + emission). Phases throw
// `Errors.CompileError`; this module converts it into results.

type stats = {
  lines: int,
  registers: int,
}

type diagnostics = {
  ok: bool,
  code: string,
  errors: array<Errors.t>,
  warnings: array<Errors.t>,
  stats: stats,
}

let internalError = (message: string): Errors.t =>
  Errors.make(~file="Compiler.res", ~fn="compile", `internal compiler error: ${message}`)

let compileWithDiagnostics = (source: string, ~options: option<CodegenTypes.compilerOptions>=?): diagnostics => {
  let options = options->Option.getOr({})
  let debug = options.debug->Option.getOr(false)
  let maxLines = options.maxLines->Option.getOr(CodegenTypes.ic10MaxLines)
  let empty = {lines: 0, registers: 0}
  try {
    let tokens = Lexer.tokenize(source)
    let ast = Parser.parse(tokens)
    let (ir, warnings, names) = IRGen.generate(ast)
    if debug {
      Console.log("=== IR (before optimization) ===\n" ++ IRPrint.print(ir))
    }
    let ir = IROptimizer.optimize(ir, ~names)
    if debug {
      Console.log("=== IR (after optimization) ===\n" ++ IRPrint.print(ir))
    }
    let out = IRToIC10.generate(ir, ~names)
    let warnings = Array.copy(warnings)
    if out.lines > maxLines {
      warnings->Array.push(
        Errors.warning(
          ~file="Compiler.res",
          ~fn="compile",
          `program has ${Int.toString(out.lines)} lines; an IC10 chip runs at most ${Int.toString(
              maxLines,
            )}`,
        ),
      )
    }
    out.code
    ->String.split("\n")
    ->Array.forEachWithIndex((l, i) =>
      if String.length(l) > CodegenTypes.ic10MaxLineLength {
        warnings->Array.push(
          Errors.warning(
            ~file="Compiler.res",
            ~fn="compile",
            `output line ${Int.toString(i + 1)} is longer than ${Int.toString(
                CodegenTypes.ic10MaxLineLength,
              )} characters`,
          ),
        )
      }
    )
    {
      ok: true,
      code: out.code,
      errors: [],
      warnings,
      stats: {lines: out.lines, registers: out.registers},
    }
  } catch {
  | Errors.CompileError(e) => {ok: false, code: "", errors: [e], warnings: [], stats: empty}
  | JsExn(e) =>
    let message = e->JsExn.message->Option.getOr("unknown error")
    {ok: false, code: "", errors: [internalError(message)], warnings: [], stats: empty}
  }
}

// Backwards compatible API: Ok(assembly) or Error(message)
let compile = (source: string, ~options: option<CodegenTypes.compilerOptions>=?, ()): result<
  string,
  string,
> => {
  let d = compileWithDiagnostics(source, ~options?)
  if d.ok {
    Ok(d.code)
  } else {
    Error(d.errors->Array.map(Errors.format)->Array.join("\n"))
  }
}

// Optimized IR with virtual registers (for debugging and tests)
let compileToIR = (source: string, ~optimize=true): result<string, string> =>
  try {
    let (ir, _, _) = IRGen.generate(Parser.parse(Lexer.tokenize(source)))
    Ok(IRPrint.print(optimize ? IROptimizer.optimize(ir) : ir))
  } catch {
  | Errors.CompileError(e) => Error(Errors.format(e))
  }

let formatDiagnostic = Errors.format
