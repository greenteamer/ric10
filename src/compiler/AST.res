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

// Variant constructor definition (in type declarations)
type variantConstructor = {
  name: string,
  hasArgument: bool, // true if constructor takes a single argument
}

// AST node types (mutually recursive)
type rec astNode =
  | VariableDeclaration(string, expr) // let x = expr
  | BinaryExpression(binaryOp, expr, expr) // expr op expr
  | Literal(int) // integer literal
  | Identifier(string) // variable name
  | IfStatement(expr, blockStatement, option<blockStatement>) // if (expr) { stmts } else { stmts }
  | BlockStatement(blockStatement) // { stmt1; stmt2; ... }
  | TypeDeclaration(string, array<variantConstructor>) // type name = Constructor1 | Constructor2(arg)
  | VariantConstructor(string, option<expr>) // Constructor or Constructor(expr)
  | SwitchExpression(expr, array<matchCase>) // switch expr { | Pattern1 => body1 | Pattern2 => body2 }
  | RefCreation(expr) // ref(expr)
  | RefAccess(string) // identifier.contents
  | RefAssignment(string, expr) // identifier := expr

and expr = astNode

and stmt = astNode

and blockStatement = array<astNode>

// Match case for pattern matching (must be after blockStatement is defined)
and matchCase = {
  constructorName: string,
  argumentBinding: option<string>, // variable name for argument (if constructor has one)
  body: blockStatement, // code to execute for this case
}

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

let createTypeDeclaration = (name: string, constructors: array<variantConstructor>): astNode => {
  TypeDeclaration(name, constructors)
}

let createVariantConstructor = (name: string, argument: option<expr>): astNode => {
  VariantConstructor(name, argument)
}

let createSwitchExpression = (scrutinee: expr, cases: array<matchCase>): astNode => {
  SwitchExpression(scrutinee, cases)
}

let createRefCreation = (value: expr): astNode => {
  RefCreation(value)
}

let createRefAccess = (name: string): astNode => {
  RefAccess(name)
}

let createRefAssignment = (name: string, value: expr): astNode => {
  RefAssignment(name, value)
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
