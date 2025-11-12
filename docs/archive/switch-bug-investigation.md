# Switch Statement Bug Investigation

## User Bug Report

### Source Code

```rescript
type state = Idle | Fill
let state = ref(Idle)
while true {
  let x = 100
  switch state.contents {
  | Idle => state := Fill
  | Fill => state := Idle
  }
  %raw("yield")
}
```

### Generated IC10 Assembly

```asm
define x 100
push 0  # Idle variant tag
move r0 sp  # get stack pointer
sub r0 r0 1  # adjust to variant address
label0:
move sp r0  # THIS LINE RESETS TO 0 IN EVERY ITERATION
peek r15  # read variant tag
beq r15 0 match_case_2  # match Idle
beq r15 1 match_case_3  # match Fill
j match_end_1  # no match
match_case_2:  # case Idle
push 1  # Fill variant tag
move r0 sp  # get stack pointer
sub r0 r0 1  # adjust to variant address
j match_end_1  # end case
match_case_3:  # case Fill
push 0  # Idle variant tag
move r0 sp  # get stack pointer
sub r0 r0 1  # adjust to variant address
j match_end_1  # end case
match_end_1:  # end match
yield
j label0
```

### Reported Problem

**Symptoms:**

- State shifts to Idle Every iteration
- **BUG:** In the next iteration at `move sp r0` instruction after `label0`, "it resets to 0 and jumps again in Idle case"

**Expected Behavior:**
State should be Fill in the second iteration then jumps to Idle... So they should replace each other ever iteration.

**Actual Behavior:**
State appears to reset to Idle (tag 0) instead of staying Fill (tag 1)

---

## Initial Analysis & Questions

### Root Cause Hypothesis #1: Stack Pointer Management

The line `move sp r0` executes at the **start of every iteration** (right after `label0:`). This could be problematic if:

- `r0` is not correctly updated when a new variant is created
- The stack pointer restoration happens before variant data is read

---

## Questions for User

### 1. Clarification on "line 11 resets to 0"

What exactly resets to 0? Please specify:
in Idle case

```
move r0 sp  # r0 sets to 1 (Fill)
sub r0 r0 1  # r0 subs 1 - 1 so it points to 0
```

so in next iteration when `move sp r0` happens, `sp` is set to 0.

### 2. Stack Behavior Question

In IC10 assembly, when you execute:

```asm
push 2      # Push Fill tag
push r3     # Push Fill payload
move r0 sp  # Get stack pointer
sub r0 r0 2 # Adjust
```

here is what happens:

```
push 2      # r16 == 1
push r3     # r16 == 2
move r0 sp  # r0 == 2
sub r0 r0 2 # r0 == 2
```
