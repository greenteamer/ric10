let tanks = hash("StructuresTankSmall")
let atmTank = hash("AtmTank")
let maxPressure = 5000

while true {
  let tempValue = lbn(tanks, atmTank, "Temperature", Maximum)
  if tempValue < 403 {
    sbn(tanks, atmTank, "Temperature", tempValue)
  }
  %raw("yield")
}
