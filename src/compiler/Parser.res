// Parser for ReScript → IC10 compiler
// Recursive descent parser that consumes tokens from Lexer and builds AST

// Parser state - tracks position in token array
type parser = {
  tokens: array<Lexer.token>,
  position: int,
  length: int,
}

// Create a parser from an array of tokens
let create = (tokens: array<Lexer.token>): parser => {
  {
    tokens,
    position: 0,
    length: Array.length(tokens),
  }
}

// Check if we've reached end of tokens
let isEOF = (parser: parser): bool => {
  parser.position >= parser.length
}

// Peek at current token without advancing
let peek = (parser: parser): option<Lexer.token> => {
  if isEOF(parser) {
    None
  } else {
    Array.get(parser.tokens, parser.position)
  }
}

// Advance to next token
let advance = (parser: parser): parser => {
  {...parser, position: parser.position + 1}
}

// Helper: Check if two tokens match
let tokensMatch = (token1: Lexer.token, token2: Lexer.token): bool => {
  switch (token1, token2) {
  | (Lexer.Let, Lexer.Let) => true
  | (Lexer.If, Lexer.If) => true
  | (Lexer.Else, Lexer.Else) => true
  | (Lexer.Assign, Lexer.Assign) => true
  | (Lexer.Plus, Lexer.Plus) => true
  | (Lexer.Minus, Lexer.Minus) => true
  | (Lexer.Multiply, Lexer.Multiply) => true
  | (Lexer.Divide, Lexer.Divide) => true
  | (Lexer.GreaterThan, Lexer.GreaterThan) => true
  | (Lexer.LessThan, Lexer.LessThan) => true
  | (Lexer.EqualEqual, Lexer.EqualEqual) => true
  | (Lexer.LeftParen, Lexer.LeftParen) => true
  | (Lexer.RightParen, Lexer.RightParen) => true
  | (Lexer.LeftBrace, Lexer.LeftBrace) => true
  | (Lexer.RightBrace, Lexer.RightBrace) => true
  | (Lexer.EOF, Lexer.EOF) => true
  | (Lexer.IntLiteral(n1), Lexer.IntLiteral(n2)) => n1 == n2
  | (Lexer.Identifier(s1), Lexer.Identifier(s2)) => s1 == s2
  | (Lexer.Invalid(s1), Lexer.Invalid(s2)) => s1 == s2
  | _ => false
  }
}

// Expect a specific token and advance, or return error
let expect = (parser: parser, expected: Lexer.token): result<parser, string> => {
  switch peek(parser) {
  | Some(token) if tokensMatch(token, expected) =>
    Ok(advance(parser))
  | Some(token) =>
    Error("Expected " ++ Lexer.tokenToString(expected) ++ " but found " ++ Lexer.tokenToString(token))
  | None =>
    Error("Expected " ++ Lexer.tokenToString(expected) ++ " but reached end of file")
  }
}

// Parse an expression: handles precedence and binary operators
let rec parseExpression = (parser: parser): result<(parser, AST.expr), string> => {
  parseAdditiveExpression(parser)
}

// Parse additive expressions (+, -)
and parseAdditiveExpression = (parser: parser): result<(parser, AST.expr), string> => {
  switch parseMultiplicativeExpression(parser) {
  | Error(msg) => Error(msg)
  | Ok((parser, left)) =>
    parseAdditiveExpressionRest(parser, left)
  }
}

and parseAdditiveExpressionRest = (parser: parser, left: AST.expr): result<(parser, AST.expr), string> => {
  switch peek(parser) {
  | Some(Lexer.Plus) =>
    let parser = advance(parser)
    switch parseMultiplicativeExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, right)) =>
      parseAdditiveExpressionRest(parser, AST.createBinaryExpression(AST.Add, left, right))
    }
  | Some(Lexer.Minus) =>
    let parser = advance(parser)
    switch parseMultiplicativeExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, right)) =>
      parseAdditiveExpressionRest(parser, AST.createBinaryExpression(AST.Sub, left, right))
    }
  | _ => Ok((parser, left))
  }
}

// Parse multiplicative expressions (*, /)
and parseMultiplicativeExpression = (parser: parser): result<(parser, AST.expr), string> => {
  switch parseComparisonExpression(parser) {
  | Error(msg) => Error(msg)
  | Ok((parser, left)) =>
    parseMultiplicativeExpressionRest(parser, left)
  }
}

and parseMultiplicativeExpressionRest = (parser: parser, left: AST.expr): result<(parser, AST.expr), string> => {
  switch peek(parser) {
  | Some(Lexer.Multiply) =>
    let parser = advance(parser)
    switch parseComparisonExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, right)) =>
      parseMultiplicativeExpressionRest(parser, AST.createBinaryExpression(AST.Mul, left, right))
    }
  | Some(Lexer.Divide) =>
    let parser = advance(parser)
    switch parseComparisonExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, right)) =>
      parseMultiplicativeExpressionRest(parser, AST.createBinaryExpression(AST.Div, left, right))
    }
  | _ => Ok((parser, left))
  }
}

// Parse comparison expressions (>, <, ==)
and parseComparisonExpression = (parser: parser): result<(parser, AST.expr), string> => {
  switch parsePrimaryExpression(parser) {
  | Error(msg) => Error(msg)
  | Ok((parser, left)) =>
    parseComparisonExpressionRest(parser, left)
  }
}

and parseComparisonExpressionRest = (parser: parser, left: AST.expr): result<(parser, AST.expr), string> => {
  switch peek(parser) {
  | Some(Lexer.GreaterThan) =>
    let parser = advance(parser)
    switch parsePrimaryExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, right)) =>
      parseComparisonExpressionRest(parser, AST.createBinaryExpression(AST.Gt, left, right))
    }
  | Some(Lexer.LessThan) =>
    let parser = advance(parser)
    switch parsePrimaryExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, right)) =>
      parseComparisonExpressionRest(parser, AST.createBinaryExpression(AST.Lt, left, right))
    }
  | Some(Lexer.EqualEqual) =>
    let parser = advance(parser)
    switch parsePrimaryExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, right)) =>
      parseComparisonExpressionRest(parser, AST.createBinaryExpression(AST.Eq, left, right))
    }
  | _ => Ok((parser, left))
  }
}

// Parse primary expressions: literals, identifiers, parentheses
and parsePrimaryExpression = (parser: parser): result<(parser, AST.expr), string> => {
  switch peek(parser) {
  | Some(Lexer.IntLiteral(value)) =>
    let parser = advance(parser)
    Ok((parser, AST.createLiteral(value)))
  | Some(Lexer.Identifier(name)) =>
    let parser = advance(parser)
    Ok((parser, AST.createIdentifier(name)))
  | Some(Lexer.LeftParen) =>
    let parser = advance(parser)
    switch parseExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, expr)) =>
      switch expect(parser, Lexer.RightParen) {
      | Error(msg) => Error(msg)
      | Ok(parser) => Ok((parser, expr))
      }
    }
  | Some(token) => Error("Unexpected token in expression: " ++ Lexer.tokenToString(token))
  | None => Error("Unexpected end of file in expression")
  }
}

// Parse a variable declaration: let identifier = expression
let parseVariableDeclaration = (parser: parser): result<(parser, AST.astNode), string> => {
  // Expect "let"
  switch expect(parser, Lexer.Let) {
  | Error(msg) => Error(msg)
  | Ok(parser) =>
    // Expect identifier
    switch peek(parser) {
    | Some(Lexer.Identifier(name)) =>
      let parser = advance(parser)
      // Expect "="
      switch expect(parser, Lexer.Assign) {
      | Error(msg) => Error(msg)
      | Ok(parser) =>
        // Parse expression
        switch parseExpression(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, expr)) =>
          Ok((parser, AST.createVariableDeclaration(name, expr)))
        }
      }
    | Some(token) => Error("Expected identifier after 'let', found " ++ Lexer.tokenToString(token))
    | None => Error("Expected identifier after 'let', but reached end of file")
    }
  }
}

// Parse an if statement: if expression { statements } else { statements }?
let rec parseIfStatement = (parser: parser): result<(parser, AST.astNode), string> => {
  // Parse: if expr { statements }
  switch parseExpression(parser) {
  | Error(msg) => Error(msg)
  | Ok((parser, condition)) =>
    switch parseBlockStatement(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, thenBlock)) =>
      // Check for else block
      switch peek(parser) {
      | Some(Lexer.Else) =>
        let parser = advance(parser) // consume 'else' token
        switch parseBlockStatement(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, elseBlock)) =>
          Ok((parser, AST.createIfStatement(condition, thenBlock, Some(elseBlock))))
        }
      | _ =>
        Ok((parser, AST.createIfStatement(condition, thenBlock, None)))
      }
    }
  }
}

// Parse a statement
and parseStatement = (parser: parser): result<(parser, AST.astNode), string> => {
  switch peek(parser) {
  | Some(Lexer.Let) => parseVariableDeclaration(parser)
  | Some(Lexer.If) =>
    let parser = advance(parser) // consume 'if' token
    parseIfStatement(parser)
  | Some(Lexer.LeftBrace) =>
    switch parseBlockStatement(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, block)) => Ok((parser, AST.createBlockStatement(block)))
    }
  | Some(Lexer.LeftParen) =>
    // Could be an if statement - for now parse as expression
    parseExpression(parser)
  | Some(_) =>
    // Try parsing as expression
    parseExpression(parser)
  | None => Error("Unexpected end of file")
  }
}

// Parse a block statement: { statements }
and parseBlockStatement = (parser: parser): result<(parser, AST.blockStatement), string> => {
  switch expect(parser, Lexer.LeftBrace) {
  | Error(msg) => Error(msg)
  | Ok(parser) =>
    let rec parseStatements = (parser: parser, statements: array<AST.astNode>): result<(parser, array<AST.astNode>), string> => {
      switch peek(parser) {
      | Some(Lexer.RightBrace) =>
        Ok((advance(parser), statements))
      | Some(_) =>
        switch parseStatement(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, stmt)) =>
          let newStatements = {
            let len = Array.length(statements)
            let newArr = Array.make(~length=len + 1, AST.createLiteral(0))
            for i in 0 to len - 1 {
              switch Array.get(statements, i) {
              | Some(v) => newArr[i] = v
              | None => ()
              }
            }
            newArr[len] = stmt
            newArr
          }
          parseStatements(parser, newStatements)
        }
      | None => Error("Expected '}' but reached end of file")
      }
    }
    switch parseStatements(parser, Array.make(~length=0, AST.createLiteral(0))) {
    | Error(msg) => Error(msg)
    | Ok((parser, statements)) => Ok((parser, statements))
    }
  }
}


// Parse a program (sequence of statements)
let parse = (tokens: array<Lexer.token>): result<AST.program, string> => {
  let parser = create(tokens)
  let rec parseStatements = (parser: parser, statements: array<AST.stmt>): result<(parser, array<AST.stmt>), string> => {
    if isEOF(parser) {
      Ok((parser, statements))
    } else {
      switch peek(parser) {
      | Some(Lexer.EOF) => Ok((parser, statements))
      | Some(_) =>
        switch parseStatement(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, stmt)) =>
          let newStatements = {
            let len = Array.length(statements)
            let newArr = Array.make(~length=len + 1, AST.createLiteral(0))
            for i in 0 to len - 1 {
              switch Array.get(statements, i) {
              | Some(v) => newArr[i] = v
              | None => ()
              }
            }
            newArr[len] = stmt
            newArr
          }
          parseStatements(parser, newStatements)
        }
      | None => Ok((parser, statements))
      }
    }
  }
  switch parseStatements(parser, Array.make(~length=0, AST.createLiteral(0))) {
  | Error(msg) => Error("Parse error: " ++ msg)
  | Ok((_, statements)) => Ok(statements)
  }
}
