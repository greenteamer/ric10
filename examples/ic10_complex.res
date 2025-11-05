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
