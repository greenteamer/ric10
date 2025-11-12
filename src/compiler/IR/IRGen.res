// IR Generation - Convert AST to IR
// Phase 1: Simple expressions and variables only

// Variable info: vreg and whether it's a ref
type varInfo = {
  vreg: int,
  isRef: bool,
}

// Variant type metadata
type variantTypeInfo = {
  constructors: array<AST.variantConstructor>,
  baseAddr: int, // Stack base address for this type
  maxArgs: int, // Maximum arguments across all constructors
  allocated: bool, // Whether a ref has been created for this type
}

// Stack allocator state
type stackAllocator = {nextFreeSlot: int}

// State for IR generation
type state = {
  nextVReg: int, // Counter for virtual register allocation
  instructions: list<IR.instr>, // Accumulated IR instructions
  nextLabel: int, // Counter for label generation
  varMap: Belt.Map.String.t<varInfo>, // Variable name → variable info mapping
  // Variant type support
  variantTypes: Belt.Map.String.t<variantTypeInfo>, // typeName → type metadata
  variantTags: Belt.Map.String.t<int>, // constructorName → tag
  refToTypeName: Belt.Map.String.t<string>, // refName → typeName
  stackAllocator: stackAllocator, // Stack memory allocator
  // Device tracking
  deviceMap: Belt.Map.String.t<string>, // variableName → device ref (e.g., "furnace" → "d0", "housing" → "db")
}

// Create initial state
let createState = (): state => {
  nextVReg: 0,
  instructions: list{},
  nextLabel: 0,
  varMap: Belt.Map.String.empty,
  variantTypes: Belt.Map.String.empty,
  variantTags: Belt.Map.String.empty,
  refToTypeName: Belt.Map.String.empty,
  stackAllocator: {nextFreeSlot: 0},
  deviceMap: Belt.Map.String.empty,
}

// Allocate a new virtual register
let allocVReg = (state: state): (state, IR.vreg) => {
  let vreg = state.nextVReg
  let newState = {...state, nextVReg: state.nextVReg + 1}
  (newState, vreg)
}

// Emit an instruction
let emit = (state: state, instr: IR.instr): state => {
  {...state, instructions: list{instr, ...state.instructions}}
}

// Allocate stack segment
let allocateStackSegment = (allocator: stackAllocator, slotCount: int): (stackAllocator, int) => {
  let baseAddr = allocator.nextFreeSlot
  let newAllocator = {nextFreeSlot: allocator.nextFreeSlot + slotCount}
  (newAllocator, baseAddr)
}

// Get variant type name from constructor name
let getTypeNameFromConstructor = (state: state, constructorName: string): option<string> => {
  Belt.Map.String.findFirstBy(state.variantTypes, (_typeName, typeInfo) => {
    Array.some(typeInfo.constructors, constructor => constructor.name == constructorName)
  })->Option.map(((typeName, _)) => typeName)
}

// Calculate maximum arguments across all constructors
let getMaxArgsForVariantType = (constructors: array<AST.variantConstructor>): int => {
  Array.reduce(constructors, 0, (maxArgs, constructor) => {
    if constructor.argCount > maxArgs {
      constructor.argCount
    } else {
      maxArgs
    }
  })
}

// Convert AST binary operator to IR binary operator
let convertBinOp = (op: AST.binaryOp): result<IR.binOp, string> => {
  switch op {
  | Add => Ok(IR.AddOp)
  | Sub => Ok(IR.SubOp)
  | Mul => Ok(IR.MulOp)
  | Div => Ok(IR.DivOp)
  | Lt | Gt | Eq =>
    Error("[IRGen.res][convertArithOp]: comparison operators should use convertCompareOp")
  }
}

// Convert AST comparison operator to IR comparison operator (normal)
let normalCompareOp = (op: AST.binaryOp): result<IR.compareOp, string> => {
  switch op {
  | Lt => Ok(IR.LtOp)
  | Gt => Ok(IR.GtOp)
  | Eq => Ok(IR.EqOp)
  | _ => Error("[IRGen.res][normalCompareOp]: not a comparison operator")
  }
}

// Invert comparison operator for if-only statements
// Used when we want to skip the then-block if condition is FALSE
let invertCompareOp = (op: AST.binaryOp): result<IR.compareOp, string> => {
  switch op {
  | Lt => Ok(IR.GeOp) // NOT(a < b) is (a >= b)
  | Gt => Ok(IR.LeOp) // NOT(a > b) is (a <= b)
  | Eq => Ok(IR.NeOp) // NOT(a == b) is (a != b)
  | _ => Error("[IRGen.res][invertCompareOp]: not a comparison operator")
  }
}

// Generate IR for an expression
// Returns (newState, vreg) where vreg contains the result
let rec generateExpr = (state: state, expr: AST.expr): result<(state, IR.vreg), string> => {
  switch expr {
  // Literal: allocate vreg, emit Move with immediate value
  | Literal(n) => {
      let (state, vreg) = allocVReg(state)
      let state = emit(state, IR.Move(vreg, IR.Num(n)))
      Ok(state, vreg)
    }

  // LiteralBool: only used for while true, error in expression context
  | LiteralBool(_) =>
    Error("[IRGen.res][generateExpr]: boolean literals can only be used in 'while true' loops")

  // Identifier: lookup variable, allocate new vreg, emit Move from source vreg
  // OR check if it's a zero-arg variant constructor
  | Identifier(name) =>
    switch state.varMap->Belt.Map.String.get(name) {
    | Some(varInfo) => {
        let (state, vreg) = allocVReg(state)
        let state = emit(state, IR.Move(vreg, IR.VReg(varInfo.vreg)))
        Ok(state, vreg)
      }
    | None =>
      // Check if this identifier is a zero-arg variant constructor
      switch getTypeNameFromConstructor(state, name) {
      | Some(_typeName) =>
        // This is a zero-arg variant constructor - treat as VariantConstructor(name, [])
        // Note: In expression context, this represents the constructor value itself
        // In ref context (handled in VariableDeclaration/RefAssignment), it will be properly initialized
        Error(
          `Zero-arg variant constructor '${name}' cannot be used directly in expressions. ` ++
          `Use it in ref() or assignment context: ref(${name}) or varName := ${name}`,
        )
      | None => Error(`Variable '${name}' not found`)
      }
    }

  // BinaryExpression: check if arithmetic or comparison
  | BinaryExpression(op, left, right) =>
    // Check if it's a comparison operator
    switch op {
    | Lt | Gt | Eq =>
      // Comparison: emit Compare instruction
      normalCompareOp(op)->Result.flatMap(cmpOp => {
        generateExpr(state, left)->Result.flatMap(((state, leftVreg)) => {
          generateExpr(state, right)->Result.flatMap(
            ((state, rightVreg)) => {
              let (state, resultVreg) = allocVReg(state)
              let state = emit(
                state,
                IR.Compare(resultVreg, cmpOp, IR.VReg(leftVreg), IR.VReg(rightVreg)),
              )
              Ok(state, resultVreg)
            },
          )
        })
      })
    | Add | Sub | Mul | Div =>
      // Arithmetic: emit Binary instruction
      convertBinOp(op)->Result.flatMap(irOp => {
        generateExpr(state, left)->Result.flatMap(((state, leftVreg)) => {
          generateExpr(state, right)->Result.flatMap(
            ((state, rightVreg)) => {
              let (state, resultVreg) = allocVReg(state)
              let state = emit(
                state,
                IR.Binary(resultVreg, irOp, IR.VReg(leftVreg), IR.VReg(rightVreg)),
              )
              Ok(state, resultVreg)
            },
          )
        })
      })
    }

  // RefCreation: ref(expr) - same as regular variable, just generates the value
  | RefCreation(valueExpr) => generateExpr(state, valueExpr)

  // RefAccess: identifier.contents - lookup ref variable and return its vreg
  | RefAccess(name) =>
    switch state.varMap->Belt.Map.String.get(name) {
    | Some(varInfo) =>
      if !varInfo.isRef {
        Error(`Variable '${name}' is not a ref, cannot use .contents`)
      } else {
        // For simple refs, just return the vreg (no instruction needed)
        // Allocate new vreg and move the ref's value
        let (state, vreg) = allocVReg(state)
        let state = emit(state, IR.Move(vreg, IR.VReg(varInfo.vreg)))
        Ok(state, vreg)
      }
    | None => Error(`Variable '${name}' not found`)
    }

  // FunctionCall: IC10 functions like l(), s(), etc.
  | FunctionCall(funcName, args) =>
    switch funcName {
    | "device" =>
      // device() should only be used in variable declarations, not in expressions
      Error(
        "[IRGen.res][generateExpr]: device() can only be used in variable declarations: let furnace = device(0)",
      )

    | "l" =>
      // l(device, "Property") - Load instruction
      if Array.length(args) != 2 {
        Error("[IRGen.res][generateExpr]: l() expects 2 arguments: device and property name")
      } else {
        switch (args[0], args[1]) {
        | (Some(AST.ArgExpr(AST.Literal(devicePin))), Some(AST.ArgString(property))) =>
          // Allocate vreg for result
          let (state, resultVReg) = allocVReg(state)

          // Emit DeviceLoad instruction with property as string
          // Convert integer device pin to string reference (0 → "d0", etc.)
          let deviceRef = `d${Int.toString(devicePin)}`
          let state = emit(state, IR.DeviceLoad(resultVReg, IR.DevicePin(deviceRef), property, None))

          Ok((state, resultVReg))

        | (Some(AST.ArgExpr(AST.Identifier(deviceVar))), Some(AST.ArgString(property))) =>
          // Look up device variable in deviceMap
          switch state.deviceMap->Belt.Map.String.get(deviceVar) {
          | Some(deviceRef) =>
            // Allocate vreg for result
            let (state, resultVReg) = allocVReg(state)

            // Emit DeviceLoad instruction - deviceRef is already a string like "d0" or "db"
            let state = emit(state, IR.DeviceLoad(resultVReg, IR.DevicePin(deviceRef), property, None))

            Ok((state, resultVReg))
          | None =>
            Error(`[IRGen.res][generateExpr]: Variable '${deviceVar}' is not a device`)
          }

        | _ => Error("[IRGen.res][generateExpr]: l() expects (device: int or identifier, property: string)")
        }
      }

    | "lb" =>
      // lb(typeHash, "Property", "Mode") - Batch load by type
      if Array.length(args) != 3 {
        Error("[IRGen.res][generateExpr]: lb() expects 3 arguments: type hash, property, mode")
      } else {
        switch (args[0], args[1], args[2]) {
        | (Some(AST.ArgExpr(AST.Identifier(typeHashVar))), Some(AST.ArgString(property)), Some(AST.ArgString(mode))) =>
          // Allocate vreg for result
          let (state, resultVReg) = allocVReg(state)

          // Emit DeviceLoad with DeviceType
          let state = emit(state, IR.DeviceLoad(resultVReg, IR.DeviceType(typeHashVar), property, Some(mode)))

          Ok((state, resultVReg))
        | _ => Error("[IRGen.res][generateExpr]: lb() expects (typeHash: identifier, property: string, mode: string)")
        }
      }

    | "lbn" =>
      // lbn(typeHash, nameHash, "Property", "Mode") - Batch load by type and name
      if Array.length(args) != 4 {
        Error("[IRGen.res][generateExpr]: lbn() expects 4 arguments: type hash, name hash, property, mode")
      } else {
        switch (args[0], args[1], args[2], args[3]) {
        | (
            Some(AST.ArgExpr(AST.Identifier(typeHashVar))),
            Some(AST.ArgExpr(AST.Identifier(nameHashVar))),
            Some(AST.ArgString(property)),
            Some(AST.ArgString(mode))
          ) =>
          // Allocate vreg for result
          let (state, resultVReg) = allocVReg(state)

          // Emit DeviceLoad with DeviceNamed
          let state = emit(state, IR.DeviceLoad(resultVReg, IR.DeviceNamed(typeHashVar, nameHashVar), property, Some(mode)))

          Ok((state, resultVReg))
        | _ => Error("[IRGen.res][generateExpr]: lbn() expects (typeHash: identifier, nameHash: identifier, property: string, mode: string)")
        }
      }

    | _ => Error(`Function '${funcName}' not yet implemented in IR mode`)
    }

  // SwitchExpression: switch scrutinee.contents { | Pattern => body }
  | SwitchExpression(scrutinee, cases) =>
    // Check if this is a variant ref switch
    switch scrutinee {
    | RefAccess(refName) =>
      // Check if this ref is a variant ref
      switch Belt.Map.String.get(state.refToTypeName, refName) {
      | Some(typeName) =>
        // This is a variant ref - use stack-based approach
        switch Belt.Map.String.get(state.variantTypes, typeName) {
        | None => Error(`Variant type not found: ${typeName}`)
        | Some(typeInfo) =>
          // Allocate vreg for tag
          let (state, tagVReg) = allocVReg(state)

          // Read tag from stack using StackGet
          let state = emit(state, IR.StackGet(tagVReg, typeInfo.baseAddr))

          // Generate labels for each case and end label
          let matchEndLabel = `match_end_${Int.toString(state.nextLabel)}`
          let state = {...state, nextLabel: state.nextLabel + 1}

          // Generate branch instructions for each case
          let (state, caseLabels) = Array.reduceWithIndex(cases, (state, []), (
            (state, labels),
            matchCase,
            _idx,
          ) => {
            // Look up constructor tag
            switch Belt.Map.String.get(state.variantTags, matchCase.constructorName) {
            | None => (state, labels) // Skip unknown constructors
            | Some(tag) =>
              let caseLabel = `match_case_${Int.toString(state.nextLabel)}`
              let state = {...state, nextLabel: state.nextLabel + 1}

              // Generate: Compare tagVReg == tag, then Bnez to caseLabel
              let (state, cmpVReg) = allocVReg(state)
              let state = emit(state, IR.Compare(cmpVReg, IR.EqOp, IR.VReg(tagVReg), IR.Num(tag)))
              let state = emit(state, IR.Bnez(IR.VReg(cmpVReg), caseLabel))

              (state, Array.concat(labels, [(caseLabel, matchCase, tag)]))
            }
          })

          // Jump to end if no case matched (fallthrough)
          let state = emit(state, IR.Goto(matchEndLabel))

          // Generate code for each case body
          let stateResult = Array.reduce(caseLabels, Ok(state), (
            stateResult,
            (label, matchCase, tag),
          ) => {
            stateResult->Result.flatMap(state => {
              // Add case label
              let state = emit(state, IR.Label(label))

              // Extract argument bindings from stack
              let stateResult = Array.reduceWithIndex(
                matchCase.argumentBindings,
                Ok(state),
                (stateResult, bindingName, index) => {
                  stateResult->Result.flatMap(
                    state => {
                      // Allocate vreg for binding
                      let (state, bindingVReg) = allocVReg(state)

                      // Calculate address: baseAddr + tag * maxArgs + 1 + index
                      let address = typeInfo.baseAddr + tag * typeInfo.maxArgs + 1 + index

                      // Emit StackGet to read value
                      let state = emit(state, IR.StackGet(bindingVReg, address))

                      // Add to varMap
                      let varMap = Belt.Map.String.set(
                        state.varMap,
                        bindingName,
                        {vreg: bindingVReg, isRef: false},
                      )

                      Ok({...state, varMap})
                    },
                  )
                },
              )

              stateResult->Result.flatMap(
                state => {
                  // Generate case body
                  generateBlock(state, matchCase.body)->Result.map(
                    state => {
                      // Jump to match end
                      emit(state, IR.Goto(matchEndLabel))
                    },
                  )
                },
              )
            })
          })

          stateResult->Result.map(state => {
            // Add match end label
            let state = emit(state, IR.Label(matchEndLabel))

            // Allocate result vreg (even if not used)
            let (state, resultVReg) = allocVReg(state)

            (state, resultVReg)
          })
        }

      | None =>
        // Not a variant ref
        Error("[IRGen.res][generateExpr]: switch expression only supports variant refs in IR mode")
      }

    | _ =>
      Error(
        "[IRGen.res][generateExpr]: switch expression scrutinee must be a ref access (e.g., state.contents)",
      )
    }

  // Phase 1: Only support simple expressions
  | _ => {
      Console.log2("Unsupported expression type:", expr)
      Error("[IRGen.res][generateExpr]: expression type not supported in Phase 1")
    }
  }
}

// Generate IR for a block of statements
and generateBlock = (state: state, block: AST.blockStatement): result<state, string> => {
  let rec processStmts = (state: state, stmts: array<AST.stmt>, index: int): result<
    state,
    string,
  > => {
    if index >= Array.length(stmts) {
      Ok(state)
    } else {
      switch stmts[index] {
      | Some(stmt) =>
        generateStmt(state, stmt)->Result.flatMap(state => processStmts(state, stmts, index + 1))
      | None => Error("[IRGen.res][generateBlock]: internal error: array index out of bounds")
      }
    }
  }
  processStmts(state, block, 0)
}

// Generate if-only statement (no else block)
// Uses INVERTED comparison + Bnez to skip then-block when condition is FALSE
and generateIfOnly = (state: state, condition: AST.expr, thenBlock: AST.blockStatement): result<
  state,
  string,
> => {
  // Extract comparison from condition
  switch condition {
  | BinaryExpression(op, left, right) =>
    switch op {
    | Lt | Gt | Eq =>
      // Generate left and right operands
      generateExpr(state, left)->Result.flatMap(((state, leftVreg)) => {
        generateExpr(state, right)->Result.flatMap(((state, rightVreg)) => {
          // Use INVERTED comparison
          invertCompareOp(op)->Result.flatMap(
            invertedOp => {
              let (state, resultVreg) = allocVReg(state)
              let state = emit(
                state,
                IR.Compare(resultVreg, invertedOp, IR.VReg(leftVreg), IR.VReg(rightVreg)),
              )

              // Allocate end label
              let endLabel = `label${Belt.Int.toString(state.nextLabel)}`
              let state = {...state, nextLabel: state.nextLabel + 1}

              // Emit Bnez - if inverted condition is true (original is false), skip then block
              let state = emit(state, IR.Bnez(IR.VReg(resultVreg), endLabel))

              // Generate then block
              generateBlock(state, thenBlock)->Result.flatMap(
                state => {
                  // Emit end label
                  let state = emit(state, IR.Label(endLabel))
                  Ok(state)
                },
              )
            },
          )
        })
      })
    | _ => Error("[IRGen.res][generateIfOnly]: if condition must be a comparison expression")
    }
  | _ => Error("[IRGen.res][generateIfOnly]: if condition must be a comparison expression")
  }
}

// Generate if-else statement
// Uses NORMAL comparison + Bnez to jump to then-block when condition is TRUE
and generateIfElse = (
  state: state,
  condition: AST.expr,
  thenBlock: AST.blockStatement,
  elseBlock: AST.blockStatement,
): result<state, string> => {
  // Extract comparison from condition
  switch condition {
  | BinaryExpression(op, left, right) =>
    switch op {
    | Lt | Gt | Eq =>
      // Generate left and right operands
      generateExpr(state, left)->Result.flatMap(((state, leftVreg)) => {
        generateExpr(state, right)->Result.flatMap(((state, rightVreg)) => {
          // Use NORMAL comparison
          normalCompareOp(op)->Result.flatMap(
            normalOp => {
              let (state, resultVreg) = allocVReg(state)
              let state = emit(
                state,
                IR.Compare(resultVreg, normalOp, IR.VReg(leftVreg), IR.VReg(rightVreg)),
              )

              // Allocate labels
              let thenLabel = `label${Belt.Int.toString(state.nextLabel)}`
              let endLabel = `label${Belt.Int.toString(state.nextLabel + 1)}`
              let state = {...state, nextLabel: state.nextLabel + 2}

              // Emit Bnez - if condition is true, jump to then
              let state = emit(state, IR.Bnez(IR.VReg(resultVreg), thenLabel))

              // Generate else block (falls through)
              generateBlock(state, elseBlock)->Result.flatMap(
                state => {
                  // Jump over then block
                  let state = emit(state, IR.Goto(endLabel))

                  // Then block label
                  let state = emit(state, IR.Label(thenLabel))

                  // Generate then block
                  generateBlock(state, thenBlock)->Result.flatMap(
                    state => {
                      // End label
                      let state = emit(state, IR.Label(endLabel))
                      Ok(state)
                    },
                  )
                },
              )
            },
          )
        })
      })
    | _ => Error("[IRGen.res][generateIfElse]: if condition must be a comparison expression")
    }
  | _ => Error("[IRGen.res][generateIfElse]: if condition must be a comparison expression")
  }
}

// Generate while loop
// Uses INVERTED comparison + Bnez to exit loop when condition is FALSE (same as if-only)
and generateWhileLoop = (state: state, condition: AST.expr, body: AST.blockStatement): result<
  state,
  string,
> => {
  // Allocate loop start and exit labels
  let loopLabel = `label${Belt.Int.toString(state.nextLabel)}`
  let exitLabel = `label${Belt.Int.toString(state.nextLabel + 1)}`
  let state = {...state, nextLabel: state.nextLabel + 2}

  // Emit loop start label
  let state = emit(state, IR.Label(loopLabel))

  // Handle different condition types
  switch condition {
  // Comparison expression: use inverted comparison (like if-only)
  | BinaryExpression(op, left, right) =>
    switch op {
    | Lt | Gt | Eq =>
      // Generate left and right operands
      generateExpr(state, left)->Result.flatMap(((state, leftVreg)) => {
        generateExpr(state, right)->Result.flatMap(((state, rightVreg)) => {
          // Use INVERTED comparison (exit when condition is false)
          invertCompareOp(op)->Result.flatMap(
            invertedOp => {
              let (state, resultVreg) = allocVReg(state)
              let state = emit(
                state,
                IR.Compare(resultVreg, invertedOp, IR.VReg(leftVreg), IR.VReg(rightVreg)),
              )

              // Emit Bnez - if inverted condition is true (original is false), exit loop
              let state = emit(state, IR.Bnez(IR.VReg(resultVreg), exitLabel))

              // Generate loop body
              generateBlock(state, body)->Result.flatMap(
                state => {
                  // Jump back to loop start
                  let state = emit(state, IR.Goto(loopLabel))

                  // Emit exit label
                  let state = emit(state, IR.Label(exitLabel))
                  Ok(state)
                },
              )
            },
          )
        })
      })
    | _ => Error("[IRGen.res][generateWhileLoop]: while condition must be a comparison expression")
    }

  // LiteralBool(true): infinite loop with no condition check
  | LiteralBool(true) =>
    // Generate loop body
    generateBlock(state, body)->Result.flatMap(state => {
      // Jump back to loop start (infinite loop)
      let state = emit(state, IR.Goto(loopLabel))
      Ok(state)
    })

  // LiteralBool(false): loop that never executes (skip to exit)
  | LiteralBool(false) =>
    // Skip loop body entirely, just emit exit label
    let state = emit(state, IR.Label(exitLabel))
    Ok(state)

  // Integer literals: not supported - use 'while true' instead
  | Literal(_) =>
    Error(
      "Integer literals are not supported in while conditions - use 'while true' for infinite loops",
    )

  // Other expression types: not supported
  | _ =>
    Error(
      "[IRGen.res][generateWhileLoop]: while condition must be a comparison expression or 'while true'",
    )
  }
}

// Generate IR for a statement
and generateStmt = (state: state, stmt: AST.stmt): result<state, string> => {
  switch stmt {
  // TypeDeclaration: allocate stack space and store metadata
  | TypeDeclaration(typeName, constructors) => {
      // 1. Calculate maximum arguments across all constructors
      let maxArgs = getMaxArgsForVariantType(constructors)

      // 2. Calculate total slots needed: 1 (tag) + N (constructors) * M (max args)
      let numConstructors = Array.length(constructors)
      let slotCount = 1 + numConstructors * maxArgs

      // 3. Allocate stack segment
      let (stackAllocator, baseAddr) = allocateStackSegment(state.stackAllocator, slotCount)

      // 4. Build constructor tag mappings
      let variantTags = Array.reduceWithIndex(constructors, state.variantTags, (
        tags,
        constructor,
        index,
      ) => Belt.Map.String.set(tags, constructor.name, index))

      // 5. Store type metadata
      let typeInfo = {
        constructors,
        baseAddr,
        maxArgs,
        allocated: false, // No ref created yet
      }
      let variantTypes = Belt.Map.String.set(state.variantTypes, typeName, typeInfo)

      // 6. Emit StackAlloc instruction
      let state = emit(state, IR.StackAlloc(slotCount))

      Ok({
        ...state,
        stackAllocator,
        variantTypes,
        variantTags,
      })
    }

  // VariableDeclaration: generate expression, store vreg in varMap
  | VariableDeclaration(name, init) =>
    // Check if this is a variant constructor ref
    switch init {
    | RefCreation(VariantConstructor(constructorName, args)) =>
      // This is a variant ref - use stack-based approach
      // 1. Determine type name from constructor
      switch getTypeNameFromConstructor(state, constructorName) {
      | None => Error(`Unknown variant constructor: ${constructorName}`)
      | Some(typeName) =>
        // 2. Get type metadata
        switch Belt.Map.String.get(state.variantTypes, typeName) {
        | None => Error(`Variant type not found: ${typeName}`)
        | Some(typeInfo) =>
          // 3. Check if type already has a ref allocated
          if typeInfo.allocated {
            Error(
              `Type '${typeName}' already has a ref allocated. ` ++
              `IC10 compiler supports one ref per variant type. ` ++
              `Workaround: Define a second type (e.g., 'type ${typeName}2 = ...')`,
            )
          } else {
            // 4. Get constructor tag
            switch Belt.Map.String.get(state.variantTags, constructorName) {
            | None => Error(`Constructor tag not found: ${constructorName}`)
            | Some(tag) =>
              // 5. Mark type as allocated
              let updatedTypeInfo = {...typeInfo, allocated: true}
              let variantTypes = Belt.Map.String.set(state.variantTypes, typeName, updatedTypeInfo)

              // 6. Store ref → type mapping
              let refToTypeName = Belt.Map.String.set(state.refToTypeName, name, typeName)

              // 7. Allocate vreg for ref variable
              let (state, refVReg) = allocVReg(state)
              let varMap = Belt.Map.String.set(state.varMap, name, {vreg: refVReg, isRef: true})

              // 8. Initialize ref to point to base address
              let state = emit(state, IR.Move(refVReg, IR.Num(typeInfo.baseAddr)))

              // 9. Initialize variant data on stack using StackPoke
              // 9a. Poke tag
              let state = emit(state, IR.StackPoke(typeInfo.baseAddr, IR.Num(tag)))

              // 9b. Poke all arguments
              let stateResult = Array.reduceWithIndex(args, Ok(state), (
                stateResult,
                arg,
                index,
              ) => {
                stateResult->Result.flatMap(state => {
                  // Generate argument expression
                  generateExpr(state, arg)->Result.map(
                    ((state, argVReg)) => {
                      // Calculate address: baseAddr + tag * maxArgs + 1 + index
                      let address = typeInfo.baseAddr + tag * typeInfo.maxArgs + 1 + index

                      // Emit StackPoke
                      emit(state, IR.StackPoke(address, IR.VReg(argVReg)))
                    },
                  )
                })
              })

              stateResult->Result.map(state => {
                {...state, variantTypes, refToTypeName, varMap}
              })
            }
          }
        }
      }

    | RefCreation(Identifier(constructorName)) =>
      // Check if this identifier is a zero-arg variant constructor
      switch getTypeNameFromConstructor(state, constructorName) {
      | Some(typeName) =>
        // This is a zero-arg variant constructor - treat as VariantConstructor(name, [])
        // Reuse the same logic as VariantConstructor case
        switch Belt.Map.String.get(state.variantTypes, typeName) {
        | None => Error(`Variant type not found: ${typeName}`)
        | Some(typeInfo) =>
          // Check if type already has a ref allocated
          if typeInfo.allocated {
            Error(
              `Type '${typeName}' already has a ref allocated. ` ++
              `IC10 compiler supports one ref per variant type. ` ++
              `Workaround: Define a second type (e.g., 'type ${typeName}2 = ...')`,
            )
          } else {
            // Get constructor tag
            switch Belt.Map.String.get(state.variantTags, constructorName) {
            | None => Error(`Constructor tag not found: ${constructorName}`)
            | Some(tag) =>
              // Mark type as allocated
              let updatedTypeInfo = {...typeInfo, allocated: true}
              let variantTypes = Belt.Map.String.set(state.variantTypes, typeName, updatedTypeInfo)

              // Store ref → type mapping
              let refToTypeName = Belt.Map.String.set(state.refToTypeName, name, typeName)

              // Allocate vreg for ref variable
              let (state, refVReg) = allocVReg(state)
              let varMap = Belt.Map.String.set(state.varMap, name, {vreg: refVReg, isRef: true})

              // Initialize ref to point to base address
              let state = emit(state, IR.Move(refVReg, IR.Num(typeInfo.baseAddr)))

              // Initialize variant data on stack using StackPoke
              // Poke tag (no arguments for zero-arg constructor)
              let state = emit(state, IR.StackPoke(typeInfo.baseAddr, IR.Num(tag)))

              Ok({...state, variantTypes, refToTypeName, varMap})
            }
          }
        }
      | None =>
        // Not a variant constructor - use simple ref approach
        generateExpr(state, Identifier(constructorName))->Result.map(((state, vreg)) => {
          {...state, varMap: state.varMap->Belt.Map.String.set(name, {vreg, isRef: true})}
        })
      }

    | RefCreation(valueExpr) =>
      // Non-variant ref - use simple approach
      generateExpr(state, valueExpr)->Result.map(((state, vreg)) => {
        {...state, varMap: state.varMap->Belt.Map.String.set(name, {vreg, isRef: true})}
      })

    | _ =>
      // Check if this is a device() or hash() call
      switch init {
      | FunctionCall("device", args) =>
        // Track this as a device variable (no code generation needed)
        switch args[0] {
        | Some(AST.ArgString(deviceRef)) =>
          // Just add to deviceMap, don't generate any IR or allocate vreg
          // deviceRef can be "d0", "d1", "db", etc.
          let deviceMap = Belt.Map.String.set(state.deviceMap, name, deviceRef)
          Ok({...state, deviceMap})
        | _ => Error("[IRGen.res][generateStmt]: device() expects a string device reference: device(\"d0\") or device(\"db\")")
        }
      | FunctionCall("hash", args) =>
        // hash("StructureTank") -> emit DefHash and track name as hash constant
        switch args[0] {
        | Some(AST.ArgString(hashInput)) =>
          // Emit DefHash instruction
          let state = emit(state, IR.DefHash(name, hashInput))
          // Hash constants don't need vregs - they're just references in device operations
          Ok(state)
        | _ => Error("[IRGen.res][generateStmt]: hash() expects a string literal: hash(\"StructureTank\")")
        }
      | _ =>
        // Not a ref, not a device, not a hash - normal variable
        generateExpr(state, init)->Result.map(((state, vreg)) => {
          {...state, varMap: state.varMap->Belt.Map.String.set(name, {vreg, isRef: false})}
        })
      }
    }

  // IfStatement: handle if-only and if-else
  | IfStatement(condition, thenBlock, elseBlock) =>
    switch elseBlock {
    | None => generateIfOnly(state, condition, thenBlock)
    | Some(block) => generateIfElse(state, condition, thenBlock, block)
    }

  // RefAssignment: identifier := expr
  | RefAssignment(name, valueExpr) =>
    switch state.varMap->Belt.Map.String.get(name) {
    | Some(varInfo) =>
      if !varInfo.isRef {
        Error(`Variable '${name}' is not a ref, cannot use := assignment`)
      } else {
        // Check if this is a variant ref assignment
        switch Belt.Map.String.get(state.refToTypeName, name) {
        | Some(typeName) =>
          // This is a variant ref - use stack poke approach
          switch valueExpr {
          | VariantConstructor(constructorName, args) =>
            // Get type metadata
            switch Belt.Map.String.get(state.variantTypes, typeName) {
            | None => Error(`Variant type not found: ${typeName}`)
            | Some(typeInfo) =>
              // Get constructor tag
              switch Belt.Map.String.get(state.variantTags, constructorName) {
              | None => Error(`Constructor tag not found: ${constructorName}`)
              | Some(tag) =>
                // Poke tag to baseAddr
                let state = emit(state, IR.StackPoke(typeInfo.baseAddr, IR.Num(tag)))

                // Poke all arguments
                Array.reduceWithIndex(args, Ok(state), (stateResult, arg, index) => {
                  stateResult->Result.flatMap(state => {
                    // Generate argument expression
                    generateExpr(state, arg)->Result.map(
                      ((state, argVReg)) => {
                        // Calculate address: baseAddr + tag * maxArgs + 1 + index
                        let address = typeInfo.baseAddr + tag * typeInfo.maxArgs + 1 + index

                        // Emit StackPoke
                        emit(state, IR.StackPoke(address, IR.VReg(argVReg)))
                      },
                    )
                  })
                })
              }
            }

          | Identifier(constructorName) =>
            // Check if this identifier is a zero-arg variant constructor
            switch getTypeNameFromConstructor(state, constructorName) {
            | Some(_identTypeName) =>
              // This is a zero-arg variant constructor - treat as VariantConstructor(name, [])
              // Get type metadata
              switch Belt.Map.String.get(state.variantTypes, typeName) {
              | None => Error(`Variant type not found: ${typeName}`)
              | Some(typeInfo) =>
                // Get constructor tag
                switch Belt.Map.String.get(state.variantTags, constructorName) {
                | None => Error(`Constructor tag not found: ${constructorName}`)
                | Some(tag) =>
                  // Poke tag to baseAddr (no arguments for zero-arg constructor)
                  let state = emit(state, IR.StackPoke(typeInfo.baseAddr, IR.Num(tag)))
                  Ok(state)
                }
              }
            | None =>
              Error(
                "[IRGen.res][generateStmt]: variant ref can only be assigned variant constructors",
              )
            }

          | _ =>
            Error(
              "[IRGen.res][generateStmt]: variant ref can only be assigned variant constructors",
            )
          }

        | None =>
          // Not a variant ref - use simple approach
          generateExpr(state, valueExpr)->Result.map(((state, valueVreg)) => {
            // Emit Move to overwrite the ref's vreg
            emit(state, IR.Move(varInfo.vreg, IR.VReg(valueVreg)))
          })
        }
      }
    | None => Error(`Variable '${name}' not found`)
    }

  // WhileLoop: while condition { body }
  | WhileLoop(condition, body) => generateWhileLoop(state, condition, body)

  // RawInstruction: raw IC10 assembly (e.g., yield)
  | RawInstruction(instruction) =>
    // Emit raw instruction directly to IR
    let state = emit(state, IR.RawInstruction(instruction))
    Ok(state)

  // BlockStatement: { stmt1; stmt2; ... }
  | BlockStatement(block) => generateBlock(state, block)

  // SwitchExpression: when used as a statement (for side effects)
  | SwitchExpression(scrutinee, cases) =>
    // Generate the switch expression and discard the result vreg
    generateExpr(state, SwitchExpression(scrutinee, cases))->Result.map(((state, _resultVreg)) =>
      state
    )

  // FunctionCall as statement: s(device, property, value)
  | FunctionCall(funcName, args) =>
    switch funcName {
    | "s" =>
      // s(device, "Property", value) - Store instruction
      if Array.length(args) != 3 {
        Error(
          "[IRGen.res][generateStmt]: s() expects 3 arguments: device, property name, and value",
        )
      } else {
        switch (args[0], args[1], args[2]) {
        // Case 1: s(identifier, "Property", value) - device variable
        | (
            Some(AST.ArgExpr(AST.Identifier(deviceVar))),
            Some(AST.ArgString(property)),
            Some(AST.ArgExpr(valueExpr)),
          ) =>
          // Look up device variable in deviceMap
          switch state.deviceMap->Belt.Map.String.get(deviceVar) {
          | Some(deviceRef) =>
            // Check if value is a literal - use immediate value
            // deviceRef is already a string like "d0" or "db"
            switch valueExpr {
            | AST.Literal(n) =>
              // Use immediate value directly
              Ok(emit(state, IR.DeviceStore(IR.DevicePin(deviceRef), property, IR.Num(n))))
            | _ =>
              // Generate value expression into a vreg
              generateExpr(state, valueExpr)->Result.map(((state, valueVReg)) => {
                // Emit DeviceStore instruction with vreg
                emit(state, IR.DeviceStore(IR.DevicePin(deviceRef), property, IR.VReg(valueVReg)))
              })
            }
          | None =>
            Error(`[IRGen.res][generateStmt]: Variable '${deviceVar}' is not a device. Use: let ${deviceVar} = device("d0")`)
          }

        // Case 2: s(literal, "Property", value) - direct device pin
        | (
            Some(AST.ArgExpr(AST.Literal(devicePin))),
            Some(AST.ArgString(property)),
            Some(AST.ArgExpr(valueExpr)),
          ) =>
          // Check if value is a literal - use immediate value
          // Convert integer device pin to string reference (0 → "d0", etc.)
          let deviceRef = `d${Int.toString(devicePin)}`
          switch valueExpr {
          | AST.Literal(n) =>
            // Use immediate value directly
            Ok(emit(state, IR.DeviceStore(IR.DevicePin(deviceRef), property, IR.Num(n))))
          | _ =>
            // Generate value expression into a vreg
            generateExpr(state, valueExpr)->Result.map(((state, valueVReg)) => {
              // Emit DeviceStore instruction with vreg
              emit(state, IR.DeviceStore(IR.DevicePin(deviceRef), property, IR.VReg(valueVReg)))
            })
          }

        | _ =>
          Error(
            "[IRGen.res][generateStmt]: s() expects (device: identifier or int, property: string, value: expr)",
          )
        }
      }

    | "sb" =>
      // sb(typeHash, "Property", value) - Batch store by type
      if Array.length(args) != 3 {
        Error("[IRGen.res][generateStmt]: sb() expects 3 arguments: type hash, property, value")
      } else {
        switch (args[0], args[1], args[2]) {
        | (
            Some(AST.ArgExpr(AST.Identifier(typeHashVar))),
            Some(AST.ArgString(property)),
            Some(AST.ArgExpr(valueExpr)),
          ) =>
          // Check if value is a literal
          switch valueExpr {
          | AST.Literal(n) =>
            Ok(emit(state, IR.DeviceStore(IR.DeviceType(typeHashVar), property, IR.Num(n))))
          | _ =>
            generateExpr(state, valueExpr)->Result.map(((state, valueVReg)) => {
              emit(state, IR.DeviceStore(IR.DeviceType(typeHashVar), property, IR.VReg(valueVReg)))
            })
          }
        | _ =>
          Error("[IRGen.res][generateStmt]: sb() expects (typeHash: identifier, property: string, value: expr)")
        }
      }

    | "sbn" =>
      // sbn(typeHash, nameHash, "Property", value) - Batch store by type and name
      if Array.length(args) != 4 {
        Error("[IRGen.res][generateStmt]: sbn() expects 4 arguments: type hash, name hash, property, value")
      } else {
        switch (args[0], args[1], args[2], args[3]) {
        | (
            Some(AST.ArgExpr(AST.Identifier(typeHashVar))),
            Some(AST.ArgExpr(AST.Identifier(nameHashVar))),
            Some(AST.ArgString(property)),
            Some(AST.ArgExpr(valueExpr)),
          ) =>
          // Check if value is a literal
          switch valueExpr {
          | AST.Literal(n) =>
            Ok(emit(state, IR.DeviceStore(IR.DeviceNamed(typeHashVar, nameHashVar), property, IR.Num(n))))
          | _ =>
            generateExpr(state, valueExpr)->Result.map(((state, valueVReg)) => {
              emit(state, IR.DeviceStore(IR.DeviceNamed(typeHashVar, nameHashVar), property, IR.VReg(valueVReg)))
            })
          }
        | _ =>
          Error("[IRGen.res][generateStmt]: sbn() expects (typeHash: identifier, nameHash: identifier, property: string, value: expr)")
        }
      }

    | _ =>
      Error(
        `[IRGen.res][generateStmt]: function '${funcName}' not yet implemented as statement in IR mode`,
      )
    }

  // Phase 2: Support variable declarations and if statements
  | _ => {
      // Debug: log the unsupported statement type
      Console.log2("Unsupported statement type:", stmt)
      Error("[IRGen.res][generateStmt]: statement type not supported in Phase 2")
    }
  }
}

// Generate IR for entire program
let generate = (ast: AST.program): result<IR.t, string> => {
  let initialState = createState()

  // Process all statements
  let rec processStmts = (state: state, stmts: array<AST.stmt>, index: int): result<
    state,
    string,
  > => {
    if index >= Array.length(stmts) {
      Ok(state)
    } else {
      switch stmts[index] {
      | Some(stmt) =>
        generateStmt(state, stmt)->Result.flatMap(state => {
          processStmts(state, stmts, index + 1)
        })
      | None => Error("[IRGen.res][generate]: internal error: array index out of bounds")
      }
    }
  }

  processStmts(initialState, ast, 0)->Result.map(finalState => {
    // Create a single block with all instructions (reversed to correct order)
    let instructions = finalState.instructions->List.reverse
    let block: IR.block = {
      name: "main",
      instructions,
    }
    list{block}
  })
}
