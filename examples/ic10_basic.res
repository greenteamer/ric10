let i = ref(0)
let temp = l(d0, "Temperature")

if i.contents < 5 {
  s(d0, "Setting", temp)
  i := i.contents + 1
}
