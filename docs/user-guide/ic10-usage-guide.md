# IC10 Bindings - Usage Guide

## Quick Start

The IC10 bindings allow you to write type-safe ReScript code that compiles to IC10 assembly for the Stationeers game.

## Important Syntax Rules

### ❌ What DOESN'T Work

```rescript
// ❌ Module-prefixed calls
let temp = IC10.l(IC10.d0, "Temperature")

// ❌ Comments (not supported yet)
// This is a comment

// ❌ Module constants
let device = IC10.d0

// ❌ Property constants
let temp = IC10.l(d0, IC10.Property.temperature)

// ❌ Else-if syntax
else if condition { ... }
```

### ✅ What DOES Work

```rescript
// ✅ Direct function calls
let d0 = 0
let temp = l(d0, "Temperature")

// ✅ No comments (remove them)
let maxTemp = 500

// ✅ Device variables
let d0 = 0
let d1 = 1

// ✅ String literal properties
let temp = l(d0, "Temperature")

// ✅ Nested if instead of else-if
else {
  if condition { ... }
}
```

## Available IC10 Functions

### Device I/O

**Load from device pin:**
```rescript
let d0 = 0
let temp = l(d0, "Temperature")
```

**Store to device pin:**
```rescript
let d1 = 1
s(d1, "Setting", 100)
```

### Hash Operations

**Load by device hash:**
```rescript
let avgTemp = lb(12345, "Temperature")
```

**Store by device hash:**
```rescript
sb(67890, "On", 1)
```

### Network Operations

**Load by network (with aggregation):**
```rescript
let avgTemp = lbn("Furnace", "MainFurnace", "Temperature", "Average")
let maxPressure = lbn("GasSensor", "Reactor", "Pressure", "Maximum")
```

**Store by network:**
```rescript
sbn("LEDDisplay", "StatusDisplay", "Setting", 100)
sbn("Heater", "MainHeater", "On", 0)
```

## Complete Examples

### Example 1: Basic Device I/O

```rescript
let d0 = 0
let d1 = 1
let d2 = 2
let d3 = 3

let temp = l(d0, "Temperature")

s(d1, "Setting", 100)

let pressure = l(d2, "Pressure")

s(d3, "On", 1)
```

**Compiles to:**
```
move r0 0
move r1 1
move r2 2
move r3 3
move r15 0
l r14 dr15 Temperature
move r4 r14
move r14 1
move r13 100
s dr14 Setting r13
move r13 0
move r12 2
l r11 dr12 Pressure
move r5 r11
move r11 0
move r10 3
move r9 1
s dr10 On r9
move r9 0
```

### Example 2: Temperature Control Loop

```rescript
let maxTemp = 500
let d0 = 0
let d1 = 1

while true {
  let currentTemp = l(d0, "Temperature")

  if currentTemp > maxTemp {
    s(d1, "On", 0)
  } else {
    s(d1, "On", 1)
  }

  %raw("yield")
}
```

**Compiles to:**
```
move r0 500
move r1 0
move r2 1
label0:
move r15 1
beqz r15 label1
move r14 0
l r13 dr14 Temperature
move r3 r13
bgt r3 r0 label3
move r13 1
move r12 1
s dr13 On r12
j label2
label3:
move r11 1
move r10 0
s dr11 On r10
label2:
yield
j label0
label1:
```

### Example 3: Network Operations

```rescript
let avgTemp = lbn("Furnace", "MainFurnace", "Temperature", "Average")

let maxPressure = lbn("GasSensor", "Reactor", "Pressure", "Maximum")

sbn("LEDDisplay", "StatusDisplay", "Setting", 100)

sbn("Heater", "MainHeater", "On", 0)
```

**Compiles to:**
```
lbn r15 HASH("Furnace") HASH("MainFurnace") Temperature Average
move r0 r15
lbn r15 HASH("GasSensor") HASH("Reactor") Pressure Maximum
move r1 r15
move r15 100
sbn HASH("LEDDisplay") HASH("StatusDisplay") Setting r15
move r15 0
move r14 0
sbn HASH("Heater") HASH("MainHeater") On r14
```

### Example 4: Complex Calculations

```rescript
let d0 = 0
let d1 = 1
let d2 = 2

let temp1 = l(d0, "Temperature")
let temp2 = l(d1, "Temperature")

let sum = temp1 + temp2
let avg = sum / 2

if avg > 400 {
  s(d2, "Setting", 0)
} else {
  s(d2, "Setting", 100)
}
```

## Common Property Names

Use these string literals for common IC10 properties:

### Sensor Properties
- `"Temperature"`
- `"Pressure"`
- `"Volume"`
- `"Setting"`
- `"Ratio"`
- `"Open"`
- `"Lock"`
- `"On"`
- `"Power"`
- `"Mode"`
- `"Activate"`

### Aggregation Modes (for lbn)
- `"Average"` - Average value across all devices
- `"Sum"` - Sum of all values
- `"Maximum"` - Maximum value
- `"Minimum"` - Minimum value

## Device Setup

Always define device variables at the start:

```rescript
let d0 = 0  // Device pin 0
let d1 = 1  // Device pin 1
let d2 = 2  // Device pin 2
let d3 = 3  // Device pin 3
let d4 = 4  // Device pin 4
let d5 = 5  // Device pin 5
```

## Register Constraints

The IC10 has only **16 registers (r0-r15)**. Keep your code simple:

✅ **Good:**
```rescript
let temp = l(d0, "Temperature")
if temp > 400 {
  s(d1, "On", 0)
}
```

❌ **Bad** (too many variables):
```rescript
let a = 1
let b = 2
let c = 3
let d = 4
let e = 5
let f = 6
let g = 7
let h = 8
let i = 9
let j = 10
let k = 11
let l = 12
let m = 13
let n = 14
let o = 15
let p = 16  // Out of registers!
```

## Tips

1. **Keep it simple** - IC10 has limited registers
2. **No comments** - Remove all `//` comments before compiling
3. **Use variables for devices** - Always assign device numbers to variables
4. **String literals only** - Property names must be string literals, not variables
5. **Nested ifs** - Use nested if statements instead of else-if
6. **Test incrementally** - Compile frequently to catch errors early

## Compiling Your Code

### Using VSCode Extension
1. Open your `.res` file in VSCode
2. Press `F5` to launch Extension Development Host
3. Open Command Palette (Cmd+Shift+P / Ctrl+Shift+P)
4. Run "Compile ReScript to IC10"
5. View the generated assembly in the output panel

### Error Messages

**"String literals can only be used as IC10 function arguments"**
- You tried to assign a string to a variable
- Use strings only as function arguments

**"Temp Register allocation failed: out of registers"**
- Too many variables in scope
- Simplify your code or split into smaller functions

**"Expected ',' or ')' after function argument"**
- Missing comma between function arguments
- Example: `l(d0, "Temperature")` ✅ not `l(d0 "Temperature")` ❌

**"Unexpected token in expression: Divide"**
- You have comments (`//`) in your code
- Remove all comments

## Working Example Files

See the `tests/` directory for working examples:
- `tests/ic10_basic.res` - Basic device I/O
- `tests/ic10_hash.res` - Hash operations
- `tests/ic10_network.res` - Network operations
- `tests/ic10_temperature_control.res` - Control loop
- `tests/ic10_complex.res` - Complex calculations

All these files successfully compile to IC10 assembly!
