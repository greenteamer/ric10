type state = Idle | Loading(float) | Unloading(float)
let state = ref(Idle)

type action = Start | Stop
let action = ref(Stop)

let furnace = device("d0")
let activateBtn = device("d1")
let vent = device("d2")

let loading = () => {
  s(vent, "Mode", 1)
  s(vent, "Open", 1)
  s(furnace, "SettingInput", 50)
  s(furnace, "SettingOutput", 0)
}

let unloading = () => {
  s(vent, "Mode", 0)
  s(vent, "Open", 1)
  s(furnace, "SettingInput", 50)
  s(furnace, "SettingOutput", 50)
}

let resolveAction = () => {
  let activateBtnState = l(activateBtn, "Open")
  if activateBtnState == 1. {
    action := Start
  } else {
    action := Stop
  }
}

while true {
  let fpressure = l(furnace, "Pressure")

  resolveAction()

  switch state.contents {
  | Idle =>
    switch action.contents {
    | Start => state := Loading(fpressure)
    | Stop => state := Idle
    }
  | Loading(p) =>
    switch action.contents {
    | Start =>
      if p > 55000. {
        state := Unloading(p)
      } else {
        loading()
      }
    | Stop => state := Idle
    }
  | Unloading(p) =>
    switch action.contents {
    | Start =>
      if p < 500. {
        state := Loading(p)
      } else {
        unloading()
      }
    | Stop => state := Idle
    }
  }
  yield()
}
