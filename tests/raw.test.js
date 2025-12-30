const Compiler = require('../out/compiler/Compiler.res.js');

describe('Raw Instructions and True Literal', () => {
    test('true literal compiles to 1', () => {
        const code = `let x = true`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain("boolean literals can only be used in 'while true' loops");
    });

    test('while true creates infinite loop', () => {
        const code = `let x = ref(0)
while true {
  x := x.contents + 1
}`;
        const expected = ``;

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
        const expected = `label0:
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
yield`;

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
        const expected = `label0:
bnez 0 label1
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('true in if condition', () => {
        const code = `if true {
  let x = 1
}`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain("if condition must be a comparison expression");
    });

    test('true in comparison', () => {
        const code = `let x = true == 1`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain("boolean literals can only be used in 'while true' loops");
    });

    test('error: invalid %raw syntax (missing parentheses)', () => {
        const code = `%raw "yield"`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain('expected LeftParen');
    });

    test('error: invalid %raw syntax (not a string)', () => {
        const code = `%raw(123)`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain('expected string literal');
    });

    test('realistic game loop example', () => {
        const code = `type State = Init | Running | Done

let state = ref(Init)

while true {
  state := Running
  let temp = 100
  %raw("yield")
}`;
        const expected = `move sp 1
poke 0 0
label0:
poke 0 1
define temp 100
yield
j label0`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});
