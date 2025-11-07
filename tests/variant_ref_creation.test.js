const Compiler = require('../src/compiler/Compiler.res.js');

describe('Variant Ref Creation - Fixed Stack Layout', () => {
  test('should pre-allocate all slots for Idle(int, int) | Fill(int, int)', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Idle(10, 20))
    `;

    const result = Compiler.compile(source, { includeComments: false });

    expect(result.TAG).toBe('Ok');
    const assembly = result._0.split('\n');

    // Should have:
    // push 0       # Idle tag (tag=0)
    // move r15 10; push r15  # Idle arg0
    // move r15 20; push r15  # Idle arg1
    // push 0       # Fill arg0 (placeholder)
    // push 0       # Fill arg1 (placeholder)
    // move r0 0    # ref points to stack[0]

    expect(assembly[0]).toBe('push 0');  // Tag
    expect(assembly[1]).toBe('move r15 10');  // Load Idle arg0
    expect(assembly[2]).toBe('push r15');  // Push Idle arg0
    expect(assembly[3]).toBe('move r15 20');  // Load Idle arg1
    expect(assembly[4]).toBe('push r15');  // Push Idle arg1
    expect(assembly[5]).toBe('push 0');  // Fill arg0 placeholder
    expect(assembly[6]).toBe('push 0');  // Fill arg1 placeholder
    expect(assembly[7]).toBe('move r0 0');  // ref = 0
  });

  test('should calculate max args correctly for mixed argument counts', () => {
    const source = `
      type state = Idle | Fill(int) | Active(int, int) | Complex(int, int, int)
      let s = ref(Active(10, 20))
    `;

    const result = Compiler.compile(source, { includeComments: false });

    expect(result.TAG).toBe('Ok');
    const assembly = result._0.split('\n');

    // Max args = 3 (from Complex)
    // 4 constructors * 3 args = 12 slots + 1 tag = 13 total
    // Active is tag 2, so args go in slots: 2*3+1 = 7, 8

    expect(assembly[0]).toBe('push 2');  // Active tag
    // Slots 1-6 (Idle and Fill slots) should be placeholders
    expect(assembly[1]).toBe('push 0');  // Idle slot 0
    expect(assembly[2]).toBe('push 0');  // Idle slot 1
    expect(assembly[3]).toBe('push 0');  // Idle slot 2
    expect(assembly[4]).toBe('push 0');  // Fill slot 0
    expect(assembly[5]).toBe('push 0');  // Fill slot 1
    expect(assembly[6]).toBe('push 0');  // Fill slot 2
    // Slots 7-8 should have Active's values
    expect(assembly[7]).toBe('move r15 10');  // Load Active arg0
    expect(assembly[8]).toBe('push r15');  // Push Active arg0
    expect(assembly[9]).toBe('move r15 20');  // Load Active arg1
    expect(assembly[10]).toBe('push r15');  // Push Active arg1
    // Remaining slots are placeholders
    expect(assembly[11]).toBe('push 0');   // Active slot 2 (unused)
    expect(assembly[12]).toBe('push 0');  // Complex slot 0
    expect(assembly[13]).toBe('push 0');  // Complex slot 1
    expect(assembly[14]).toBe('push 0');  // Complex slot 2
    expect(assembly[15]).toBe('move r0 0');  // ref = 0
  });

  test('should initialize Fill constructor correctly', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Fill(100, 200))
    `;

    const result = Compiler.compile(source, { includeComments: false });

    expect(result.TAG).toBe('Ok');
    const assembly = result._0.split('\n');

    // Fill is tag 1
    expect(assembly[0]).toBe('push 1');  // Fill tag
    expect(assembly[1]).toBe('push 0');  // Idle arg0 placeholder
    expect(assembly[2]).toBe('push 0');  // Idle arg1 placeholder
    expect(assembly[3]).toBe('move r15 100');  // Load Fill arg0
    expect(assembly[4]).toBe('push r15');  // Push Fill arg0
    expect(assembly[5]).toBe('move r15 200');  // Load Fill arg1
    expect(assembly[6]).toBe('push r15');  // Push Fill arg1
    expect(assembly[7]).toBe('move r0 0');  // ref = 0
  });
});
