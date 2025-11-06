type state =
  | Idle
  | Full(int)
  | Flushing(int)

let tanks = hash("StructuresTankSmall")
let atmTank = hash("AtmTank")
let maxPressure = 5000

let state = ref(Idle)

while true {
  state := Full(10)
  sb(tanks, "Temperature", 100)
  %raw("yield")
}
