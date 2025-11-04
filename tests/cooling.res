type state =
  | Idle
  | Fill(int)
  | Purge(int)
  | Work

let maxPressure = 5000
let maxTemp = 403

let state = ref(Idle)

while true {
  state := Purge(10)
  %raw("yield")
}
