type state = Idle(int, int) | Fill(int, int) | Purge(int, int)
type atmState = Day | Night | Storm
type confState = Heating | Pressuring

let state = ref(Idle(0, 0))
let atmState = ref(Day)

while true {
  let fTemp = l(0, "Temperature")
  let fPress = l(0, "Pressure")
  let tankTemp = l(1, "Temperature")
  let tankPress = l(1, "Pressure")
  let atmTemp = l(2, "Temperature")
  let confTemp = l(3, "Setting")
  let confPress = l(4, "Setting")

  switch atmState.contents {
  | Day =>
    switch state.contents {
    | Idle(t, p) =>
      if fTemp < 1000 {
        state := Fill(tankTemp, atmTemp)
      } else {
        state := Purge(tankTemp, atmTemp)
      }
    }
  | Night => state := Fill(tankTemp, atmTemp)
  | Storm => state := Purge(tankTemp, atmTemp)
  }
  %raw("yield")
}
