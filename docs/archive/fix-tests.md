Pattern for Fixing Tests

The Change

Old behavior: let x = 5 → created register variable move r0 5New behavior: let x = 5 → creates constant define x 5

Fixing Patterns

Pattern 1: Simple literals become constants

Before:
const code = `let x = 42`;
const expected = `move r0 42`;

After:
const code = `let x = 42`;
const expected = `define x 42`;

Pattern 2: Multiple literals become multiple constants

Before:
const code = `let a = 10
  let b = 20`;
const expected = `move r0 10
  move r1 20`;

After:
const code = `let a = 10
  let b = 20`;
const expected = `define a 10
  define b 20`;

Pattern 3: Constants used in expressions load via define name

Before:
const code = `let a = 5
  let b = 3
  let c = a + b`;
const expected = `move r0 5
  move r1 3
  add r2 r0 r1`;

After:
const code = `let a = 5
  let b = 3
  let c = a + b`;
const expected = `define a 5
  define b 3
  move r15 a
  move r14 b
  add r0 r15 r14`;

Pattern 4: Constants in comparisons use define name directly

Before:
const code = `let x = 10
  if x > 5 { ... }`;
const expected = `move r0 10
  bgt r0 5 label0`;

After:
const code = `let x = 10
  if x > 5 { ... }`;
const expected = `define x 10
  bgt x 5 label0`;

Pattern 5: Constant folding creates constants

Before:
const code = `let result = 3 + 7`;
const expected = `move r0 10`;

After:
const code = `let result = 3 + 7`;
const expected = `define result 10`;

When Tests Should Still Use Registers

If you want register variables in tests, use:

- Expressions: let x = 5 + 0 (forces register)
- Refs: let x = ref(5) (mutable)
- IC10 functions: let x = l(d0, "Temp") (function result)

Quick Check Command

To see actual output for any test:
node -e "
const Compiler = require('./out/compiler/Compiler.res.js');
const code = 'YOUR_CODE_HERE';
const result = Compiler.compile(code, { includeComments: false });
console.log(result.\_0);
"

That's the pattern! All failing tests follow these same rules.

Todos
☒ Fix basic.test.js for new constant system
☐ 38 tests remaining to fix in 9 test files
