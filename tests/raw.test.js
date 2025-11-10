const Compiler = require('../out/compiler/Compiler.res.js');

describe('Raw Instructions and True Literal', () => {
    test('true literal compiles to 1', () => {
        const code = `let x = true`;
        const expected = `define x 1`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('while true creates infinite loop', () => {
        const code = `let x = ref(0)
while true {
  x := x.contents + 1
}`;
        const expected = `move r0 0
label0:
add r0 r0 1
j label0`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('simple %raw instruction', () => {
        const code = `%raw("yield")`;
        const expected = `yield`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('multiple %raw instructions', () => {
        const code = `%raw("yield")
%raw("move r0 100")
%raw("yield")`;
        const expected = `yield
move r0 100
yield`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('while true with %raw("yield") - main game loop pattern', () => {
        const code = `let counter = ref(0)
while true {
  counter := counter.contents + 1
  %raw("yield")
}`;
        const expected = `move r0 0
label0:
add r0 r0 1
yield
j label0`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('%raw with complex instruction', () => {
        const code = `%raw("sb 12345 Setting 1")`;
        const expected = `sb 12345 Setting 1`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('%raw mixed with regular code', () => {
        const code = `let x = 5
%raw("yield")
let y = x + 3`;
        const expected = `define x 5
yield
move r15 x
add r0 r15 3`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('nested loop with while true', () => {
        const code = `let outer = ref(0)
while outer.contents < 3 {
  let inner = ref(0)
  while true {
    inner := inner.contents + 1
  }
  outer := outer.contents + 1
}`;
        const expected = `move r0 0
label0:
bge r0 3 label1
move r1 0
label2:
add r1 r1 1
j label2
add r0 r0 1
j label0
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('true in if condition', () => {
        const code = `if true {
  let x = 1
}`;
        const expected = `define x 1`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('true in comparison', () => {
        const code = `let x = true == 1`;
        const expected = `define x 1`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('error: invalid %raw syntax (missing parentheses)', () => {
        const code = `%raw "yield"`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain('Expected LeftParen');
    });

    test('error: invalid %raw syntax (not a string)', () => {
        const code = `%raw(123)`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain('Expected string literal');
    });

    test('realistic game loop example', () => {
        const code = `type State = Init | Running | Done

let state = ref(Init)

while true {
  state := Running
  let temp = 100
  %raw("yield")
}`;
        const expected = `define temp 100
push 0
move r0 0
label0:
poke 0 1
yield
j label0`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});
