let tanks = hash("StructuresTankSmall")
let atmTank = hash("AtmTank")
let maxPressure = 5000
let tempValue = lbn(tanks, atmTank, "Temperature", Maximum)

sb(tanks, "Temperature", tempValue, Maximum)
