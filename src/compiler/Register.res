type t = int

let minRegister = 0
let maxRegister = 15

let isValid = (n: int): bool => n >= minRegister && n <= maxRegister

let fromInt = n =>
  switch isValid(n) {
  | true => Ok(n)
  | false => Error("[Register] constructor failed: not valid register range.")
  }

let toInt = r => r

let toString = r => "r" ++ Int.toString(r)

let compare = (r1, r2) => r1 - r2
let equal = (r1, r2) => r1 == r2

let prev = r =>
  switch isValid(r - 1) {
  | true => Some(r - 1)
  | false => None
  }

let next = r =>
  switch isValid(r + 1) {
  | true => Some(r + 1)
  | false => None
  }
