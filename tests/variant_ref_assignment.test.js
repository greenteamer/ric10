const Compiler = require('../src/compiler/Compiler.res.js');

describe('Variant Ref Assignment - Poke Instructions', () => {
  test('should use poke to update variant tag and arguments', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Idle(0, 0))
      state := Fill(100, 200)
    `;

    const result = Compiler.compile(source);

    expect(result.TAG).toBe('Ok');
    const assembly = result._0;

    // Check assignment poke instructions
    // Fill is tag=1, args at addresses 3,4
    expect(assembly).toContain('poke 0 1');    // Set tag to Fill
    expect(assembly).toContain('poke 3 100');  // Fill arg0
    expect(assembly).toContain('poke 4 200');  // Fill arg1
  });

  test('should calculate correct addresses for different constructors', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Fill(1, 2))
      state := Idle(10, 20)
    `;

    const result = Compiler.compile(source);

    expect(result.TAG).toBe('Ok');
    const assembly = result._0;

    // Idle is tag 0, maxArgs = 2
    // Idle arg0 address: 0*2+1 = 1
    // Idle arg1 address: 0*2+2 = 2

    expect(assembly).toContain('poke 0 0');   // Set tag to Idle
    expect(assembly).toContain('poke 1 10');  // Idle arg0
    expect(assembly).toContain('poke 2 20');  // Idle arg1
  });

  test('should handle expressions in variant arguments', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Idle(0, 0))
      state := Fill(10 + 5, 20 * 2)
    `;

    const result = Compiler.compile(source);

    expect(result.TAG).toBe('Ok');
    const assembly = result._0;

    // Should evaluate expressions (constant folded to 15 and 40), then poke
    // Fill is tag 1, args at addresses 3,4
    expect(assembly).toContain('poke 0 1');   // Fill tag
    expect(assembly).toContain('poke 3 15');  // Fill arg0 (constant folded)
    expect(assembly).toContain('poke 4 40');  // Fill arg1 (constant folded)
  });

  test('should work with mixed argument counts', () => {
    const source = `
      type state = Idle | Fill(int) | Active(int, int) | Complex(int, int, int)
      let s = ref(Idle)
      s := Active(10, 20)
    `;

    const result = Compiler.compile(source);

    expect(result.TAG).toBe('Ok');
    const assembly = result._0;

    // maxArgs = 3 (from Complex)
    // Active is tag 2
    // Active arg0 address: 2*3+1 = 7
    // Active arg1 address: 2*3+2 = 8

    expect(assembly).toContain('poke 0 2');  // Active tag
    expect(assembly).toContain('poke 7 10');  // Active arg0
    expect(assembly).toContain('poke 8 20');  // Active arg1
  });
});
