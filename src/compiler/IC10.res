// IC10.res - ReScript bindings for IC10 assembly instructions
// These are stub implementations that exist purely for type checking.
// The actual compiler recognizes these function names and generates IC10 assembly instead.

// Device references (d0-d5, db)
type device = int

module Mode = {
  type t = Maximum | Minimum | Average | Sum

  let toString = (mode: t): string =>
    switch mode {
    | Maximum => "Maximum"
    | Minimum => "Minimum"
    | Average => "Average"
    | Sum => "Sum"
    }

  let fromString = (str: string): result<t, string> =>
    switch str {
    | "Maximum" => Ok(Maximum)
    | "Minimum" => Ok(Minimum)
    | "Average" => Ok(Average)
    | "Sum" => Ok(Sum)
    | _ => Error("Invalid mode string")
    }
}

let d0: device = 0
let d1: device = 1
let d2: device = 2
let d3: device = 3
let d4: device = 4
let d5: device = 5
let db: device = -1 // Database device

// Load operations - read from devices
// l r0 d0 Temperature
let l = (_device: device, _property: string): int => {
  0
}

// lb r0 HASH Temperature
let lb = (_typeHash: int, _property: string, _mode: Mode.t): int => {
  0
}

// lbn r0 HASH("Type") HASH("Name") Property Mode
let lbn = (_typeHash: int, _nameHash: int, _property: string, _mode: Mode.t): int => {
  0
}

// Store operations - write to devices
// s d0 Setting 1
let s = (_device: device, _property: string, _value: int): unit => {
  () // Stub - never executed
}

// sb HASH Setting 1
let sb = (_hash: int, _property: string, _value: int, _mode: Mode.t): unit => {
  ()
}

// sbn HASH("Type") HASH("Name") Property Value
let sbn = (_typeHash: int, _nameHash: int, _property: string, _value: int): unit => {
  ()
}

let hash = (string): int => {
  0
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
