const { compile } = require('../src/compiler/Compiler.res.js');

describe('Variant Types', () => {
  describe('Type Declarations', () => {
    test('should compile simple tag-only variant type', () => {
      const input = `
        type state = Idle | Active | Stopped
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      // Type declarations generate no IC10 code
      expect(result._0).toBe('');
    });

    test('should compile variant type with single argument constructors', () => {
      const input = `
        type result = Ok(int) | Error(int)
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      expect(result._0).toBe('');
    });

    test('should compile mixed variant type', () => {
      const input = `
        type state = Idle | FillSystem(int) | PurgeSystem(int) | Cooling
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      expect(result._0).toBe('');
    });
  });

  describe('Variant Construction', () => {
    test('should compile tag-only constructor assignment', () => {
      const input = `
        type state = Idle | Active
        let currentState = Idle
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      const asm = result._0;
      expect(asm).toContain('push 0'); // Tag for Idle
      expect(asm).toContain('move r'); // Uses temp register
      expect(asm).toContain('sp');
      expect(asm).toContain('sub');
    });

    test('should compile constructor with argument', () => {
      const input = `
        type result = Ok(int) | Error(int)
        let x = Ok(42)
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      const asm = result._0;
      expect(asm).toContain('push 0'); // Tag for Ok
      expect(asm).toContain('push');   // Argument pushed
      expect(asm).toContain('sp');     // Stack pointer used
      expect(asm).toContain('sub');    // Calculate base address
    });

    test('should compile multiple variant values', () => {
      const input = `
        type state = Idle | Active
        let state1 = Idle
        let state2 = Active
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      const asm = result._0;
      expect(asm).toContain('push 0'); // Tag for Idle
      expect(asm).toContain('push 1'); // Tag for Active
    });
  });

  describe('Match Expressions (Basic)', () => {
    test('should compile simple match with tag-only variants', () => {
      const input = `
        type state = Idle | Active
        let currentState = Idle
        let result = match currentState {
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

      // Should have branch instructions
      expect(asm).toContain('move sp');
      expect(asm).toContain('peek');
      expect(asm).toContain('beq');
      expect(asm).toContain('match_case_');
      expect(asm).toContain('match_end_');
    });
  });

  describe('FSM Example', () => {
    test('should compile basic FSM state transition', () => {
      const input = `
        type state = Idle | FillSystem(int) | PurgeSystem(int) | Cooling
        let currentState = Idle
      `;
      const result = compile(input);
      if (result.TAG === 'Error') {
        console.log('FSM compilation error:', result._0);
      }
      expect(result.TAG).toBe('Ok');
    });
  });
});
