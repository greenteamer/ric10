const Compiler = require('../src/compiler/Compiler.res.js');

describe('Complete Variant Loop (Fixed Stack)', () => {
  test('should handle complete variant workflow with fixed stack', () => {
    const source = `
      type state = Idle | Fill(int) | Active(int, int)
      let s = ref(Idle)

      switch s.contents {
      | Idle => s := Fill(100)
      | Fill(pressure) => s := Active(pressure, 50)
      | Active(p, t) => s := Idle
      }
    `;

    const result = Compiler.compile(source, { includeComments: false });

    console.log('Result:', result.TAG);
    if (result.TAG === 'Ok') {
      console.log('Assembly:');
      console.log(result._0);
    } else {
      console.log('Error:', result._0);
    }

    expect(result.TAG).toBe('Ok');

    if (result.TAG === 'Ok') {
      const assembly = result._0;

      // Check ref creation with fixed stack (Idle has no args, Fill has 1, Active has 2 => maxArgs = 2)
      // Total slots: 1 + (3 * 2) = 7
      expect(assembly).toContain('push 0');  // Idle tag
      expect(assembly).toContain('push 0');  // 6 placeholder slots
      expect(assembly).toContain('move r0 0'); // ref points to stack[0]

      // Check switch uses get db 0 to read tag
      expect(assembly).toContain('get r15 db 0'); // or another temp register

      // Check case branches
      expect(assembly).toContain('beq');
      expect(assembly).toContain('match_case_');

      // Check poke instructions for assignments
      expect(assembly).toContain('poke 0 1'); // Switch to Fill (tag=1)
      expect(assembly).toContain('poke 3');   // Write Fill's arg at address 3 (1*2+1+0)

      expect(assembly).toContain('poke 0 2'); // Switch to Active (tag=2)
      expect(assembly).toContain('poke 5');   // Write Active's arg0 at address 5 (2*2+1+0)
      expect(assembly).toContain('poke 6');   // Write Active's arg1 at address 6 (2*2+1+1)

      expect(assembly).toContain('poke 0 0'); // Switch back to Idle (tag=0)
    }
  });

  test('should extract pattern bindings using get db', () => {
    const source = `
      type state = Idle | Active(int, int)
      let s = ref(Active(10, 20))

      switch s.contents {
      | Idle => s := Active(0, 0)
      | Active(p, t) => s := Active(30, 40)
      }
    `;

    const result = Compiler.compile(source, { includeComments: false });

    console.log('Result:', result.TAG);
    if (result.TAG === 'Ok') {
      console.log('Assembly:');
      console.log(result._0);
    } else {
      console.log('Error:', result._0);
    }

    expect(result.TAG).toBe('Ok');

    if (result.TAG === 'Ok') {
      const assembly = result._0;

      // Check ref creation (Active has 2 args, Idle has 0 => maxArgs = 2)
      // Total slots: 1 + (2 * 2) = 5
      expect(assembly).toContain('push 1');  // Active tag
      expect(assembly).toContain('move r15 10'); // Load 10 into temp
      expect(assembly).toContain('push r15'); // Push arg0
      expect(assembly).toContain('move r15 20'); // Load 20 into temp
      expect(assembly).toContain('push 0');  // 2 placeholder slots for Idle

      // Check pattern binding extraction using get db
      // Active is tag=1, maxArgs=2, so args at addresses: 1*2+1+0=3 and 1*2+1+1=4
      expect(assembly).toContain('get r1 db 3'); // extract p
      expect(assembly).toContain('get r2 db 4'); // extract t
    }
  });

  test('should handle zero-arg constructors in switch', () => {
    const source = `
      type state = Idle | Fill(int)
      let s = ref(Fill(10))

      switch s.contents {
      | Idle => s := Fill(20)
      | Fill(p) => s := Idle
      }
    `;

    const result = Compiler.compile(source, { includeComments: false });

    console.log('Result:', result.TAG);
    if (result.TAG === 'Ok') {
      console.log('Assembly:');
      console.log(result._0);
    } else {
      console.log('Error:', result._0);
    }

    expect(result.TAG).toBe('Ok');

    if (result.TAG === 'Ok') {
      const assembly = result._0;

      // Check ref creation (Fill has 1 arg, Idle has 0 => maxArgs = 1)
      // Total slots: 1 + (2 * 1) = 3
      expect(assembly).toContain('push 1');  // Fill tag
      expect(assembly).toContain('move r15 10'); // Load 10 into temp
      expect(assembly).toContain('push r15'); // Push Fill arg
      expect(assembly).toContain('push 0');  // Idle placeholder

      // Check switch uses get db 0
      expect(assembly).toContain('get r15 db 0');

      // Check Idle case has no pattern extraction (zero args)
      // Check Fill case extracts binding at address: 1*1+1+0=2
      expect(assembly).toContain('get r1 db 2'); // extract p

      // Check assignment to Idle (zero args, just update tag)
      expect(assembly).toContain('poke 0 0'); // Set tag to Idle
    }
  });
});
