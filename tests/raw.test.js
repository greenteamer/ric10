const Compiler = require('../out/compiler/Compiler.res.js');

describe('Raw Instructions and True Literal', () => {
    test('true literal compiles to 1', () => {
        const code = `let x = true`;
        const expected = `move r0 1`;

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
move r15 1
beqz r15 label1
add r0 r0 1
j label0
label1:`;

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
move r15 1
beqz r15 label1
add r0 r0 1
yield
j label0
label1:`;

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
        const expected = `move r0 5
yield
add r1 r0 3`;

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
move r15 r0
bge r15 3 label1
move r1 0
label2:
move r15 1
beqz r15 label3
add r1 r1 1
j label2
label3:
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
        const expected = `move r0 1`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('true in comparison', () => {
        const code = `let x = true == 1`;
        const expected = `move r0 1`;

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
        const expected = `push 0
move r15 sp
sub r15 r15 1
move r0 r15
label0:
move r15 1
beqz r15 label1
push 1
move r14 sp
sub r14 r14 1
move r0 r14
move r1 100
yield
j label0
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});
