// Register Allocator for ReScript → IC10 compiler
// Simple linear allocation strategy: assigns registers sequentially (r0, r1, r2, ...)
// IC10 has 16 registers (r0-r15)

// Variable information
type variableInfo = {
  register: Register.t,
  isRef: bool,
}

// Variable-to-info mapping (Belt.Map.String for O(log n) lookups)
type varMap = Belt.Map.String.t<variableInfo>

// Register allocation state
type allocator = {
  nextRegister: int, // Next available register (0-15)
  nextTempRegister: int, // Next available tmp register (15-0)
  variableMap: varMap, // Maps variable names to register numbers
}

// Create a new register allocator
let create = (): allocator => {
  {
    nextRegister: 0,
    nextTempRegister: 15,
    variableMap: Belt.Map.String.empty,
  }
}

// Look up a variable in the map - O(log n) instead of O(n)
let lookup = (varMap: varMap, variableName: string): option<variableInfo> => {
  Belt.Map.String.get(varMap, variableName)
}

// Allocate a register for a variable
let allocate = (allocator: allocator, variableName: string, isRef: bool): result<
  (allocator, Register.t),
  string,
> => {
  switch lookup(allocator.variableMap, variableName) {
  | Some({register: existingRegister, _}) =>
    // Variable shadowing: reuse the same register
    // Update isRef status for this shadowing
    let newVarMap = Belt.Map.String.set(
      allocator.variableMap,
      variableName,
      {register: existingRegister, isRef},
    )
    Ok(({...allocator, variableMap: newVarMap}, existingRegister))
  | None =>
    if allocator.nextRegister > allocator.nextTempRegister {
      Error("[RegisterAlloc.res][allocate]: out of registers (all 16 registers allocated)")
    } else {
      switch Register.fromInt(allocator.nextRegister) {
      | Error(msg) => Error("[RegisterAlloc.res][allocate]<-" ++ msg)
      | Ok(reg) =>
        Ok(
          {
            ...allocator,
            nextRegister: allocator.nextRegister + 1,
            variableMap: Belt.Map.String.set(
              allocator.variableMap,
              variableName,
              {register: reg, isRef},
            ),
          },
          reg,
        )
      }
    }
  }
}

// Allocate a register for a ref variable
let allocateRef = (allocator: allocator, variableName: string): result<
  (allocator, Register.t),
  string,
> => {
  allocate(allocator, variableName, true)
}

// Allocate a register for a normal (non-ref) variable
let allocateNormal = (allocator: allocator, variableName: string): result<
  (allocator, Register.t),
  string,
> => {
  allocate(allocator, variableName, false)
}

let allocateTempRegister = (allocator: allocator): result<(allocator, Register.t), string> => {
  if allocator.nextRegister > allocator.nextTempRegister {
    Error("[RegisterAlloc.res][allocateTempRegister]: out of temporary registers")
  } else {
    switch Register.fromInt(allocator.nextTempRegister) {
    | Error(msg) => Error("[RegisterAlloc.res][allocateTempRegister]<-" ++ msg)
    | Ok(reg) => {
        let tempName = "_temp_" ++ Int.toString(allocator.nextTempRegister)
        Ok(
          {
            ...allocator,
            nextTempRegister: allocator.nextTempRegister - 1,
            variableMap: Belt.Map.String.set(
              allocator.variableMap,
              tempName,
              {register: reg, isRef: false},
            ),
          },
          reg,
        )
      }
    }
  }
}

// Get the register for an existing variable
// Returns None if variable not found
let getRegister = (allocator: allocator, variableName: string): option<Register.t> => {
  switch lookup(allocator.variableMap, variableName) {
  | Some({register, _}) => Some(register)
  | None => None
  }
}

// Get full variable info (register + isRef flag)
let getVariableInfo = (allocator: allocator, variableName: string): option<variableInfo> => {
  lookup(allocator.variableMap, variableName)
}

// Check if a variable has been allocated
let isAllocated = (allocator: allocator, variableName: string): bool => {
  switch lookup(allocator.variableMap, variableName) {
  | Some(_) => true
  | None => false
  }
}

// Get or allocate a register (allocates if not found)
let getOrAllocate = (allocator: allocator, variableName: string, isRef: bool): result<
  (allocator, Register.t),
  string,
> => {
  switch getRegister(allocator, variableName) {
  | Some(reg) => Ok(allocator, reg)
  | None => allocate(allocator, variableName, isRef)
  }
}

// Free a temporary register (removes it from the map and potentially reuses the slot)
let freeTempRegister = (allocator: allocator, register: Register.t): allocator => {
  // Remove all temporary variables that use this register
  let newVariableMap = Belt.Map.String.keep(allocator.variableMap, (name, varInfo) => {
    // Keep entry if it's NOT a temp variable with the target register
    !(String.startsWith(name, "_temp_") && varInfo.register == register)
  })

  // If freeing the "last" temporary register (rightmost used)
  if Register.toInt(register) == allocator.nextTempRegister + 1 {
    {
      ...allocator,
      nextTempRegister: allocator.nextTempRegister + 1, // Move right
      variableMap: newVariableMap,
    }
  } else {
    {
      ...allocator,
      variableMap: newVariableMap,
    }
  }
}

// Free multiple temporary registers at once
let freeTempRegisterMultiple = (allocator: allocator, regNums: array<Register.t>): allocator => {
  Array.reduce(regNums, allocator, (acc, regNum) => freeTempRegister(acc, regNum))
}

// Get variable name by register number (reverse lookup)
let getVariableName = (allocator: allocator, register: Register.t): option<string> => {
  Belt.Map.String.findFirstBy(allocator.variableMap, (_name, varInfo) => {
    Register.equal(varInfo.register, register)
  })->Option.map(((name, _varInfo)) => name)
}

let freeTempIfTemp = (allocator: allocator, register: Register.t): allocator => {
  switch getVariableName(allocator, register) {
  | Some(name) if String.startsWith(name, "_temp_") => freeTempRegister(allocator, register)
  | _ => allocator // это постоянная переменная, не трогаем
  }
}
