# IC10 Bindings - Quick Reference

## What Are IC10 Bindings?

Phantom bindings that provide type-safe ReScript functions for IC10 assembly instructions. The functions exist only for type checking - the compiler recognizes them by name and generates assembly instead of calling them.

## How It Works

```rescript
// You write:
let temp = IC10.l(IC10.d0, "Temperature")

// Compiler generates:
// l r0 d0 Temperature

// The IC10.l function never executes!
```

## Available Functions

### Device References
```rescript
IC10.d0, IC10.d1, IC10.d2, IC10.d3, IC10.d4, IC10.d5  // Device pins 0-5
IC10.db                                                 // Database device
```

### Load Operations (Read from devices)
```rescript
IC10.l(device, property)                    // Load from single device
// Example: IC10.l(IC10.d0, "Temperature")
// Generates: l r0 d0 Temperature

IC10.lb(hash, property)                     // Load by hash (all matching devices)
// Example: IC10.lb(12345, "Pressure")
// Generates: lb r0 12345 Pressure

IC10.lbn(deviceType, deviceName, property, mode)  // Load from network
// Example: IC10.lbn("Furnace", "Main", "Temperature", "Average")
// Generates: lbn r0 HASH("Furnace") HASH("Main") Temperature Average
```

### Store Operations (Write to devices)
```rescript
IC10.s(device, property, value)             // Store to single device
// Example: IC10.s(IC10.d1, "Setting", 100)
// Generates: move r1 100; s d1 Setting r1

IC10.sb(hash, property, value)              // Store by hash
// Example: IC10.sb(67890, "On", 1)
// Generates: move r1 1; sb 67890 On r1

IC10.sbn(deviceType, deviceName, property, value)  // Store to network
// Example: IC10.sbn("LED", "Status", "Setting", 50)
// Generates: move r1 50; sbn HASH("LED") HASH("Status") Setting r1
```

### Property Constants
```rescript
IC10.Property.temperature    // "Temperature"
IC10.Property.pressure       // "Pressure"
IC10.Property.volume         // "Volume"
IC10.Property.setting        // "Setting"
IC10.Property.on             // "On"
IC10.Property.power          // "Power"
IC10.Property.mode           // "Mode"
IC10.Property.activate       // "Activate"
IC10.Property.open_          // "Open"
IC10.Property.lock           // "Lock"
IC10.Property.maximum        // "Maximum"
IC10.Property.minimum        // "Minimum"
IC10.Property.average        // "Average"
IC10.Property.sum            // "Sum"
```

## Complete Example

```rescript
// Temperature control system
let maxTemp = 403
let minTemp = 300

while true {
  // Read current temperature from sensor (d0)
  let currentTemp = IC10.l(IC10.d0, IC10.Property.temperature)

  // Control heater (d1) and cooler (d2)
  if currentTemp > maxTemp {
    IC10.s(IC10.d1, IC10.Property.on, 0)  // Turn off heater
    IC10.s(IC10.d2, IC10.Property.on, 1)  // Turn on cooler
  } else if currentTemp < minTemp {
    IC10.s(IC10.d1, IC10.Property.on, 1)  // Turn on heater
    IC10.s(IC10.d2, IC10.Property.on, 0)  // Turn off cooler
  } else {
    IC10.s(IC10.d1, IC10.Property.on, 0)  // Turn off both
    IC10.s(IC10.d2, IC10.Property.on, 0)
  }

  %raw("yield")  // Wait for next tick
}
```

Compiles to clean IC10 assembly with optimal register usage and direct branch instructions.

## Type Safety Benefits

### ✅ Autocomplete
IDE provides autocomplete for properties and functions

### ✅ Type Checking
```rescript
let temp: int = IC10.l(d0, "Temperature")     // ✅ Correct
let temp: string = IC10.l(d0, "Temperature")  // ❌ Type error
IC10.l(d0, 123)                               // ❌ Type error: expects string
```

### ✅ Compile-time Errors
```rescript
IC10.l(d0)                    // ❌ Missing argument
IC10.l("d0", "Temperature")   // ❌ Wrong type: expects device, not string
```

### ✅ Documentation
Function signatures document expected parameters and return types

## Current Limitations

1. **Property names must be string literals** - cannot use variables:
   ```rescript
   IC10.l(d0, "Temperature")        // ✅ OK
   let prop = "Temperature"
   IC10.l(d0, prop)                 // ❌ Error
   ```

2. **Limited instruction coverage** - only device I/O operations currently supported

3. **Comma handling is implicit** - parser doesn't require explicit commas (will be improved)

## Implementation Status

### ✅ Completed
- [x] Device references (d0-d5, db)
- [x] Load operations (l, lb, lbn)
- [x] Store operations (s, sb, sbn)
- [x] Property constants module
- [x] TypeScript type definitions
- [x] Parser support for function calls and string literals
- [x] Code generation for all six IC10 I/O functions

### 🚧 Planned
- [ ] Add Comma token to lexer
- [ ] Expand to full IC10 instruction set (math, trig, stack operations)
- [ ] Hash constants for reagents and gases
- [ ] Comprehensive test suite
- [ ] Example programs

## Files Modified

- `src/compiler/AST.res` - Added FunctionCall and StringLiteral nodes
- `src/compiler/IC10.res` - **NEW** - Phantom binding definitions
- `src/compiler/Parser.res` - Added function call parsing
- `src/compiler/ExprGen.res` - Added IC10 instruction generation
- `src/compiler/IC10.gen.ts` - **AUTO-GENERATED** - TypeScript definitions

## Next Steps

1. **Add test coverage** - Create tests for all IC10 functions
2. **Example programs** - Write real Stationeers scenarios using bindings
3. **Expand instruction set** - Add math, trig, and stack operations
4. **Improve parser** - Add explicit comma handling
5. **Validation** - Warn about unknown property names

See `docs/IC10_BINDINGS.md` for complete implementation details.
