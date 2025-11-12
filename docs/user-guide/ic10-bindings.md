# IC10 Bindings Implementation

## Overview

This document describes the implementation of **pseudo bindings** for IC10 assembly instructions in the ReScript → IC10 compiler. These bindings allow developers to write type-safe ReScript code that interacts with IC10 devices while maintaining full type checking during development.

## Motivation

The IC10 assembly language (used in the Stationeers game) has specific instructions for device I/O operations:

- **Load operations**: Read values from devices (`l`, `lb`, `lbn`)
- **Store operations**: Write values to devices (`s`, `sb`, `sbn`)
- **Device references**: Access to device pins (`d0`-`d5`, `db`)

Without bindings, developers would need to use raw assembly instructions (`%raw("l r0 d0 Temperature")`), which:
- Lacks type safety
- Has no IDE autocomplete
- Is error-prone and hard to maintain
- Doesn't integrate with ReScript's type system

## Architecture: Phantom Bindings

The implementation uses a **phantom binding** pattern:

1. **ReScript bindings** (`IC10.res`): Define type-safe function signatures that never execute
2. **Compiler recognition**: The compiler recognizes these specific function names during code generation
3. **Assembly generation**: Instead of calling the functions, the compiler generates IC10 assembly instructions

### Example Flow

```rescript
// User writes type-safe ReScript:
let temp = IC10.l(IC10.d0, "Temperature")

// Compiler recognizes IC10.l and generates:
// l r0 d0 Temperature

// The IC10.l function body never executes!
```

## Implementation Details

### 1. AST Extensions (`AST.res`)

Added support for function calls and string literals:

```rescript
type argument =
  | ArgExpr(expr)        // Expression argument: IC10.l(d0, ...)
  | ArgString(string)    // String literal: IC10.l(..., "Temperature")

type astNode =
  | ...
  | StringLiteral(string)                  // "Temperature"
  | FunctionCall(string, array<argument>)  // IC10.l(d0, "Temperature")
```

**Rationale**: IC10 instructions mix expressions and string literals. For example, `l r0 d0 Temperature` requires:
- `d0` (device reference - expression)
- `"Temperature"` (property name - string literal)

### 2. Bindings Module (`IC10.res`)

Defines phantom implementations for IC10 instructions:

```rescript
// Device references (d0-d5, db)
type device = int

let d0: device = 0  // d0 = device pin 0
let d1: device = 1
// ... d2-d5
let db: device = -1  // Special database device

// Load operations
@genType
let l = (_device: device, _property: string): int => {
  0  // Stub - never executed, replaced by compiler
}

@genType
let lb = (_hash: int, _property: string): int => {
  0  // Load by hash
}

@genType
let lbn = (_deviceType: string, _deviceName: string,
           _property: string, _mode: string): int => {
  0  // Load by network
}

// Store operations
@genType
let s = (_device: device, _property: string, _value: int): unit => {
  ()  // Stub - never executed
}

@genType
let sb = (_hash: int, _property: string, _value: int): unit => {
  ()  // Store by hash
}

@genType
let sbn = (_deviceType: string, _deviceName: string,
           _property: string, _value: int): unit => {
  ()  // Store by network
}
```

**Key Points**:
- Functions return dummy values (0 for `int`, `()` for `unit`)
- `@genType` annotation creates TypeScript definitions for VSCode integration
- Parameter names start with `_` to indicate they're unused in the stub
- Type signatures enforce correct usage at compile time

### 3. Parser Extensions (`Parser.res`)

Added parsing for:

**Function call arguments**:
```rescript
// Parses: functionName(arg1, arg2, arg3, ...)
and parseFunctionArguments = (parser: parser): result<(parser, array<AST.argument>), string>
```

**String literals in expressions**:
```rescript
| Some(Lexer.StringLiteral(str)) =>
  let parser = advance(parser)
  Ok((parser, AST.createStringLiteral(str)))
```

**Function call vs variant constructor disambiguation**:
```rescript
// Checks if identifier is IC10 function
let isIC10Function = name == "l" || name == "lb" || name == "lbn" ||
                     name == "s" || name == "sb" || name == "sbn"

if isIC10Function {
  // Parse as function call with multiple arguments
  parseFunctionArguments(parser)
} else {
  // Parse as variant constructor (single argument)
  parseExpression(parser)
}
```

### 4. Code Generation (`ExprGen.res`)

The compiler recognizes IC10 functions by name and generates assembly:

#### Device References

```rescript
| AST.Identifier(name) =>
  if name == "d0" || name == "d1" || ... {
    // d0 = 0, d1 = 1, etc.
    let deviceNum = switch name {
    | "d0" => 0
    | "d1" => 1
    // ...
    }
    // Generate: move rN deviceNum
  }
  else if name == "db" {
    // Generate: move rN db
  }
```

#### Load Operations

**`l` (load from device)**:
```rescript
| AST.FunctionCall("l", args) =>
  // l resultReg device property
  // Example: IC10.l(d0, "Temperature")
  // Generates: l r0 d0 Temperature

  switch (args[0], args[1]) {
  | (ArgExpr(deviceExpr), ArgString(property)) =>
    // 1. Generate code for device expression
    // 2. Allocate result register
    // 3. Generate: l resultReg dDeviceReg property
  }
```

**`lb` (load by hash)**:
```rescript
| AST.FunctionCall("lb", args) =>
  // lb resultReg hash property
  // Example: IC10.lb(12345, "Temperature")
  // Generates: lb r0 12345 Temperature
```

**`lbn` (load by network)**:
```rescript
| AST.FunctionCall("lbn", args) =>
  // lbn resultReg HASH("type") HASH("name") property mode
  // Example: IC10.lbn("Furnace", "MainFurnace", "Temperature", "Average")
  // Generates: lbn r0 HASH("Furnace") HASH("MainFurnace") Temperature Average
```

#### Store Operations

Store operations (`s`, `sb`, `sbn`) follow similar patterns but:
- Return `unit` (no result value)
- Generate a dummy register with value 0 for consistency in the expression generation pipeline

```rescript
| AST.FunctionCall("s", args) =>
  // s device property value
  // Example: IC10.s(d0, "Setting", 100)
  // Generates: s d0 Setting r1

  // After generating instruction:
  // Allocate dummy register for unit return type
  switch RegisterAlloc.allocateTempRegister(allocator) {
  | Ok((allocator, dummyReg)) =>
    // Generate: move dummyReg 0
  }
```

## Usage Examples

### Basic Device I/O

```rescript
// Read temperature from device 0
let temp = IC10.l(IC10.d0, "Temperature")

// Set setting on device 1
IC10.s(IC10.d1, "Setting", 100)

// Compiles to:
// l r0 d0 Temperature
// move r1 100
// s d1 Setting r1
```

### Using Property Constants

```rescript
// IC10.Property module provides named constants
let pressure = IC10.l(IC10.d2, IC10.Property.pressure)
IC10.s(IC10.d3, IC10.Property.on, 1)

// Compiles to:
// l r0 d2 Pressure
// move r1 1
// s d3 On r1
```

### Hash-based Operations

```rescript
// Load from all devices of a specific hash
let avgTemp = IC10.lb(12345, "Temperature")

// Store to all devices with hash
IC10.sb(67890, "Setting", 50)

// Compiles to:
// lb r0 12345 Temperature
// move r1 50
// sb 67890 Setting r1
```

### Network Operations

```rescript
// Read average temperature from all furnaces named "MainFurnace"
let avgTemp = IC10.lbn("Furnace", "MainFurnace", "Temperature", "Average")

// Set all LED displays named "StatusDisplay" to show value
IC10.sbn("LEDDisplay", "StatusDisplay", "Setting", 100)

// Compiles to:
// lbn r0 HASH("Furnace") HASH("MainFurnace") Temperature Average
// move r1 100
// sbn HASH("LEDDisplay") HASH("StatusDisplay") Setting r1
```

### Complex Example: Temperature Control

```rescript
// Type-safe temperature control logic
let maxTemp = 500
let currentTemp = IC10.l(IC10.d0, IC10.Property.temperature)

if currentTemp > maxTemp {
  // Turn off heater
  IC10.s(IC10.d1, IC10.Property.on, 0)
} else {
  // Turn on heater
  IC10.s(IC10.d1, IC10.Property.on, 1)
}

// Compiles to:
// move r0 500
// l r1 d0 Temperature
// bge r1 r0 label0
// move r2 0
// s d1 On r2
// j label1
// label0:
// move r2 1
// s d1 On r2
// label1:
```

## Current Limitations

### 1. No Comma Token in Lexer

The parser currently handles function arguments without explicit comma tokenization. It relies on sequential parsing of arguments:

```rescript
// Works but fragile:
IC10.l(d0, "Temperature")  // Two arguments parsed sequentially

// Should eventually support:
IC10.l(d0,    "Temperature")  // With explicit comma handling
```

**TODO**: Add `Comma` token to lexer and update parser to expect commas between arguments.

### 2. Limited IC10 Instruction Coverage

Currently only implements basic device I/O:
- ✅ `l`, `lb`, `lbn` (load operations)
- ✅ `s`, `sb`, `sbn` (store operations)
- ❌ Math operations (`sqrt`, `abs`, `min`, `max`, etc.)
- ❌ Trigonometric functions (`sin`, `cos`, `tan`, etc.)
- ❌ Stack operations (`push`, `pop`, `peek`)
- ❌ Special instructions (`yield` is handled via `%raw`)

### 3. String Literal Restrictions

String literals can only appear as IC10 function arguments:

```rescript
// ✅ Valid:
IC10.l(d0, "Temperature")

// ❌ Invalid:
let prop = "Temperature"
IC10.l(d0, prop)  // Error: property must be string literal

// Generates error:
// "String literals can only be used as IC10 function arguments"
```

**Rationale**: IC10 assembly requires compile-time constant property names. Variables would require runtime string handling, which IC10 doesn't support.

### 4. Device Reference Handling

Device references (`d0`-`d5`, `db`) are currently treated specially in the identifier parsing:

```rescript
// These work:
IC10.l(IC10.d0, "Temperature")  // d0 as module access
IC10.l(d0, "Temperature")       // d0 as identifier (if imported)

// But implementation is inconsistent - d0 values are defined in IC10.res
// but recognized as special identifiers in ExprGen.res
```

**TODO**: Consolidate device reference handling - either:
- Option A: Import from IC10 module (`IC10.d0`)
- Option B: Treat as special identifiers (`d0`)

### 5. Unit Return Type Handling

Store operations return `unit` but the expression generator requires a register:

```rescript
// Current workaround: allocate dummy register with 0
IC10.s(d0, "Setting", 100)
// Generates:
// s d0 Setting r1
// move r2 0  // Unnecessary dummy value
```

**Optimization**: Statement-level code generation should handle unit-returning functions without allocating dummy registers.

## Type Safety Benefits

### Compile-time Property Validation

```rescript
// TypeScript/ReScript IDE integration:
IC10.l(d0, IC10.Property.temperature)  // ✅ Autocomplete available
IC10.l(d0, IC10.Property.presure)      // ❌ Typo caught at compile time

// vs raw assembly:
%raw("l r0 d0 Presure")  // ❌ Typo not caught until runtime
```

### Function Signature Enforcement

```rescript
// Correct usage:
IC10.l(d0, "Temperature")              // ✅ Returns int
IC10.s(d1, "Setting", 100)            // ✅ Returns unit

// Type errors caught:
let x: string = IC10.l(d0, "Temp")    // ❌ Type error: int ≠ string
IC10.l(d0, 123)                       // ❌ Type error: expects string property
IC10.s(d0)                            // ❌ Type error: missing arguments
```

### Device Type Safety

```rescript
type device = int

let myDevice: device = IC10.d0
IC10.l(myDevice, "Temperature")        // ✅ Type-safe device reference

IC10.l("d0", "Temperature")            // ❌ Type error: expects device, not string
IC10.l(true, "Temperature")            // ❌ Type error: expects device, not bool
```

## Testing Strategy

### Unit Tests Needed

1. **Parser tests**: Function call parsing with mixed argument types
   ```rescript
   IC10.l(d0, "Temperature")           // ArgExpr + ArgString
   IC10.lbn("Type", "Name", "Prop", "Mode")  // All ArgString
   ```

2. **Code generation tests**: Verify assembly output
   ```rescript
   // Input: IC10.l(IC10.d0, "Temperature")
   // Expected: l r0 d0 Temperature

   // Input: IC10.s(IC10.d1, "Setting", 100)
   // Expected: move r1 100\ns d1 Setting r1
   ```

3. **Error handling tests**:
   ```rescript
   IC10.l(d0)                    // Missing argument
   IC10.l(d0, "Temp", extra)     // Too many arguments
   let x = "Temperature"; IC10.l(d0, x)  // Variable instead of literal
   ```

4. **Type checking tests** (via ReScript compiler):
   ```rescript
   let temp: int = IC10.l(d0, "Temperature")     // ✅
   let temp: string = IC10.l(d0, "Temperature")  // ❌
   ```

### Integration Tests

Real-world Stationeers scenarios:

```rescript
// Cooling system controller
let maxTemp = 403
while true {
  let temp = IC10.l(IC10.d0, "Temperature")
  let pressure = IC10.l(IC10.d0, "Pressure")

  if temp > maxTemp {
    IC10.s(IC10.d1, "On", 1)  // Activate cooler
  } else {
    IC10.s(IC10.d1, "On", 0)  // Deactivate cooler
  }

  %raw("yield")
}
```

## Future Enhancements

### 1. Additional IC10 Instructions

Expand bindings to cover full IC10 instruction set:

```rescript
// Math operations
@genType let sqrt = (_value: int): int => 0
@genType let abs = (_value: int): int => 0
@genType let min = (_a: int, _b: int): int => 0
@genType let max = (_a: int, _b: int): int => 0

// Trigonometry (angles in degrees)
@genType let sin = (_angle: int): int => 0
@genType let cos = (_angle: int): int => 0

// Stack operations
@genType let push = (_value: int): unit => ()
@genType let pop = (): int => 0
@genType let peek = (): int => 0
```

### 2. Reagent/Gas Hash Constants

Add type-safe hash constants for common values:

```rescript
module Hash = {
  // Reagents
  let iron = 1758427767
  let copper = 1103972403
  let gold = 226410516

  // Gases
  let oxygen = -1526513293
  let nitrogen = -1324664829
  let carbonDioxide = 1713245960
}

// Usage:
let ironCount = IC10.lb(Hash.iron, "Quantity")
```

### 3. Property Type System

Create type-safe property access:

```rescript
module Device = {
  type temperature
  type pressure
  type setting

  @genType
  let getTemperature = (_device: device): temperature => ...

  @genType
  let setPressure = (_device: device, _value: pressure): unit => ...
}

// Usage prevents property/device mismatches:
Device.getTemperature(d0)  // ✅
Device.getTemperature(100) // ❌ Type error
```

### 4. Device Type Annotations

Add device type information for better safety:

```rescript
module Device = {
  type furnace
  type gasAnalyzer
  type led

  let furnace = (pin: int): furnace => ...
  let gasAnalyzer = (pin: int): gasAnalyzer => ...
}

// Type-safe device operations:
let f = Device.furnace(0)
IC10.l(f, "Temperature")     // ✅
IC10.l(f, "InvalidProp")     // ❌ Could validate at type level
```

### 5. Compile-time Property Validation

Validate property names against known IC10 properties:

```rescript
// Parser could check property strings against whitelist
IC10.l(d0, "Temperature")    // ✅ Known property
IC10.l(d0, "Temperatur")     // ⚠️  Warning: unknown property (typo?)
```

## Implementation Checklist

- [x] Add `StringLiteral` token to lexer
- [x] Add `argument` and `FunctionCall` AST nodes
- [x] Create `IC10.res` phantom bindings module
- [x] Implement device reference recognition (`d0`-`d5`, `db`)
- [x] Implement `l` (load) instruction generation
- [x] Implement `lb` (load by hash) instruction generation
- [x] Implement `lbn` (load by network) instruction generation
- [x] Implement `s` (store) instruction generation
- [x] Implement `sb` (store by hash) instruction generation
- [x] Implement `sbn` (store by network) instruction generation
- [x] Generate TypeScript definitions (`@genType`)
- [ ] Add `Comma` token to lexer
- [ ] Update parser to handle explicit commas in argument lists
- [ ] Write comprehensive parser tests for function calls
- [ ] Write code generation tests for all IC10 instructions
- [ ] Add error message tests for malformed function calls
- [ ] Create example ReScript programs using IC10 bindings
- [ ] Document common Stationeers patterns with type-safe bindings
- [ ] Consider expanding to full IC10 instruction set

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  ReScript Source Code                                       │
│  let temp = IC10.l(IC10.d0, "Temperature")                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  Lexer (Lexer.res)                                          │
│  - Recognizes StringLiteral tokens                          │
│  - Tokenizes: Identifier("l"), LeftParen, Identifier("d0"), │
│    StringLiteral("Temperature"), RightParen                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  Parser (Parser.res)                                        │
│  - Recognizes IC10 function names                           │
│  - Parses mixed argument types (expr + string)              │
│  - Creates FunctionCall("l", [ArgExpr(...), ArgString(...)]) │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  AST (AST.res)                                              │
│  FunctionCall("l", [                                        │
│    ArgExpr(Identifier("d0")),                               │
│    ArgString("Temperature")                                 │
│  ])                                                         │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  Code Generator (ExprGen.res)                               │
│  - Pattern matches FunctionCall("l", ...)                   │
│  - Generates device expression: move r1 0  (d0 = 0)         │
│  - Allocates result register: r0                            │
│  - Generates IC10: l r0 d1 Temperature                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  IC10 Assembly Output                                       │
│  l r0 d0 Temperature                                        │
└─────────────────────────────────────────────────────────────┘

Note: IC10.res bindings never execute - they exist only for type checking
```

## Conclusion

The phantom binding pattern provides a clean, type-safe way to integrate IC10 assembly instructions into ReScript code. Users benefit from:

1. **Type safety**: Compiler enforces correct argument types and counts
2. **IDE support**: Autocomplete and inline documentation
3. **Maintainability**: Self-documenting code with named constants
4. **Error prevention**: Typos caught at compile time, not runtime

The implementation successfully bridges the gap between high-level type-safe code and low-level assembly generation, making IC10 development more robust and enjoyable.
