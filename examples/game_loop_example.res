// Example: Main game loop with yield
// This is the common IC10 pattern for Stationeers

// Game state
type state = Idle | Processing | Complete

let state = ref(Idle)
let counter = ref(0)

// Main game loop - runs every tick
while true {
  // Update state
  state := Processing

  // Increment counter
  counter := counter.contents + 1

  // Check if done
  if counter.contents > 100 {
    state := Complete
  }

  // Yield control back to IC10 runtime
  // This pauses execution until next tick
  %raw("yield")
}

// This compiles to IC10 assembly:
// push 0
// move r15 sp
// sub r15 r15 1
// move r0 r15
// move r1 0
// label0:
// move r15 1
// beqz r15 label1
// push 1
// move r14 sp
// sub r14 r14 1
// move r0 r14
// add r1 r1 1
// move r15 r1
// bge r15 101 label2
// j label3
// label2:
// push 2
// move r14 sp
// sub r14 r14 1
// move r0 r14
// label3:
// yield
// j label0
// label1:
