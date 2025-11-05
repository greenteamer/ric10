let counter = ref(0)
while true {
  counter := counter.contents + 1
  %raw("yield")
}
