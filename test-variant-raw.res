type state = Idle(int, int) | Fill(int, int) | Purge(int, int)
type atmState = Day(int) | Night(int) | Storm(int)
let state = ref(Idle(0, 0))
let atmState = ref(Day(0))
while true {
  let tankTemp = 100
  let atmTemp = 200
  switch atmState.contents {
  | Day(temp) => state := Idle(tankTemp, atmTemp)
  | Night(temp) => state := Fill(tankTemp, atmTemp)
  | Storm(temp) => state := Purge(tankTemp, atmTemp)
  }
  %raw("yield")
}
