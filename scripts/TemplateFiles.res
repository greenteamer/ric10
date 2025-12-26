// Template files for project initialization

// IC10.res bindings - copied from src/compiler/IC10.res
let ic10Bindings = `// IC10.res - ReScript bindings for IC10 assembly instructions
// These are stub implementations that exist purely for type checking.
// The actual compiler recognizes these function names and generates IC10 assembly instead.

// Device references (d0-d5, db)
type device = int

// Bulk operation modes for lb/lbn operations
module Mode = {
  // String constants for bulk operations
  let maximum = "Maximum"
  let minimum = "Minimum"
  let average = "Average"
  let sum = "Sum"
}

// Device reference - creates a device reference from a device string
// Examples:
//   let furnace = device("d0")   // Device pin 0
//   let pump = device("d1")      // Device pin 1
//   let housing = device("db")   // Database device
//   let sensor = device("d2")    // Device pin 2
//
// Use descriptive variable names for better code clarity:
//   let mainFurnace = device("d0")
//   let backupFurnace = device("d1")
//   let tempSensor = device("d2")
let device = (_deviceRef: string): device => {
  0
}

// Load operations - read from devices
// l r0 d0 Temperature
let l = (_device: device, _property: string): int => {
  0
}

// lb r0 typeHash Temperature Maximum
// typeHash should be a variable from hash("StructureTank")
let lb = (_typeHash: string, _property: string, _mode: string): int => {
  0
}

// lbn r0 typeHash nameHash Property Mode
// typeHash and nameHash should be variables from hash()
let lbn = (_typeHash: string, _nameHash: string, _property: string, _mode: string): int => {
  0
}

// Store operations - write to devices
// s d0 Setting 1
let s = (_device: device, _property: string, _value: int): unit => {
  () // Stub - never executed
}

// sb typeHash Setting 1
// typeHash should be a variable from hash("StructureTank")
let sb = (_typeHash: string, _property: string, _value: int): unit => {
  ()
}

// sbn typeHash nameHash Property Value
// typeHash and nameHash should be variables from hash()
let sbn = (_typeHash: string, _nameHash: string, _property: string, _value: int): unit => {
  ()
}

// hash("StructureTank") -> defines a hash constant
// Usage: let typeHash = hash("StructureTank")
let hash = (_string: string): string => {
  "" // Returns the variable name (compiler recognizes this)
}

// Common IC10 properties for convenience and documentation
module Property = {
  // Environmental
  let temperature = "Temperature"
  let pressure = "Pressure"
  let volume = "Volume"

  // Power
  let setting = "Setting"
  let on = "On"
  let power = "Power"
  let mode = "Mode"

  // Logic
  let activate = "Activate"
  let open_ = "Open" // 'open' is reserved keyword
  let lock = "Lock"
}
`

// Example.res - Simple example code
let exampleCode = `let furnace = device("d0")
let sensor = device("d1")

while true {
  let temp = l(sensor, "Temperature")

  if temp < 500 {
    s(furnace, "On", 1)
  } else {
    s(furnace, "On", 0)
  }

  %raw("yield")
}
`

// rescript.json template
let rescriptConfig = (projectName: string) => "{
  \"name\": \"" ++ projectName ++ "\",
  \"sources\": [
    {
      \"dir\": \"src\",
      \"subdirs\": true
    }
  ],
  \"package-specs\": [
    {
      \"module\": \"commonjs\",
      \"in-source\": false
    }
  ],
  \"suffix\": \".res.js\",
  \"bs-dependencies\": [\"@rescript/core\"],
  \"bsc-flags\": [\"-open RescriptCore\", \"-open IC10\"]
}
"

// package.json template
let packageJson = (projectName: string) => "{
  \"name\": \"" ++ projectName ++ "\",
  \"version\": \"1.0.0\",
  \"description\": \"IC10 assembly project using ReScript\",
  \"scripts\": {
    \"build\": \"rescript\",
    \"dev\": \"rescript -w\",
    \"compile\": \"ric10 src/Example.res\"
  },
  \"dependencies\": {
    \"@rescript/core\": \"^1.6.1\",
    \"rescript\": \"^11.1.4\"
  }
}
"

// README.md template
let readme = (projectName: string) => "# " ++ projectName ++ "

IC10 assembly project using ReScript

## Quick Start

1. Install dependencies:
   ```bash
   npm install
   ```

2. Compile Example.res to IC10:
   ```bash
   ric10 src/Example.res
   # Creates src/Example.ic10
   ```

3. Watch mode (auto-compile on changes):
   ```bash
   npm run dev
   ```

## Project Structure

- `src/IC10.res` - IC10 bindings (device functions)
- `src/Example.res` - Example code (edit this!)
- `rescript.json` - ReScript compiler config

## Available IC10 Functions

- `device(ref)` - Create device reference
- `l(device, property)` - Load from device
- `s(device, property, value)` - Store to device
- `lb/lbn` - Batch load operations
- `sb/sbn` - Batch store operations
- `hash(string)` - Generate hash constant

## IC10 Property Constants

Use `Property.temperature`, `Property.pressure`, `Property.on`, etc.

See `src/IC10.res` for full API documentation.

## Resources

- [Stationeers IC10 Documentation](https://stationeers-wiki.com/IC10)
- [ReScript Documentation](https://rescript-lang.org)
"

// .gitignore template
let gitignore = `node_modules/
lib/
*.js
*.js.map
!.gitkeep
`
