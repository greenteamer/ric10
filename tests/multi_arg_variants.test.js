const Compiler = require('../src/compiler/Compiler.res.js');

describe('Multi-Argument Variant Parsing', () => {
  test('should parse type declaration with multiple arguments', () => {
    const source = `type state = Idle(int, int) | Fill(int, int, int) | Waiting(int)`;

    const result = Compiler.compile(source, { includeComments: false });

    // Should not error during parsing
    expect(result.TAG).toBe('Ok');
  });

  test('should parse variant constructor with multiple arguments', () => {
    const source = `
      type state = Idle(int, int)
      let x = Idle(10, 20)
    `;

    const result = Compiler.compile(source, { includeComments: false });

    // Should not error during parsing
    expect(result.TAG).toBe('Ok');
  });

  test('should parse switch with multi-argument pattern bindings', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Idle(0, 0))
      switch state.contents {
      | Idle(p, t) => state := Fill(p + 10, t + 5)
      | Fill(p, t) => state := Idle(p - 10, t - 5)
      }
    `;

    const result = Compiler.compile(source, { includeComments: false });

    // Should not error during parsing
    expect(result.TAG).toBe('Ok');
  });

  test('should handle mixed argument counts', () => {
    const source = `
      type state = Idle | Fill(int) | Active(int, int) | Complex(int, int, int)
      let s = ref(Active(10, 20))
    `;

    const result = Compiler.compile(source, { includeComments: false });

    // Should not error during parsing
    expect(result.TAG).toBe('Ok');
  });

  test('should parse complete example from design doc', () => {
    const source = `
      type state = Idle(int, int) | Fill(int, int)
      let state = ref(Idle(0, 0))

      while true {
        switch state.contents {
        | Idle(p, t) => state := Fill(p + 10, t + 5)
        | Fill(p, t) => state := Idle(p - 10, t - 5)
        }
        %raw("yield")
      }
    `;

    const result = Compiler.compile(source, { includeComments: false });

    // Should not error during parsing
    expect(result.TAG).toBe('Ok');
  });
});
