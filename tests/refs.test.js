const Compiler = require('../out/compiler/Compiler.res.js');

describe('Mutable References (ref)', () => {
  describe('Basic Operations', () => {
    test('create ref with literal', () => {
      const code = `let x = ref(42)`;
      const expected = `move r0 42`;

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Ok');
      expect(result._0).toBe(expected);
    });

    test('create ref with expression', () => {
      const code = `let x = ref(10 + 20)`;
      const expected = `move r0 30`; // Optimizer folds 10 + 20 to 30

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Ok');
      expect(result._0).toBe(expected);
    });

    test('read ref contents', () => {
      const code = `let x = ref(10)
let y = x.contents`;
      const expected = `move r0 10
move r1 r0`;

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Ok');
      expect(result._0).toBe(expected);
    });

    test('mutate ref', () => {
      const code = `let x = ref(0)
x := 5`;
      const expected = `move r0 0
move r0 5`;

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Ok');
      expect(result._0).toBe(expected);
    });
  });

  describe('Complex Operations', () => {
    test('increment pattern', () => {
      const code = `let counter = ref(0)
counter := counter.contents + 1`;
      const expected = `move r0 0
add r0 r0 1`;

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Ok');
      expect(result._0).toBe(expected);
    });

    test('mutation in if statement', () => {
      const code = `let x = ref(0)
if x.contents < 10 {
  x := x.contents + 1
}`;
      const expected = `move r0 0
bge r0 10 label0
add r0 r0 1
label0:`;

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Ok');
      expect(result._0).toBe(expected);
    });

    test('multiple refs', () => {
      const code = `let x = ref(1)
let y = ref(2)
let sum = x.contents + y.contents`;
      const expected = `move r0 1
move r1 2
add r2 r0 r1`;

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Ok');
      expect(result._0).toBe(expected);
    });

    test('use ref contents in arithmetic', () => {
      const code = `let x = ref(10)
let y = x.contents * 2`;
      const expected = `move r0 10
mul r1 r0 2`;

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Ok');
      expect(result._0).toBe(expected);
    });
  });

  describe('Error Cases', () => {
    test('colonEqual on non-ref', () => {
      const code = `let x = 10
x := 20`;

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Error');
      expect(result._0).toContain('Undefined variable: x');
    });

    test('contents on non-ref', () => {
      const code = `let x = 10
let y = x.contents`;

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Error');
      expect(result._0).toContain('Undefined variable: x');
    });

    test('undefined variable in ref assignment', () => {
      const code = `x := 10`;

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Error');
      expect(result._0).toContain('Undefined variable');
    });

    test('undefined ref in contents access', () => {
      const code = `let y = x.contents`;

      const result = Compiler.compile(code);
      expect(result.TAG).toBe('Error');
      expect(result._0).toContain('Undefined variable');
    });
  });
});
