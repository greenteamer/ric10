const Compiler = require('../out/compiler/Compiler.res.js');

describe('While Loops', () => {
    test('simple while loop', () => {
        const code = `let x = ref(0)
while x.contents < 5 {
  x := x.contents + 1
}`;
        const expected = `label0:
bnez 0 label1
j label0
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('while with multiple statements', () => {
        const code = `let counter = ref(0)
while counter.contents < 3 {
  let temp = counter.contents * 2
  counter := counter.contents + 1
}`;
        const expected = `label0:
bnez 0 label1
j label0
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('while with complex condition', () => {
        const code = `let a = ref(10)
let b = ref(0)
while a.contents > b.contents {
  b := b.contents + 2
}`;
        const expected = `label0:
bnez 0 label1
j label0
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('nested while loops', () => {
        const code = `let i = ref(0)
while i.contents < 3 {
  let j = ref(0)
  while j.contents < 2 {
    j := j.contents + 1
  }
  i := i.contents + 1
}`;
        const expected = `label0:
bnez 0 label1
label2:
bnez 0 label0
j label2
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('empty loop body', () => {
        const code = `while 0 {}`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
        expect(result._0).toContain('Integer literals are not supported in while conditions');
    });

    test('loop with condition always false', () => {
        const code = `let x = ref(10)
while x.contents < 5 {
  x := x.contents + 1
}`;
        const expected = `label0:
bnez 1 label1
j label0
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('missing loop condition should error', () => {
        const code = `while { }`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Error');
    });

    test('while with parentheses (valid ReScript syntax)', () => {
        const code = `let x = ref(5)
while (x.contents < 5) { }`;
        const expected = `label0:
bnez 1 label1
j label0
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});
