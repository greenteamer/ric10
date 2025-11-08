// Shared types for code generation modules
// Avoids type incompatibility issues between StmtGen, ExprGen, BranchGen, etc.

type compilerOptions = {
  debugAST: bool,
  includeComments: bool,
  useIR: bool,
}

type defineValue =
  | HashExpr(string)
  | NumberValue(int)

type codegenState = {
  allocator: RegisterAlloc.allocator,
  stackAllocator: StackAlloc.stackAllocator,
  instructions: array<string>,
  labelCounter: int,
  variantTypes: Belt.Map.String.t<array<AST.variantConstructor>>, // typeName -> constructors
  variantTags: Belt.Map.String.t<int>, // constructorName -> tag
  variantRefTypes: Belt.Map.String.t<string>, // refName -> typeName (tracks which refs hold which variant types)
  defines: Belt.Map.String.t<defineValue>,
  defineOrder: array<(string, defineValue)>,
  options: compilerOptions,
}
