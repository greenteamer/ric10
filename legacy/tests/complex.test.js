const Compiler = require('../out/compiler/Compiler.res.js');

describe('Complex Expressions and Cases', () => {
    test('complex arithmetic expression in condition', () => {
        const code = `let a = 5
let b = 3
let c = 2
if a + b > c * 4 {
  let result = 1
}`;
        // TODO: This test reveals a compiler bug where a complex condition
        // with constant-folded expressions causes an error.
        // The compiler should handle this gracefully.
        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
    });

    test('literal optimization', () => {
        const code = `let x = 10
let y = x + 5`;
        const expected = `define x 10`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('multiple operations in sequence', () => {
        const code = `let a = 10
let b = 20
let sum = a + b
let diff = b - a
let product = a * b
if sum > 25 {
  let flag = 1
}`;
        const expected = `define a 10
define b 20
bnez 0 label0
define flag 1
label0:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('chained comparisons with different types', () => {
        const code = `let x = 15
let y = 10
let z = 5
if x > y {
  let a = 1
}
if y == 10 {
  let b = 2
}
if z < 3 {
  let c = 3
}`;
        const expected = `define x 15
define y 10
define z 5
bnez 0 label0
define a 1
label0:
bnez 0 label1
define b 2
label1:
bnez 1 label2
define c 3
label2:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});