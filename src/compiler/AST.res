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
  argCount: int, // number of arguments (0, 1, 2, ...)
}

// AST node types (mutually recursive)
type rec astNode =
  | VariableDeclaration(string, expr) // let x = expr
  | BinaryExpression(binaryOp, expr, expr) // expr op expr
  | Literal(int) // integer literal
  | LiteralBool(bool) // boolean literal (for while true)
  | LiteralStr(string) // string literal (for IC10 property names)
  | Identifier(string) // variable name
  | FunctionCall(string, array<argument>) // functionName(arg1, arg2, ...)
  | IfStatement(expr, blockStatement, option<blockStatement>) // if (expr) { stmts } else { stmts }
  | WhileLoop(expr, blockStatement) // while expr { stmts }
  | BlockStatement(blockStatement) // { stmt1; stmt2; ... }
  | TypeDeclaration(string, array<variantConstructor>) // type name = Constructor1 | Constructor2(arg1, arg2, ...)
  | VariantConstructor(string, array<expr>) // Constructor(expr1, expr2, ...) or Constructor
  | SwitchExpression(expr, array<matchCase>) // switch expr { | Pattern1 => body1 | Pattern2 => body2 }
  | RefCreation(expr) // ref(expr)
  | RefAccess(string) // identifier.contents
  | RefAssignment(string, expr) // identifier := expr
  | RawInstruction(string) // %raw("instruction") - raw IC10 assembly

and expr = astNode

and stmt = astNode

and blockStatement = array<astNode>

// Function call arguments (can be expressions, string literals, or device identifiers)
and argument =
  | ArgExpr(expr) // Expression argument (evaluated)
  | ArgString(string) // String literal argument (for property names, etc.)
  | ArgDevice(string) // Device identifier (d0-d5, db) - for IC10 device references
  | ArgMode(string) // Mode argument (Maximum, Minimum, Average, Sum) - for bulk operations

// Match case for pattern matching (must be after blockStatement is defined)
and matchCase = {
  constructorName: string,
  argumentBindings: array<string>, // variable names for arguments (empty array if no args)
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

let createIfStatement = (
  condition: expr,
  thenBlock: blockStatement,
  elseBlock: option<blockStatement>,
): astNode => {
  IfStatement(condition, thenBlock, elseBlock)
}

let createWhileLoop = (condition: expr, body: blockStatement): astNode => {
  WhileLoop(condition, body)
}

let createBlockStatement = (statements: array<astNode>): astNode => {
  BlockStatement(statements)
}

let createTypeDeclaration = (name: string, constructors: array<variantConstructor>): astNode => {
  TypeDeclaration(name, constructors)
}

let createVariantConstructor = (name: string, arguments: array<expr>): astNode => {
  VariantConstructor(name, arguments)
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

let createRawInstruction = (instruction: string): astNode => {
  RawInstruction(instruction)
}

let createStringLiteral = (value: string): astNode => {
  LiteralStr(value)
}

let createFunctionCall = (name: string, args: array<argument>): astNode => {
  FunctionCall(name, args)
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
