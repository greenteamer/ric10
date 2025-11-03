const Compiler = require('../out/compiler/Compiler.res.js');

describe('Basic Variable Declarations and Arithmetic', () => {
    test('simple variable declaration', () => {
        const code = `let x = 42`;
        const expected = `move r0 42`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('multiple variable declarations', () => {
        const code = `let a = 10
let b = 20
let c = 30`;
        const expected = `move r0 10
move r1 20
move r2 30`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('addition operation', () => {
        const code = `let a = 5
let b = 3
let c = a + b`;
        const expected = `move r0 5
move r1 3
add r2 r0 r1`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('subtraction operation', () => {
        const code = `let x = 10
let y = 4
let z = x - y`;
        const expected = `move r0 10
move r1 4
sub r2 r0 r1`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('multiplication operation', () => {
        const code = `let a = 6
let b = 7
let c = a * b`;
        const expected = `move r0 6
move r1 7
mul r2 r0 r1`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('division operation', () => {
        const code = `let x = 15
let y = 3
let z = x / y`;
        const expected = `move r0 15
move r1 3
div r2 r0 r1`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('constant folding optimization', () => {
        const code = `let result = 3 + 7`;
        const expected = `move r0 10`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('mixed arithmetic operations', () => {
        const code = `let a = 2
let b = 3
let c = 4
let result = a + b * c`;
        const expected = `move r0 2
move r1 3
move r2 4
mul r15 r1 r2
add r3 r0 r15`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});