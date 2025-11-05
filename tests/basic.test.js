const Compiler = require('../out/compiler/Compiler.res.js');

describe('Basic Variable Declarations and Arithmetic', () => {
    test('simple constant declaration', () => {
        const code = `let x = 42`;
        const expected = `define x 42`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('multiple constant declarations', () => {
        const code = `let a = 10
let b = 20
let c = 30`;
        const expected = `define a 10
define b 20
define c 30`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('addition with constants', () => {
        const code = `let a = 5
let b = 3
let c = a + b`;
        const expected = `define a 5
define b 3
move r15 a
move r14 b
add r0 r15 r14`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('subtraction with constants', () => {
        const code = `let x = 10
let y = 4
let z = x - y`;
        const expected = `define x 10
define y 4
move r15 x
move r14 y
sub r0 r15 r14`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('multiplication with constants', () => {
        const code = `let a = 6
let b = 7
let c = a * b`;
        const expected = `define a 6
define b 7
move r15 a
move r14 b
mul r0 r15 r14`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('division with constants', () => {
        const code = `let x = 15
let y = 3
let z = x / y`;
        const expected = `define x 15
define y 3
move r15 x
move r14 y
div r0 r15 r14`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('constant folding optimization', () => {
        const code = `let result = 3 + 7`;
        const expected = `define result 10`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('mixed arithmetic with constants', () => {
        const code = `let a = 2
let b = 3
let c = 4
let result = a + b * c`;
        const expected = `define a 2
define b 3
define c 4
move r15 a
move r14 b
move r13 c
mul r12 r14 r13
add r0 r15 r12`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});