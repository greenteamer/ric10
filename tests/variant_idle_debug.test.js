const Compiler = require('../src/compiler/Compiler.res.js');

describe('Debug Idle Constructor', () => {
  test('should handle Idle constructor with no args', () => {
    const source = `
      type state = Idle | Fill(int)
      let s = ref(Idle)
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
  });

  test('should assign to Idle from another constructor', () => {
    const source = `
      type state = Idle | Fill(int)
      let s = ref(Fill(10))
      s := Idle
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
  });
});
