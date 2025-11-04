type state =
  | Idle
  | Fill(int)
  | Purge(int)
  | Work

let maxPressure = 5000

let state = Fill(10)

let someMutVar = ref(0)

let newState = switch state {
| Idle => Idle
| Fill(x) => if x > maxPressure {
    someMutVar := x + 100
    Purge(x)
  } else {
    Fill(x)
  }
| Purge(x) => Purge(100)
| Work => Work
}
