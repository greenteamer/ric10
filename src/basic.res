let a = 2
let b = 3

let c = ref(0)

while c.contents < 10 {
  if c.contents < a {
    c := c.contents + a
  } else {
    c := c.contents + b
  }
}
