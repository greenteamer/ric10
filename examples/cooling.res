let tanks = hash("StructureTankBigInsulated")
let atmTank = hash("AtmTank")
let gasSensors = hash("StructureGasSensor")
let atmSensor = hash("AtmSensor")
let maxTemp = 403

type state = Idle | Purge | Fill
let state = ref(Idle)

while true {
  let tankPressure = lbn(tanks, atmTank, "Pressure", Maximum)
  let atmTemp = lbn(gasSensors, atmSensor, "Temperature", Maximum)
  switch state.contents {
  | Idle =>
    if tankPressure < 3500 {
      if atmTemp < maxTemp {
        state := Fill
      }
    } else {
      state := Purge
    }
  | Purge =>
    if tankPressure < 500 {
      state := Idle
    } else {
      state := Purge
    }
  | Fill =>
    if tankPressure > 4000 {
      state := Idle
    } else {
      state := Fill
    }
  }
  %raw("yield")
}
