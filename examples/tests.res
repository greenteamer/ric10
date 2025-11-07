type state = Idle | Fill
let state = ref(Idle)
while true {
  let x = 100
  switch state.contents {
  | Idle => state := Fill
  | Fill => state := Idle
  }
  %raw("yield")
}
