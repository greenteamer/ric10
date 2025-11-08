let tanks = hash("StructureTankBigInsulated")
let atmTank = hash("AtmTank")
let gasSensors = hash("StructureGasSensor")
let atmSensor = hash("AtmSensor")
let maxTemp = 403

type state = Idle | Purge(int) | Fill(int)
let state = ref(Idle)

while true {
  let tankPressure = lbn(tanks, atmTank, "Pressure", Maximum)
  let atmTemp = lbn(gasSensors, atmSensor, "Temperature", Maximum)
  switch state.contents {
  | Idle =>
    if tankPressure < 3500 {
      if atmTemp < maxTemp {
        state := Fill(tankPressure)
      }
    } else {
      state := Purge(tankPressure)
    }
  | Purge(pressure) =>
    if tankPressure < 500 {
      state := Idle
    } else {
      state := Purge(pressure)
    }
  | Fill(pressure) =>
    if tankPressure > 4000 {
      state := Idle
    } else {
      state := Fill(pressure)
    }
  }
  %raw("yield")
}
