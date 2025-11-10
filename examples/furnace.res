let tanks = hash("StructureTankSmallInsulated")
let gasSensors = hash("StructureGasSensor")
let vents = hash("StructureActiveVent")
let switches = hash("StructureLogicSwitch2")
let dials = hash("StructureLogicDial")
let furnaces = hash("StructureAdvancedFurnace")

let atmSensor = hash("AtmSensor")
let furnace = hash("Furnace")
let furnaceTank = hash("FurnaceTank")
let furnaceVent = hash("FurnaceVent")
let furnaceSwitch = hash("FurnaceSwitch")
let furnaceTempDial = hash("FurnaceTempDial")
let furnacePressDial = hash("FurnacePressDial")

sbn(vents, furnaceVent, "On", 0)
sbn(vents, furnaceVent, "Lock", 0)
sbn(vents, furnaceVent, "Mode", 1)

sbn(switches, furnaceSwitch, "Open", 0)

sbn(dials, furnaceTempDial, "Mode", 1500)
sbn(dials, furnaceTempDial, "Setting", 0)

sbn(dials, furnacePressDial, "Mode", 50000)
sbn(dials, furnacePressDial, "Setting", 0)

type state = Idle | Fill | Purge
let state = ref(Idle)

while true {
  let tankPressure = lbn(tanks, furnaceTank, "Pressure", Maximum)
  let tankTemp = lbn(tanks, furnaceTank, "Temperature", Maximum)
  let atmTemp = lbn(gasSensors, atmSensor, "Temperature", Maximum)
  let tempSetting = lbn(dials, furnaceTempDial, "Setting", Maximum)
  let pressSetting = lbn(dials, furnacePressDial, "Setting", Maximum)
  let furnaceTemp = lbn(furnaces, furnace, "Temperature", Maximum)
  let furnacePress = lbn(furnaces, furnace, "Pressure", Maximum)

  if furnaceSwitch == 1 {
    sbn(vents, furnaceVent, "On", 1)
  } else {
    sbn(vents, furnaceVent, "On", 0)
  }

  switch state.contents {
  | Idle =>
    if furnacePress > 50000 {
      state := Purge
    }
  | Fill => state := Idle
  | Purge =>
    if furnacePress < furnacePressDial {
      if furnaceTemp < furnaceTempDial {
        sbn(furnaces, furnace, "SettingOutput", 100)
      }
    }
  }
  %raw("yield")
}
