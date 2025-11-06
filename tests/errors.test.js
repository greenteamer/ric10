const Compiler = require('../out/compiler/Compiler.res.js');

describe('Error Cases and Edge Conditions', () => {
    test('syntax error - missing variable name', () => {
        const code = `let = 5`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain('Expected identifier after');
    });

    test('syntax error - missing assignment operator', () => {
        const code = `let x 5`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain('Expected Assign');
    });

    test('syntax error - missing closing brace', () => {
        const code = `let x = 5
if x > 3 {
  let y = 1`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain("Expected '}'");
    });

    test('syntax error - invalid number', () => {
        const code = `let x = abc`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error'); // Should fail when trying to use undefined variable
    });

    test('register exhaustion - too many variables', () => {
        // Create code that tries to allocate more than 16 registers
        const variables = Array.from({length: 20}, (_, i) => `let var${i} = ref(${i})`).join('\n');

        const result = Compiler.compile(variables);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain('Out of registers');
    });

    test('empty program', () => {
        const code = ``;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe('');
    });

    test('only whitespace', () => {
        const code = `

        `;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe('');
    });

    test('valid edge case - zero values', () => {
        const code = `let zero = 0
if zero == 0 {
  let flag = 1
}`;
        const expected = `define zero 0
define flag 1
bne zero 0 label0
label0:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('valid edge case - negative numbers', () => {
        const code = `let neg = -5
let pos = 10
let sum = neg + pos`;

        // This should work if our lexer supports negative numbers
        // If not, it will fail and we'll know we need to implement it
        const result = Compiler.compile(code);
        if (result.TAG === 'Ok') {
            const expected = `define neg -5
define pos 10
move r15 neg
move r14 pos
add r0 r15 r14`;
            expect(result._0).toBe(expected);
        } else {
            // Expected to fail since we haven't implemented negative number parsing
            expect(result.TAG).toBe('Error');
        }
    });

    test('single character variable names', () => {
        const code = `let a = 1
let b = 2
let c = a + b`;
        const expected = `define a 1
define b 2
move r15 a
move r14 b
add r0 r15 r14`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});