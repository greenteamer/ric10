# Changelog: Function Block Ordering Fix

**Date:** 2025-11-13
**Type:** Critical Bug Fix
**Affected:** IR Pipeline (IRGen)

## Summary

Fixed critical bug where function definitions were placed before main code in IC10 output, causing incorrect execution order. Functions are now correctly placed after main code with a safety jump to prevent fall-through.

## Problem

### Original Behavior (Buggy)

When functions were declared in ReScript (required before use), they appeared first in IC10 output:

```ic10
increment:          # Function executes first!
  add r0 r0 1
  j ra              # Jump to undefined ra
label0:             # Main loop
  jal increment
  j label0
```

**Issue:** IC10 executes linearly from top. This caused:
1. Function body executing immediately on program start
2. `j ra` jumping to undefined/zero address
3. Main code executing second (if at all)

### Root Cause

ReScript requires functions to be declared before use:
```rescript
let increment = () => { ... }  // Must come first
while true { increment() }      // Uses function
```

IRGen was directly translating this order to IC10, not accounting for IC10's linear execution model.

## Solution

### New Behavior (Fixed)

Main code executes first, functions placed after:

```ic10
label0:             # Main loop executes first
  jal increment
  j label0
j __end             # Safety: prevent fall-through
__end:
  j __end
increment:          # Function definition after
  add r0 r0 1
  j ra
```

### Implementation

Modified `IRGen.res` to separate function blocks from main code:

1. **Added `functionBlocks` field** to state
   - Tracks function definitions separately from main instructions

2. **Modified `FunctionDeclaration` handler**
   - Creates separate IR block for each function
   - Adds block to `functionBlocks` list instead of main instructions

3. **Updated `generate()` function**
   - Outputs main block first
   - Adds safety jump (`j __end` → infinite loop)
   - Appends function blocks after

### Safety Mechanism

Added `__end` label with infinite loop after main code:
```ic10
j __end
__end:
  j __end
```

This prevents execution from falling through into function definitions if main code completes.

## Changes

### Source Code

**File:** `src/compiler/IR/IRGen.res`

1. Added to state type:
   ```rescript
   functionBlocks: list<IR.block>
   ```

2. Modified `FunctionDeclaration` case in `generateStmt`:
   - Creates temporary state for function body
   - Generates function instructions in isolated context
   - Packages as IR block
   - Adds to `functionBlocks` list

3. Updated `generate()` function:
   - Checks if function blocks exist
   - Adds safety jump mechanism if needed
   - Concatenates blocks: main first, then functions

### Tests

**File:** `tests/functions.test.js`

Updated all test expectations to reflect correct output order:
- Simple function declaration
- Function declaration and call
- Multiple function calls
- Function with multiple statements
- Function in main loop

### Documentation

**Updated Files:**

1. **`docs/architecture/ir-reference.md`**
   - Added `Call` and `Return` instruction documentation
   - Added "Function Block Ordering" section to IRGen
   - Added example showing function compilation
   - Updated "Recent Fixes" section

2. **`docs/user-guide/language-reference.md`**
   - Added complete "Functions" section with examples
   - Updated table of contents
   - Added functions to key features list
   - Changed "Functions - Not supported" to "Function parameters/returns - Limited"

## Impact

### Before Fix
- ❌ Functions executed incorrectly on program start
- ❌ Potential crashes or undefined behavior
- ❌ Main code may not execute at all

### After Fix
- ✅ Main code executes first (correct order)
- ✅ Functions only execute when called
- ✅ Safety jump prevents fall-through
- ✅ All function tests passing (6/6)

## Test Results

**Functions Test Suite:**
```
✓ simple function declaration
✓ function declaration and call
✓ multiple function calls
✓ function with multiple statements
✓ function in main loop
✓ error on undefined function call
```

All 6 tests passing.

## Migration Notes

**No action required for existing code.** This is a compiler fix that automatically applies to all function usage.

**Example Before/After:**

Input (unchanged):
```rescript
let tick = () => {
  %raw("add r0 r0 1")
}

while true {
  tick()
}
```

Old Output (buggy):
```ic10
tick:
add r0 r0 1
j ra
label0:
jal tick
j label0
```

New Output (fixed):
```ic10
label0:
jal tick
j label0
j __end
__end:
j __end
tick:
add r0 r0 1
j ra
```

## Related Documentation

- [IR Reference](architecture/ir-reference.md) - Complete IR instruction set
- [Language Reference](user-guide/language-reference.md) - Functions section
- [IR Design](architecture/ir-design.md) - Original IR architecture

## See Also

- Issue: Function execution order bug
- PR: Function block ordering fix
- Tests: `tests/functions.test.js`
