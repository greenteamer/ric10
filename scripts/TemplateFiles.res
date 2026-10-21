// Template files for `ric10 init <name>`.
// ic10Bindings is a verbatim copy of src/compiler/IC10.res (a test keeps them in sync).

let ic10Bindings = `// IC10.res - ReScript bindings for the ric10 compiler.
//
// These are type-checking stubs: running your program through the real
// ReScript compiler (with -open IC10) proves it is well-typed, while ric10
// recognises the same names and emits IC10 instructions for them.
// Math: use the standard library (Math.abs, Math.sqrt, Math.floor, Math.min,
// Math.max, Math.sin, ..., Float.toInt, Int.toFloat) - ric10 maps those too.

type device

type batchMode = Average | Sum | Minimum | Maximum

type reagentMode = Contents | Required | Recipe | TotalContents

// Values written to devices may be int, float or bool (true = 1).

// --- devices -------------------------------------------------------------

// Device pin: device("d0") .. device("d5"), device("db") (the IC housing)
let device = (_pin: string): device => Obj.magic(0)
let d0: device = Obj.magic(0)
let d1: device = Obj.magic(1)
let d2: device = Obj.magic(2)
let d3: device = Obj.magic(3)
let d4: device = Obj.magic(4)
let d5: device = Obj.magic(5)
let db: device = Obj.magic(-1)

// Device by ReferenceId (uses ld / sd)
let deviceId = (_referenceId: float): device => Obj.magic(0)

// HASH("StructureVolumePump")
let hash = (_name: string): int => 0

// l r? d? logicType
let l = (_device: device, _logicType: string): float => 0.0
// s d? logicType value
let s = (_device: device, _logicType: string, _value: 'a): unit => ()
// ls r? d? slot slotLogicType
let ls = (_device: device, _slot: int, _slotLogicType: string): float => 0.0
// ss d? slot slotLogicType value
let ss = (_device: device, _slot: int, _slotLogicType: string, _value: 'a): unit => ()
// lr r? d? reagentMode reagentHash
let lr = (_device: device, _mode: reagentMode, _reagent: int): float => 0.0
// sdse / sdns: is a device connected to the pin?
let isSet = (_device: device): bool => false
let isNotSet = (_device: device): bool => true

// --- batch operations on every device of a prefab type ---------------------

let lb = (_prefabHash: int, _logicType: string, _mode: batchMode): float => 0.0
let lbn = (_prefabHash: int, _nameHash: int, _logicType: string, _mode: batchMode): float => 0.0
let lbs = (_prefabHash: int, _slot: int, _slotLogicType: string, _mode: batchMode): float => 0.0
let lbns = (
  _prefabHash: int,
  _nameHash: int,
  _slot: int,
  _slotLogicType: string,
  _mode: batchMode,
): float => 0.0
let sb = (_prefabHash: int, _logicType: string, _value: 'a): unit => ()
let sbn = (_prefabHash: int, _nameHash: int, _logicType: string, _value: 'a): unit => ()
let sbs = (_prefabHash: int, _slot: int, _slotLogicType: string, _value: 'a): unit => ()

// --- execution ----------------------------------------------------------

// Pause until the next game tick
let yield = (): unit => ()
// Pause for a number of seconds
let sleep = (_seconds: float): unit => ()

// --- stack memory (512 slots) ---------------------------------------------

let push = (_value: 'a): unit => ()
let pop = (): float => 0.0
let peek = (): float => 0.0
let poke = (_address: int, _value: 'a): unit => ()
let get = (_device: device, _address: int): float => 0.0
let put = (_device: device, _address: int, _value: 'a): unit => ()
let clr = (_device: device): unit => ()

// --- misc -----------------------------------------------------------------

// Branch-free conditional: select r? cond a b
let select = (cond: bool, a: 'a, b: 'a): 'a => cond ? a : b
let lerp = (a: float, b: float, t: float): float => a +. (b -. a) *. t
let rand = (): float => 0.0
`

let exampleCode = `// Furnace heater: keeps a furnace below a temperature limit.
let furnace = device("d0")
let sensor = device("d1")

let limit = 500.

while true {
  let temp = l(sensor, "Temperature")
  s(furnace, "On", temp < limit)
  yield()
}
`

let rescriptConfig = (projectName: string) =>
  `{
  "name": "${projectName}",
  "sources": [{"dir": "src", "subdirs": true}],
  "package-specs": [{"module": "esmodule", "in-source": true}],
  "suffix": ".res.mjs",
  "compiler-flags": ["-open IC10"]
}
`

let packageJson = (projectName: string) =>
  `{
  "name": "${projectName}",
  "version": "1.0.0",
  "private": true,
  "description": "Stationeers IC10 scripts written in ReScript",
  "scripts": {
    "typecheck": "rescript",
    "compile": "ric10 src/Example.res"
  },
  "devDependencies": {
    "rescript": "^12.1.0",
    "rescript-ic10-compiler": "^0.2.0"
  }
}
`

let readme = (projectName: string) =>
  `# ${projectName}

Stationeers IC10 scripts written in ReScript and compiled with ric10.

## Workflow

    npm install
    npm run typecheck          # the real ReScript compiler checks your program
    npx ric10 src/Example.res  # writes src/Example.ic10

Paste the .ic10 file into an IC housing in game.

## Files

- src/IC10.res: bindings for IC10 instructions (devices, batch ops, stack, yield)
- src/Example.res: your script

## Cheatsheet

    let sensor = device("d0")                  // pins d0..d5, db
    let t = l(sensor, "Temperature")           // read (float)
    s(d1, "On", t > 300.)                      // write int/float/bool
    let tanks = hash("StructureTankSmall")
    let avg = lb(tanks, "Pressure", Average)   // batch read
    yield()                                    // wait one tick

Language: let, refs, if/switch/blocks as expressions, while, for, functions with
parameters, variants with payloads, pattern matching. Math via Math.* .

## Resources

- https://stationeers-wiki.com/IC10
- https://rescript-lang.org
`

let gitignore = `node_modules/
lib/
*.res.mjs
`
