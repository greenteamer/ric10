"use strict";
const Compiler = require('../out/compiler/Compiler.res.js');

const testCode = `let a = 2
let b = 1
let c = a + b
if c < 5 {
  let a = a + 1
} else {
  let a = 100
}`;

const expected = `move r0 2
move r1 1
add r2 r0 r1
blt r2 5 label1
move r0 100
j label0
label1:
add r0 r0 1
label0:`;

test(testCode, () => {
    const result = Compiler.compile(testCode);
    expect(result._0).toBe(expected);
});
