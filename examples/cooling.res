let tanks = hash("StructuresTankSmall")
let atmTank = hash("AtmTank")
let maxPressure = 5000

type state = Idle | Purge(int) | Fill(int)
let state = ref(Idle)

while true {
  let tempValue = lbn(tanks, atmTank, "Temperature", Maximum)
  switch state.contents {
  | Idle => state := Purge(tempValue)
  | Purge(x) => sbn(tanks, atmTank, "Temperature", x)
  | Fill(x) => if x < maxPressure {
      let newTemp = lbn(tanks, atmTank, "Temperature", Maximum)
      state := Fill(newTemp)
    } else {
      state := Idle
  }
  %raw("yield")
}
