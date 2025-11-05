type state =
  | Idle
  | Fill(int)
  | Purge(int)
  | Work

let d0 = IC10.d0

let maxPressure = 5000
let maxTemp = 403

let state = ref(Idle)

while true {
  state := Purge(10)
  %raw("yield")
}
