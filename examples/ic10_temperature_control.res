let maxTemp = 500
let d0 = 0
let d1 = 1

while true {
  let currentTemp = l(d0, "Temperature")

  if currentTemp > maxTemp {
    s(d1, "On", 0)
  } else {
    s(d1, "On", 1)
  }

  %raw("yield")
}
