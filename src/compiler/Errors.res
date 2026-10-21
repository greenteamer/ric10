// Structured compiler diagnostics.
//
// Every error carries the module/function that raised it (project convention:
// "[File.res][function]: message"), an optional source location and an optional
// hint. `format` is the single place where a diagnostic becomes text.

type loc = {line: int, col: int}

type severity = Error | Warning

type t = {
  severity: severity,
  file: string, // e.g. "Parser.res"
  fn: string, // e.g. "parsePrimary"
  message: string,
  loc: option<loc>,
  hint: option<string>,
}

let noLoc: loc = {line: 0, col: 0}

let make = (~file, ~fn, ~loc=?, ~hint=?, message): t => {
  severity: Error,
  file,
  fn,
  message,
  loc: switch loc {
  | Some(l) if l.line > 0 => Some(l)
  | _ => None
  },
  hint,
}

let warning = (~file, ~fn, ~loc=?, ~hint=?, message): t => {
  ...make(~file, ~fn, ~loc?, ~hint?, message),
  severity: Warning,
}

let formatLoc = (loc: loc) => `${Int.toString(loc.line)}:${Int.toString(loc.col)}`

let format = (e: t): string => {
  let where = switch e.loc {
  | Some(loc) => ` ${formatLoc(loc)}`
  | None => ""
  }
  let hint = switch e.hint {
  | Some(h) => `\n  hint: ${h}`
  | None => ""
  }
  `[${e.file}][${e.fn}]${where}: ${e.message}${hint}`
}

// Internal control flow: compiler phases throw `CompileError` and the
// orchestrator converts it into a `result` at the boundary.
exception CompileError(t)

let fail = (~file, ~fn, ~loc=?, ~hint=?, message) =>
  throw(CompileError(make(~file, ~fn, ~loc?, ~hint?, message)))
