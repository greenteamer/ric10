type t

let fromInt: int => result<t, string>
let toInt: t => int

let toString: t => string

let next: t => option<t>
let prev: t => option<t>

let compare: (t, t) => int
let equal: (t, t) => bool
