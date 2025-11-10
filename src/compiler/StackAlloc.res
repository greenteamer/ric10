// Stack Allocator for IC10 compiler
// Manages allocation of variant values on the IC10 stack (512 slots)
// Variants are stored as [tag, ?argument] and variables hold register pointing to stack base

// Stack allocator state
type stackAllocator = {
  currentStackPointer: int, // Tracks logical position in stack (0-511)
  variantMap: Belt.Map.String.t<int>, // Maps variable name → stack base address
}

// Create a new stack allocator
let create = (): stackAllocator => {
  {
    currentStackPointer: 0,
    variantMap: Belt.Map.String.empty,
  }
}

// Allocate stack space for a variant
// Returns (new allocator, stack base address)
// hasArgument: true if variant has a payload (uses 2 slots), false if tag-only (1 slot)
let allocateVariant = (allocator: stackAllocator, variableName: string, hasArgument: bool): (stackAllocator, int) => {
  let slotsNeeded = if hasArgument { 2 } else { 1 }
  let baseAddress = allocator.currentStackPointer

  let newAllocator = {
    currentStackPointer: allocator.currentStackPointer + slotsNeeded,
    variantMap: Belt.Map.String.set(allocator.variantMap, variableName, baseAddress),
  }

  (newAllocator, baseAddress)
}

// Get stack base address for a variant variable
let getVariantAddress = (allocator: stackAllocator, variableName: string): option<int> => {
  Belt.Map.String.get(allocator.variantMap, variableName)
}

// Free stack space for a variant (when variable goes out of scope)
// Note: In our simple compiler, we don't actually compact the stack
// We just remove the variable from the map
// This could be extended for more sophisticated stack management
let freeVariant = (allocator: stackAllocator, variableName: string): stackAllocator => {
  {
    ...allocator,
    variantMap: Belt.Map.String.remove(allocator.variantMap, variableName),
  }
}

// Get current stack pointer position
let getCurrentStackPointer = (allocator: stackAllocator): int => {
  allocator.currentStackPointer
}

// Check if we have room for more variants
let hasSpace = (allocator: stackAllocator, slotsNeeded: int): bool => {
  allocator.currentStackPointer + slotsNeeded <= 512
}

// Get all active variant variables (for debugging)
let getActiveVariants = (allocator: stackAllocator): array<string> => {
  Belt.Map.String.keysToArray(allocator.variantMap)
}
