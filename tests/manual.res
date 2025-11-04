type state =
  | Idle
  | Fill(int)
  | Purge(int)
  | Work

let maxPressure = 5000
let maxTemp = 403

let state = Idle

let newState = switch state {
| Idle => Idle
| Fill(x) =>
  if x > maxPressure {
    Purge(x)
  } else {
    Fill(x)
  }
| Purge(x) => Purge(100)
| Work => Work
}
