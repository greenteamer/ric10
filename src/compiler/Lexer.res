// Simple lexer for ReScript → IC10 compiler
// Tokenizes ReScript source code into a stream of tokens

// Token type definitions
type token =
  | Let // keyword: let
  | If // keyword: if
  | Else // keyword: else
  | Identifier(string) // variable names, function names
  | IntLiteral(int) // integer literals
  | Plus // +
  | Minus // -
  | Multiply // *
  | Divide // /
  | GreaterThan // >
  | LessThan // <
  | Assign // =
  | EqualEqual // ==
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
    | Some("(") => (advance(lexer), LeftParen)
    | Some(")") => (advance(lexer), RightParen)
    | Some("{") => (advance(lexer), LeftBrace)
    | Some("}") => (advance(lexer), RightBrace)
    | Some("=") =>
      let lexer = advance(lexer)
      switch peekChar(lexer) {
      | Some("=") => (advance(lexer), EqualEqual)
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
      | _ => (lexer, Identifier(ident))
      }
    | Some(c) =>
      let lexer = advance(lexer)
      (lexer, Invalid("Unexpected character: " ++ c))
    }
  }
}

// Tokenize entire source code into array of tokens
let tokenize = (source: string): result<array<token>, string> => {
  let tokens: ref<array<token>> = ref(Array.make(~length=0, Let))
  let rec loop = (lexer: lexer): result<unit, string> => {
    let (lexer, token) = nextToken(lexer)
    switch token {
    | EOF => Ok()
    | Invalid(msg) => Error("Lexer error: " ++ msg)
    | _ => {
        let current = tokens.contents
        let len = Array.length(current)
        let newArr = Array.make(~length=len + 1, Let)
        for i in 0 to len - 1 {
          switch current[i] {
          | Some(v) => newArr[i] = v
          | None => ()
          }
        }
        newArr[len] = token
        tokens := newArr
        loop(lexer)
      }
    }
  }
  switch loop(create(source)) {
  | Ok(_) => Ok(tokens.contents)
  | Error(msg) => Error(msg)
  }
}

// Helper: Convert token to string for debugging
let tokenToString = (token: token): string => {
  switch token {
  | Let => "Let"
  | If => "If"
  | Else => "Else"
  | Identifier(name) => "Identifier(" ++ name ++ ")"
  | IntLiteral(n) => "IntLiteral(" ++ Int.toString(n) ++ ")"
  | Plus => "Plus"
  | Minus => "Minus"
  | Multiply => "Multiply"
  | Divide => "Divide"
  | GreaterThan => "GreaterThan"
  | LessThan => "LessThan"
  | Assign => "Assign"
  | EqualEqual => "EqualEqual"
  | LeftParen => "LeftParen"
  | RightParen => "RightParen"
  | LeftBrace => "LeftBrace"
  | RightBrace => "RightBrace"
  | EOF => "EOF"
  | Invalid(msg) => "Invalid(" ++ msg ++ ")"
  }
}
