// Optimizer - AST optimization pass for constant folding and algebraic identities
// Runs before code generation to simplify expressions

include AST

// Recursively optimize an AST node
let rec optimize = (node: astNode): astNode => {
  switch node {
  // ===== CONSTANT FOLDING =====
  // Addition
  | BinaryExpression(Add, Literal(x), Literal(y)) => Literal(x + y)
  // Subtraction
  | BinaryExpression(Sub, Literal(x), Literal(y)) => Literal(x - y)
  // Multiplication
  | BinaryExpression(Mul, Literal(x), Literal(y)) => Literal(x * y)
  // Division
  | BinaryExpression(Div, Literal(x), Literal(y)) =>
    y != 0 ? Literal(x / y) : node // Preserve division by zero for runtime error
  // Comparisons
  | BinaryExpression(Lt, Literal(x), Literal(y)) => Literal(x < y ? 1 : 0)
  | BinaryExpression(Gt, Literal(x), Literal(y)) => Literal(x > y ? 1 : 0)
  | BinaryExpression(Eq, Literal(x), Literal(y)) => Literal(x == y ? 1 : 0)

  // ===== ALGEBRAIC IDENTITIES =====
  // Addition with zero
  | BinaryExpression(Add, expr, Literal(0)) => optimize(expr)
  | BinaryExpression(Add, Literal(0), expr) => optimize(expr)

  // Subtraction with zero
  | BinaryExpression(Sub, expr, Literal(0)) => optimize(expr)

  // Multiplication by zero
  | BinaryExpression(Mul, Literal(0), _) => Literal(0)
  | BinaryExpression(Mul, _, Literal(0)) => Literal(0)

  // Multiplication by one
  | BinaryExpression(Mul, expr, Literal(1)) => optimize(expr)
  | BinaryExpression(Mul, Literal(1), expr) => optimize(expr)

  // Division by one
  | BinaryExpression(Div, expr, Literal(1)) => optimize(expr)

  // ===== RECURSIVE OPTIMIZATION =====
  // Optimize nested binary expressions
  | BinaryExpression(op, left, right) =>
    let optimizedLeft = optimize(left)
    let optimizedRight = optimize(right)
    // Try to optimize again after simplifying children
    if optimizedLeft != left || optimizedRight != right {
      optimize(BinaryExpression(op, optimizedLeft, optimizedRight))
    } else {
      BinaryExpression(op, optimizedLeft, optimizedRight)
    }

  // Optimize variable declarations
  | VariableDeclaration(name, expr) =>
    VariableDeclaration(name, optimize(expr))

  // Optimize if statements
  | IfStatement(condition, thenBlock, elseBlock) =>
    let optimizedCondition = optimize(condition)
    let optimizedThen = optimizeBlock(thenBlock)
    let optimizedElse = switch elseBlock {
    | Some(block) => Some(optimizeBlock(block))
    | None => None
    }

    // Constant condition evaluation
    switch optimizedCondition {
    | Literal(0) =>
      // Condition is always false - use else block or empty
      switch optimizedElse {
      | Some(block) => BlockStatement(block)
      | None => BlockStatement([]) // Empty block
      }
    | Literal(_) =>
      // Condition is always true - use then block
      BlockStatement(optimizedThen)
    | _ =>
      // Keep if statement with optimized parts
      IfStatement(optimizedCondition, optimizedThen, optimizedElse)
    }

  // Optimize block statements
  | BlockStatement(statements) =>
    BlockStatement(optimizeBlock(statements))

  // Optimize type declarations (pass through unchanged - compile-time only)
  | TypeDeclaration(_, _) => node

  // Optimize variant constructors
  | VariantConstructor(name, argumentOpt) =>
    switch argumentOpt {
    | None => node
    | Some(arg) => VariantConstructor(name, Some(optimize(arg)))
    }

  // Optimize match expressions
  | MatchExpression(scrutinee, cases) =>
    let optimizedScrutinee = optimize(scrutinee)
    let optimizedCases = Array.map(cases, matchCase => {
      {
        ...matchCase,
        body: optimizeBlock(matchCase.body),
      }
    })
    MatchExpression(optimizedScrutinee, optimizedCases)

  // Leaf nodes - no optimization needed
  | Literal(_) => node
  | Identifier(_) => node
  }
}

// Optimize a block of statements
and optimizeBlock = (statements: blockStatement): blockStatement => {
  Array.map(statements, stmt => optimize(stmt))
}

// Optimize entire program
let optimizeProgram = (program: program): program => {
  Array.map(program, stmt => optimize(stmt))
}
