type state = Idle | Pressurizing | Depressurizing | Waiting
type action =
  | EmergencyStop
  | Stop
  | Pressurize
  | Depressurize
  | Deplete

let furnaceType = hash("StructureAdvancedFurnace")
let furnaceName = hash("Furnace")
let lcdType = hash("StructureLCD")
let lcdName = hash("FurnaceLCD")

let maxPressure = 50000

let housing = device("db")

let emergencyLever = device("d0")
let atmSensor = device("d1")
let vent = device("d2")
let tank = device("d3")
let tankValve = device("d4")
let atmValve = device("d5")

let state = ref(Idle)
let action = ref(Stop)

let stopCmd = () => {
  sbn(furnaceType, furnaceName, "SettingInput", 0)
  sbn(furnaceType, furnaceName, "SettingOutput", 0)
  s(tankValve, "On", 0)
  s(atmValve, "On", 0)
  s(vent, "On", 0)
}

let pressurizeCmd = () => {
  sbn(furnaceType, furnaceName, "SettingInput", 100)
  sbn(furnaceType, furnaceName, "SettingOutput", 0)
}

let depressurizeCmd = () => {
  sbn(furnaceType, furnaceName, "SettingInput", 0)
  sbn(furnaceType, furnaceName, "SettingOutput", 100)
}

let openTankValveCmd = () => {
  s(tankValve, "On", 1)
  s(atmValve, "On", 0)
}

let openAtmValveCmd = () => {
  s(tankValve, "On", 0)
  s(atmValve, "On", 1)
}

while true {
  let fTemp = lbn(furnaceType, furnaceName, "Temperature", "Maximum")
  let fPress = lbn(furnaceType, furnaceName, "Pressure", "Maximum")
  let atmTemp = l(atmSensor, "Temperature")
  let isEmergencyLeverOpen = l(emergencyLever, "Open")

  if isEmergencyLeverOpen == 1 {
    action := EmergencyStop
  }

  sbn(lcdType, lcdName, "Setting", fTemp)

  switch state.contents {
  | Idle =>
    switch action.contents {
    | EmergencyStop => {
        stopCmd()
        state := Waiting
      }
    | Stop => {
        stopCmd()
        state := Idle
      }
    | Pressurize => {
        pressurizeCmd()
        state := Pressurizing
      }
    | Depressurize => {
        depressurizeCmd()
        state := Depressurizing
      }
    }
  | Waiting =>
    if fPress == 1 {
      stopCmd()
      state := Waiting
    } else {
      stopCmd()
      state := Idle
    }
  }

  %raw("yield")
}
