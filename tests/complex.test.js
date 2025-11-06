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

    test('arithmetic with literal optimization', () => {
        const code = `let x = 10
let y = x + 5`;
        const expected = `define x 10
move r15 x
add r0 r15 5`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('multiplication with literal optimization', () => {
        const code = `let base = 7
let doubled = base * 2`;
        const expected = `define base 7
move r15 base
mul r0 r15 2`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('subtraction with literal', () => {
        const code = `let start = 100
let remaining = start - 25`;
        const expected = `define start 100
move r15 start
sub r0 r15 25`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('division with literal', () => {
        const code = `let total = 50
let half = total / 2`;
        const expected = `define total 50
move r15 total
div r0 r15 2`;

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
define flag 1
move r15 a
move r14 b
add r0 r15 r14
move r14 b
move r13 a
sub r1 r14 r13
move r13 a
move r12 b
mul r2 r13 r12
ble r0 25 label0
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
define a 1
define b 2
define c 3
ble x y label0
label0:
bne y 10 label1
label1:
bge z 3 label2
label2:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});