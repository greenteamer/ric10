// Register Allocator for ReScript → IC10 compiler
// Simple linear allocation strategy: assigns registers sequentially (r0, r1, r2, ...)
// IC10 has 16 registers (r0-r15)

// Variable-to-register mapping (association list)
type varMap = list<(string, Register.t)>

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
    variableMap: list{},
  }
}

// Look up a variable in the map
let lookup = (varMap: varMap, variableName: string): option<Register.t> => {
  let rec loop = lst => {
    switch lst {
    | list{} => None
    | list =>
      switch List.head(list) {
      | Some((name, register)) if name == variableName => Some(register)
      | Some(_) =>
        switch List.tail(list) {
        | Some(rest) => loop(rest)
        | None => None
        }
      | None => None
      }
    }
  }
  loop(varMap)
}

// Allocate a register for a variable
let allocate = (allocator: allocator, variableName: string): result<
  (allocator, Register.t),
  string,
> => {
  switch lookup(allocator.variableMap, variableName) {
  | Some(_) => Error("Variable '" ++ variableName ++ "' is already allocated")
  | None =>
    if allocator.nextRegister > allocator.nextTempRegister {
      Error("Out of registers")
    } else {
      switch Register.fromInt(allocator.nextRegister) {
      | Error(msg) => Error("Register allocation failed: " ++ msg)
      | Ok(reg) =>
        Ok(
          {
            ...allocator,
            nextRegister: allocator.nextRegister + 1,
            variableMap: list{(variableName, reg), ...allocator.variableMap},
          },
          reg,
        )
      }
    }
  }
}

let allocateTempRegister = (allocator: allocator): result<(allocator, Register.t), string> => {
  if allocator.nextRegister > allocator.nextTempRegister {
    Error("Temp Register allocation failed: out of registers")
  } else {
    switch Register.fromInt(allocator.nextTempRegister) {
    | Error(_) => Error("Temp Register allocation failed: invalid register number")
    | Ok(reg) => {
        let tempName = "_temp_" ++ Int.toString(allocator.nextTempRegister)
        Ok(
          {
            ...allocator,
            nextTempRegister: allocator.nextTempRegister - 1,
            variableMap: list{(tempName, reg), ...allocator.variableMap},
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
let getOrAllocate = (allocator: allocator, variableName: string): result<
  (allocator, Register.t),
  string,
> => {
  switch getRegister(allocator, variableName) {
  | Some(reg) => Ok(allocator, reg)
  | None => allocate(allocator, variableName)
  }
}

// Free a temporary register (removes it from the map and potentially reuses the slot)
let freeTempRegister = (allocator: allocator, register: Register.t): allocator => {
  // Remove all temporary variables that use this register
  let rec removeTempFromMap = (varMap: varMap): varMap => {
    switch varMap {
    | list{} => list{}
    | list{(name, reg), ...rest} =>
      // Check if this is a temp variable with the target register
      if String.startsWith(name, "_temp_") && reg == register {
        removeTempFromMap(rest) // Skip this entry
      } else {
        list{(name, reg), ...removeTempFromMap(rest)} // Keep this entry
      }
    }
  }

  let newVariableMap = removeTempFromMap(allocator.variableMap)

  // Если освобождаем "последний" временный (самый правый использованный)
  if Register.toInt(register) == allocator.nextTempRegister + 1 {
    {
      ...allocator,
      nextTempRegister: allocator.nextTempRegister + 1, // двигаем вправо
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
  allocator.variableMap
  ->List.find(((_, reg)) => Register.equal(reg, register))
  ->Option.map(((name, _)) => name)
}

let freeTempIfTemp = (allocator: allocator, register: Register.t): allocator => {
  switch getVariableName(allocator, register) {
  | Some(name) if String.startsWith(name, "_temp_") => freeTempRegister(allocator, register)
  | _ => allocator // это постоянная переменная, не трогаем
  }
}
