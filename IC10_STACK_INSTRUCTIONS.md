# IC10 Stack Instructions Reference

## Stack Operations

### clr
**Description:** Clears the stack memory for the provided device.
**Syntax:** `clr d?`

### clrd
**Description:** Seeks directly for the provided device id and clears the stack memory of that device.
**Syntax:** `clrd id(r?|num)`

### get
**Description:** Using the provided device, attempts to read the stack value at the provided address, and places it in the register.
**Syntax:** `get r? device(d?|r?|id) address(r?|num)`

### getd
**Description:** Seeks directly for the provided device id, attempts to read the stack value at the provided address, and places it in the register.
**Syntax:** `getd r? id(r?|id) address(r?|num)`

### peek
**Description:** Register = the value at the top of the stack (at sp).
**Syntax:** `peek r?`
**Note:** Only reads from current stack pointer (sp), no address argument available.

### poke
**Description:** Stores the provided value at the provided address in the stack.
**Syntax:** `poke address(r?|num) value(r?|num)`

### pop
**Description:** Register = the value at the top of the stack and decrements sp.
**Syntax:** `pop r?`

### push
**Description:** Pushes the value of a to the stack at sp and increments sp.
**Syntax:** `push a(r?|num)`

### put
**Description:** Using the provided device, attempts to write the provided value to the stack at the provided address.
**Syntax:** `put device(d?|r?|id) address(r?|num) value(r?|num)`

### putd
**Description:** Seeks directly for the provided device id, attempts to write the provided value to the stack at the provided address.
**Syntax:** `putd id(r?|id) address(r?|num) value(r?|num)`

## Key Insights for Compiler

1. **peek has no address argument** - only reads from sp
2. **To read from arbitrary stack address:** Must use `move sp address` first, then `peek`
3. **poke can write to arbitrary address** without modifying sp
4. **push always writes to sp** and increments sp
5. **Device stack operations** (get/put) can access arbitrary addresses on device stacks
