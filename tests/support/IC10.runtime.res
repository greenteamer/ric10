// Executable twin of src/compiler/IC10.res for differential tests.
// Same signatures; every call goes to globalThis.__ic10 (tests/support/jsChip.mjs).

type device

type batchMode = Average | Sum | Minimum | Maximum

type reagentMode = Contents | Required | Recipe | TotalContents

let device: string => device = %raw(`p => globalThis.__ic10.device(p)`)
let d0: device = device("d0")
let d1: device = device("d1")
let d2: device = device("d2")
let d3: device = device("d3")
let d4: device = device("d4")
let d5: device = device("d5")
let db: device = device("db")
let hash: string => int = %raw(`s => globalThis.__ic10.hash(s)`)

let l: (device, string) => float = %raw(`(d, p) => globalThis.__ic10.l(d, p)`)
let s: (device, string, 'a) => unit = %raw(`(d, p, v) => globalThis.__ic10.s(d, p, v)`)
let ls: (device, int, string) => float = %raw(`(d, i, p) => globalThis.__ic10.ls(d, i, p)`)
let ss: (device, int, string, 'a) => unit = %raw(`(d, i, p, v) => globalThis.__ic10.ss(d, i, p, v)`)
let lr: (device, reagentMode, int) => float = %raw(`() => { throw new Error("lr not emulated") }`)
let isSet: device => bool = %raw(`d => globalThis.__ic10.isSet(d)`)
let isNotSet: device => bool = %raw(`d => !globalThis.__ic10.isSet(d)`)

let lb: (int, string, batchMode) => float = %raw(`(h, p, m) => globalThis.__ic10.lb(h, undefined, p, m)`)
let lbn: (int, int, string, batchMode) => float = %raw(`(h, n, p, m) => globalThis.__ic10.lb(h, n, p, m)`)
let lbs: (int, int, string, batchMode) => float = %raw(`() => { throw new Error("lbs not emulated") }`)
let lbns: (int, int, int, string, batchMode) => float = %raw(`() => { throw new Error("lbns not emulated") }`)
let sb: (int, string, 'a) => unit = %raw(`(h, p, v) => globalThis.__ic10.sb(h, undefined, p, v)`)
let sbn: (int, int, string, 'a) => unit = %raw(`(h, n, p, v) => globalThis.__ic10.sb(h, n, p, v)`)
let sbs: (int, int, string, 'a) => unit = %raw(`() => { throw new Error("sbs not emulated") }`)

let yield: unit => unit = %raw(`() => globalThis.__ic10.yield()`)
let sleep: float => unit = %raw(`s => globalThis.__ic10.sleep(s)`)

let push: 'a => unit = %raw(`v => globalThis.__ic10.push(v)`)
let pop: unit => float = %raw(`() => globalThis.__ic10.pop()`)
let peek: unit => float = %raw(`() => globalThis.__ic10.peek()`)
let get: (device, int) => float = %raw(`(d, a) => globalThis.__ic10.get(d, a)`)
let put: (device, int, 'a) => unit = %raw(`(d, a, v) => globalThis.__ic10.put(d, a, v)`)
let getd: (float, int) => float = %raw(`(id, a) => globalThis.__ic10.getd(id, a)`)
let putd: (float, int, 'a) => unit = %raw(`(id, a, v) => globalThis.__ic10.putd(id, a, v)`)

let select = (cond: bool, a: 'a, b: 'a): 'a => cond ? a : b
let lerp = (a: float, b: float, t: float): float => a +. (b -. a) *. t
let rand: unit => float = %raw(`() => 0.5`)
