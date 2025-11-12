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

let lcd = device(0)
let atmSensor = device(1)
let vent = device(2)
let tank = device(3)
let tankValve = device(4)
let atmValve = device(5)

while true {
  let fTemp = lbn(furnaceType, furnaceName, "Temperature", "Maximum")
  let atmTemp = l(atmSensor, "Temperature")

  s(lcd, "Setting", fTemp)

  %raw("yield")
}
