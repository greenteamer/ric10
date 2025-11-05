let i = ref(0)

while i.contents < 5 {
  let temp = l(d0, "Temperature")
  s(d0, "Setting", temp)
  i := i.contents + 1
  %raw("yield")
}
