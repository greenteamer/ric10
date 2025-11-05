const Compiler = require('../out/compiler/Compiler.res.js');

describe('While Loops', () => {
    test('simple while loop', () => {
        const code = `let x = ref(0)
while x.contents < 5 {
  x := x.contents + 1
}`;
        const expected = `move r0 0
label0:
bge r0 5 label1
add r0 r0 1
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
        const expected = `move r0 0
label0:
bge r0 3 label1
mul r1 r0 2
add r0 r0 1
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
        const expected = `move r0 10
move r1 0
label0:
ble r0 r1 label1
add r1 r1 2
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
        const expected = `move r0 0
label0:
bge r0 3 label1
move r1 0
label2:
bge r1 2 label3
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

    test('empty loop body', () => {
        const code = `while 0 {}`;
        const expected = `label0:
j label0`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });

    test('loop with condition always false', () => {
        const code = `let x = ref(10)
while x.contents < 5 {
  x := x.contents + 1
}`;
        const expected = `move r0 10
label0:
bge r0 5 label1
add r0 r0 1
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
        const expected = `move r0 5
label0:
bge r0 5 label1
j label0
label1:`;

        const result = Compiler.compile(code);
        expect(result.TAG).toBe('Ok');
        expect(result._0).toBe(expected);
    });
});
