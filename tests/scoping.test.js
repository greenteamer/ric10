const Compiler = require('../out/compiler/Compiler.res.js');

describe('Scoping and Block Statements', () => {
    test('simple block statement', () => {
        const code = `{
  let x = 5
  let y = 10
}`;
        const expected = `move r0 5
move r1 10`;

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
        const expected = `move r0 100
bgt r0 50 label1
mul r0 r0 2
j label0
label1:
div r0 r0 2
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
        const expected = `move r0 1
move r1 2
bge r0 r1 label0
move r0 10
move r1 20
add r2 r0 r1
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
        const expected = `move r0 5
add r1 r0 1
mul r2 r1 2`;

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
        const expected = `move r0 75
ble r0 80 label0
move r1 1
label0:
move r2 1`;

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
        const expected = `move r0 5
bne r0 1 label0
move r1 10
label0:
bne r0 5 label1
move r1 50
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
        const expected = `move r0 10
move r1 3
mul r2 r0 r1
bgt r2 25 label1
move r0 20
sub r3 r0 r2
j label0
label1:
move r0 5
add r3 r0 r2
label0:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});