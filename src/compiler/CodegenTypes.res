// Shared types for code generation modules
// Avoids type incompatibility issues between StmtGen, ExprGen, BranchGen, etc.

type codegenState = {
  allocator: RegisterAlloc.allocator,
  stackAllocator: StackAlloc.stackAllocator,
  instructions: array<string>,
  labelCounter: int,
  variantTypes: Belt.Map.String.t<array<AST.variantConstructor>>,
  variantTags: Belt.Map.String.t<int>,
}
