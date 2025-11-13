const Compiler = require('../src/compiler/Compiler.res.js');

describe('Variant Ref Assignment - Poke Instructions', () => {
  test('should use poke to update variant tag and arguments', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Idle(0, 0))
      state := Fill(100, 200)
    `;

    const result = Compiler.compile(source, { includeComments: false });

    expect(result.TAG).toBe('Ok');
    const assembly = result._0.split('\n');

    // Find the poke instructions (after the initial ref creation)
    // Should have:
    // poke 0 1         # Set tag to Fill (tag=1)
    // poke 3 <reg>     # Fill arg0 at address: 1*2+1 = 3
    // poke 4 <reg>     # Fill arg1 at address: 1*2+2 = 4

    const pokeInstructions = assembly.filter(line => line.startsWith('poke'));

    expect(pokeInstructions.length).toBeGreaterThanOrEqual(3);
    expect(pokeInstructions[0]).toBe('poke 0 1');  // Tag
    expect(pokeInstructions[1]).toMatch(/poke 3 r\d+/);  // Fill arg0
    expect(pokeInstructions[2]).toMatch(/poke 4 r\d+/);  // Fill arg1
  });

  test('should calculate correct addresses for different constructors', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Fill(1, 2))
      state := Idle(10, 20)
    `;

    const result = Compiler.compile(source, { includeComments: false });

    expect(result.TAG).toBe('Ok');
    const assembly = result._0.split('\n');

    const pokeInstructions = assembly.filter(line => line.startsWith('poke'));

    // Idle is tag 0, maxArgs = 2
    // Idle arg0 address: 0*2+1 = 1
    // Idle arg1 address: 0*2+2 = 2

    expect(pokeInstructions.length).toBeGreaterThanOrEqual(3);
    expect(pokeInstructions[0]).toBe('poke 0 0');  // Tag = Idle
    expect(pokeInstructions[1]).toMatch(/poke 1 r\d+/);  // Idle arg0
    expect(pokeInstructions[2]).toMatch(/poke 2 r\d+/);  // Idle arg1
  });

  test('should handle expressions in variant arguments', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Idle(0, 0))
      state := Fill(10 + 5, 20 * 2)
    `;

    const result = Compiler.compile(source, { includeComments: false });

    expect(result.TAG).toBe('Ok');
    const assembly = result._0.split('\n');

    const pokeInstructions = assembly.filter(line => line.startsWith('poke'));

    // Should evaluate expressions into temp registers, then poke
    expect(pokeInstructions.length).toBeGreaterThanOrEqual(3);
    expect(pokeInstructions[0]).toBe('poke 0 1');  // Fill tag
    expect(pokeInstructions[1]).toMatch(/poke 3 r\d+/);  // Fill arg0 (15)
    expect(pokeInstructions[2]).toMatch(/poke 4 r\d+/);  // Fill arg1 (40)
  });

  test('should work with mixed argument counts', () => {
    const source = `
      type state = Idle | Fill(int) | Active(int, int) | Complex(int, int, int)
      let s = ref(Idle)
      s := Active(10, 20)
    `;

    const result = Compiler.compile(source, { includeComments: false });

    expect(result.TAG).toBe('Ok');
    const assembly = result._0.split('\n');

    const pokeInstructions = assembly.filter(line => line.startsWith('poke'));

    // maxArgs = 3 (from Complex)
    // Active is tag 2
    // Active arg0 address: 2*3+1 = 7
    // Active arg1 address: 2*3+2 = 8

    expect(pokeInstructions.length).toBeGreaterThanOrEqual(3);
    expect(pokeInstructions[0]).toBe('poke 0 2');  // Active tag
    expect(pokeInstructions[1]).toMatch(/poke 7 r\d+/);  // Active arg0
    expect(pokeInstructions[2]).toMatch(/poke 8 r\d+/);  // Active arg1
  });
});
