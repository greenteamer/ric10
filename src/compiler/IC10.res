// IC10.res - ReScript bindings for IC10 assembly instructions
// These are stub implementations that exist purely for type checking.
// The actual compiler recognizes these function names and generates IC10 assembly instead.

// Device references (d0-d5, db)
type device = int

let d0: device = 0
let d1: device = 1
let d2: device = 2
let d3: device = 3
let d4: device = 4
let d5: device = 5
let db: device = -1  // Database device

// Load operations - read from devices
// l r0 d0 Temperature
@genType
let l = (_device: device, _property: string): int => {
  0  // Stub - never executed, replaced by compiler
}

// lb r0 HASH Temperature
@genType
let lb = (_hash: int, _property: string): int => {
  0
}

// lbn r0 HASH("Type") HASH("Name") Property Mode
@genType
let lbn = (_deviceType: string, _deviceName: string, _property: string, _mode: string): int => {
  0
}

// Store operations - write to devices
// s d0 Setting 1
@genType
let s = (_device: device, _property: string, _value: int): unit => {
  ()  // Stub - never executed
}

// sb HASH Setting 1
@genType
let sb = (_hash: int, _property: string, _value: int): unit => {
  ()
}

// sbn HASH("Type") HASH("Name") Property Value
@genType
let sbn = (_deviceType: string, _deviceName: string, _property: string, _value: int): unit => {
  ()
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
  let open_ = "Open"  // 'open' is reserved keyword
  let lock = "Lock"

  // Network modes for lbn
  let maximum = "Maximum"
  let minimum = "Minimum"
  let average = "Average"
  let sum = "Sum"
}
