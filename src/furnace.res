type state = Idle | Pressurizing | Depressurizing | Waiting
type action =
  | EmergencyStop
  | Stop
  | Pressurize
  | Depressurize
  | Heat
  | Deplete

let furnaceType = hash("StructureAdvancedFurnace")
let furnaceName = hash("Furnace")

let housing = device("db")
let lcd = device("d0")
let atmSensor = device("d1")
let vent = device("d2")
let tank = device("d3")
let tankValve = device("d4")
let atmValve = device("d5")

while true {
  let fTemp = lbn(furnaceType, furnaceName, "Temperature", "Maximum")
  let atmTemp = l(atmSensor, "Temperature")

  s(housing, "Setting", fTemp)

  %raw("yield")
}
