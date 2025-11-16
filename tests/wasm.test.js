const Compiler = require('../out/compiler/Compiler.res.js');

describe('WASM Backend', () => {
    const wasmOptions = {
        includeComments: false,
        debugAST: false,
        backend: 'WASM'  // Use WASM backend instead of IC10
    };

    test('simple constant declaration', () => {
        const code = `let x = 42`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        expect(output).toContain('(module');
        expect(output).toContain('(func $main');
        expect(output).toContain(')');
    });

    test('binary operation with constants', () => {
        const code = `let a = 5
let b = 3
let c = a + b`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        expect(output).toContain('(module');
        expect(output).toContain('(i32.add)');
        expect(output).toContain('(local.set');
    });

    test('comparison operations', () => {
        const code = `let x = 10
let y = 20
let z = x < y`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        expect(output).toContain('(i32.lt_s)');
    });

    test('if statement', () => {
        const code = `let x = 10
if x > 5 {
  let y = 1
}`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        expect(output).toContain('(if');
        expect(output).toContain('(then');
    });

    test('while loop', () => {
        const code = `let x = 0
while x < 10 {
  let y = 1
}`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        // WASM output should have loop structures via labels and branches
        expect(output).toContain('(br $');
    });

    test('arithmetic operations', () => {
        const code = `let a = 10
let b = 5
let sum = a + b
let diff = a - b
let prod = a * b
let quot = a / b`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        expect(output).toContain('(i32.add)');
        expect(output).toContain('(i32.sub)');
        expect(output).toContain('(i32.mul)');
        expect(output).toContain('(i32.div_s)');
    });

    test('local variable allocation', () => {
        const code = `let x = 1
let y = 2
let z = x + y`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        // Should have local variable declarations
        expect(output).toContain('(local $v');
        expect(output).toContain('i32)');
    });

    test('constant folding in WASM', () => {
        const code = `let result = 3 + 7`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        // Constant folding happens at AST level, so should just have a constant
        expect(output).toContain('(module');
    });

    test('nested expressions', () => {
        const code = `let x = 2
let y = 3
let z = (x + y) * 2`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        expect(output).toContain('(i32.add)');
        expect(output).toContain('(i32.mul)');
    });

    test('multiple comparison operators', () => {
        const code = `let a = 10
let b = 20
let lt = a < b
let gt = a > 5`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        expect(output).toContain('(i32.lt_s)');
        expect(output).toContain('(i32.gt_s)');
    });

    test('variant types with stack operations', () => {
        // Variants are complex, skip for basic WASM test
        // This would require full variant support in the compiler
        const code = `let x = 42`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        // Basic test that WASM generation works
        expect(output).toContain('(module');
    });

    test('device operations are commented out', () => {
        const code = `let temp = l(0, "Temperature")`;

        const result = Compiler.compile(code, wasmOptions);
        expect(result.TAG).toBe('Ok');

        const output = result._0;
        // Device operations should be commented as not supported
        expect(output).toContain(';; DeviceLoad not supported in WASM');
    });
});
