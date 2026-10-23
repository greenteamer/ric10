// Parser: tokens -> AST (Pratt parser for expressions, recursive descent for
// statements, patterns and types).
//
// Operator precedence mirrors ReScript 12 (verified against the real compiler):
//   :=  <  ?:  <  ||  <  &&  <  |||  <  ^^^  <  &&&  <  == != < <= > >=
//   <  << >> >>>  <  + -  <  * / %  <  **  <  unary - ! ~~~  <  postfix . -> ()

open AST

type t = {
  tokens: array<Lexer.t>,
  mutable pos: int,
  // inside a switch guard `| P if cond => body` the `=>` ends the guard,
  // so `y => ...` and `(a > b) => ...` must not be read as lambdas
  mutable inGuard: bool,
}

let file = "Parser.res"

let cur = p => p.tokens->Array.getUnsafe(p.pos)
let peekAt = (p, offset) => {
  let i = Math.Int.min(p.pos + offset, Array.length(p.tokens) - 1)
  p.tokens->Array.getUnsafe(i)
}
let tok = p => cur(p).tok
let loc = p => cur(p).loc
let bump = p => p.pos = Math.Int.min(p.pos + 1, Array.length(p.tokens) - 1)

let fail = (p, ~fn, ~hint=?, message) =>
  Errors.fail(~file, ~fn, ~loc=loc(p), ~hint?, message)

let describe = (t: Lexer.token) =>
  switch t {
  | EOF => "end of file"
  | _ => `'${Lexer.tokenToString(t)}'`
  }

let isOp = (p, op) =>
  switch tok(p) {
  | Op(o) => o == op
  | _ => false
  }
let isKeyword = (p, kw) =>
  switch tok(p) {
  | Keyword(k) => k == kw
  | _ => false
  }

let expectOp = (p, ~fn, op) =>
  if isOp(p, op) {
    bump(p)
  } else {
    fail(p, ~fn, `expected '${op}' but found ${describe(tok(p))}`)
  }

let expectKeyword = (p, ~fn, kw) =>
  if isKeyword(p, kw) {
    bump(p)
  } else {
    fail(p, ~fn, `expected '${kw}' but found ${describe(tok(p))}`)
  }

let expectIdent = (p, ~fn) =>
  switch tok(p) {
  | Ident(name) =>
    bump(p)
    name
  | other => fail(p, ~fn, `expected identifier but found ${describe(other)}`)
  }

let skipSemis = p =>
  while isOp(p, ";") {
    bump(p)
  }

// ---------------------------------------------------------------------------
// Types (only parsed to be skipped; the head name is kept for annotations)

let rec parseType = (p): option<string> => {
  let fn = "parseType"
  let head = switch tok(p) {
  | Op("(") =>
    // tuple or parenthesized type
    bump(p)
    let _ = parseType(p)
    while isOp(p, ",") {
      bump(p)
      let _ = parseType(p)
    }
    expectOp(p, ~fn, ")")
    None
  | Op("'") => fail(p, ~fn, "type variables are not supported")
  | Ident(_) | UIdent(_) =>
    // qualified path: Belt.Map.t / state
    let name = ref("")
    let continue = ref(true)
    while continue.contents {
      switch tok(p) {
      | Ident(n) | UIdent(n) =>
        name := n
        bump(p)
        if isOp(p, ".") {
          bump(p)
        } else {
          continue := false
        }
      | _ => continue := false
      }
    }
    if isOp(p, "<") {
      bump(p)
      let _ = parseType(p)
      while isOp(p, ",") {
        bump(p)
        let _ = parseType(p)
      }
      expectOp(p, ~fn, ">")
    }
    Some(name.contents)
  | other => fail(p, ~fn, `expected a type but found ${describe(other)}`)
  }
  if isOp(p, "=>") {
    bump(p)
    let _ = parseType(p)
    None
  } else {
    head
  }
}

// ---------------------------------------------------------------------------
// Patterns

let rec parsePattern = (p): pattern => {
  let first = parsePatternAtom(p)
  if isOp(p, "|") {
    bump(p)
    let rest = parsePattern(p)
    {pdesc: POr(first, rest), ploc: first.ploc}
  } else {
    first
  }
}

and parsePatternAtom = (p): pattern => {
  let fn = "parsePattern"
  let ploc = loc(p)
  let pdesc = switch tok(p) {
  | Ident("_") =>
    bump(p)
    PWild
  | Ident(name) =>
    bump(p)
    PVar(name)
  | Keyword("true") =>
    bump(p)
    PBool(true)
  | Keyword("false") =>
    bump(p)
    PBool(false)
  | Number(n, _) =>
    bump(p)
    PNumber(n)
  | Op("-") | Op("-.") =>
    bump(p)
    switch tok(p) {
    | Number(n, _) =>
      bump(p)
      PNumber(-.n)
    | other => fail(p, ~fn, `expected a number after '-' but found ${describe(other)}`)
    }
  | UIdent(first) =>
    bump(p)
    // Module.Ctor: only the last segment names the constructor
    let name = ref(first)
    while isOp(p, ".") {
      switch peekAt(p, 1).tok {
      | UIdent(n) =>
        bump(p)
        bump(p)
        name := n
      | other => fail(p, ~fn, `expected a constructor after '.' but found ${describe(other)}`)
      }
    }
    let name = name.contents
    if isOp(p, "(") && !cur(p).nl {
      bump(p)
      let args = [parsePattern(p)]
      while isOp(p, ",") {
        bump(p)
        args->Array.push(parsePattern(p))
      }
      expectOp(p, ~fn, ")")
      PConstr(name, args)
    } else {
      PConstr(name, [])
    }
  | Op("(") =>
    bump(p)
    let inner = parsePattern(p)
    if isOp(p, ",") {
      fail(p, ~fn, "tuple patterns are not supported")
    }
    expectOp(p, ~fn, ")")
    inner.pdesc
  | other => fail(p, ~fn, `expected a pattern but found ${describe(other)}`)
  }
  {pdesc, ploc}
}

// ---------------------------------------------------------------------------
// Expressions

type infix = {
  lbp: int,
  rbp: int,
  op: option<binop>, // None for special forms (:=, ?)
}

// Binding powers: level L gives lbp = 2L; left-associative operators parse
// their right operand at 2L + 1, right-associative ones at 2L - 1.
let infixOf = (t: Lexer.token): option<(string, infix)> => {
  let left = (name, level, op) => Some((name, {lbp: 2 * level, rbp: 2 * level + 1, op}))
  let right = (name, level, op) => Some((name, {lbp: 2 * level, rbp: 2 * level - 1, op}))
  switch t {
  | Op(":=") => right(":=", 1, None)
  | Op("?") => right("?", 2, None)
  | Op("||") => left("||", 3, Some(Or))
  | Op("&&") => left("&&", 4, Some(And))
  | Op("|||") => left("|||", 5, Some(BitOr))
  | Op("^^^") => left("^^^", 6, Some(BitXor))
  | Op("&&&") => left("&&&", 7, Some(BitAnd))
  | Op("==") | Op("===") => left("==", 8, Some(Eq))
  | Op("!=") | Op("!==") => left("!=", 8, Some(Ne))
  | Op("<") => left("<", 8, Some(Lt))
  | Op("<=") => left("<=", 8, Some(Le))
  | Op(">") => left(">", 8, Some(Gt))
  | Op(">=") => left(">=", 8, Some(Ge))
  | Op("<<") => left("<<", 9, Some(Shl))
  | Op(">>") => left(">>", 9, Some(Shr))
  | Op(">>>") => left(">>>", 9, Some(Ushr))
  | Op("+") | Op("+.") => left("+", 10, Some(Add))
  | Op("-") | Op("-.") => left("-", 10, Some(Sub))
  | Op("*") | Op("*.") => left("*", 11, Some(Mul))
  | Op("/") | Op("/.") => left("/", 11, Some(Div))
  | Op("%") => left("%", 11, Some(Mod))
  | Op("**") => right("**", 12, Some(Pow))
  | _ => None
  }
}

// Unary operators bind tighter than `**` (ReScript: -2 ** 2 == 4)
let prefixBp = 25

// Does the token stream at `p.pos` (pointing at "(") start a lambda?
let looksLikeLambda = (p): bool => {
  let depth = ref(0)
  let i = ref(p.pos)
  let result = ref(None)
  let n = Array.length(p.tokens)
  while result.contents == None && i.contents < n {
    switch (p.tokens->Array.getUnsafe(i.contents)).tok {
    | Op("(") => depth := depth.contents + 1
    | Op(")") =>
      depth := depth.contents - 1
      if depth.contents == 0 {
        // found matching paren: lambda if followed by `=>` or `: type =>`
        let next = (p.tokens->Array.getUnsafe(Math.Int.min(i.contents + 1, n - 1))).tok
        result :=
          Some(
            switch next {
            | Op("=>") => true
            | Op(":") =>
              // scan a short type annotation for a following `=>`
              let j = ref(i.contents + 2)
              let found = ref(false)
              let stop = ref(false)
              while !stop.contents && j.contents < n {
                switch (p.tokens->Array.getUnsafe(j.contents)).tok {
                | Op("=>") =>
                  found := true
                  stop := true
                | Ident(_) | UIdent(_) | Op(".") | Op("<") | Op(">") | Op(",") => ()
                | _ => stop := true
                }
                j := j.contents + 1
              }
              found.contents
            | _ => false
            },
          )
      }
    | EOF => result := Some(false)
    | _ => ()
    }
    i := i.contents + 1
  }
  result.contents->Option.getOr(false)
}

let rec parseExpr = (p): expr => parseExprBp(p, 0)

and parseExprBp = (p, minBp): expr => {
  let fn = "parseExpression"
  let lhs = ref(parsePrefix(p))
  let continue = ref(true)
  while continue.contents {
    switch infixOf(tok(p)) {
    | Some((name, info)) if info.lbp > minBp =>
      let opLoc = loc(p)
      bump(p)
      switch (name, info.op) {
      | (":=", _) =>
        let rhs = parseExprBp(p, info.rbp)
        lhs := mk(Assign(lhs.contents, rhs), opLoc)
      | ("?", _) =>
        let thenE = parseExprBp(p, 0)
        expectOp(p, ~fn, ":")
        let elseE = parseExprBp(p, info.rbp)
        lhs := mk(If(lhs.contents, thenE, Some(elseE)), lhs.contents.loc)
      | (_, Some(op)) =>
        let rhs = parseExprBp(p, info.rbp)
        lhs := mk(Binary(op, lhs.contents, rhs), opLoc)
      | (_, None) => continue := false
      }
    | _ =>
      // `r.contents = v`
      if isOp(p, "=") && minBp == 0 {
        switch lhs.contents.desc {
        | Deref(_) =>
          let opLoc = loc(p)
          bump(p)
          let rhs = parseExprBp(p, 0)
          lhs := mk(Assign(lhs.contents, rhs), opLoc)
        | _ => continue := false
        }
      } else {
        continue := false
      }
    }
  }
  lhs.contents
}

and parsePrefix = (p): expr => {
  let l = loc(p)
  switch tok(p) {
  | Op("-") | Op("-.") =>
    bump(p)
    let operand = parseExprBp(p, prefixBp)
    switch operand.desc {
    | Number(n, isFloat) => mk(Number(-.n, isFloat), l)
    | _ => mk(Unary(Neg, operand), l)
    }
  | Op("+") | Op("+.") =>
    bump(p)
    parseExprBp(p, prefixBp)
  | Op("!") =>
    bump(p)
    mk(Unary(Not, parseExprBp(p, prefixBp)), l)
  | Op("~~~") =>
    bump(p)
    mk(Unary(BitNot, parseExprBp(p, prefixBp)), l)
  | _ => parsePostfix(p, parsePrimary(p))
  }
}

// One call argument: `expr`, `~name=expr`, or the pun `~name`
and parseArg = (p, ~fn): expr => {
  if isOp(p, "~") {
    let l = loc(p)
    bump(p)
    let name = expectIdent(p, ~fn)
    if isOp(p, "?") {
      fail(p, ~fn, "optional argument passing (~name?) is not supported")
    }
    let value = if isOp(p, "=") {
      bump(p)
      parseExpr(p)
    } else {
      mk(Ident(name), l)
    }
    mk(Labeled(name, value), l)
  } else {
    parseExpr(p)
  }
}

and parseArgs = (p, ~fn): array<expr> => {
  expectOp(p, ~fn, "(")
  let args = []
  if isOp(p, ")") {
    bump(p)
  } else {
    args->Array.push(parseArg(p, ~fn))
    while isOp(p, ",") {
      bump(p)
      if !isOp(p, ")") {
        args->Array.push(parseArg(p, ~fn))
      }
    }
    expectOp(p, ~fn, ")")
  }
  // `f()` passes unit; drop it so arity matches the parameter list
  switch args {
  | [{desc: Unit}] => []
  | _ => args
  }
}

// Qualified callee: `Math.sqrt`, `IC10.l`, `Float.toInt`
and parseQualifiedName = (p, ~fn, first: string): string => {
  let name = ref(first)
  let continue = ref(true)
  while continue.contents && isOp(p, ".") {
    switch peekAt(p, 1).tok {
    | Ident(n) =>
      // a lowercase segment ends the path: Math.sqrt
      bump(p)
      bump(p)
      name := name.contents ++ "." ++ n
      continue := false
    | UIdent(n) =>
      bump(p)
      bump(p)
      name := name.contents ++ "." ++ n
    | other => fail(p, ~fn, `expected a name after '.' but found ${describe(other)}`)
    }
  }
  name.contents
}

and parsePostfix = (p, base: expr): expr => {
  let fn = "parsePostfix"
  let e = ref(base)
  let continue = ref(true)
  while continue.contents {
    if isOp(p, ".") {
      bump(p)
      switch tok(p) {
      | Ident("contents") =>
        let l = loc(p)
        bump(p)
        e := mk(Deref(e.contents), l)
      | other =>
        fail(
          p,
          ~fn,
          `field access '.${Lexer.tokenToString(other)}' is not supported`,
          ~hint="only `ref.contents` is supported (records are not)",
        )
      }
    } else if isOp(p, "->") {
      let l = loc(p)
      bump(p)
      let name = switch tok(p) {
      | Ident(n) =>
        bump(p)
        n
      | UIdent(n) =>
        bump(p)
        parseQualifiedName(p, ~fn, n)
      | other => fail(p, ~fn, `expected a function name after '->' but found ${describe(other)}`)
      }
      let args = if isOp(p, "(") && !cur(p).nl {
        parseArgs(p, ~fn)
      } else {
        []
      }
      e := mk(Call(name, [e.contents, ...args]), l)
    } else {
      continue := false
    }
  }
  e.contents
}

and parseLambda = (p): expr => {
  let fn = "parseLambda"
  let l = loc(p)
  let params = []
  switch tok(p) {
  | Ident(name) =>
    params->Array.push({pname: name, ptype: None, labeled: false, paramLoc: loc(p)})
    bump(p)
  | _ =>
    expectOp(p, ~fn, "(")
    let parseParam = () => {
      let paramLoc = loc(p)
      let labeled = if isOp(p, "~") {
        bump(p)
        true
      } else {
        false
      }
      switch tok(p) {
      | Op(")") if !labeled => ()
      | Ident(name) =>
        bump(p)
        let ptype = if isOp(p, ":") {
          bump(p)
          parseType(p)
        } else {
          None
        }
        if isOp(p, "=") {
          fail(p, ~fn, "default parameter values are not supported")
        }
        if isOp(p, "?") {
          fail(p, ~fn, "optional parameters are not supported")
        }
        params->Array.push({pname: name, ptype, labeled, paramLoc})
      | other => fail(p, ~fn, `expected a parameter name but found ${describe(other)}`)
      }
    }
    parseParam()
    while isOp(p, ",") {
      bump(p)
      parseParam()
    }
    expectOp(p, ~fn, ")")
    if isOp(p, ":") {
      bump(p)
      let _ = parseType(p)
    }
  }
  expectOp(p, ~fn, "=>")
  let body = parseExpr(p)
  mk(Fun(params, body), l)
}

and parsePrimary = (p): expr => {
  let fn = "parsePrimary"
  let l = loc(p)
  switch tok(p) {
  | Number(n, isFloat) =>
    bump(p)
    mk(Number(n, isFloat), l)
  | String(s) =>
    bump(p)
    mk(String(s), l)
  | Keyword("true") =>
    bump(p)
    mk(Bool(true), l)
  | Keyword("false") =>
    bump(p)
    mk(Bool(false), l)
  | Ident(name) =>
    if peekAt(p, 1).tok == Op("=>") && !p.inGuard {
      parseLambda(p)
    } else {
      bump(p)
      if isOp(p, "(") && !cur(p).nl {
        mk(Call(name, parseArgs(p, ~fn)), l)
      } else {
        mk(Ident(name), l)
      }
    }
  | UIdent(name) =>
    bump(p)
    if isOp(p, ".") {
      // Module path: Math.sqrt(x), IC10.l(...)
      let qualified = parseQualifiedName(p, ~fn, name)
      if isOp(p, "(") && !cur(p).nl {
        mk(Call(qualified, parseArgs(p, ~fn)), l)
      } else {
        mk(Ident(qualified), l)
      }
    } else if isOp(p, "(") && !cur(p).nl {
      mk(Constructor(name, parseArgs(p, ~fn)), l)
    } else {
      mk(Constructor(name, []), l)
    }
  | Op("(") =>
    if !p.inGuard && looksLikeLambda(p) {
      parseLambda(p)
    } else {
      bump(p)
      if isOp(p, ")") {
        bump(p)
        mk(Unit, l)
      } else {
        let inner = parseExpr(p)
        if isOp(p, ":") {
          // (e: type)
          bump(p)
          let _ = parseType(p)
        }
        if isOp(p, ",") {
          fail(p, ~fn, "tuples are not supported")
        }
        expectOp(p, ~fn, ")")
        inner
      }
    }
  | Op("{") => parseBlock(p)
  | Keyword("if") => parseIf(p)
  | Keyword("switch") => parseSwitch(p)
  | Keyword("while") =>
    bump(p)
    let cond = parseExpr(p)
    let body = parseBlock(p)
    mk(While(cond, body), l)
  | Keyword("for") =>
    bump(p)
    let var = expectIdent(p, ~fn)
    expectKeyword(p, ~fn, "in")
    let from = parseExpr(p)
    let down = if isKeyword(p, "downto") {
      bump(p)
      true
    } else {
      expectKeyword(p, ~fn, "to")
      false
    }
    let to_ = parseExpr(p)
    let body = parseBlock(p)
    mk(For(var, from, to_, down, body), l)
  | Extension("raw") =>
    bump(p)
    expectOp(p, ~fn, "(")
    let text = switch tok(p) {
    | String(s) =>
      bump(p)
      s
    | other => fail(p, ~fn, `expected a string literal in %raw() but found ${describe(other)}`)
    }
    expectOp(p, ~fn, ")")
    mk(Raw(text), l)
  | Extension(name) => fail(p, ~fn, `extension point %${name} is not supported`)
  | Op("[") => fail(p, ~fn, "arrays are not supported")
  | Op("#") => fail(p, ~fn, "polymorphic variants are not supported")
  | Keyword(kw) => fail(p, ~fn, `unexpected keyword '${kw}' in expression`)
  | other => fail(p, ~fn, `unexpected ${describe(other)} in expression`)
  }
}

and parseIf = (p): expr => {
  let fn = "parseIf"
  let l = loc(p)
  expectKeyword(p, ~fn, "if")
  let cond = parseExpr(p)
  let thenE = parseBlock(p)
  let elseE = if isKeyword(p, "else") {
    bump(p)
    if isKeyword(p, "if") {
      Some(parseIf(p))
    } else {
      Some(parseBlock(p))
    }
  } else {
    None
  }
  mk(If(cond, thenE, elseE), l)
}

and parseSwitch = (p): expr => {
  let fn = "parseSwitch"
  let l = loc(p)
  expectKeyword(p, ~fn, "switch")
  let scrutinee = parseExpr(p)
  expectOp(p, ~fn, "{")
  let cases = []
  while !isOp(p, "}") {
    let caseLoc = loc(p)
    expectOp(p, ~fn, "|")
    let pattern = parsePattern(p)
    let guard = if isKeyword(p, "if") || isKeyword(p, "when") {
      bump(p)
      let saved = p.inGuard
      p.inGuard = true
      let g = parseExpr(p)
      p.inGuard = saved
      Some(g)
    } else {
      None
    }
    expectOp(p, ~fn, "=>")
    // Case body: a sequence of statements up to the next `|` or `}`
    let bodyLoc = loc(p)
    let stmts = []
    while !isOp(p, "|") && !isOp(p, "}") {
      if tok(p) == EOF {
        fail(p, ~fn, "unterminated switch: expected '}'")
      }
      stmts->Array.push(parseStatement(p))
      skipSemis(p)
    }
    let body = switch stmts {
    | [Expr(e)] => e
    | _ => mk(Block(stmts), bodyLoc)
    }
    cases->Array.push({pattern, guard, body, caseLoc})
  }
  expectOp(p, ~fn, "}")
  if cases->Array.length == 0 {
    Errors.fail(~file, ~fn, ~loc=l, "switch must have at least one case")
  }
  mk(Switch(scrutinee, cases), l)
}

and parseBlock = (p): expr => {
  let fn = "parseBlock"
  let l = loc(p)
  expectOp(p, ~fn, "{")
  let stmts = []
  skipSemis(p)
  while !isOp(p, "}") {
    if tok(p) == EOF {
      fail(p, ~fn, "expected '}' but reached end of file")
    }
    stmts->Array.push(parseStatement(p))
    skipSemis(p)
  }
  expectOp(p, ~fn, "}")
  mk(Block(stmts), l)
}

// Dotted module path after its first segment: Furnace.Sensors
and parseModulePath = (p, ~fn, first: string): string => {
  let name = ref(first)
  while isOp(p, ".") {
    switch peekAt(p, 1).tok {
    | UIdent(n) =>
      bump(p)
      bump(p)
      name := name.contents ++ "." ++ n
    | other => fail(p, ~fn, `expected a module name after '.' but found ${describe(other)}`)
    }
  }
  name.contents
}

and parseTypeDecl = (p): option<stmt> => {
  let fn = "parseTypeDecl"
  let l = loc(p)
  expectKeyword(p, ~fn, "type")
  if isKeyword(p, "rec") {
    bump(p)
  }
  let name = expectIdent(p, ~fn)
  if isOp(p, "<") {
    fail(p, ~fn, "generic types are not supported")
  }
  expectOp(p, ~fn, "=")
  let isVariant = switch (tok(p), peekAt(p, 1).tok) {
  | (Op("|"), _) => true
  | (UIdent(_), Op(".")) => false
  | (UIdent(_), _) => true
  | _ => false
  }
  if isOp(p, "{") {
    fail(p, ~fn, "record types are not supported", ~hint="use a variant with payload instead")
  } else if !isVariant {
    // type alias: `type temp = float` - nothing to compile
    let _ = parseType(p)
    None
  } else {
    let ctors = []
    if isOp(p, "|") {
      bump(p)
    }
    let parseCtor = () => {
      let cloc = loc(p)
      switch tok(p) {
      | UIdent(cname) =>
        bump(p)
        let argTypes = []
        if isOp(p, "(") {
          bump(p)
          argTypes->Array.push(parseType(p)->Option.getOr(""))
          while isOp(p, ",") {
            bump(p)
            argTypes->Array.push(parseType(p)->Option.getOr(""))
          }
          expectOp(p, ~fn, ")")
        }
        ctors->Array.push({cname, argTypes, cloc})
      | other => fail(p, ~fn, `expected a constructor name but found ${describe(other)}`)
      }
    }
    parseCtor()
    while isOp(p, "|") {
      bump(p)
      parseCtor()
    }
    Some(TypeDecl(name, ctors, l))
  }
}

and parseStatement = (p): stmt => {
  let fn = "parseStatement"
  let l = loc(p)
  switch tok(p) {
  | Keyword("let") =>
    bump(p)
    if isKeyword(p, "rec") {
      fail(p, ~fn, "recursive functions are not supported", ~hint="IC10 has no call stack frames; use a while loop")
    }
    let name = switch tok(p) {
    | Ident(n) =>
      bump(p)
      n
    | Op("(") => fail(p, ~fn, "destructuring is not supported")
    | other => fail(p, ~fn, `expected a name after 'let' but found ${describe(other)}`)
    }
    if isOp(p, ":") {
      bump(p)
      let _ = parseType(p)
    }
    expectOp(p, ~fn, "=")
    let value = parseExpr(p)
    if isKeyword(p, "and") {
      fail(p, ~fn, "'let ... and ...' is not supported")
    }
    Let(name, value, l)
  | Keyword("type") =>
    switch parseTypeDecl(p) {
    | Some(s) => s
    | None => Expr(mk(Unit, l))
    }
  | Keyword("open") =>
    bump(p)
    switch tok(p) {
    | UIdent(first) =>
      bump(p)
      Open(parseModulePath(p, ~fn, first), l)
    | other => fail(p, ~fn, `expected a module name after 'open' but found ${describe(other)}`)
    }
  | Keyword("module") =>
    bump(p)
    if isKeyword(p, "type") {
      fail(p, ~fn, "module types are not supported")
    }
    let name = switch tok(p) {
    | UIdent(n) =>
      bump(p)
      n
    | other => fail(p, ~fn, `expected a module name but found ${describe(other)}`)
    }
    if isOp(p, "(") || isOp(p, ":") {
      fail(p, ~fn, "functors and module signatures are not supported", ~hint="use a plain module Name = { ... }")
    }
    expectOp(p, ~fn, "=")
    switch tok(p) {
    | Op("(") =>
      fail(p, ~fn, "functors are not supported", ~hint="use a plain module Name = { ... }")
    | Op("{") =>
      bump(p)
      let stmts = []
      skipSemis(p)
      while !isOp(p, "}") {
        if tok(p) == EOF {
          fail(p, ~fn, `expected '}' closing module ${name}`)
        }
        stmts->Array.push(parseStatement(p))
        skipSemis(p)
      }
      expectOp(p, ~fn, "}")
      Module(name, stmts, l)
    | _ => fail(p, ~fn, "module aliases (module A = B) are not supported")
    }
  | Keyword("external") => fail(p, ~fn, "externals are not supported")
  | Keyword("exception") | Keyword("try") => fail(p, ~fn, "exceptions are not supported")
  | Op("@") => fail(p, ~fn, "attributes are not supported")
  | _ => Expr(parseExpr(p))
  }
}

let parse = (tokens: array<Lexer.t>): program => {
  let p = {tokens, pos: 0, inGuard: false}
  let stmts = []
  skipSemis(p)
  while tok(p) != EOF {
    stmts->Array.push(parseStatement(p))
    skipSemis(p)
  }
  stmts
}
