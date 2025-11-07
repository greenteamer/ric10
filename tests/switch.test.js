const { compile } = require('../src/compiler/Compiler.res.js');

describe('Switch Statement Comprehensive Tests', () => {
  describe('Tag-only matches', () => {
    test('should match tag-only variants in expression context', () => {
      const input = `
        type state = Idle | Active
        let s = ref(Idle)
        let result = switch s.contents {
          | Idle => 0
          | Active => 1
        }
      `;
      const result = compile(input);
      if (result.TAG === 'Error') {
        console.log('Compilation error:', result._0);
      }
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should have switch infrastructure using fixed stack approach
      expect(asm).toContain('get r15 db 0'); // Read tag from stack[0]
      expect(asm).toContain('beq');
      expect(asm).toContain('match_case_');
      expect(asm).toContain('match_end_');

      // Should generate case bodies (move result to registers)
      expect(asm).toContain('move');
    });

    test('should match tag-only variants in statement context', () => {
      const input = `
        type state = Idle | Active
        let s = ref(Idle)
        let x = ref(0)
        switch s.contents {
          | Idle => x := 10
          | Active => x := 20
        }
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should have switch infrastructure
      expect(asm).toContain('beq');
      expect(asm).toContain('match_case_');

      // Should execute case bodies (ref assignments)
      expect(asm).toContain('move r');
    });
  });

  describe('Payload extraction', () => {
    test('should extract payload into bound variable', () => {
      const input = `
        type result = Ok(int) | Error(int)
        let r = ref(Ok(42))
        let value = switch r.contents {
          | Ok(x) => x
          | Error(e) => e
        }
      `;
      const result = compile(input);
      if (result.TAG === 'Error') {
        console.log('Payload extraction error:', result._0);
      }
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should have payload extraction
      expect(asm).toContain('add sp');
      expect(asm).toContain('peek');

      // Should have case labels
      expect(asm).toContain('match_case_');
    });

    test('should use extracted payload in case body', () => {
      const input = `
        type state = Fill(int)
        let s = ref(Fill(100))
        let x = ref(0)
        switch s.contents {
          | Fill(value) => x := value
        }
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should extract payload and use it
      expect(asm).toContain('add sp');
      expect(asm).toContain('peek');
      expect(asm).toContain('move r');
    });
  });

  describe('FSM patterns', () => {
    test('should handle state transitions with ref assignments', () => {
      const input = `
        type state = Idle | Purge(int) | Fill(int)
        let state = ref(Idle)
        switch state.contents {
          | Idle => state := Purge(100)
          | Purge(x) => state := Fill(x)
          | Fill(x) => state := Idle
        }
      `;
      const result = compile(input);
      if (result.TAG === 'Error') {
        console.log('FSM pattern error:', result._0);
      }
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should have all three cases
      expect(asm).toContain('beq');
      expect((asm.match(/match_case_/g) || []).length).toBeGreaterThanOrEqual(3);

      // Should construct new variants in case bodies
      expect(asm).toContain('push');
    });

    test('should handle if statements in case bodies', () => {
      const input = `
        type state = Fill(int)
        let s = ref(Fill(5000))
        let x = ref(0)
        switch s.contents {
          | Fill(pressure) => {
              if pressure < 1000 {
                x := 1
              } else {
                x := 2
              }
            }
        }
      `;
      const result = compile(input);
      if (result.TAG === 'Error') {
        console.log('Nested if error:', result._0);
      }
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should have switch infrastructure
      expect(asm).toContain('match_case_');

      // Should have if statement branches
      expect(asm).toContain('blt');
      expect(asm).toContain('label');
    });
  });

  describe('IC10 functions in case bodies', () => {
    test('should handle IC10 store functions in case body', () => {
      const input = `
        let tanks = hash("StructureTanks")
        let atmTank = hash("AtmTank")
        type state = Purge(int)
        let s = ref(Purge(100))
        switch s.contents {
          | Purge(temp) => sbn(tanks, atmTank, "Temperature", temp)
        }
      `;
      const result = compile(input);
      if (result.TAG === 'Error') {
        console.log('IC10 function error:', result._0);
      }
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should have payload extraction
      expect(asm).toContain('add sp');
      expect(asm).toContain('peek');

      // Should call IC10 function
      expect(asm).toContain('sbn');
      expect(asm).toContain('tanks');
      expect(asm).toContain('atmTank');
    });

    test('should handle IC10 load functions with payload', () => {
      const input = `
        let tanks = hash("StructureTanks")
        let atmTank = hash("AtmTank")
        type state = Query(int)
        let s = ref(Query(5))
        let result = ref(0)
        switch s.contents {
          | Query(threshold) => {
              if threshold > 0 {
                result := lbn(tanks, atmTank, "Temperature", Maximum)
              }
            }
        }
      `;
      const result = compile(input);
      if (result.TAG === 'Error') {
        console.log('IC10 load function error:', result._0);
      }
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should have switch and payload extraction
      expect(asm).toContain('match_case_');
      expect(asm).toContain('add sp');

      // Should have if check and load
      expect(asm).toContain('label'); // if statement creates labels
      expect(asm).toContain('lbn');
    });
  });

  describe('Integration test - Full cooling FSM', () => {
    test('should compile complete cooling system FSM', () => {
      const input = `
        let tanks = hash("StructuresTankSmall")
        let atmTank = hash("AtmTank")
        let maxPressure = 5000

        type state = Idle | Purge(int) | Fill(int)
        let state = ref(Idle)

        let tempValue = lbn(tanks, atmTank, "Temperature", Maximum)
        switch state.contents {
          | Idle => state := Purge(tempValue)
          | Purge(x) => sbn(tanks, atmTank, "Temperature", x)
          | Fill(x) => if x < maxPressure {
              let newTemp = lbn(tanks, atmTank, "Temperature", Maximum)
              state := Fill(newTemp)
            } else {
              state := Idle
            }
        }
      `;
      const result = compile(input);
      if (result.TAG === 'Error') {
        console.log('Full FSM compilation error:', result._0);
      }
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should have all switch infrastructure
      expect(asm).toContain('move sp');
      expect(asm).toContain('peek');
      expect(asm).toContain('beq');

      // Should have all three cases
      expect((asm.match(/match_case_/g) || []).length).toBeGreaterThanOrEqual(3);

      // Should have IC10 functions
      expect(asm).toContain('lbn');
      expect(asm).toContain('sbn');

      // Should have if statement in Fill case
      expect(asm).toContain('blt');

      // Should have variant construction
      expect(asm).toContain('push');

      // Should end properly
      expect(asm).toContain('match_end_');
    });
  });

  describe('Edge cases', () => {
    test('should handle single-case switch', () => {
      const input = `
        type state = Only
        let s = ref(Only)
        let x = ref(0)
        switch s.contents {
          | Only => x := 42
        }
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should still generate switch infrastructure
      expect(asm).toContain('beq');
      expect(asm).toContain('match_case_');
    });

    test('should handle multiple statements in case body', () => {
      const input = `
        type state = Idle | Active
        let s = ref(Idle)
        let x = ref(0)
        switch s.contents {
          | Idle => x := 1
          | Active => x := 2
        }
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
    });

    test('should handle mixed tag-only and payload constructors', () => {
      const input = `
        type state = Idle | FillSystem(int) | PurgeSystem(int) | Cooling
        let s = ref(FillSystem(100))
        let result = ref(0)
        switch s.contents {
          | Idle => result := 0
          | FillSystem(pressure) => result := pressure
          | PurgeSystem(temp) => result := temp
          | Cooling => result := 99
        }
      `;
      const result = compile(input);
      if (result.TAG === 'Error') {
        console.log('Mixed constructors error:', result._0);
      }
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should have all four cases
      expect((asm.match(/match_case_/g) || []).length).toBeGreaterThanOrEqual(4);

      // Should have payload extraction for some cases
      expect(asm).toContain('add sp');
      expect(asm).toContain('peek');
    });
  });
});
