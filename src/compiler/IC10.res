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
