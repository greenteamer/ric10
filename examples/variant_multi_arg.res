// Test multi-argument variant parsing
type state = Idle(int, int) | Fill(int, int) | Waiting(int)

let state = ref(Idle(0, 0))

while true {
  switch state.contents {
  | Idle(p, t) => state := Fill(p + 10, t + 5)
  | Fill(p, t) => state := Idle(p - 10, t - 5)
  | Waiting(delay) => state := Idle(delay, 0)
  }
  %raw("yield")
}
