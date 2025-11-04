const Compiler = require('../out/compiler/Compiler.res.js');

describe('Complex Expressions and Cases', () => {
    test('complex arithmetic expression in condition', () => {
        const code = `let a = 5
let b = 3
let c = 2
if a + b > c * 4 {
  let result = 1
}`;
        const expected = `move r0 5
move r1 3
move r2 2
sgt r15 r1 r2
move r14 4
mul r13 r15 r14
add r12 r0 r13
beqz r12 label0
move r3 1
label0:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('arithmetic with literal optimization', () => {
        const code = `let x = 10
let y = x + 5`;
        const expected = `move r0 10
add r1 r0 5`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('multiplication with literal optimization', () => {
        const code = `let base = 7
let doubled = base * 2`;
        const expected = `move r0 7
mul r1 r0 2`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('subtraction with literal', () => {
        const code = `let start = 100
let remaining = start - 25`;
        const expected = `move r0 100
sub r1 r0 25`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('division with literal', () => {
        const code = `let total = 50
let half = total / 2`;
        const expected = `move r0 50
div r1 r0 2`;

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
        const expected = `move r0 10
move r1 20
add r2 r0 r1
sub r3 r1 r0
mul r4 r0 r1
ble r2 25 label0
move r5 1
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
        const expected = `move r0 15
move r1 10
move r2 5
ble r0 r1 label0
move r3 1
label0:
bne r1 10 label1
move r4 2
label1:
bge r2 3 label2
move r5 3
label2:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});