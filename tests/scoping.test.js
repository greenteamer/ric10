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

    test('variable shadowing with same name', () => {
        const code = `let value = 100
if value > 50 {
  let value = value / 2
} else {
  let value = value * 2
}`;
        const expected = `define value 100
bgt value 50 label1
move r15 value
mul r0 r15 2
j label0
label1:
move r15 value
div r0 r15 2
label0:`;

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
define a 10
define b 20
bge a b label0
move r15 a
move r14 b
add r0 r15 r14
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
        const expected = `define x 5
move r15 x
add r0 r15 1
mul r1 r0 2`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('if without else - simple case', () => {
        const code = `let temperature = 75
if temperature > 80 {
  let cooling = 1
}
let done = 1`;
        const expected = `define temperature 75
define cooling 1
define done 1
ble temperature 80 label0
label0:`;

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
define action 10
define action 50
bne status 1 label0
label0:
bne status 5 label1
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
define base 20
define base 5
move r15 base
move r14 multiplier
mul r0 r15 r14
bgt r0 25 label1
move r14 base
sub r1 r14 r0
j label0
label1:
move r14 base
add r1 r14 r0
label0:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});