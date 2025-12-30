const Compiler = require('../src/compiler/Compiler.res.js');

describe('Variant Ref Creation - Fixed Stack Layout', () => {
  test('should pre-allocate all slots for Idle(int, int) | Fill(int, int)', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Idle(10, 20))
    `;

    const result = Compiler.compile(source);

    expect(result.TAG).toBe('Ok');
    const assembly = result._0;

    // Fixed stack layout:
    // Total slots: 1 tag + (2 constructors * 2 maxArgs) = 5
    // Idle tag=0, args at slots 1,2
    // Fill tag=1, args at slots 3,4

    expect(assembly).toContain('move sp 5');  // Allocate 5 stack slots
    expect(assembly).toContain('poke 0 0');   // Idle tag
    expect(assembly).toContain('poke 1 10');  // Idle arg0
    expect(assembly).toContain('poke 2 20');  // Idle arg1
  });

  test('should calculate max args correctly for mixed argument counts', () => {
    const source = `
      type state = Idle | Fill(int) | Active(int, int) | Complex(int, int, int)
      let s = ref(Active(10, 20))
    `;

    const result = Compiler.compile(source);

    expect(result.TAG).toBe('Ok');
    const assembly = result._0;

    // Max args = 3 (from Complex)
    // 4 constructors * 3 args = 12 slots + 1 tag = 13 total
    // Active is tag 2, so args go in slots: 2*3+1+0 = 7, 2*3+1+1 = 8

    expect(assembly).toContain('move sp 13');  // Allocate 13 stack slots
    expect(assembly).toContain('poke 0 2');    // Active tag (tag=2)
    expect(assembly).toContain('poke 7 10');   // Active arg0 at address 7
    expect(assembly).toContain('poke 8 20');   // Active arg1 at address 8
  });

  test('should initialize Fill constructor correctly', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Fill(100, 200))
    `;

    const result = Compiler.compile(source);

    expect(result.TAG).toBe('Ok');
    const assembly = result._0;

    // Fill is tag 1, args at slots 3,4 (tag=1, maxArgs=2, so 1*2+1+0=3, 1*2+1+1=4)
    expect(assembly).toContain('move sp 5');   // Allocate 5 stack slots
    expect(assembly).toContain('poke 0 1');    // Fill tag
    expect(assembly).toContain('poke 3 100');  // Fill arg0 at address 3
    expect(assembly).toContain('poke 4 200');  // Fill arg1 at address 4
  });
});
