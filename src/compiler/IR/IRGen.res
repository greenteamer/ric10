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
  | Lt | Gt | Eq => Error("Comparison operators should use convertCompareOp")
  }
}

// Convert AST comparison operator to IR comparison operator (normal)
let normalCompareOp = (op: AST.binaryOp): result<IR.compareOp, string> => {
  switch op {
  | Lt => Ok(IR.LtOp)
  | Gt => Ok(IR.GtOp)
  | Eq => Ok(IR.EqOp)
  | _ => Error("Not a comparison operator")
  }
}

// Invert comparison operator for if-only statements
// Used when we want to skip the then-block if condition is FALSE
let invertCompareOp = (op: AST.binaryOp): result<IR.compareOp, string> => {
  switch op {
  | Lt => Ok(IR.GeOp) // NOT(a < b) is (a >= b)
  | Gt => Ok(IR.LeOp) // NOT(a > b) is (a <= b)
  | Eq => Ok(IR.NeOp) // NOT(a == b) is (a != b)
  | _ => Error("Not a comparison operator")
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
  | LiteralBool(_) => Error("Boolean literals can only be used in 'while true' loops")

  // Identifier: lookup variable, allocate new vreg, emit Move from source vreg
  | Identifier(name) =>
    switch state.varMap->Belt.Map.String.get(name) {
    | Some(varInfo) => {
        let (state, vreg) = allocVReg(state)
        let state = emit(state, IR.Move(vreg, IR.VReg(varInfo.vreg)))
        Ok(state, vreg)
      }
    | None => Error(`Variable '${name}' not found`)
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
    | "l" =>
      // l(device, "Property") - Load instruction
      if Array.length(args) != 2 {
        Error("l() expects 2 arguments: device pin and property name")
      } else {
        switch (args[0], args[1]) {
        | (Some(AST.ArgExpr(AST.Literal(devicePin))), Some(AST.ArgString(property))) =>
          // Parse property name to deviceParam
          let deviceParamResult = switch property {
          | "Temperature" => Ok(IR.Temperature)
          | "Setting" => Ok(IR.Setting)
          | "Pressure" => Ok(IR.Pressure)
          | _ => Error(`Unknown device parameter: ${property}`)
          }

          deviceParamResult->Result.flatMap(deviceParam => {
            // Allocate vreg for result
            let (state, resultVReg) = allocVReg(state)

            // Emit Load instruction
            let state = emit(state, IR.Load(resultVReg, IR.DevicePin(devicePin), deviceParam, None))

            Ok((state, resultVReg))
          })

        | _ => Error("l() expects (device_pin: int, property: string)")
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
        Error("Switch expression only supports variant refs in IR mode")
      }

    | _ => Error("Switch expression scrutinee must be a ref access (e.g., state.contents)")
    }

  // Phase 1: Only support simple expressions
  | _ => Error("Expression type not supported in Phase 1")
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
      | None => Error("Internal error: array index out of bounds")
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
    | _ => Error("If condition must be a comparison expression")
    }
  | _ => Error("If condition must be a comparison expression")
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
    | _ => Error("If condition must be a comparison expression")
    }
  | _ => Error("If condition must be a comparison expression")
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
    | _ => Error("While condition must be a comparison expression")
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
  | _ => Error("While condition must be a comparison expression or 'while true'")
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

    | RefCreation(valueExpr) =>
      // Non-variant ref - use simple approach
      generateExpr(state, valueExpr)->Result.map(((state, vreg)) => {
        {...state, varMap: state.varMap->Belt.Map.String.set(name, {vreg, isRef: true})}
      })

    | _ =>
      // Not a ref - normal variable
      generateExpr(state, init)->Result.map(((state, vreg)) => {
        {...state, varMap: state.varMap->Belt.Map.String.set(name, {vreg, isRef: false})}
      })
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
          | _ => Error("Variant ref can only be assigned variant constructors")
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

  // Phase 2: Support variable declarations and if statements
  | _ => {
      // Debug: log the unsupported statement type
      Console.log2("Unsupported statement type:", stmt)
      Error("Statement type not supported in Phase 2")
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
      | None => Error("Internal error: array index out of bounds")
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
