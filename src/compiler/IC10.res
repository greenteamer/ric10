// IC10.res - ReScript bindings for IC10 assembly instructions
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

let d0: device = 0
let d1: device = 1
let d2: device = 2
let d3: device = 3
let d4: device = 4
let d5: device = 5
let db: device = -1 // Database device

// Device reference - creates a device reference from a pin number
// let furnace = device(0) -> d0
let device = (_pin: int): device => {
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
