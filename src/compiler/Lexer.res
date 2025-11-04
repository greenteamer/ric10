// Simple lexer for ReScript → IC10 compiler
// Tokenizes ReScript source code into a stream of tokens

// Token type definitions
type token =
  | Let // keyword: let
  | If // keyword: if
  | Else // keyword: else
  | While // keyword: while
  | Type // keyword: type
  | Switch // keyword: switch
  | Ref // keyword: ref
  | True // keyword: true
  | Identifier(string) // variable names, function names
  | IntLiteral(int) // integer literals
  | StringLiteral(string) // string literals
  | Plus // +
  | Minus // -
  | Multiply // *
  | Divide // /
  | GreaterThan // >
  | LessThan // <
  | Assign // =
  | EqualEqual // ==
  | Arrow // =>
  | Pipe // |
  | ColonEqual // :=
  | Dot // .
  | Percent // %
  | Comma // ,
  | LeftParen // (
  | RightParen // )
  | LeftBrace // {
  | RightBrace // }
  | EOF // End of file
  | Invalid(string) // Invalid token (for error reporting)

// Lexer state
type lexer = {
  source: string,
  position: int,
  length: int,
}

// Create a new lexer from source code
let create = (source: string): lexer => {
  {
    source,
    position: 0,
    length: source->String.length,
  }
}

// Check if we've reached end of input
let isEOF = (lexer: lexer): bool => {
  lexer.position >= lexer.length
}

// Peek at current character without advancing
let peekChar = (lexer: lexer): option<string> => {
  if isEOF(lexer) {
    None
  } else {
    Some(String.slice(lexer.source, ~start=lexer.position, ~end=lexer.position + 1))
  }
}

// Advance position by one
let advance = (lexer: lexer): lexer => {
  {...lexer, position: lexer.position + 1}
}

// Skip whitespace characters
let skipWhitespace = (lexer: lexer): lexer => {
  let rec loop = (l: lexer): lexer => {
    switch peekChar(l) {
    | Some(" ") | Some("\t") | Some("\n") | Some("\r") => loop(advance(l))
    | _ => l
    }
  }
  loop(lexer)
}

// Read an integer literal
let readInteger = (lexer: lexer): (lexer, int) => {
  let isDigit = (c: string): bool => {
    c == "0" ||
    c == "1" ||
    c == "2" ||
    c == "3" ||
    c == "4" ||
    c == "5" ||
    c == "6" ||
    c == "7" ||
    c == "8" ||
    c == "9"
  }
  let rec loop = (l: lexer, acc: string): (lexer, int) => {
    switch peekChar(l) {
    | Some(c) if isDigit(c) =>
      let l = advance(l)
      loop(l, acc ++ c)
    | _ =>
      switch Int.fromString(acc) {
      | Some(n) => (l, n)
      | None => (l, 0)
      }
    }
  }
  switch peekChar(lexer) {
  | Some(c) if isDigit(c) => loop(advance(lexer), c)
  | _ => (lexer, 0)
  }
}

// Read an identifier (starts with letter or _, followed by letters, digits, or _)
let readIdentifier = (lexer: lexer): (lexer, string) => {
  let isLetterOrUnderscore = (c: string): bool => {
    (c >= "a" && c <= "z") || c >= "A" && c <= "Z" || c == "_"
  }
  let isAlphanumericOrUnderscore = (c: string): bool => {
    isLetterOrUnderscore(c) || (c >= "0" && c <= "9")
  }
  let rec loop = (l: lexer, acc: string): (lexer, string) => {
    switch peekChar(l) {
    | Some(c) if isAlphanumericOrUnderscore(c) =>
      let l = advance(l)
      loop(l, acc ++ c)
    | _ => (l, acc)
    }
  }
  switch peekChar(lexer) {
  | Some(c) if isLetterOrUnderscore(c) =>
    let l = advance(lexer)
    loop(l, c)
  | _ => (lexer, "")
  }
}

// Read a string literal (handles "string")
let readStringLiteral = (lexer: lexer): (lexer, string) => {
  let rec loop = (l: lexer, acc: string): (lexer, string) => {
    switch peekChar(l) {
    | Some("\"") => (advance(l), acc) // End quote
    | Some("\\") =>
      // Handle escape sequences
      let l = advance(l)
      switch peekChar(l) {
      | Some("n") => loop(advance(l), acc ++ "\n")
      | Some("t") => loop(advance(l), acc ++ "\t")
      | Some("\\") => loop(advance(l), acc ++ "\\")
      | Some("\"") => loop(advance(l), acc ++ "\"")
      | Some(c) => loop(advance(l), acc ++ c) // Unknown escape, keep as is
      | None => (l, acc)
      }
    | Some(c) => loop(advance(l), acc ++ c)
    | None => (l, acc) // Unterminated string
    }
  }
  switch peekChar(lexer) {
  | Some("\"") => loop(advance(lexer), "")
  | _ => (lexer, "")
  }
}

// Read next token from source
let nextToken = (lexer: lexer): (lexer, token) => {
  let lexer = skipWhitespace(lexer)
  if isEOF(lexer) {
    (lexer, EOF)
  } else {
    switch peekChar(lexer) {
    | None => (lexer, EOF)
    | Some("+") => (advance(lexer), Plus)
    | Some("-") => (advance(lexer), Minus)
    | Some("*") => (advance(lexer), Multiply)
    | Some("/") => (advance(lexer), Divide)
    | Some(">") => (advance(lexer), GreaterThan)
    | Some("<") => (advance(lexer), LessThan)
    | Some("|") => (advance(lexer), Pipe)
    | Some(".") => (advance(lexer), Dot)
    | Some("%") => (advance(lexer), Percent)
    | Some(",") => (advance(lexer), Comma)
    | Some("(") => (advance(lexer), LeftParen)
    | Some(")") => (advance(lexer), RightParen)
    | Some("{") => (advance(lexer), LeftBrace)
    | Some("}") => (advance(lexer), RightBrace)
    | Some("\"") =>
      let (lexer, str) = readStringLiteral(lexer)
      (lexer, StringLiteral(str))
    | Some(":") =>
      let lexer = advance(lexer)
      switch peekChar(lexer) {
      | Some("=") => (advance(lexer), ColonEqual)
      | _ => (lexer, Invalid("Unexpected character ':'"))
      }
    | Some("=") =>
      let lexer = advance(lexer)
      switch peekChar(lexer) {
      | Some("=") => (advance(lexer), EqualEqual)
      | Some(">") => (advance(lexer), Arrow)
      | _ => (lexer, Assign)
      }
    | Some(c) if c >= "0" && c <= "9" =>
      let (lexer, value) = readInteger(lexer)
      (lexer, IntLiteral(value))
    | Some(c) if (c >= "a" && c <= "z") || c >= "A" && c <= "Z" || c == "_" =>
      let (lexer, ident) = readIdentifier(lexer)
      switch ident {
      | "let" => (lexer, Let)
      | "if" => (lexer, If)
      | "else" => (lexer, Else)
      | "while" => (lexer, While)
      | "type" => (lexer, Type)
      | "switch" => (lexer, Switch)
      | "ref" => (lexer, Ref)
      | "true" => (lexer, True)
      | _ => (lexer, Identifier(ident))
      }
    | Some(c) =>
      let lexer = advance(lexer)
      (lexer, Invalid("Unexpected character: " ++ c))
    }
  }
}

// Tokenize entire source code into array of tokens
// Uses List for O(1) cons operations, then converts to array
let tokenize = (source: string): result<array<token>, string> => {
  let rec loop = (lexer: lexer, acc: list<token>): result<list<token>, string> => {
    let (lexer, token) = nextToken(lexer)
    switch token {
    | EOF => Ok(acc)
    | Invalid(msg) => Error("Lexer error: " ++ msg)
    | _ => loop(lexer, list{token, ...acc}) // O(1) cons operation
    }
  }
  switch loop(create(source), list{}) {
  | Ok(tokens) => Ok(List.toArray(List.reverse(tokens))) // Convert list to array
  | Error(msg) => Error(msg)
  }
}

// Helper: Convert token to string for debugging
let tokenToString = (token: token): string => {
  switch token {
  | Let => "Let"
  | If => "If"
  | Else => "Else"
  | While => "While"
  | Type => "Type"
  | Switch => "Switch"
  | Ref => "Ref"
  | True => "True"
  | Identifier(name) => "Identifier(" ++ name ++ ")"
  | IntLiteral(n) => "IntLiteral(" ++ Int.toString(n) ++ ")"
  | StringLiteral(str) => "StringLiteral(" ++ str ++ ")"
  | Plus => "Plus"
  | Minus => "Minus"
  | Multiply => "Multiply"
  | Divide => "Divide"
  | GreaterThan => "GreaterThan"
  | LessThan => "LessThan"
  | Assign => "Assign"
  | EqualEqual => "EqualEqual"
  | Arrow => "Arrow"
  | Pipe => "Pipe"
  | ColonEqual => "ColonEqual"
  | Dot => "Dot"
  | Percent => "Percent"
  | Comma => "Comma"
  | LeftParen => "LeftParen"
  | RightParen => "RightParen"
  | LeftBrace => "LeftBrace"
  | RightBrace => "RightBrace"
  | EOF => "EOF"
  | Invalid(msg) => "Invalid(" ++ msg ++ ")"
  }
}
