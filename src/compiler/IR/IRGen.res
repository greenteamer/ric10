let convertExpr = expr => {
  switch expr {
  | AST.Literal(value) => IR.DefNum(value)
  }
}

let convertNode = stmt => {
  switch stmt {
  | AST.VariableDeclaration(name, value) => IR.Def(name, convertExpr(value))
  }
}

let generate = (ast: AST.program) => {
  let rec recursiveGenerate = (nodes: list<AST.stmt>): IR.t => {
    switch nodes {
    | list{node} => convertNode(node)
    | list{node, ...rest} => list{convertNode(node), ...recursiveGenerate(rest)}
    }
  }

  ast->List.fromArray->recursiveGenerate
}
