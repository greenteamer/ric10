type state = Idle | Pressurizing | Depressurizing | Emergency

let furnaceType = hash("StructureAdvancedFurnace")
let furnaceName = hash("Furnace")

let lcdType = hash("StructureConsoleLED5")
let lcd1Name = hash("FurnaceLCD1")
let lcd2Name = hash("FurnaceLCD2")

let dialType = hash("StructureLogicDial")
let dialTempName = hash("FurnaceDialTemp")
let dialPressName = hash("FurnaceDialPress")

let housing = device("db")

let emergencyLever = device("d0")
let atmSensor = device("d1")
let vent = device("d2")
let tank = device("d3")
let tankValve = device("d4")
let atmValve = device("d5")

let state = ref(Idle)

let stopCmd = () => {
  sbn(furnaceType, furnaceName, "SettingInput", 0)
  sbn(furnaceType, furnaceName, "SettingOutput", 0)
  s(tankValve, "On", 0)
  s(atmValve, "On", 0)
  s(vent, "On", 0)
}

let pressurizeCmd = () => {
  sbn(furnaceType, furnaceName, "SettingInput", 10)
  sbn(furnaceType, furnaceName, "SettingOutput", 0)
  s(vent, "Mode", 1)
}

let depressurizeCmd = () => {
  sbn(furnaceType, furnaceName, "SettingInput", 0)
  sbn(furnaceType, furnaceName, "SettingOutput", 10)
  s(vent, "Mode", 0)
}

let openTankValveCmd = () => {
  s(tankValve, "On", 1)
  s(atmValve, "On", 0)
  s(vent, "On", 0)
}

let openAtmValveCmd = () => {
  s(tankValve, "On", 0)
  s(atmValve, "On", 1)
  s(vent, "On", 1)
}

while true {
  let fTemp = lbn(furnaceType, furnaceName, "Temperature", "Maximum")
  let fPress = lbn(furnaceType, furnaceName, "Pressure", "Maximum")
  let atmTemp = l(atmSensor, "Temperature")
  let tankTemp = l(tank, "Temperature")
  let isEmergencyLeverOpen = l(emergencyLever, "Open")
  let confTemp = lbn(dialType, dialTempName, "Setting", "Maximum")
  let confPress = lbn(dialType, dialPressName, "Setting", "Maximum")

  if fPress > 55000 {
    state := Emergency
  }

  if isEmergencyLeverOpen == 1 {
    state := Emergency
  }

  sbn(lcdType, lcd2Name, "Setting", atmTemp)

  switch state.contents {
  | Emergency =>
    if isEmergencyLeverOpen == 0 {
      state := Idle
    }

  | Idle => {
      stopCmd()
      if isEmergencyLeverOpen == 1 {
        state := Emergency
      } else if fPress > confPress {
        state := Depressurizing
      } else {
        state := Pressurizing
      }
    }

  | Pressurizing =>
    if fPress > confPress {
      state := Idle
    } else if atmTemp > confTemp {
      openAtmValveCmd()
      pressurizeCmd()
    } else if tankTemp > confTemp {
      openTankValveCmd()
      pressurizeCmd()
    } else {
      state := Idle
    }

  | Depressurizing =>
    if fPress < confPress {
      state := Idle
    } else if fTemp > tankTemp {
      openTankValveCmd()
      depressurizeCmd()
    } else {
      openAtmValveCmd()
      depressurizeCmd()
    }
  }

  %raw("yield")
}
