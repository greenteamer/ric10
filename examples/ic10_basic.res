let maxTemp = 500

let i = ref(0)
let temp = l(d0, "Temperature")

if i.contents < maxTemp {
  s(d0, "Setting", temp)
  i := i.contents + 1
}
