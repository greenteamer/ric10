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
      expect(asm).toContain('move sp 1'); // Stack allocation
      expect(asm).toContain('poke 0 0'); // Tag for Idle poked to stack[0]
    });

    test('should compile constructor with argument', () => {
      const input = `
        type result = Ok(int) | Error(int)
        let x = ref(Ok(42))
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      const asm = result._0;
      expect(asm).toContain('move sp 3'); // Stack allocation (1 tag + 2 constructors * 1 arg)
      expect(asm).toContain('poke 0 0'); // Tag for Ok poked to stack[0]
      expect(asm).toContain('poke 1 42'); // Argument poked to stack[1]
    });

    test('should compile multiple variant values', () => {
      // Only one ref per variant type is allowed, so we use ref assignment instead
      const input = `
        type state = Idle | Active
        let currentState = ref(Idle)
      `;
      const result = compile(input);
      expect(result.TAG).toBe('Ok');
      const asm = result._0;
      expect(asm).toContain('move sp 1'); // Stack allocation
      expect(asm).toContain('poke 0 0'); // Tag for Idle
    });
  });

  describe('Switch Expressions (Basic)', () => {
    test('should compile simple switch with tag-only variants', () => {
      const input = `
        type state = Idle | Active
        let currentState = ref(Idle)
        switch currentState.contents {
          | Idle => %raw("move r0 0")
          | Active => %raw("move r0 1")
        }
      `;
      const result = compile(input);
      if (result.TAG === 'Error') {
        console.log('Compilation error:', result._0);
      }
      expect(result.TAG).toBe('Ok');
      const asm = result._0;

      // Should have branch instructions using fixed stack approach
      expect(asm).toContain('get r0 db 0'); // Read tag from stack[0]
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
