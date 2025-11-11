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
    parser.tokens[parser.position]
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
  | (Lexer.While, Lexer.While) => true
  | (Lexer.Type, Lexer.Type) => true
  | (Lexer.Switch, Lexer.Switch) => true
  | (Lexer.Ref, Lexer.Ref) => true
  | (Lexer.True, Lexer.True) => true
  | (Lexer.Assign, Lexer.Assign) => true
  | (Lexer.ColonEqual, Lexer.ColonEqual) => true
  | (Lexer.Dot, Lexer.Dot) => true
  | (Lexer.Percent, Lexer.Percent) => true
  | (Lexer.Comma, Lexer.Comma) => true
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
  | (Lexer.StringLiteral(s1), Lexer.StringLiteral(s2)) => s1 == s2
  | (Lexer.Identifier(s1), Lexer.Identifier(s2)) => s1 == s2
  | (Lexer.Invalid(s1), Lexer.Invalid(s2)) => s1 == s2
  | _ => false
  }
}

// Expect a specific token and advance, or return error
let expect = (parser: parser, expected: Lexer.token): result<parser, string> => {
  switch peek(parser) {
  | Some(token) if tokensMatch(token, expected) => Ok(advance(parser))
  | Some(token) =>
    Error(
      "[Parser.res][expect]: expected " ++
      Lexer.tokenToString(expected) ++
      " but found " ++
      Lexer.tokenToString(token),
    )
  | None =>
    Error(
      "[Parser.res][expect]: expected " ++
      Lexer.tokenToString(expected) ++ " but reached end of file",
    )
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
  | Ok((parser, left)) => parseAdditiveExpressionRest(parser, left)
  }
}

and parseAdditiveExpressionRest = (parser: parser, left: AST.expr): result<
  (parser, AST.expr),
  string,
> => {
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
  | Ok((parser, left)) => parseMultiplicativeExpressionRest(parser, left)
  }
}

and parseMultiplicativeExpressionRest = (parser: parser, left: AST.expr): result<
  (parser, AST.expr),
  string,
> => {
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
// Parse postfix expressions like .contents
and parsePostfixExpression = (parser: parser, base: AST.expr): result<
  (parser, AST.expr),
  string,
> => {
  switch peek(parser) {
  | Some(Lexer.Dot) =>
    // Consume dot
    let parser = advance(parser)
    // Expect identifier for field name
    switch peek(parser) {
    | Some(Lexer.Identifier(fieldName)) =>
      Console.log2("[peek(parser)] identifier: ", (parser, fieldName))
      let parser = advance(parser)
      if fieldName == "contents" {
        // Base must be a simple identifier
        switch base {
        | AST.Identifier(refName) =>
          // Return RefAccess node
          Ok((parser, AST.createRefAccess(refName)))
        | _ =>
          Error(
            "[Parser.res][parsePostfixExpression]: only simple identifiers can be dereferenced with .contents",
          )
        }
      } else {
        Error("[Parser.res][parsePostfixExpression]: only .contents field is supported for refs")
      }
    | _ => Error("[Parser.res][parsePostfixExpression]: expected field name after '.'")
    }
  | _ =>
    // No postfix operator, return base as-is
    Ok((parser, base))
  }
}

and parseComparisonExpression = (parser: parser): result<(parser, AST.expr), string> => {
  switch parsePrimaryExpression(parser) {
  | Error(msg) => Error(msg)
  | Ok((parser, expr)) =>
    // Check for postfix operators like .contents
    switch parsePostfixExpression(parser, expr) {
    | Error(msg) => Error(msg)
    | Ok((parser, postfixExpr)) => parseComparisonExpressionRest(parser, postfixExpr)
    }
  }
}

and parseComparisonExpressionRest = (parser: parser, left: AST.expr): result<
  (parser, AST.expr),
  string,
> => {
  switch peek(parser) {
  | Some(Lexer.GreaterThan) =>
    let parser = advance(parser)
    switch parsePrimaryExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, right)) =>
      // Also handle postfix expressions like .contents on the right side
      switch parsePostfixExpression(parser, right) {
      | Error(msg) => Error(msg)
      | Ok((parser, rightPostfix)) =>
        parseComparisonExpressionRest(
          parser,
          AST.createBinaryExpression(AST.Gt, left, rightPostfix),
        )
      }
    }
  | Some(Lexer.LessThan) =>
    let parser = advance(parser)
    switch parsePrimaryExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, right)) =>
      // Also handle postfix expressions like .contents on the right side
      switch parsePostfixExpression(parser, right) {
      | Error(msg) => Error(msg)
      | Ok((parser, rightPostfix)) =>
        parseComparisonExpressionRest(
          parser,
          AST.createBinaryExpression(AST.Lt, left, rightPostfix),
        )
      }
    }
  | Some(Lexer.EqualEqual) =>
    let parser = advance(parser)
    switch parsePrimaryExpression(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, right)) =>
      // Also handle postfix expressions like .contents on the right side
      switch parsePostfixExpression(parser, right) {
      | Error(msg) => Error(msg)
      | Ok((parser, rightPostfix)) =>
        parseComparisonExpressionRest(
          parser,
          AST.createBinaryExpression(AST.Eq, left, rightPostfix),
        )
      }
    }
  | _ => Ok((parser, left))
  }
}

// Parse primary expressions: literals, identifiers, parentheses, switch, variant constructors
// Parse ref(expr) - ref creation
and parseRefCreation = (parser: parser): result<(parser, AST.expr), string> => {
  // Expect "ref" token (already consumed by caller)
  // Expect "("
  switch expect(parser, Lexer.LeftParen) {
  | Error(e) => Error(e)
  | Ok(parser) =>
    // Parse inner expression
    switch parseExpression(parser) {
    | Error(e) => Error(e)
    | Ok((parser, expr)) =>
      // Expect ")"
      switch expect(parser, Lexer.RightParen) {
      | Error(e) => Error(e)
      | Ok(parser) => Ok((parser, AST.createRefCreation(expr)))
      }
    }
  }
}

// Parse variant constructor arguments: (expr1, expr2, expr3)
// Returns array of expressions
and parseVariantConstructorArguments = (parser: parser): result<
  (parser, array<AST.expr>),
  string,
> => {
  // Expect opening paren
  switch expect(parser, Lexer.LeftParen) {
  | Error(msg) => Error(msg)
  | Ok(parser) =>
    let rec parseArgs = (parser: parser, args: list<AST.expr>): result<
      (parser, list<AST.expr>),
      string,
    > => {
      switch peek(parser) {
      | Some(Lexer.RightParen) =>
        // End of arguments
        Ok((advance(parser), args))
      | _ =>
        // Parse expression
        switch parseExpression(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, expr)) =>
          // Check for comma (more args) or closing paren
          switch peek(parser) {
          | Some(Lexer.RightParen) => Ok((advance(parser), list{expr, ...args}))
          | Some(Lexer.Comma) =>
            let parser = advance(parser) // consume comma
            parseArgs(parser, list{expr, ...args})
          | _ =>
            Error(
              "[Parser.res][parseVariantConstructorArgs]: expected ',' or ')' after variant constructor argument",
            )
          }
        }
      }
    }

    // Handle empty argument list
    switch peek(parser) {
    | Some(Lexer.RightParen) => Ok((advance(parser), []))
    | _ =>
      switch parseArgs(parser, list{}) {
      | Error(msg) => Error(msg)
      | Ok((parser, args)) => Ok((parser, List.toArray(List.reverse(args))))
      }
    }
  }
}

// Parse function call arguments: (arg1, arg2, ...)
// Arguments can be expressions, string literals, or device identifiers
and parseFunctionArguments = (parser: parser): result<(parser, array<AST.argument>), string> => {
  let rec parseArgs = (parser: parser, args: list<AST.argument>): result<
    (parser, list<AST.argument>),
    string,
  > => {
    switch peek(parser) {
    | Some(Lexer.RightParen) =>
      // End of arguments
      Ok((advance(parser), args))
    | Some(Lexer.StringLiteral(str)) =>
      // String literal argument
      let parser = advance(parser)
      let arg = AST.ArgString(str)
      // Check for comma (more arguments) or closing paren
      switch peek(parser) {
      | Some(Lexer.RightParen) => Ok((advance(parser), list{arg, ...args}))
      | Some(Lexer.Comma) =>
        // Consume comma and parse next argument
        let parser = advance(parser)
        parseArgs(parser, list{arg, ...args})
      | _ =>
        Error("[Parser.res][parseFunctionArguments]: expected ',' or ')' after function argument")
      }
    | Some(Lexer.Identifier(name)) =>
      // Check if this is a device identifier (d0-d5, db)
      let isDeviceId =
        name == "d0" ||
        name == "d1" ||
        name == "d2" ||
        name == "d3" ||
        name == "d4" ||
        name == "d5" ||
        name == "db"

      let isMode = name == "Maximum" || name == "Minimum" || name == "Average" || name == "Sum"

      switch (isDeviceId, isMode) {
      | (true, false) => {
          Console.log2("[parseFunctionArguments] device id: ", (parser, name))
          // Device identifier - treat as ArgDevice
          let parser = advance(parser)
          let arg = AST.ArgDevice(name)
          // Check for comma or closing paren
          switch peek(parser) {
          | Some(Lexer.RightParen) => Ok((advance(parser), list{arg, ...args}))
          | Some(Lexer.Comma) =>
            // Consume comma and parse next argument
            let parser = advance(parser)
            parseArgs(parser, list{arg, ...args})
          | _ =>
            Error(
              "[Parser.res][parseFunctionArguments]: expected ',' or ')' after function argument",
            )
          }
        }
      | (false, true) => {
          Console.log2("[parseFunctionArguments] mode id: ", (parser, name))
          let parser = advance(parser)

          let arg = AST.ArgMode(IC10.Mode.fromString(name)->Belt.Result.getExn)
          // Check for comma or closing paren
          switch peek(parser) {
          | Some(Lexer.RightParen) => Ok((advance(parser), list{arg, ...args}))
          | _ => Error("[Parser.res][parseFunctionArguments]: expected ')' after mode argument")
          }
        }
      | _ =>
        // Regular identifier - parse as expression
        switch parseExpression(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, expr)) =>
          let arg = AST.ArgExpr(expr)
          // Check for comma or closing paren
          switch peek(parser) {
          | Some(Lexer.RightParen) => Ok((advance(parser), list{arg, ...args}))
          | Some(Lexer.Comma) =>
            // Consume comma and parse next argument
            let parser = advance(parser)
            parseArgs(parser, list{arg, ...args})
          | _ =>
            Error(
              "[Parser.res][parseFunctionArguments]: expected ',' or ')' after function argument",
            )
          }
        }
      }

    | Some(_) =>
      // Expression argument (for other token types)
      switch parseExpression(parser) {
      | Error(msg) => Error(msg)
      | Ok((parser, expr)) =>
        let arg = AST.ArgExpr(expr)
        // Check for comma or closing paren
        switch peek(parser) {
        | Some(Lexer.RightParen) => Ok((advance(parser), list{arg, ...args}))
        | Some(Lexer.Comma) =>
          // Consume comma and parse next argument
          let parser = advance(parser)
          parseArgs(parser, list{arg, ...args})
        | _ =>
          Error("[Parser.res][parseFunctionArguments]: expected ',' or ')' after function argument")
        }
      }
    | None =>
      Error(
        "[Parser.res][parseFunctionArguments]: unexpected end of file while parsing function arguments",
      )
    }
  }

  // Expect opening paren
  switch expect(parser, Lexer.LeftParen) {
  | Error(msg) => Error(msg)
  | Ok(parser) =>
    // Handle empty argument list
    switch peek(parser) {
    | Some(Lexer.RightParen) => Ok((advance(parser), []))
    | _ =>
      switch parseArgs(parser, list{}) {
      | Error(msg) => Error(msg)
      | Ok((parser, args)) => Ok((parser, List.toArray(List.reverse(args))))
      }
    }
  }
}

and parsePrimaryExpression = (parser: parser): result<(parser, AST.expr), string> => {
  switch peek(parser) {
  | Some(Lexer.IntLiteral(value)) =>
    let parser = advance(parser)
    Ok((parser, AST.createLiteral(value)))
  | Some(Lexer.True) =>
    let parser = advance(parser)
    Ok((parser, AST.LiteralBool(true))) // boolean true literal
  | Some(Lexer.Ref) =>
    let parser = advance(parser)
    parseRefCreation(parser)
  | Some(Lexer.Switch) => parseSwitchExpression(parser)
  | Some(Lexer.StringLiteral(str)) =>
    let parser = advance(parser)
    Ok((parser, AST.createStringLiteral(str)))
  | Some(Lexer.Identifier(name)) =>
    let parser = advance(parser)
    // Check if this is followed by parentheses
    switch peek(parser) {
    | Some(Lexer.LeftParen) =>
      // Determine if this is a function call or variant constructor
      // IC10 functions: l, lb, lbn, s, sb, sbn, device
      // HASH is also a function (used in constants)
      let isIC10Function =
        name == "l" ||
        name == "lb" ||
        name == "lbn" ||
        name == "s" ||
        name == "sb" ||
        name == "sbn" ||
        name == "hash" ||
        name == "device"

      if isIC10Function {
        // Parse as function call with multiple arguments
        switch parseFunctionArguments(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, args)) => Ok((parser, AST.createFunctionCall(name, args)))
        }
      } else {
        // Parse as variant constructor with multiple arguments: Constructor(arg1, arg2, ...)
        switch parseVariantConstructorArguments(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, args)) => Ok((parser, AST.createVariantConstructor(name, args)))
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
        let rec parseMatchCases = (parser: parser, cases: list<AST.matchCase>): result<
          (parser, list<AST.matchCase>),
          string,
        > => {
          // Check for closing brace
          switch peek(parser) {
          | Some(Lexer.RightBrace) => Ok((advance(parser), cases))
          | Some(Lexer.Pipe) =>
            let parser = advance(parser) // consume |
            // Parse constructor name
            switch peek(parser) {
            | Some(Lexer.Identifier(constructorName)) =>
              let parser = advance(parser)

              // Check for argument bindings: | Constructor(arg1, arg2, arg3) =>
              let (parser, argumentBindings) = switch peek(parser) {
              | Some(Lexer.LeftParen) =>
                let parser = advance(parser) // consume (

                // Parse comma-separated argument names
                let rec parseBindings = (parser: parser, bindings: list<string>): (
                  parser,
                  list<string>,
                ) => {
                  switch peek(parser) {
                  | Some(Lexer.Identifier(argName)) =>
                    let parser = advance(parser)
                    // Check for comma (more args) or closing paren
                    switch peek(parser) {
                    | Some(Lexer.Comma) =>
                      let parser = advance(parser) // consume comma
                      parseBindings(parser, list{argName, ...bindings})
                    | Some(Lexer.RightParen) => (advance(parser), list{argName, ...bindings})
                    | _ => (parser, bindings) // error case, fallback
                    }
                  | Some(Lexer.RightParen) => (advance(parser), bindings) // empty parens
                  | _ => (parser, bindings) // error case, fallback
                  }
                }

                let (parser, bindings) = parseBindings(parser, list{})
                (parser, List.toArray(List.reverse(bindings)))
              | _ => (parser, [])
              }

              // Expect arrow
              switch expect(parser, Lexer.Arrow) {
              | Error(msg) => Error(msg)
              | Ok(parser) =>
                // Parse case body (either a block statement, a single statement, or a single expression)
                switch peek(parser) {
                | Some(Lexer.LeftBrace) =>
                  // Block statement - will call parseBlockStatement defined later
                  switch parseBlockStatement(parser) {
                  | Error(msg) => Error(msg)
                  | Ok((parser, body)) =>
                    let matchCase: AST.matchCase = {
                      constructorName,
                      argumentBindings,
                      body,
                    }
                    parseMatchCases(parser, list{matchCase, ...cases})
                  }
                | _ =>
                  // Try to parse as a statement first (for ref assignments, if statements, etc.)
                  // If that fails, fall back to parsing as an expression
                  switch parseStatement(parser) {
                  | Ok((parser, stmt)) =>
                    let matchCase: AST.matchCase = {
                      constructorName,
                      argumentBindings,
                      body: [stmt], // Wrap single statement in array
                    }
                    parseMatchCases(parser, list{matchCase, ...cases})
                  | Error(_) =>
                    // Statement parsing failed, try expression
                    switch parseExpression(parser) {
                    | Error(msg) => Error(msg)
                    | Ok((parser, expr)) =>
                      let matchCase: AST.matchCase = {
                        constructorName,
                        argumentBindings,
                        body: [expr], // Wrap single expression in array
                      }
                      parseMatchCases(parser, list{matchCase, ...cases})
                    }
                  }
                }
              }

            | Some(token) =>
              Error(
                "[Parser.res][parseSwitchExpression]: expected constructor name in match case, found " ++
                Lexer.tokenToString(token),
              )
            | None =>
              Error(
                "[Parser.res][parseSwitchExpression]: expected constructor name in match case, but reached end of file",
              )
            }
          | Some(token) =>
            Error(
              "[Parser.res][parseSwitchExpression]: expected '|' or '}' in match expression, found " ++
              Lexer.tokenToString(token),
            )
          | None =>
            Error(
              "[Parser.res][parseSwitchExpression]: expected '|' or '}' in match expression, but reached end of file",
            )
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
        | Ok((parser, expr)) => Ok((parser, AST.createVariableDeclaration(name, expr)))
        }
      }
    | Some(token) =>
      Error(
        "[Parser.res][parseVariableDeclaration]: expected identifier after 'let', found " ++
        Lexer.tokenToString(token),
      )
    | None =>
      Error(
        "[Parser.res][parseVariableDeclaration]: expected identifier after 'let', but reached end of file",
      )
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
        let rec parseConstructors = (
          parser: parser,
          constructors: list<AST.variantConstructor>,
        ): result<(parser, list<AST.variantConstructor>), string> => {
          // Optionally consume leading pipe (for consistency)
          let parser = switch peek(parser) {
          | Some(Lexer.Pipe) => advance(parser)
          | _ => parser
          }

          // Expect constructor name
          switch peek(parser) {
          | Some(Lexer.Identifier(constructorName)) =>
            let parser = advance(parser)

            // Check for arguments: Constructor(int, int, int)
            let (parser, argCount) = switch peek(parser) {
            | Some(Lexer.LeftParen) =>
              let parser = advance(parser) // consume (

              // Parse comma-separated type names to count arguments
              let rec countArgs = (parser: parser, count: int): (parser, int) => {
                switch peek(parser) {
                | Some(Lexer.Identifier(_)) =>
                  let parser = advance(parser) // consume type identifier
                  // Check for comma (more args) or closing paren
                  switch peek(parser) {
                  | Some(Lexer.Comma) =>
                    let parser = advance(parser) // consume comma
                    countArgs(parser, count + 1)
                  | Some(Lexer.RightParen) => (advance(parser), count + 1)
                  | _ => (parser, count) // error case, fallback
                  }
                | Some(Lexer.RightParen) => (advance(parser), count) // empty parens
                | _ => (parser, count) // error case, fallback
                }
              }

              countArgs(parser, 0)
            | _ => (parser, 0)
            }

            let constructor: AST.variantConstructor = {
              name: constructorName,
              argCount,
            }

            // Check for more constructors (separated by |)
            switch peek(parser) {
            | Some(Lexer.Pipe) => parseConstructors(parser, list{constructor, ...constructors})
            | _ => Ok((parser, list{constructor, ...constructors}))
            }

          | Some(token) =>
            Error(
              "[Parser.res][parseTypeDeclaration]: expected constructor name, found " ++
              Lexer.tokenToString(token),
            )
          | None =>
            Error(
              "[Parser.res][parseTypeDeclaration]: expected constructor name, but reached end of file",
            )
          }
        }

        switch parseConstructors(parser, list{}) {
        | Error(msg) => Error(msg)
        | Ok((parser, constructors)) =>
          Ok((
            parser,
            AST.createTypeDeclaration(typeName, List.toArray(List.reverse(constructors))),
          ))
        }
      }
    | Some(token) =>
      Error(
        "[Parser.res][parseTypeDeclaration]: expected type name after 'type', found " ++
        Lexer.tokenToString(token),
      )
    | None =>
      Error(
        "[Parser.res][parseTypeDeclaration]: expected type name after 'type', but reached end of file",
      )
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
      | _ => Ok((parser, AST.createIfStatement(condition, thenBlock, None)))
      }
    }
  }
}

// Parse a while loop: while condition { statements }
// Part of the same mutual recursion group as expression parsers
and parseWhileLoop = (parser: parser): result<(parser, AST.astNode), string> => {
  // Parse: while expr { statements }
  switch parseExpression(parser) {
  | Error(msg) => Error(msg)
  | Ok((parser, condition)) =>
    switch parseBlockStatement(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, body)) => Ok((parser, AST.createWhileLoop(condition, body)))
    }
  }
}

// Parse a statement
// Parse ref assignment: identifier := expr
and parseRefAssignment = (parser: parser, name: string): result<(parser, AST.stmt), string> => {
  // Expect ":=" (caller has already identified this pattern)
  switch expect(parser, Lexer.ColonEqual) {
  | Error(e) => Error(e)
  | Ok(parser) =>
    // Parse right-hand side expression
    switch parseExpression(parser) {
    | Error(e) => Error(e)
    | Ok((parser, expr)) => Ok((parser, AST.createRefAssignment(name, expr)))
    }
  }
}

// Parse %raw("instruction") - raw IC10 assembly instruction
and parseRawInstruction = (parser: parser): result<(parser, AST.astNode), string> => {
  // Expect %
  switch expect(parser, Lexer.Percent) {
  | Error(msg) => Error(msg)
  | Ok(parser) =>
    // Expect "raw" identifier
    switch peek(parser) {
    | Some(Lexer.Identifier("raw")) =>
      let parser = advance(parser)
      // Expect (
      switch expect(parser, Lexer.LeftParen) {
      | Error(msg) => Error(msg)
      | Ok(parser) =>
        // Expect string literal
        switch peek(parser) {
        | Some(Lexer.StringLiteral(instruction)) =>
          let parser = advance(parser)
          // Expect )
          switch expect(parser, Lexer.RightParen) {
          | Error(msg) => Error(msg)
          | Ok(parser) => Ok((parser, AST.createRawInstruction(instruction)))
          }
        | Some(token) =>
          Error(
            "[Parser.res][parseRawInstruction]: expected string literal in %raw() but found " ++
            Lexer.tokenToString(token),
          )
        | None =>
          Error(
            "[Parser.res][parseRawInstruction]: expected string literal in %raw() but reached end of file",
          )
        }
      }
    | Some(token) =>
      Error(
        "[Parser.res][parseRawInstruction]: expected 'raw' after % but found " ++
        Lexer.tokenToString(token),
      )
    | None =>
      Error("[Parser.res][parseRawInstruction]: expected 'raw' after % but reached end of file")
    }
  }
}

and parseStatement = (parser: parser): result<(parser, AST.astNode), string> => {
  switch peek(parser) {
  | Some(Lexer.Let) => parseVariableDeclaration(parser)
  | Some(Lexer.Type) => parseTypeDeclaration(parser)
  | Some(Lexer.If) =>
    let parser = advance(parser) // consume 'if' token
    parseIfStatement(parser)
  | Some(Lexer.While) =>
    let parser = advance(parser) // consume 'while' token
    parseWhileLoop(parser)
  | Some(Lexer.Percent) =>
    // Parse %raw("instruction")
    parseRawInstruction(parser)
  | Some(Lexer.LeftBrace) =>
    switch parseBlockStatement(parser) {
    | Error(msg) => Error(msg)
    | Ok((parser, block)) => Ok((parser, AST.createBlockStatement(block)))
    }
  | Some(Lexer.Identifier(name)) =>
    // Look ahead for := operator
    let parser1 = advance(parser) // Consume identifier
    switch peek(parser1) {
    | Some(Lexer.ColonEqual) =>
      // This is a ref assignment
      parseRefAssignment(parser1, name)
    | _ =>
      // Not an assignment, try parsing as expression
      parseExpression(parser)
    }
  | Some(Lexer.LeftParen) =>
    // Could be an if statement - for now parse as expression
    parseExpression(parser)
  | Some(_) =>
    // Try parsing as expression
    parseExpression(parser)
  | None => Error("[Parser.res][parseStatement]: unexpected end of file")
  }
}

// Parse a block statement: { statements }
// Uses List for O(1) cons operations, then converts to array
and parseBlockStatement = (parser: parser): result<(parser, AST.blockStatement), string> => {
  switch expect(parser, Lexer.LeftBrace) {
  | Error(msg) => Error(msg)
  | Ok(parser) =>
    let rec parseStatements = (parser: parser, statements: list<AST.astNode>): result<
      (parser, list<AST.astNode>),
      string,
    > => {
      switch peek(parser) {
      | Some(Lexer.RightBrace) => Ok((advance(parser), statements))
      | Some(_) =>
        switch parseStatement(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, stmt)) => parseStatements(parser, list{stmt, ...statements}) // O(1) cons
        }
      | None => Error("[Parser.res][parseBlockStatement]: expected '}' but reached end of file")
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
  let rec parseStatements = (parser: parser, statements: list<AST.stmt>): result<
    (parser, list<AST.stmt>),
    string,
  > => {
    if isEOF(parser) {
      Ok((parser, statements))
    } else {
      switch peek(parser) {
      | Some(Lexer.EOF) => Ok((parser, statements))
      | Some(_) =>
        switch parseStatement(parser) {
        | Error(msg) => Error(msg)
        | Ok((parser, stmt)) => parseStatements(parser, list{stmt, ...statements}) // O(1) cons
        }
      | None => Ok((parser, statements))
      }
    }
  }
  let parser = create(tokens)
  switch parseStatements(parser, list{}) {
  | Error(msg) => Error("[Parser.res][parse]<-" ++ msg)
  | Ok((_, statements)) =>
    Ok(
      statements
      ->List.reverse
      ->List.toArray,
    )
  }
}
