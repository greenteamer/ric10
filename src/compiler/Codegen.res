// Code Generator for ReScript → IC10 compiler
// Converts AST nodes into IC10 assembly instructions

// Code generation state
type codegenState = {
  allocator: RegisterAlloc.allocator,
  instructions: array<string>, // Generated IC10 instructions
  labelCounter: int, // Counter for generating unique labels
}

// Create initial codegen state
let create = (): codegenState => {
  {
    allocator: RegisterAlloc.create(),
    instructions: Array.make(~length=0, ""),
    labelCounter: 0,
  }
}

// Add an instruction to the output
let addInstruction = (state: codegenState, instruction: string): codegenState => {
  let len = Array.length(state.instructions)
  let newInstructions = Array.make(~length=len + 1, "")
  for i in 0 to len - 1 {
    switch state.instructions[i] {
    | Some(v) => newInstructions[i] = v
    | None => ()
    }
  }
  newInstructions[len] = instruction
  {...state, instructions: newInstructions}
}

// Generate a unique label
let generateLabel = (state: codegenState): (codegenState, string) => {
  let label = "label" ++ Int.toString(state.labelCounter)
  let newState = {...state, labelCounter: state.labelCounter + 1}
  (newState, label)
}

// Основная функция - генерирует выражение и возвращает регистр с результатом
let rec generateExpression = (state: codegenState, expr: AST.expr): result<
  (codegenState, Register.t),
  string,
> => {
  switch expr {
  | AST.Literal(value) =>
    // Аллоцируем временный регистр для литерала
    switch RegisterAlloc.allocateTempRegister(state.allocator) {
    | Error(msg) => Error(msg)
    | Ok((allocator, reg)) =>
      let newState = {...state, allocator}
      let instr = "move " ++ Register.toString(reg) ++ " " ++ Int.toString(value)
      Ok((addInstruction(newState, instr), reg))
    }

  | AST.Identifier(name) =>
    // Просто возвращаем регистр переменной БЕЗ генерации move
    switch RegisterAlloc.getRegister(state.allocator, name) {
    | None => Error("Variable not found: " ++ name)
    | Some(reg) => Ok((state, reg))
    }

  | AST.BinaryExpression(op, left, right) =>
    // Генерируем левый операнд
    switch generateExpression(state, left) {
    | Error(msg) => Error(msg)
    | Ok((state1, leftReg)) =>
      // Генерируем правый операнд
      switch generateExpression(state1, right) {
      | Error(msg) => Error(msg)
      | Ok((state2, rightReg)) =>
        // Аллоцируем регистр для результата
        switch RegisterAlloc.allocateTempRegister(state2.allocator) {
        | Error(msg) => Error(msg)
        | Ok((allocator, resultReg)) =>
          let state3 = {...state2, allocator}
          let opStr = switch op {
          | AST.Add => "add"
          | AST.Sub => "sub"
          | AST.Mul => "mul"
          | AST.Div => "div"
          | AST.Gt => "sgt"
          | AST.Lt => "slt"
          | AST.Eq => "seq"
          }
          // Используем leftReg и rightReg напрямую (БЕЗ лишних move)
          let instr =
            opStr ++
            " " ++
            Register.toString(resultReg) ++
            " " ++
            Register.toString(leftReg) ++
            " " ++
            Register.toString(rightReg)

          let state4 = addInstruction(state3, instr)

          // Освобождаем leftReg и rightReg (если они временные!)
          let allocator2 = RegisterAlloc.freeTempIfTemp(
            RegisterAlloc.freeTempIfTemp(state4.allocator, leftReg),
            rightReg,
          )

          Ok({...state4, allocator: allocator2}, resultReg)
        }
      }
    }

  | AST.VariableDeclaration(_, _) => Error("VariableDeclaration found in expression context")
  | AST.IfStatement(_, _, _) => Error("IfStatement found in expression context")
  | AST.BlockStatement(_) => Error("BlockStatement found in expression context")
  }
}

// Вспомогательная функция - генерирует выражение СРАЗУ в указанный регистр
// Используется только когда мы заранее знаем куда писать (например, в переменную)
let rec generateExpressionInto = (
  state: codegenState,
  expr: AST.expr,
  targetReg: Register.t,
): result<codegenState, string> => {
  switch expr {
  | AST.Literal(value) =>
    // Пишем литерал сразу в целевой регистр
    let instr = "move " ++ Register.toString(targetReg) ++ " " ++ Int.toString(value)
    Ok(addInstruction(state, instr))

  | AST.Identifier(name) =>
    // Копируем из регистра переменной в целевой (если нужно)
    switch RegisterAlloc.getRegister(state.allocator, name) {
    | None => Error("Variable not found: " ++ name)
    | Some(sourceReg) =>
      if sourceReg == targetReg {
        Ok(state) // Уже в нужном месте
      } else {
        let instr = "move " ++ Register.toString(targetReg) ++ " " ++ Register.toString(sourceReg)
        Ok(addInstruction(state, instr))
      }
    }

  | AST.BinaryExpression(op, left, right) =>
    switch (left, right) {
    | (AST.Literal(leftVal), AST.Literal(rightVal)) =>
      // Constant folding: both operands are literals
      let resultVal = switch op {
      | AST.Add => leftVal + rightVal
      | AST.Sub => leftVal - rightVal
      | AST.Mul => leftVal * rightVal
      | AST.Div => leftVal / rightVal // Note: integer division
      | AST.Gt => leftVal > rightVal ? 1 : 0
      | AST.Lt => leftVal < rightVal ? 1 : 0
      | AST.Eq => leftVal == rightVal ? 1 : 0
      }
      let instr = "move " ++ Register.toString(targetReg) ++ " " ++ Int.toString(resultVal)
      Ok(addInstruction(state, instr))
    | _ =>
      // Default behavior: one or both operands are not literals
      switch generateExpression(state, left) {
      | Error(msg) => Error(msg)
      | Ok((state1, leftReg)) =>
        switch generateExpression(state1, right) {
        | Error(msg) => Error(msg)
        | Ok((state2, rightReg)) =>
          let opStr = switch op {
          | AST.Add => "add"
          | AST.Sub => "sub"
          | AST.Mul => "mul"
          | AST.Div => "div"
          | AST.Gt => "sgt"
          | AST.Lt => "slt"
          | AST.Eq => "seq"
          }
          let instr =
            opStr ++
            " " ++
            Register.toString(targetReg) ++
            " " ++
            Register.toString(leftReg) ++
            " " ++
            Register.toString(rightReg)
          
          let allocator = RegisterAlloc.freeTempIfTemp(
            RegisterAlloc.freeTempIfTemp(state2.allocator, leftReg),
            rightReg,
          )

          Ok(addInstruction({...state2, allocator: allocator}, instr))
        }
      }
    }

  | AST.VariableDeclaration(_, _) => Error("VariableDeclaration found in expression context")
  | AST.IfStatement(_, _, _) => Error("IfStatement found in expression context")
  | AST.BlockStatement(_) => Error("BlockStatement found in expression context")
  }
}

// Generate IC10 code for a statement
let rec generateStatement = (state: codegenState, stmt: AST.astNode): result<
  codegenState,
  string,
> => {
  switch stmt {
  | AST.VariableDeclaration(name, expr) =>
    // 1. Сначала аллоцируем регистр для переменной
    switch RegisterAlloc.allocate(state.allocator, name) {
    | Error(msg) => Error(msg)
    | Ok((allocator, varReg)) =>
      let state1 = {...state, allocator}
      // 2. Генерируем выражение СРАЗУ в целевой регистр
      switch generateExpressionInto(state1, expr, varReg) {
      | Error(msg) => Error(msg)
      | Ok(newState) => Ok(newState)
      }
    }
  | AST.BinaryExpression(op, left, right) =>
    // Standalone expression - just generate it
    switch generateExpression(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }
  | AST.IfStatement(condition, thenBlock, elseBlock) =>
    // Generate condition
    switch generateExpression(state, condition) {
    | Error(msg) => Error(msg)
    | Ok((state1, condReg)) =>
      // Generate labels
      switch generateLabel(state1) {
      | (state2, elseLabel) =>
        switch generateLabel(state2) {
        | (state3, endLabel) =>
          // Branch if condition is false (jump to else or end)
          let jumpLabel = switch elseBlock {
          | Some(_) => elseLabel
          | None => endLabel
          }
          let branchInstr = "beqz " ++ Register.toString(condReg) ++ " " ++ jumpLabel
          let state4 = addInstruction(state3, branchInstr)
          // Generate then block
          switch generateBlock(state4, thenBlock) {
          | Error(msg) => Error(msg)
          | Ok(state5) =>
            // Generate else block if present
            switch elseBlock {
            | Some(elseStatements) =>
              // Jump to end after then block
              let jumpEndInstr = "j " ++ endLabel
              let state6 = addInstruction(state5, jumpEndInstr)
              // Add else label
              let state7 = addInstruction(state6, elseLabel ++ ":")
              switch generateBlock(state7, elseStatements) {
              | Error(msg) => Error(msg)
              | Ok(state8) =>
                // Add end label
                Ok(addInstruction(state8, endLabel ++ ":"))
              }
            | None =>
              // Add end label after then block
              Ok(addInstruction(state5, endLabel ++ ":"))
            }
          }
        }
      }
    }
  | AST.BlockStatement(statements) => generateBlock(state, statements)
  | AST.Literal(_) =>
    // Standalone literal - generate it
    switch generateExpression(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }
  | AST.Identifier(_) =>
    // Standalone identifier - generate it
    switch generateExpression(state, stmt) {
    | Error(msg) => Error(msg)
    | Ok((newState, _reg)) => Ok(newState)
    }
  }
}

// Generate IC10 code for a block of statements
and generateBlock = (state: codegenState, statements: AST.blockStatement): result<
  codegenState,
  string,
> => {
  let rec loop = (state: codegenState, i: int): result<codegenState, string> => {
    if i >= Array.length(statements) {
      Ok(state)
    } else {
      switch statements[i] {
      | Some(stmt) =>
        switch generateStatement(state, stmt) {
        | Error(msg) => Error(msg)
        | Ok(newState) => loop(newState, i + 1)
        }
      | None => Ok(state)
      }
    }
  }
  loop(state, 0)
}

// Generate IC10 code for a program
let generate = (program: AST.program): result<string, string> => {
  let state = create()
  let rec loop = (state: codegenState, i: int): result<codegenState, string> => {
    if i >= Array.length(program) {
      Ok(state)
    } else {
      switch program[i] {
      | Some(stmt) =>
        switch generateStatement(state, stmt) {
        | Error(msg) => Error(msg)
        | Ok(newState) => loop(newState, i + 1)
        }
      | None => Ok(state)
      }
    }
  }
  switch loop(state, 0) {
  | Error(msg) => Error("Code generation error: " ++ msg)
  | Ok(finalState) =>
    // Join instructions with newlines
    let code = Array.join(finalState.instructions, "\n")
    Ok(code)
  }
}
