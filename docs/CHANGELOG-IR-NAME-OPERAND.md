# Changelog: IR Name Operand Support

**Date:** 2025-11-12
**Type:** Bug Fix / Feature Completion
**Impact:** IR architecture migration - unblocked

## Summary

Fixed pattern matching warnings for the `Name` operand variant across all IR modules, enabling proper constant reference support throughout the IR pipeline.

## Problem

The `Name(string)` operand variant was added to `IR.res` to support constant references (e.g., `define` statements), but three IR processing modules were missing pattern match cases, causing compilation warnings:

```
Warning number 8: You forgot to handle a possible case here, for example: | Name(_)
```

**Affected Files:**
- `src/compiler/IR/IRPrint.res` - Missing `Name(_)` case in `printOperand`
- `src/compiler/IR/IRToIC10.res` - Missing `Name(_)` case in `convertOperand`
- `src/compiler/IR/IROptimizer.res` - Missing `Name(_)` cases in `findUsedVRegs` and `substituteOperand`

## Changes Made

### 1. IRPrint.res
**Location:** `printOperand` function (line 9-14)

**Before:**
```rescript
let printOperand = (operand: IR.operand): string => {
  switch operand {
  | VReg(vreg) => printVReg(vreg)
  | Num(n) => Int.toString(n)
  }
}
```

**After:**
```rescript
let printOperand = (operand: IR.operand): string => {
  switch operand {
  | VReg(vreg) => printVReg(vreg)
  | Num(n) => Int.toString(n)
  | Name(name) => name
  }
}
```

**Effect:** IR pretty-printer now correctly formats named constants

### 2. IRToIC10.res
**Location:** `convertOperand` function (line 40-48)

**Before:**
```rescript
let convertOperand = (state: state, operand: IR.operand): result<(state, string), string> => {
  switch operand {
  | VReg(vreg) =>
    allocatePhysicalReg(state, vreg)->Result.map(((state, physicalReg)) => {
      (state, `r${Int.toString(physicalReg)}`)
    })
  | Num(n) => Ok((state, Int.toString(n)))
  }
}
```

**After:**
```rescript
let convertOperand = (state: state, operand: IR.operand): result<(state, string), string> => {
  switch operand {
  | VReg(vreg) =>
    allocatePhysicalReg(state, vreg)->Result.map(((state, physicalReg)) => {
      (state, `r${Int.toString(physicalReg)}`)
    })
  | Num(n) => Ok((state, Int.toString(n)))
  | Name(name) => Ok((state, name))
  }
}
```

**Effect:** IC10 code generator now correctly passes through named constants

### 3. IROptimizer.res
**Location:** Multiple functions

#### 3a. `findUsedVRegs` function (line 8-48)
Added `Name(_)` cases for all instruction types:
- `Move(_, Name(_))` → used
- `Binary(_, _, Name(_), ...)` → used (multiple patterns)
- `Compare(_, _, Name(_), ...)` → used (multiple patterns)
- `Bnez(Name(_), _)` → used
- `DeviceStore(_, _, Name(_))` → used
- `Unary(_, _, Name(_))` → used

**Effect:** Dead code elimination correctly ignores named constants (they don't use registers)

#### 3b. `substituteOperand` function (line 63-73)
**Before:**
```rescript
let substituteOperand = (op: IR.operand, copies: copyMap): IR.operand => {
  switch op {
  | VReg(vreg) =>
    switch copies->Belt.Map.Int.get(vreg) {
    | Some(replacement) => replacement
    | None => op
    }
  | Num(_) => op
  }
}
```

**After:**
```rescript
let substituteOperand = (op: IR.operand, copies: copyMap): IR.operand => {
  switch op {
  | VReg(vreg) =>
    switch copies->Belt.Map.Int.get(vreg) {
    | Some(replacement) => replacement
    | None => op
    }
  | Num(_) => op
  | Name(_) => op
  }
}
```

**Effect:** Constant propagation correctly handles named constants (no substitution needed)

## Impact

### Build Status
- ✅ **Before:** 3 pattern matching warnings
- ✅ **After:** 0 pattern matching warnings
- ✅ **Build:** Completes successfully in ~110ms

### Test Status
- Test failures are expected during migration (constant optimization differences)
- No new test failures introduced by this change
- IR pipeline now has complete operand type coverage

### Functionality Enabled
1. **Constant References:** Named constants can now be used throughout the IR
2. **Define Statements:** `define maxTemp 1000` generates `Name("maxTemp")` operands
3. **Hash Constants:** `define furnaceType HASH("...")` references work correctly
4. **Optimization Safety:** All IR optimizations now correctly handle named constants

## Documentation Updates

### New Documentation
- **Created:** `docs/architecture/ir-reference.md` - Complete IR reference with types, instructions, and examples

### Updated Documentation
- **Updated:** `docs/architecture/ir-design.md` - Added `Name` operand to convertOperand section
- **Updated:** `docs/architecture/ir-migration-report.md` - Added section on Name operand fixes
- **Updated:** `docs/README.md` - Added IR reference and migration report links
- **Updated:** `CLAUDE.md` - Added IR architecture overview and documentation links

## Example Usage

### Constant Reference in IR
```rescript
// ReScript
let furnaceType = hash("StructureAdvancedFurnace")
let temp = lb(furnaceType, "Temperature", "Maximum")
```

**IR Generated:**
```
DefInt("furnaceType", HASH("..."))
DeviceLoad(v0, DeviceType(Name("furnaceType")), "Temperature", Some("Maximum"))
```

**IC10 Output:**
```
define furnaceType HASH("StructureAdvancedFurnace")
lb r0 furnaceType Temperature Maximum
```

## Next Steps

The main blocker for IR migration has been resolved. Remaining work:

1. **Constant Optimization** - Emit `define` for simple constants instead of `move`
2. **Test Updates** - Accept different but equivalent register allocation
3. **Migration Completion** - Switch to IR as default pipeline

## Related Issues

- Main blocker for IR architecture migration
- Enables full constant support in IR pipeline
- Required for feature parity with legacy codegen

## References

- IR Type Definition: `src/compiler/IR/IR.res:3-6`
- IR Reference Guide: `docs/architecture/ir-reference.md`
- Migration Report: `docs/architecture/ir-migration-report.md`
