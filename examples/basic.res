// Thermostat: keeps a room between two temperatures with a heater and a cooler.
let sensor = device("d0")
let heater = device("d1")
let cooler = device("d2")

let low = 290.
let high = 300.

type mode = Heating | Cooling | Idle

let mode = ref(Idle)

while true {
  let t = l(sensor, "Temperature")
  mode :=
    if t < low {
      Heating
    } else if t > high {
      Cooling
    } else {
      Idle
    }
  switch mode.contents {
  | Heating =>
    s(heater, "On", 1)
    s(cooler, "On", 0)
  | Cooling =>
    s(heater, "On", 0)
    s(cooler, "On", 1)
  | Idle =>
    s(heater, "On", 0)
    s(cooler, "On", 0)
  }
  yield()
}
