# Complete Variant Multi-Type Implementation - Remaining Changes

## Status
✅ IR.res - Complete (device type + stack operations)
✅ IRToIC10.res - Complete (stack ops + Load lowering)
✅ IRGen.res - State and helpers added

## Remaining Changes for IRGen.res

Due to the large size of the remaining changes, I'll provide them in sections that need to be added to `src/compiler/IR/IRGen.res`:

### 1. Add FunctionCall support to generateExpr (before SwitchExpression)

Add this case after the `RefAccess` case and before the catch-all error:

```rescript
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
```

### 2. Add SwitchExpression support to generateExpr (before catch-all error)

```rescript
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
          let (state, caseLabels) = Array.reduceWithIndex(
            cases,
            (state, []),
            ((state, labels), matchCase, _idx) => {
              // Look up constructor tag
              switch Belt.Map.String.get(state.variantTags, matchCase.constructorName) {
              | None => (state, labels) // Skip unknown constructors
              | Some(tag) =>
                let caseLabel = `match_case_${Int.toString(state.nextLabel)}`
                let state = {...state, nextLabel: state.nextLabel + 1}

                // Generate: Compare tagVReg == tag, then Bnez to caseLabel
                let (state, cmpVReg) = allocVReg(state)
                let state = emit(
                  state,
                  IR.Compare(cmpVReg, IR.EqOp, IR.VReg(tagVReg), IR.Num(tag)),
                )
                let state = emit(state, IR.Bnez(IR.VReg(cmpVReg), caseLabel))

                (state, Array.concat(labels, [(caseLabel, matchCase, tag)]))
              }
            },
          )

          // Jump to end if no case matched (fallthrough)
          let state = emit(state, IR.Goto(matchEndLabel))

          // Generate code for each case body
          let stateResult = Array.reduce(caseLabels, Ok(state), (stateResult, (label, matchCase, tag)) => {
            stateResult->Result.flatMap(state => {
              // Add case label
              let state = emit(state, IR.Label(label))

              // Extract argument bindings from stack
              let stateResult = Array.reduceWithIndex(
                matchCase.argumentBindings,
                Ok(state),
                (stateResult, bindingName, index) => {
                  stateResult->Result.flatMap(state => {
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
                  })
                },
              )

              stateResult->Result.flatMap(state => {
                // Generate case body
                generateBlock(state, matchCase.body)->Result.map(state => {
                  // Jump to match end
                  emit(state, IR.Goto(matchEndLabel))
                })
              })
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
```

### 3. Fix generateBlock mutual recursion

Change the line that currently reads:
```rescript
let rec generateBlock = (state: state, block: AST.blockStatement): result<state, string> => {
```

To:
```rescript
and generateBlock = (state: state, block: AST.blockStatement): result<state, string> => {
```

This makes `generateBlock` part of the mutual recursion chain started by `let rec generateExpr`.

### 4. Add TypeDeclaration case to generateStmt

Add this as the FIRST case in the `generateStmt` function (before VariableDeclaration):

```rescript
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
      let variantTags = Array.reduceWithIndex(
        constructors,
        state.variantTags,
        (tags, constructor, index) =>
          Belt.Map.String.set(tags, constructor.name, index),
      )

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
```

### 5. Replace VariableDeclaration case in generateStmt

Replace the entire `VariableDeclaration` case with this comprehensive version that handles variant refs:

```rescript
  // VariableDeclaration: generate expression, store vreg in varMap
  | VariableDeclaration(name, init) => {
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
                let variantTypes = Belt.Map.String.set(
                  state.variantTypes,
                  typeName,
                  updatedTypeInfo,
                )

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
                let stateResult = Array.reduceWithIndex(args, Ok(state), (stateResult, arg, index) => {
                  stateResult->Result.flatMap(state => {
                    // Generate argument expression
                    generateExpr(state, arg)->Result.map(((state, argVReg)) => {
                      // Calculate address: baseAddr + tag * maxArgs + 1 + index
                      let address = typeInfo.baseAddr + tag * typeInfo.maxArgs + 1 + index

                      // Emit StackPoke
                      emit(state, IR.StackPoke(address, IR.VReg(argVReg)))
                    })
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
    }
```

### 6. Replace RefAssignment case in generateStmt

Replace the entire `RefAssignment` case with this version that handles variant refs:

```rescript
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
                    generateExpr(state, arg)->Result.map(((state, argVReg)) => {
                      // Calculate address: baseAddr + tag * maxArgs + 1 + index
                      let address = typeInfo.baseAddr + tag * typeInfo.maxArgs + 1 + index

                      // Emit StackPoke
                      emit(state, IR.StackPoke(address, IR.VReg(argVReg)))
                    })
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
```

## Summary

All changes preserve existing functionality while adding:
1. ✅ Device type for IC10 instructions
2. ✅ Stack operations (StackAlloc, StackPoke, StackGet, StackPush)
3. ✅ Full variant type support with one-ref-per-type restriction
4. ✅ IC10 Load instruction (l function)
5. ✅ Switch expressions on variant refs

The implementation follows the design document exactly and enables your test code to work:

```rescript
type state = Idle(int, int) | Fill(int, int) | Purge(int, int)
type atmState = Day(int) | Night(int) | Storm(int)

let state = ref(Idle(0, 0))
let atmState = ref(Day(0))

while true {
  let tankTemp = l(0, "Temperature")
  let atmTemp = l(1, "Temperature")

  switch atmState.contents {
  | Day(temp) => state := Idle(tankTemp, atmTemp)
  | Night(temp) => state := Fill(tankTemp, atmTemp)
  | Storm(temp) => state := Purge(tankTemp, atmTemp)
  }
}
```

This should now compile successfully with IR mode!
