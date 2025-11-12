const Compiler = require('../src/compiler/Compiler.res.js');

describe('Function Declarations and Calls', () => {
    test('simple function declaration', () => {
        const code = `let setup = () => {
  %raw("move r0 100")
}`;
        const expected = `setup:
move r0 100
j ra`;

        const result = Compiler.compile(code, {useIR: true}, undefined);
        if (result.TAG === 'Error') {
            console.log('Error:', result._0);
        }
        expect(result.TAG).toBe('Ok');
        expect(result._0.TAG).toBe('Program');
        expect(result._0._0).toBe(expected);
    });

    test('function declaration and call', () => {
        const code = `let setup = () => {
  %raw("move r0 100")
}

setup()`;
        const expected = `setup:
move r0 100
j ra
jal setup`;

        const result = Compiler.compile(code, {useIR: true}, undefined);
        expect(result.TAG).toBe('Ok');
        expect(result._0.TAG).toBe('Program');
        expect(result._0._0).toBe(expected);
    });

    test('multiple function calls', () => {
        const code = `let init = () => {
  %raw("move r0 1")
}

let reset = () => {
  %raw("move r0 0")
}

init()
reset()
init()`;
        const expected = `init:
move r0 1
j ra
reset:
move r0 0
j ra
jal init
jal reset
jal init`;

        const result = Compiler.compile(code, {useIR: true}, undefined);
        expect(result.TAG).toBe('Ok');
        expect(result._0.TAG).toBe('Program');
        expect(result._0._0).toBe(expected);
    });

    test('function with multiple statements', () => {
        const code = `let configure = () => {
  %raw("move r0 100")
  %raw("move r1 200")
  %raw("add r2 r0 r1")
}

configure()`;
        const expected = `configure:
move r0 100
move r1 200
add r2 r0 r1
j ra
jal configure`;

        const result = Compiler.compile(code, {useIR: true}, undefined);
        expect(result.TAG).toBe('Ok');
        expect(result._0.TAG).toBe('Program');
        expect(result._0._0).toBe(expected);
    });

    test('function in main loop', () => {
        const code = `let tick = () => {
  %raw("add r0 r0 1")
}

while true {
  tick()
}`;
        const expected = `tick:
add r0 r0 1
j ra
label0:
jal tick
j label0`;

        const result = Compiler.compile(code, {useIR: true}, undefined);
        expect(result.TAG).toBe('Ok');
        expect(result._0.TAG).toBe('Program');
        expect(result._0._0).toBe(expected);
    });

    test('error on undefined function call', () => {
        const code = `unknownFunc()`;

        const result = Compiler.compile(code, {useIR: true}, undefined);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain("Unknown identifier 'unknownFunc'");
    });
});
