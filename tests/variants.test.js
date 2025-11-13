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
        let currentState = ref(Idle)
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      const asm = result._0;
      expect(asm).toContain('push 0'); // Tag for Idle
      expect(asm).toContain('move r0 0'); // Ref points to stack[0]
    });

    test('should compile constructor with argument', () => {
      const input = `
        type result = Ok(int) | Error(int)
        let x = ref(Ok(42))
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      const asm = result._0;
      expect(asm).toContain('push 0'); // Tag for Ok
      expect(asm).toContain('push');   // Argument pushed
      expect(asm).toContain('move r0 0'); // Ref points to stack[0]
    });

    test('should compile multiple variant values', () => {
      const input = `
        type state = Idle | Active
        let state1 = ref(Idle)
        let state2 = ref(Active)
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      const asm = result._0;
      expect(asm).toContain('push 0'); // Tag for Idle
      expect(asm).toContain('push 1'); // Tag for Active
    });
  });

  describe('Switch Expressions (Basic)', () => {
    test('should compile simple switch with tag-only variants', () => {
      const input = `
        type state = Idle | Active
        let currentState = ref(Idle)
        let result = switch currentState.contents {
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

      // Should have branch instructions using fixed stack approach
      expect(asm).toContain('get r15 db 0'); // Read tag from stack[0]
      expect(asm).toContain('beq');
      expect(asm).toContain('match_case_');
      expect(asm).toContain('match_end_');
    });
  });

  describe('FSM Example', () => {
    test('should compile basic FSM state transition', () => {
      const input = `
        type state = Idle | FillSystem(int) | PurgeSystem(int) | Cooling
        let currentState = ref(Idle)
      `;
      const result = compile(input);
      if (result.TAG === 'Error') {
        console.log('FSM compilation error:', result._0);
      }
      expect(result.TAG).toBe('Ok');
    });
  });
});
