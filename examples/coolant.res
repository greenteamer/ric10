let housing = device("db")

let temp_sensor = device("d0")
let active_vent = device("d1")

let temp = l(temp_sensor, "Temperature")

while true {
  s(housing, "Setting", temp)
  yield()
}
