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
  | (Lexer.Type, Lexer.Type) => true
  | (Lexer.Switch, Lexer.Switch) => true
  | (Lexer.Assign, Lexer.Assign) => true
  | (Lexer.Plus, Lexer.Plus) => true
  | (Lexer.Minus, Lexer.Minus) => true
  | (Lexer.Multiply, Lexer.Multiply) => true
  | (Lexer.Divide, Lexer.Divide) => true
  | (Lexer.GreaterThan, Lexer.GreaterThan) => true
  | (Lexer.LessThan, Lexer.LessThan) => true
  | (Lexer.EqualEqual, Lexer.EqualEqual) => true
  | (Lexer.Arrow, Lexer.Arrow) => true
  | (Lexer.Pipe, Lexer.Pipe) => true
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

// Parse primary expressions: literals, identifiers, parentheses, switch, variant constructors
and parsePrimaryExpression = (parser: parser): result<(parser, AST.expr), string> => {
  switch peek(parser) {
  | Some(Lexer.IntLiteral(value)) =>
    let parser = advance(parser)
    Ok((parser, AST.createLiteral(value)))
  | Some(Lexer.Switch) =>
    parseSwitchExpression(parser)
  | Some(Lexer.Identifier(name)) =>
    let parser = advance(parser)
    // Check if this is a variant constructor call: Constructor(arg)
    switch peek(parser) {
    | Some(Lexer.LeftParen) =>
      let parser = advance(parser) // consume (
      // Parse argument expression
      switch parseExpression(parser) {
      | Error(msg) => Error(msg)
      | Ok((parser, arg)) =>
        // Expect closing paren
        switch expect(parser, Lexer.RightParen) {
        | Error(msg) => Error(msg)
        | Ok(parser) => Ok((parser, AST.createVariantConstructor(name, Some(arg))))
        }
      }
    | _ => Ok((parser, AST.createIdentifier(name)))
    }
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

// Parse a switch expression: switch expr { | Pattern1 => body1 | Pattern2 => body2 }
// Part of expression parser mutual recursion, but calls parseBlockStatement (defined later)
and parseSwitchExpression = (parser: parser): result<(parser, AST.expr), string> => {
  // Expect "switch"
  switch expect(parser, Lexer.Switch) {
  | Error(msg) => Error(msg)
  | Ok(parser) =>
    // Parse scrutinee (the expression being matched)
    switch parseExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, scrutinee)) =>
      // Expect opening brace
      switch expect(parser, Lexer.LeftBrace) {
      | Error(msg) => Error(msg)
      | Ok(parser) =>
        // Parse match cases
        let rec parseMatchCases = (parser: parser, cases: list<AST.matchCase>): result<(parser, list<AST.matchCase>), string> => {
          // Check for closing brace
          switch peek(parser) {
          | Some(Lexer.RightBrace) =>
            Ok((advance(parser), cases))
          | Some(Lexer.Pipe) =>
            let parser = advance(parser) // consume |
            // Parse constructor name
            switch peek(parser) {
            | Some(Lexer.Identifier(constructorName)) =>
              let parser = advance(parser)

              // Check for argument binding: | Constructor(argName) =>
              let (parser, argumentBinding) = switch peek(parser) {
              | Some(Lexer.LeftParen) =>
                let parser = advance(parser) // consume (
                switch peek(parser) {
                | Some(Lexer.Identifier(argName)) =>
                  let parser = advance(parser)
                  switch expect(parser, Lexer.RightParen) {
                  | Error(_) => (parser, None) // fallback
                  | Ok(parser) => (parser, Some(argName))
                  }
                | _ => (parser, None)
                }
              | _ => (parser, None)
              }

              // Expect arrow
              switch expect(parser, Lexer.Arrow) {
              | Error(msg) => Error(msg)
              | Ok(parser) =>
                // Parse case body (either a block or a single expression)
                switch peek(parser) {
                | Some(Lexer.LeftBrace) =>
                  // Block statement - will call parseBlockStatement defined later
                  switch parseBlockStatement(parser) {
                  | Error(msg) => Error(msg)
                  | Ok((parser, body)) =>
                    let matchCase: AST.matchCase = {
                      constructorName: constructorName,
                      argumentBinding: argumentBinding,
                      body: body,
                    }
                    parseMatchCases(parser, list{matchCase, ...cases})
                  }
                | _ =>
                  // Single expression - wrap it in a "block"
                  switch parseExpression(parser) {
                  | Error(msg) => Error(msg)
                  | Ok((parser, expr)) =>
                    let matchCase: AST.matchCase = {
                      constructorName: constructorName,
                      argumentBinding: argumentBinding,
                      body: [expr], // Wrap single expression in array
                    }
                    parseMatchCases(parser, list{matchCase, ...cases})
                  }
                }
              }

            | Some(token) => Error("Expected constructor name in match case, found " ++ Lexer.tokenToString(token))
            | None => Error("Expected constructor name in match case, but reached end of file")
            }
          | Some(token) => Error("Expected '|' or '}' in match expression, found " ++ Lexer.tokenToString(token))
          | None => Error("Expected '|' or '}' in match expression, but reached end of file")
          }
        }

        switch parseMatchCases(parser, list{}) {
        | Error(msg) => Error(msg)
        | Ok((parser, cases)) =>
          Ok((parser, AST.createSwitchExpression(scrutinee, List.toArray(List.reverse(cases)))))
        }
      }
    }
  }
}

// Parse a variable declaration: let identifier = expression
// Part of the same mutual recursion group
and parseVariableDeclaration = (parser: parser): result<(parser, AST.astNode), string> => {
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

// Parse a type declaration: type name = Constructor1 | Constructor2(int) | ...
// Part of the same mutual recursion group
and parseTypeDeclaration = (parser: parser): result<(parser, AST.astNode), string> => {
  // Expect "type"
  switch expect(parser, Lexer.Type) {
  | Error(msg) => Error(msg)
  | Ok(parser) =>
    // Expect type name identifier
    switch peek(parser) {
    | Some(Lexer.Identifier(typeName)) =>
      let parser = advance(parser)
      // Expect "="
      switch expect(parser, Lexer.Assign) {
      | Error(msg) => Error(msg)
      | Ok(parser) =>
        // Parse variant constructors
        let rec parseConstructors = (parser: parser, constructors: list<AST.variantConstructor>): result<(parser, list<AST.variantConstructor>), string> => {
          // Optionally consume leading pipe (for consistency)
          let parser = switch peek(parser) {
          | Some(Lexer.Pipe) => advance(parser)
          | _ => parser
          }

          // Expect constructor name
          switch peek(parser) {
          | Some(Lexer.Identifier(constructorName)) =>
            let parser = advance(parser)

            // Check for argument: Constructor(int)
            let (parser, hasArgument) = switch peek(parser) {
            | Some(Lexer.LeftParen) =>
              let parser = advance(parser) // consume (
              // For now, we just check for the presence of an argument
              // We expect an identifier (type name like "int") inside
              switch peek(parser) {
              | Some(Lexer.Identifier(_)) =>
                let parser = advance(parser) // consume type identifier
                // Expect closing paren
                switch expect(parser, Lexer.RightParen) {
                | Error(msg) => (parser, false) // fallback
                | Ok(parser) => (parser, true)
                }
              | _ => (parser, false)
              }
            | _ => (parser, false)
            }

            let constructor: AST.variantConstructor = {
              name: constructorName,
              hasArgument: hasArgument,
            }

            // Check for more constructors (separated by |)
            switch peek(parser) {
            | Some(Lexer.Pipe) =>
              parseConstructors(parser, list{constructor, ...constructors})
            | _ =>
              Ok((parser, list{constructor, ...constructors}))
            }

          | Some(token) => Error("Expected constructor name, found " ++ Lexer.tokenToString(token))
          | None => Error("Expected constructor name, but reached end of file")
          }
        }

        switch parseConstructors(parser, list{}) {
        | Error(msg) => Error(msg)
        | Ok((parser, constructors)) =>
          Ok((parser, AST.createTypeDeclaration(typeName, List.toArray(List.reverse(constructors)))))
        }
      }
    | Some(token) => Error("Expected type name after 'type', found " ++ Lexer.tokenToString(token))
    | None => Error("Expected type name after 'type', but reached end of file")
    }
  }
}

// Parse an if statement: if expression { statements } else { statements }?
// Part of the same mutual recursion group as expression parsers
and parseIfStatement = (parser: parser): result<(parser, AST.astNode), string> => {
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
  | Some(Lexer.Type) => parseTypeDeclaration(parser)
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
// Uses List for O(1) cons operations, then converts to array
and parseBlockStatement = (parser: parser): result<(parser, AST.blockStatement), string> => {
  switch expect(parser, Lexer.LeftBrace) {
  | Error(msg) => Error(msg)
  | Ok(parser) =>
    let rec parseStatements = (parser: parser, statements: list<AST.astNode>): result<(parser, list<AST.astNode>), string> => {
      switch peek(parser) {
      | Some(Lexer.RightBrace) =>
        Ok((advance(parser), statements))
      | Some(_) =>
        switch parseStatement(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, stmt)) =>
          parseStatements(parser, list{stmt, ...statements}) // O(1) cons
        }
      | None => Error("Expected '}' but reached end of file")
      }
    }
    switch parseStatements(parser, list{}) {
    | Error(msg) => Error(msg)
    | Ok((parser, statements)) => Ok((parser, List.toArray(List.reverse(statements))))
    }
  }
}

// Parse a program (sequence of statements)
// Uses List for O(1) cons operations, then converts to array
let parse = (tokens: array<Lexer.token>): result<AST.program, string> => {
  let parser = create(tokens)
  let rec parseStatements = (parser: parser, statements: list<AST.stmt>): result<(parser, list<AST.stmt>), string> => {
    if isEOF(parser) {
      Ok((parser, statements))
    } else {
      switch peek(parser) {
      | Some(Lexer.EOF) => Ok((parser, statements))
      | Some(_) =>
        switch parseStatement(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, stmt)) =>
          parseStatements(parser, list{stmt, ...statements}) // O(1) cons
        }
      | None => Ok((parser, statements))
      }
    }
  }
  switch parseStatements(parser, list{}) {
  | Error(msg) => Error("Parse error: " ++ msg)
  | Ok((_, statements)) => Ok(List.toArray(List.reverse(statements)))
  }
}
