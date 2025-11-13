# Device I/O Operations - IR Design

**Status**: Design Proposal
**Target**: Multi-backend IR support
**Related**: [IR Design](ir-design.md), [IC10 Support](../user-guide/ic10-support.md)

---

## Overview

This document describes the refactoring of device I/O operations in the IR to support multiple compilation backends (IC10, RISC, etc.) by removing platform-specific types and operations.

## Motivation

### Current Problem

The IR currently contains IC10-specific types that couple it tightly to the IC10 platform:

```rescript
// IC10-specific enums in IR
type bulkOption = Maximum | Minimum | Average | Sum
type deviceParam = Setting | Temperature | Pressure | On | Open | Mode | Lock

type instr =
  | Load(vreg, device, deviceParam, option<bulkOption>)
  | Save(device, deviceParam, operand)
```

**Issues:**
1. IR knows about IC10-specific properties (Temperature, Pressure, etc.)
2. IR knows about IC10 bulk operations (Maximum, Average, etc.)
3. Cannot support other backends without IC10-specific knowledge
4. Violates separation of concerns (IR should be platform-agnostic)

### Goals

1. **Multi-backend support**: Enable RISC and other target platforms
2. **Platform abstraction**: IR should not know IC10-specific details
3. **Backend flexibility**: Each backend decides how to implement device operations
4. **Maintain expressiveness**: Support all IC10 device operation variants

---

## Design

### Abstract IR Types

```rescript
// Platform-agnostic device addressing
type device =
  | DevicePin(string)                 // Device reference ("d0", "d1", "db", etc.)
  | DeviceReg(vreg)                   // Device address stored in register
  | DeviceType(string)                // Access by type hash
  | DeviceNamed(string, string)       // Access by type hash + name hash

// Platform-agnostic device operations
type instr =
  | DeviceLoad(vreg, device, string, option<string>)    // dest, device, property, bulk_option?
  | DeviceStore(device, string, operand)                // device, property, value
  | DefHash(string, string)                             // name, hash_input (for hash constants)
```

### Key Design Decisions

1. **Properties as strings**: `"Temperature"`, `"Setting"`, etc. are passed as generic strings
2. **Bulk options as strings**: `"Maximum"`, `"Average"`, etc. are optional string parameters
3. **Hash constants**: Type/name hashes are referenced by variable names
4. **Load-only bulk**: Only load operations support bulk options (aggregation operations)
5. **Store simplicity**: Store operations don't need bulk (single-target writes)

---

## IC10 Backend Mapping

### Instruction Selection

IRToIC10 decides which IC10 instruction to emit based on device type and bulk option:

| Device Type | Bulk Option | IC10 Instruction | Example |
|-------------|-------------|------------------|---------|
| `DevicePin` | `None` | `l` / `s` | `l r0 d0 Temperature` |
| `DeviceReg` | `None` | `l` / `s` | `l r0 r1 Temperature` |
| `DeviceType` | `Some(_)` | `lb` | `lb r0 typeHash Temperature Maximum` |
| `DeviceType` | `None` | `sb` | `sb typeHash Setting 100` |
| `DeviceNamed` | `Some(_)` | `lbn` | `lbn r0 typeHash nameHash Temperature Maximum` |
| `DeviceNamed` | `None` | `sbn` | `sbn typeHash nameHash Setting 100` |

### Translation Examples

#### Example 1: Simple Device Pin

**ReScript:**
```rescript
let sensor = device("d0")
let temp = l(sensor, "Temperature")
```

**IR:**
```rescript
DeviceLoad(vreg0, DevicePin("d0"), "Temperature", None)
```

**IC10:**
```
l r0 d0 Temperature
```

---

#### Example 2: Store to Device

**ReScript:**
```rescript
let controller = device("d0")
s(controller, "Setting", 100)
```

**IR:**
```rescript
DeviceStore(DevicePin("d0"), "Setting", Num(100))
```

**IC10:**
```
s d0 Setting 100
```

---

#### Example 3: Batch Load with Type Hash

**ReScript:**
```rescript
let typeHash = hash("StructureTank")
let maxTemp = lb(typeHash, "Temperature", "Maximum")
```

**IR:**
```rescript
DefHash("typeHash", "StructureTank")
DeviceLoad(vreg0, DeviceType("typeHash"), "Temperature", Some("Maximum"))
```

**IC10:**
```
define typeHash HASH("StructureTank")
lb r0 typeHash Temperature Maximum
```

---

#### Example 4: Batch Store by Type

**ReScript:**
```rescript
let typeHash = hash("StructureTank")
sb(typeHash, "Setting", 100)
```

**IR:**
```rescript
DefHash("typeHash", "StructureTank")
DeviceStore(DeviceType("typeHash"), "Setting", Num(100))
```

**IC10:**
```
define typeHash HASH("StructureTank")
sb typeHash Setting 100
```

---

#### Example 5: Named Device Load

**ReScript:**
```rescript
let typeHash = hash("StructureTank")
let nameHash = hash("MyTank")
let temp = lbn(typeHash, nameHash, "Temperature", "Maximum")
```

**IR:**
```rescript
DefHash("typeHash", "StructureTank")
DefHash("nameHash", "MyTank")
DeviceLoad(vreg0, DeviceNamed("typeHash", "nameHash"), "Temperature", Some("Maximum"))
```

**IC10:**
```
define typeHash HASH("StructureTank")
define nameHash HASH("MyTank")
lbn r0 typeHash nameHash Temperature Maximum
```

---

#### Example 6: Named Device Store

**ReScript:**
```rescript
let typeHash = hash("StructureTank")
let nameHash = hash("MainTank")
sbn(typeHash, nameHash, "Setting", 100)
```

**IR:**
```rescript
DefHash("typeHash", "StructureTank")
DefHash("nameHash", "MainTank")
DeviceStore(DeviceNamed("typeHash", "nameHash"), "Setting", Num(100))
```

**IC10:**
```
define typeHash HASH("StructureTank")
define nameHash HASH("MainTank")
sbn typeHash nameHash Setting 100
```

---

## RISC Backend (Future)

A RISC backend would map these operations to its own I/O instructions:

```rescript
// Hypothetical RISC mapping
DeviceLoad(vreg, device, property, bulk) =>
  match device {
  | DevicePin(n) => emit_risc_io_read(vreg, n, property)
  | DeviceType(hash) => emit_risc_batch_read(vreg, hash, property, bulk)
  ...
  }
```

The key benefit: **IRGen doesn't change** - only the backend changes.

---

## Implementation Plan

### Phase 1: Update IR Types

1. Modify `IR.res`:
   - Change `DeviceLoad` signature to use strings
   - Change `DeviceStore` signature to use strings
   - Remove `bulkOption` and `deviceParam` types
   - Add `DeviceType` and `DeviceNamed` to `device` type

### Phase 2: Update IRGen

1. Modify `IRGen.res`:
   - Parse `l()`, `s()` calls → emit `DeviceLoad`/`DeviceStore` with strings
   - Parse `lb()`, `sb()` calls → emit with `DeviceType`
   - Parse `lbn()`, `sbn()` calls → emit with `DeviceNamed`
   - Handle `hash()` function → emit `DefHash` and track constant names
   - Move property string validation out (or keep as string passthrough)

### Phase 3: Update IRToIC10

1. Modify `IRToIC10.res`:
   - Implement device type → instruction selection logic
   - Convert property strings to IC10 format
   - Convert bulk option strings to IC10 format
   - Handle all 6 IC10 device instruction variants

### Phase 4: Update IRPrint and IROptimizer

1. Update `IRPrint.res` for new instruction format
2. Update `IROptimizer.res` if needed (likely minimal changes)

### Phase 5: Testing

1. Add tests for all device operation variants
2. Test hash constant handling
3. Verify IC10 output correctness
4. Update existing tests if needed

---

## Migration Notes

### Breaking Changes

- `IR.bulkOption` and `IR.deviceParam` types removed
- `IR.Load` and `IR.Save` signatures changed to `IR.DeviceLoad` and `IR.DeviceStore`
- Property and bulk option parameters changed from enums to strings

### Backward Compatibility

None - this is a breaking change to the IR layer. All IR-generating and IR-consuming code must be updated together.

### Code Locations

Files to modify:
- `src/compiler/IR/IR.res` - Type definitions
- `src/compiler/IR/IRGen.res` - IR generation
- `src/compiler/IR/IRToIC10.res` - IC10 backend
- `src/compiler/IR/IRPrint.res` - IR debugging output
- `src/compiler/IR/IROptimizer.res` - IR optimizations (if affected)

---

## Open Questions

1. **Property validation**: Should IRGen validate property names, or let backend handle it?
   - **Proposal**: Keep as strings, let backend validate (more flexible for new backends)

2. **Hash constant substitution**: When does `typeHash` → `HASH("...")` happen?
   - **Answer**: IC10 assembler does it at runtime, we just emit `define` directives

3. **Device register allocation**: How are device-storing registers managed?
   - **Current**: Treated as regular vregs, allocated by register allocator

4. **Error messages**: Where should invalid property/bulk errors be reported?
   - **Proposal**: In backend (IRToIC10), not in IRGen, for platform flexibility

---

## Alternatives Considered

### Alternative 1: Keep IC10-Specific IR

**Pros**: No refactoring needed, works for current IC10 target
**Cons**: Cannot support other backends, violates IR abstraction principle
**Decision**: Rejected - goal is multi-backend support

### Alternative 2: Two-Tier IR (High-Level + Low-Level)

**Pros**: Maximum abstraction, clear separation
**Cons**: More complex, extra translation layer, may be over-engineered
**Decision**: Rejected - single abstract IR is sufficient

### Alternative 3: Generic External I/O Operations

**Pros**: Maximum abstraction (just "read" and "write")
**Cons**: Loses device operation structure, harder to optimize
**Decision**: Rejected - device-specific operations are core to the domain

---

## Summary

This refactoring makes the IR platform-agnostic by:
1. Removing IC10-specific types (`bulkOption`, `deviceParam`)
2. Using generic strings for properties and bulk options
3. Supporting multiple device addressing modes
4. Moving IC10-specific knowledge to the backend

This enables future support for RISC and other target platforms while maintaining full IC10 functionality.

---

**Next Steps**: Implement Phase 1 (Update IR Types) and proceed through implementation plan.
