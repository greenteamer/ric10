// Abstract Syntax Tree definitions for ReScript → IC10 compiler
// Defines the structure of parsed ReScript code

// Binary operators
type binaryOp =
  | Add // +
  | Sub // -
  | Mul // *
  | Div // /
  | Gt // >
  | Lt // <
  | Eq // ==

// AST node types (mutually recursive)
type rec astNode =
  | VariableDeclaration(string, expr) // let x = expr
  | BinaryExpression(binaryOp, expr, expr) // expr op expr
  | Literal(int) // integer literal
  | Identifier(string) // variable name
  | IfStatement(expr, blockStatement, option<blockStatement>) // if (expr) { stmts } else { stmts }
  | BlockStatement(blockStatement) // { stmt1; stmt2; ... }

and expr = astNode

and stmt = astNode

and blockStatement = array<astNode>

// Program is a list of statements
type program = array<stmt>

// Helper functions for creating AST nodes
let createVariableDeclaration = (name: string, value: expr): astNode => {
  VariableDeclaration(name, value)
}

let createBinaryExpression = (op: binaryOp, left: expr, right: expr): astNode => {
  BinaryExpression(op, left, right)
}

let createLiteral = (value: int): astNode => {
  Literal(value)
}

let createIdentifier = (name: string): astNode => {
  Identifier(name)
}

let createIfStatement = (condition: expr, thenBlock: blockStatement, elseBlock: option<blockStatement>): astNode => {
  IfStatement(condition, thenBlock, elseBlock)
}

let createBlockStatement = (statements: array<astNode>): astNode => {
  BlockStatement(statements)
}

// Helper: Convert binary operator to string
let binaryOpToString = (op: binaryOp): string => {
  switch op {
  | Add => "+"
  | Sub => "-"
  | Mul => "*"
  | Div => "/"
  | Gt => ">"
  | Lt => "<"
  | Eq => "=="
  }
}
