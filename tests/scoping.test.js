const Compiler = require('../out/compiler/Compiler.res.js');

describe('Scoping and Block Statements', () => {
    test('simple block statement', () => {
        const code = `{
  let x = 5
  let y = 10
}`;
        const expected = `define x 5
define y 10`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('multiple variable shadowing', () => {
        const code = `let a = 1
let b = 2
if a < b {
  let a = 10
  let b = 20
  let c = a + b
}`;
        const expected = `define a 1
define b 2
bnez 0 label0
define a 10
define b 20
label0:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('nested blocks with shadowing', () => {
        const code = `let x = 5
{
  let y = x + 1
  {
    let z = y * 2
  }
}`;
        const expected = `define x 5`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('consecutive if statements', () => {
        const code = `let status = 5
if status == 1 {
  let action = 10
}
if status == 5 {
  let action = 50
}`;
        const expected = `define status 5
bnez 1 label0
define action 10
label0:
bnez 0 label1
define action 50
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('complex scoping with mixed operations', () => {
        const code = `let base = 10
let multiplier = 3
let result = base * multiplier
if result > 25 {
  let base = 5
  let newResult = base + result
} else {
  let base = 20
  let newResult = base - result
}`;
        const expected = `define base 10
define multiplier 3
bnez 0 label0
define base 20
j label1
label0:
define base 5
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});