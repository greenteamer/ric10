// Abstract syntax tree for the supported ReScript subset.
// Every expression, statement and pattern carries its source location.

type loc = Errors.loc

type unop =
  | Neg // -x, -.x
  | Not // !x
  | BitNot // ~~~x

type binop =
  | Add
  | Sub
  | Mul
  | Div
  | Mod
  | Pow
  | Lt
  | Le
  | Gt
  | Ge
  | Eq
  | Ne
  | BitAnd
  | BitOr
  | BitXor
  | Shl
  | Shr // >> arithmetic shift
  | Ushr // >>> logical shift
  | And // && (short-circuit)
  | Or // || (short-circuit)

type rec expr = {desc: desc, loc: loc}
and desc =
  | Number(float, bool) // value, written as float literal
  | Bool(bool)
  | String(string)
  | Unit
  | Ident(string)
  | Constructor(string, array<expr>) // Idle, Loading(p)
  | Unary(unop, expr)
  | Binary(binop, expr, expr)
  | Call(string, array<expr>) // f(a, b); also `a->f(b)` and `Math.sqrt(x)`
  | Labeled(string, expr) // ~name=expr as a call argument (only directly inside Call args)
  | If(expr, expr, option<expr>) // also `c ? a : b`
  | Block(array<stmt>)
  | Switch(expr, array<matchCase>)
  | While(expr, expr)
  | For(string, expr, expr, bool, expr) // var, from, to, downto, body
  | Deref(expr) // r.contents
  | Assign(expr, expr) // r := v, r.contents = v
  | Fun(array<param>, expr) // (a, b) => body
  | Raw(string) // %raw("...")

and stmt =
  | Let(string, expr, loc)
  | TypeDecl(string, array<ctorDecl>, loc)
  | Module(string, array<stmt>, loc) // module Name = { ... }
  | Open(string, loc) // open Name
  | Expr(expr)

and matchCase = {
  pattern: pattern,
  guard: option<expr>,
  body: expr,
  caseLoc: loc,
}

and pattern = {pdesc: pdesc, ploc: loc}
and pdesc =
  | PWild
  | PVar(string)
  | PConstr(string, array<pattern>)
  | PNumber(float)
  | PBool(bool)
  | POr(pattern, pattern)

and param = {
  pname: string,
  ptype: option<string>, // head of the type annotation, e.g. "state" in `(s: state)`
  labeled: bool, // ~name parameter
  paramLoc: loc,
}

and ctorDecl = {
  cname: string,
  argTypes: array<string>, // head type name of each payload ("int", "float", "" if unknown)
  cloc: loc,
}

type program = array<stmt>

let binopToString = (op: binop): string =>
  switch op {
  | Add => "+"
  | Sub => "-"
  | Mul => "*"
  | Div => "/"
  | Mod => "%"
  | Pow => "**"
  | Lt => "<"
  | Le => "<="
  | Gt => ">"
  | Ge => ">="
  | Eq => "=="
  | Ne => "!="
  | BitAnd => "&&&"
  | BitOr => "|||"
  | BitXor => "^^^"
  | Shl => "<<"
  | Shr => ">>"
  | Ushr => ">>>"
  | And => "&&"
  | Or => "||"
  }

let mk = (desc, loc): expr => {desc, loc}
