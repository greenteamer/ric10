# IC10 Assembly Language Support

This document describes the IC10 assembly language features supported by the ReScript to IC10 compiler.

## Overview

The compiler translates a subset of ReScript code into IC10 assembly language for the Stationeers game. IC10 is a register-based assembly language with the following characteristics:

- **16 registers**: r0-r15 (physical registers)
- **Device references**: d0-d5, db (database)
- **No stack**: Limited to stack-based variant storage
- **Integer-only**: No floating point support

## Device Operations

### Device References

Use the `device()` function to create named device references. This is purely for code readability and doesn't generate any assembly instructions.

```rescript
let furnace = device(0)  // Maps "furnace" to d0
let tank = device(1)     // Maps "tank" to d1
let sensor = device(2)   // Maps "sensor" to d2
```

**Generated assembly:** None (no code generated)

### Load Operations

Read values from device properties using `l()` (load).

#### Basic Load: `l(device, property)`

```rescript
let temp = l(0, "Temperature")
```

**Generated assembly:**
```
l r0 d0 Temperature
```

#### Using Device References

```rescript
let furnace = device(0)
let temp = l(furnace, "Temperature")
```

**Generated assembly:**
```
l r0 d0 Temperature
```

### Store Operations

Write values to device properties using `s()` (store).

#### Store with Literal Value

```rescript
let furnace = device(0)
s(furnace, "On", 1)
```

**Generated assembly:**
```
s d0 On 1
```

**Note:** Literal values are used directly as immediate operands (no register allocation).

#### Store with Variable

```rescript
let furnace = device(0)
let value = 100
s(furnace, "Setting", value)
```

**Generated assembly:**
```
move r0 100
s d0 Setting r0
```

#### Direct Device Pin

```rescript
s(0, "On", 1)  // Directly use d0
```

**Generated assembly:**
```
s d0 On 1
```

## Supported Device Properties

The compiler recognizes the following IC10 device properties:

- `Temperature` - Device temperature
- `Pressure` - Device pressure
- `Setting` - Device setting value
- `On` - Device on/off state (0 or 1)
- `Open` - Device open/closed state
- `Mode` - Device mode
- `Lock` - Device lock state

## Batch Operations (Planned)

Future support for batch network operations:

- `lb()` - Load batch by type hash
- `lbn()` - Load batch by type and name hash
- `sb()` - Store batch by type hash
- `sbn()` - Store batch by type and name hash

## Code Generation Details

### Device Reference Optimization

Device references created with `device()` are compile-time only. The compiler:

1. **Tracks the mapping**: Variable name → device pin number
2. **Generates no code**: No move instructions or register allocation
3. **Substitutes at usage**: Replaces variable with device reference (e.g., `furnace` → `d0`)

Example:
```rescript
let furnace = device(0)
let tank = device(1)
s(furnace, "On", 1)
s(tank, "On", 0)
```

Compiles to:
```
s d0 On 1
s d1 On 0
```

**No register waste!** The `device()` calls generate zero assembly instructions.

### Immediate Value Optimization

When storing literal values, the compiler uses immediate operands instead of allocating registers:

```rescript
s(furnace, "Setting", 1500)  // Immediate value
```

Generates:
```
s d0 Setting 1500  // Direct literal, no move instruction
```

vs.

```rescript
let temp = 1500
s(furnace, "Setting", temp)  // Variable requires register
```

Generates:
```
move r0 1500
s d0 Setting r0
```

## Best Practices

### 1. Use Named Device References

**Good:**
```rescript
let furnace = device(0)
let temp = l(furnace, "Temperature")
s(furnace, "On", 1)
```

**Bad:**
```rescript
let temp = l(0, "Temperature")
s(0, "On", 1)
```

Named references improve code readability without any runtime cost.

### 2. Use Literals for Constant Values

**Good:**
```rescript
s(furnace, "On", 1)           // Uses immediate value
s(furnace, "Setting", 1500)   // Uses immediate value
```

**Bad:**
```rescript
let on = 1
let setting = 1500
s(furnace, "On", on)          // Wastes a register
s(furnace, "Setting", setting) // Wastes a register
```

Literals compile to immediate values, saving registers.

### 3. Organize Devices at the Top

```rescript
// Device definitions
let furnace = device(0)
let tank = device(1)
let atmSensor = device(2)
let tempDial = device(3)
let pressDial = device(4)

// Main logic
while true {
  let furnaceTemp = l(furnace, "Temperature")
  let tankPress = l(tank, "Pressure")
  
  if furnaceTemp > 1000 {
    s(furnace, "On", 0)
  }
  
  %raw("yield")
}
```

## Register Allocation

The compiler automatically manages the 16 physical registers (r0-r15):

- Virtual registers are allocated during IR generation
- Physical registers are assigned during code generation
- Compilation fails if >16 registers are needed
- Device references **do not** consume registers

## Examples

### Simple Furnace Controller

```rescript
let furnace = device(0)
let sensor = device(1)

while true {
  let temp = l(sensor, "Temperature")
  
  if temp < 1000 {
    s(furnace, "On", 1)
  } else {
    s(furnace, "On", 0)
  }
  
  %raw("yield")
}
```

**Generated assembly:**
```
label0:
l r0 d1 Temperature
bge r0 1000 label2
s d0 On 1
j label1
label2:
s d0 On 0
label1:
yield
j label0
```

### Multi-Device Control

```rescript
let furnace = device(0)
let tank = device(1)
let vent = device(2)

while true {
  let furnacePress = l(furnace, "Pressure")
  let tankPress = l(tank, "Pressure")
  
  if furnacePress > 50000 {
    s(vent, "On", 1)
    s(furnace, "On", 0)
  }
  
  if tankPress < 1000 {
    s(vent, "On", 0)
    s(furnace, "On", 1)
  }
  
  %raw("yield")
}
```

## Technical Notes

### IR Representation

- **device()**: No IR instructions generated, only state tracking
- **l()**: Generates `Load(vreg, DevicePin(pin), param, None)`
- **s()**: Generates `Save(DevicePin(pin), param, operand)`

### Operand Types

- `VReg(vreg)`: Virtual register reference
- `Num(n)`: Immediate integer value

The `Save` instruction accepts both operand types, allowing for register-free literal stores.

### Optimization Passes

1. **Constant Propagation**: Folds constant expressions
2. **Copy Propagation**: Eliminates redundant moves
3. **Dead Code Elimination**: Removes unused instructions
4. **Peephole Optimization**: Combines compare + branch instructions

These optimizations run at the IR level before physical register allocation.

## Limitations

1. **One device reference per variable**: You cannot reassign device references
2. **Compile-time device pins**: Device pins must be literal integers, not expressions
3. **No device arithmetic**: Cannot perform operations on device references
4. **Property name must be literal**: String literals only, no variables

## Future Enhancements

- Hash-based device lookups (`HASH("Type")`)
- Batch network operations
- Device register references (storing device in register)
- Dynamic device selection
