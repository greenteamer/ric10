// Lexer: ReScript source -> tokens with source positions.
//
// Covers the ReScript 12 subset the compiler understands: numbers (int, float,
// hex, binary, exponent, `_` separators), strings, identifiers, keywords,
// all arithmetic/bitwise/comparison operators, `->`, `%raw`, line and block
// comments.

type token =
  | Number(float, bool) // value, written as a float literal (`1.5`, `2.`, `1e3`)
  | String(string)
  | Ident(string) // lowercase / `_` identifiers
  | UIdent(string) // Capitalized identifiers: constructors, modules
  | Keyword(string) // let, if, else, while, for, in, to, downto, switch, type, true, false, rec, and
  | Extension(string) // %raw -> Extension("raw")
  | Op(string) // operators and punctuation
  | EOF

type t = {
  tok: token,
  loc: Errors.loc,
  nl: bool, // preceded by a line break (used to stop function application across lines)
}

let keywords = ["let", "if", "else", "while", "for", "in", "to", "downto", "switch", "type", "true", "false", "rec", "and", "mutable", "module", "open", "external", "exception", "try", "when", "as", "of", "assert", "lazy"]

// Longest match first
let operators = [
  "...",
  "===",
  "!==",
  ">>>",
  "&&&",
  "|||",
  "^^^",
  "~~~",
  "**",
  "+.",
  "-.",
  "*.",
  "/.",
  "==",
  "!=",
  "<=",
  ">=",
  "&&",
  "||",
  "<<",
  ">>",
  ":=",
  "=>",
  "->",
  "|>",
  "+",
  "-",
  "*",
  "/",
  "%",
  "<",
  ">",
  "!",
  "=",
  "|",
  "?",
  ":",
  ".",
  ",",
  ";",
  "(",
  ")",
  "{",
  "}",
  "[",
  "]",
  "@",
  "#",
  "~",
  "^",
  "&",
]

let isDigit = c => c >= "0" && c <= "9"
let isLower = c => (c >= "a" && c <= "z") || c == "_"
let isUpper = c => c >= "A" && c <= "Z"
let isIdentChar = c => isLower(c) || isUpper(c) || isDigit(c) || c == "'"
let isHexDigit = c => isDigit(c) || (c >= "a" && c <= "f") || (c >= "A" && c <= "F")

let tokenToString = (tok: token): string =>
  switch tok {
  | Number(n, true) => Float.toString(n) ++ (NumUtil.isInteger(n) ? "." : "")
  | Number(n, false) => Float.toString(n)
  | String(s) => `"${s}"`
  | Ident(s) | UIdent(s) | Keyword(s) | Op(s) => s
  | Extension(s) => "%" ++ s
  | EOF => "end of file"
  }

let fail = (loc, message) => Errors.fail(~file="Lexer.res", ~fn="tokenize", ~loc, message)

let tokenize = (source: string): array<t> => {
  let len = String.length(source)
  let pos = ref(0)
  let line = ref(1)
  let col = ref(1)
  let sawNewline = ref(true)
  let tokens = []

  let charAt = i => i < len ? String.charAt(source, i) : ""
  let peek = (~offset=0) => charAt(pos.contents + offset)
  let advance = () => {
    let c = peek()
    pos := pos.contents + 1
    if c == "\n" {
      line := line.contents + 1
      col := 1
      sawNewline := true
    } else {
      col := col.contents + 1
    }
  }
  let here = (): Errors.loc => {line: line.contents, col: col.contents}
  let push = (tok, loc) => {
    tokens->Array.push({tok, loc, nl: sawNewline.contents})
    sawNewline := false
  }

  let rec skipBlockComment = (startLoc, depth) =>
    if pos.contents >= len {
      fail(startLoc, "unterminated block comment")
    } else if peek() == "*" && peek(~offset=1) == "/" {
      advance()
      advance()
      if depth > 1 {
        skipBlockComment(startLoc, depth - 1)
      }
    } else if peek() == "/" && peek(~offset=1) == "*" {
      advance()
      advance()
      skipBlockComment(startLoc, depth + 1)
    } else {
      advance()
      skipBlockComment(startLoc, depth)
    }

  let readWhile = pred => {
    let start = pos.contents
    while pos.contents < len && pred(peek()) {
      advance()
    }
    String.slice(source, ~start, ~end=pos.contents)
  }

  let readNumber = (loc: Errors.loc) => {
    let stripUnderscores = s => s->String.replaceAll("_", "")
    if peek() == "0" && (peek(~offset=1) == "x" || peek(~offset=1) == "X") {
      advance()
      advance()
      let digits = readWhile(c => isHexDigit(c) || c == "_")->stripUnderscores
      switch Int.fromString(digits, ~radix=16) {
      | Some(n) => Number(Int.toFloat(n), false)
      | None => fail(loc, "invalid hexadecimal literal")
      }
    } else if peek() == "0" && (peek(~offset=1) == "b" || peek(~offset=1) == "B") {
      advance()
      advance()
      let digits = readWhile(c => c == "0" || c == "1" || c == "_")->stripUnderscores
      switch Int.fromString(digits, ~radix=2) {
      | Some(n) => Number(Int.toFloat(n), false)
      | None => fail(loc, "invalid binary literal")
      }
    } else {
      let intPart = readWhile(c => isDigit(c) || c == "_")
      let isFloat = ref(false)
      let frac = if peek() == "." && !isLower(peek(~offset=1)) && !isUpper(peek(~offset=1)) {
        // `5.` and `5.25` are floats; `x.contents` never starts with a digit
        advance()
        isFloat := true
        "." ++ readWhile(c => isDigit(c) || c == "_")
      } else {
        ""
      }
      let exp = if (
        (peek() == "e" || peek() == "E") &&
          (isDigit(peek(~offset=1)) ||
          ((peek(~offset=1) == "-" || peek(~offset=1) == "+") && isDigit(peek(~offset=2))))
      ) {
        let e = peek()
        advance()
        let sign = if peek() == "-" || peek() == "+" {
          let s = peek()
          advance()
          s
        } else {
          ""
        }
        isFloat := true
        e ++ sign ++ readWhile(isDigit)
      } else {
        ""
      }
      let text = stripUnderscores(intPart ++ frac ++ exp)
      let text = text->String.endsWith(".") ? text ++ "0" : text
      switch Float.fromString(text) {
      | Some(n) => Number(n, isFloat.contents)
      | None => fail(loc, `invalid number literal '${text}'`)
      }
    }
  }

  let readString = (loc: Errors.loc) => {
    advance() // opening quote
    let buf = ref("")
    let closed = ref(false)
    while !closed.contents {
      if pos.contents >= len || peek() == "\n" {
        fail(loc, "unterminated string literal")
      }
      let c = peek()
      advance()
      if c == "\"" {
        closed := true
      } else if c == "\\" {
        let e = peek()
        advance()
        buf :=
          buf.contents ++
          switch e {
          | "n" => "\n"
          | "t" => "\t"
          | "\\" => "\\"
          | "\"" => "\""
          | other => other
          }
      } else {
        buf := buf.contents ++ c
      }
    }
    String(buf.contents)
  }

  while pos.contents < len {
    let c = peek()
    let loc = here()
    if c == " " || c == "\t" || c == "\r" || c == "\n" {
      advance()
    } else if c == "/" && peek(~offset=1) == "/" {
      while pos.contents < len && peek() != "\n" {
        advance()
      }
    } else if c == "/" && peek(~offset=1) == "*" {
      advance()
      advance()
      skipBlockComment(loc, 1)
    } else if isDigit(c) {
      push(readNumber(loc), loc)
    } else if c == "\"" {
      push(readString(loc), loc)
    } else if c == "`" {
      fail(loc, "template strings are not supported; use \"...\"")
    } else if isLower(c) {
      let word = readWhile(isIdentChar)
      push(keywords->Array.includes(word) ? Keyword(word) : Ident(word), loc)
    } else if isUpper(c) {
      push(UIdent(readWhile(isIdentChar)), loc)
    } else if c == "%" && (isLower(peek(~offset=1)) || isUpper(peek(~offset=1))) {
      advance()
      push(Extension(readWhile(c => isIdentChar(c) || c == ".")), loc)
    } else {
      switch operators->Array.find(op =>
        String.slice(source, ~start=pos.contents, ~end=pos.contents + String.length(op)) == op
      ) {
      | Some(op) =>
        for _ in 1 to String.length(op) {
          advance()
        }
        push(Op(op), loc)
      | None => fail(loc, `unexpected character '${c}'`)
      }
    }
  }
  tokens->Array.push({tok: EOF, loc: here(), nl: true})
  tokens
}
