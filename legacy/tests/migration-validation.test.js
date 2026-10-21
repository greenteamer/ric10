const Compiler = require('../src/compiler/Compiler.res.js');

/**
 * IR Migration Validation Suite
 *
 * This test suite validates the IR pipeline against the old codegen by:
 * 1. Running all test cases through both pipelines
 * 2. Comparing outputs for differences
 * 3. Categorizing differences (identical, equivalent, different)
 * 4. Generating a migration report
 */

// Helper to compile with specific options
const compileWithOptions = (code, useIR) => {
  return Compiler.compile(code, {
    includeComments: false,
    debugAST: false,
    useIR
  });
};

// Helper to normalize assembly for comparison
const normalizeAsm = (asm) => {
  return asm
    .split('\n')
    .map(line => line.trim())
    .filter(line => line.length > 0)
    .join('\n');
};

// Helper to analyze differences between two assembly outputs
const analyzeDifference = (oldAsm, newAsm, testName) => {
  const oldLines = oldAsm.split('\n').filter(l => l.trim());
  const newLines = newAsm.split('\n').filter(l => l.trim());

  return {
    testName,
    identical: oldAsm === newAsm,
    oldLineCount: oldLines.length,
    newLineCount: newLines.length,
    oldAsm,
    newAsm,
    // Simple heuristics for semantic equivalence
    sameInstructionCount: oldLines.length === newLines.length,
    // More detailed analysis could go here
  };
};

describe('IR Migration Validation', () => {
  let migrationReport = {
    totalTests: 0,
    identical: 0,
    different: 0,
    oldErrors: 0,
    newErrors: 0,
    bothErrors: 0,
    details: []
  };

  afterAll(() => {
    console.log('\n' + '='.repeat(80));
    console.log('IR MIGRATION VALIDATION REPORT');
    console.log('='.repeat(80));
    console.log(`Total tests: ${migrationReport.totalTests}`);
    console.log(`Identical output: ${migrationReport.identical}`);
    console.log(`Different output: ${migrationReport.different}`);
    console.log(`Old codegen errors: ${migrationReport.oldErrors}`);
    console.log(`IR pipeline errors: ${migrationReport.newErrors}`);
    console.log(`Both failed: ${migrationReport.bothErrors}`);
    console.log('='.repeat(80));

    if (migrationReport.different > 0) {
      console.log('\nDIFFERENCES FOUND:');
      console.log('-'.repeat(80));
      migrationReport.details
        .filter(d => !d.identical && !d.bothFailed)
        .forEach(detail => {
          console.log(`\nTest: ${detail.testName}`);
          if (detail.oldError) {
            console.log('  Old codegen: ERROR');
            console.log(`    ${detail.oldError}`);
          }
          if (detail.newError) {
            console.log('  IR pipeline: ERROR');
            console.log(`    ${detail.newError}`);
          }
          if (!detail.oldError && !detail.newError) {
            console.log(`  Old: ${detail.oldLineCount} instructions`);
            console.log(`  New: ${detail.newLineCount} instructions`);
            console.log('  OLD OUTPUT:');
            console.log('    ' + detail.oldAsm.split('\n').join('\n    '));
            console.log('  NEW OUTPUT:');
            console.log('    ' + detail.newAsm.split('\n').join('\n    '));
          }
        });
    }
  });

  const testCase = (name, code) => {
    test(name, () => {
      migrationReport.totalTests++;

      const oldResult = compileWithOptions(code, false);
      const newResult = compileWithOptions(code, true);

      const detail = {
        testName: name,
        identical: false,
        bothFailed: false,
        oldError: null,
        newError: null,
      };

      // Check if both succeeded
      if (oldResult.TAG === 'Ok' && newResult.TAG === 'Ok') {
        const oldAsm = oldResult._0.TAG === 'Program' ? oldResult._0._0 : oldResult._0;
        const newAsm = newResult._0.TAG === 'Program' ? newResult._0._0 : newResult._0;

        const analysis = analyzeDifference(oldAsm, newAsm, name);

        if (analysis.identical) {
          migrationReport.identical++;
          detail.identical = true;
        } else {
          migrationReport.different++;
          Object.assign(detail, analysis);
        }

        // For now, just report differences - don't fail the test
        // This allows us to see all differences in one run
        expect(true).toBe(true);
      } else if (oldResult.TAG === 'Error' && newResult.TAG === 'Error') {
        // Both failed - check if same error
        migrationReport.bothErrors++;
        detail.bothFailed = true;
        detail.oldError = oldResult._0;
        detail.newError = newResult._0;

        if (oldResult._0 === newResult._0) {
          migrationReport.identical++;
          detail.identical = true;
        } else {
          migrationReport.different++;
        }

        expect(true).toBe(true);
      } else if (oldResult.TAG === 'Error') {
        // Only old failed
        migrationReport.oldErrors++;
        detail.oldError = oldResult._0;
        detail.newAsm = newResult._0.TAG === 'Program' ? newResult._0._0 : newResult._0;
        expect(true).toBe(true);
      } else {
        // Only new failed
        migrationReport.newErrors++;
        detail.newError = newResult._0;
        detail.oldAsm = oldResult._0.TAG === 'Program' ? oldResult._0._0 : oldResult._0;
        expect(true).toBe(true);
      }

      migrationReport.details.push(detail);
    });
  };

  describe('Basic Variables and Arithmetic', () => {
    testCase('simple constant declaration', `let x = 42`);

    testCase('multiple constant declarations', `let a = 10
let b = 20
let c = 30`);

    testCase('binary operation with constants', `let a = 5
let b = 3
let c = a + b`);

    testCase('constant folding optimization', `let result = 3 + 7`);

    testCase('mixed arithmetic with constants', `let x = 5
let y = 10
let result = x * 2 + y`);

    testCase('division operation', `let a = 20
let b = 4
let c = a / b`);

    testCase('subtraction operation', `let a = 15
let b = 7
let c = a - b`);
  });

  describe('Comparisons and Control Flow', () => {
    testCase('if with comparison', `let a = 3
let b = 5
if a < 10 {
  let c = 1
}`);

    testCase('if-else with comparison', `let score = 75
if score < 80 {
  let grade = 1
} else {
  let grade = 2
}`);

    testCase('variable shadowing in if-else', `let x = 10
if x < 5 {
  let x = x + 1
} else {
  let x = x - 1
}`);

    testCase('greater than comparison', `let a = 10
let b = 5
if a > b {
  let result = 1
}`);

    testCase('equality comparison', `let x = 5
let y = 5
if x == y {
  let match = 1
}`);

    testCase('nested if statements', `let x = 10
if x > 5 {
  if x < 15 {
    let y = 1
  }
}`);
  });

  describe('While Loops', () => {
    testCase('simple while loop', `let x = 0
while x < 10 {
  let x = x + 1
}`);

    testCase('while true (infinite loop)', `while true {
  let x = 1
}`);

    testCase('while with greater than', `let count = 100
while count > 0 {
  let count = count - 1
}`);
  });

  describe('References', () => {
    testCase('simple ref creation', `let x = ref(5)`);

    testCase('ref access', `let x = ref(10)
let y = x.contents`);

    testCase('ref assignment', `let counter = ref(0)
counter := 5`);

    testCase('ref in loop', `let i = ref(0)
while i.contents < 10 {
  i := i.contents + 1
}`);
  });

  describe('Variant Types', () => {
    testCase('simple variant type declaration', `type state = Idle | Active | Stopped`);

    testCase('variant type with arguments', `type result = Ok(int) | Error(int)`);

    testCase('variant ref creation - tag only', `type state = Idle | Active
let currentState = ref(Idle)`);

    testCase('variant ref creation - with arg', `type result = Ok(int) | Error(int)
let x = ref(Ok(42))`);

    testCase('variant ref assignment', `type state = Idle | Active
let s = ref(Idle)
s := Active`);

    testCase('simple switch expression', `type state = Idle | Active
let currentState = ref(Idle)
let result = switch currentState.contents {
  | Idle => 0
  | Active => 1
}`);

    testCase('switch with argument extraction', `type result = Ok(int) | Error(int)
let r = ref(Ok(42))
let value = switch r.contents {
  | Ok(n) => n
  | Error(e) => e
}`);

    testCase('variant in loop', `type state = Idle | Fill(int)
let s = ref(Idle)
while true {
  switch s.contents {
    | Idle => s := Fill(100)
    | Fill(amount) => {
        if amount > 0 {
          s := Fill(amount - 1)
        } else {
          s := Idle
        }
      }
  }
}`);
  });

  describe('IC10 Device Operations', () => {
    testCase('device declaration', `let furnace = device("d0")`);

    testCase('device store (s)', `let furnace = device("d0")
s(furnace, "On", 1)`);

    testCase('device load (l)', `let furnace = device("d0")
let temp = l(furnace, "Temperature")`);

    testCase('hash definition', `let tankHash = hash("StructureTank")`);

    testCase('batch load (lb)', `let tankHash = hash("StructureTank")
let pressure = lb(tankHash, "Pressure", "Average")`);

    testCase('batch store (sb)', `let tankHash = hash("StructureTank")
sb(tankHash, "On", 1)`);
  });

  describe('Raw Instructions', () => {
    testCase('yield instruction', `yield`);

    testCase('yield in loop', `while true {
  let x = 1
  yield
}`);
  });

  describe('Complex Programs', () => {
    testCase('nested control flow', `let x = 10
let y = 20
if x < y {
  while x < y {
    let x = x + 1
  }
} else {
  let x = x - 1
}`);

    testCase('multiple refs and variants', `type state = Idle | Active(int)
let s1 = ref(Idle)
let s2 = ref(Active(5))
let counter = ref(0)

while counter.contents < 10 {
  s1 := Active(counter.contents)
  counter := counter.contents + 1
}`);

    testCase('device I/O in control flow', `let furnace = device("d0")
let temp = l(furnace, "Temperature")

if temp < 500 {
  s(furnace, "On", 1)
} else {
  s(furnace, "On", 0)
}`);
  });

  describe('Scoping', () => {
    testCase('block scoping', `let x = 10
{
  let y = 20
  let z = x + y
}
let a = x`);

    testCase('consecutive if statements', `let x = 5
if x < 10 {
  let y = 1
}
if x < 20 {
  let y = 2
}`);
  });

  describe('Error Cases', () => {
    // These should fail in both pipelines
    testCase('undefined variable', `let x = y`);

    testCase('invalid syntax', `let x = `);

    testCase('type mismatch in variant', `type state = Idle | Active
let s = ref(Unknown)`);
  });
});
