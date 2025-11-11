type state = Idle(int, int) | Fill(int, int) | Purge(int, int)
type atmState = Day | Night | Storm

let state = ref(Idle(0, 0))
let atmState = ref(Day)

while true {
  let fTemp = l(0, "Temperature")
  let fPress = l(0, "Pressure")
  let tankTemp = l(1, "Temperature")
  let atmTemp = l(2, "Temperature")

  switch atmState.contents {
  | Day =>
    switch state.contents {
    | Idle(t, p) => state := Idle(tankTemp, atmTemp)
    }
  | Night => state := Fill(tankTemp, atmTemp)
  | Storm => state := Purge(tankTemp, atmTemp)
  }
  %raw("yield")
}
