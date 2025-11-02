// Register Allocator for ReScript → IC10 compiler
// Simple linear allocation strategy: assigns registers sequentially (r0, r1, r2, ...)
// IC10 has 16 registers (r0-r15)

// Variable-to-register mapping (association list)
type varMap = list<(string, int)>

// Register allocation state
type allocator = {
  nextRegister: int, // Next available register (0-15)
  variableMap: varMap, // Maps variable names to register numbers
}

// Create a new register allocator
let create = (): allocator => {
  {
    nextRegister: 0,
    variableMap: list{},
  }
}

// Look up a variable in the map
let lookup = (varMap: varMap, variableName: string): option<int> => {
  let rec loop = (lst: varMap): option<int> => {
    switch lst {
    | list{} => None
    | list =>
      switch List.head(list) {
      | Some((name, regNum)) if name == variableName => Some(regNum)
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
// Returns (newAllocator, registerNumber)
let allocate = (allocator: allocator, variableName: string): result<(allocator, int), string> => {
  // Check if already allocated
  switch lookup(allocator.variableMap, variableName) {
  | Some(regNum) => Ok(allocator, regNum)
  | None =>
    if allocator.nextRegister >= 16 {
      Error("Register allocation failed: out of registers")
    } else {
      let regNum = allocator.nextRegister
      Ok(
        {
          nextRegister: allocator.nextRegister + 1,
          variableMap: list{(variableName, regNum), ...allocator.variableMap},
        },
        regNum,
      )
    }
  }
}

// Get the register for an existing variable
// Returns None if variable not found
let getRegister = (allocator: allocator, variableName: string): option<int> => {
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
  (allocator, int),
  string,
> => {
  switch getRegister(allocator, variableName) {
  | Some(regNum) => Ok(allocator, regNum)
  | None => allocate(allocator, variableName)
  }
}

// Convert register number to IC10 register string (r0, r1, ..., r15)
let registerToString = (regNum: int): string => {
  "r" ++ Int.toString(regNum)
}

// Get the next temporary register (for intermediate calculations)
let allocateTempRegister = (allocator: allocator): result<(allocator, int), string> => {
  let tempName = "_temp_" ++ Int.toString(allocator.nextRegister)
  allocate(allocator, tempName)
}

// Free a temporary register (removes it from the map and potentially reuses the slot)
let freeTempRegister = (allocator: allocator, regNum: int): allocator => {
  // Remove all temporary variables that use this register
  let rec removeTempFromMap = (varMap: varMap): varMap => {
    switch varMap {
    | list{} => list{}
    | list{(name, reg), ...rest} =>
      // Check if this is a temp variable with the target register
      if String.startsWith(name, "_temp_") && reg == regNum {
        removeTempFromMap(rest) // Skip this entry
      } else {
        list{(name, reg), ...removeTempFromMap(rest)} // Keep this entry
      }
    }
  }

  let newVariableMap = removeTempFromMap(allocator.variableMap)

  // If this was the last allocated register, we can reuse it
  if regNum == allocator.nextRegister - 1 {
    {
      nextRegister: allocator.nextRegister - 1,
      variableMap: newVariableMap,
    }
  } else {
    // Register is in the middle - just remove from map
    // (More advanced: maintain a free list for reuse)
    {
      nextRegister: allocator.nextRegister,
      variableMap: newVariableMap,
    }
  }
}

// Free multiple temporary registers at once
let freeTempRegisterMultiple = (allocator: allocator, regNums: array<int>): allocator => {
  Array.reduce(regNums, allocator, (acc, regNum) => freeTempRegister(acc, regNum))
}
