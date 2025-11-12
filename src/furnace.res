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

let maxPressure = 50000
let isNormal = maxPressure - 100

let housing = device("db")
let lcd = device("d0")
let atmSensor = device("d1")
let vent = device("d2")
let tank = device("d3")
let tankValve = device("d4")
let atmValve = device("d5")

let state = ref(Idle)
let action = ref(EmergencyStop)

while true {
  let fTemp = lbn(furnaceType, furnaceName, "Temperature", "Maximum")
  let atmTemp = l(atmSensor, "Temperature")

  s(housing, "Setting", fTemp)

  switch state.contents {
  | Idle =>
    switch action.contents {
    | EmergencyStop => state := Waiting
    }
  }

  %raw("yield")
}
