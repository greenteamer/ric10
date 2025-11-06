// IC10 Bindings Tests
// Tests for IC10 device I/O operations
// Note: Functions are called directly (l, s, etc.) not through IC10 module

const Compiler = require('../src/compiler/Compiler.res.js');

describe('IC10 Bindings - Basic Operations', () => {
  test('l (load from device) - basic using d0', () => {
    const source = `
      let d0 = 0
      let temp = l(d0, "Temperature")
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('define d0 0');
    expect(asm).toMatch(/l r\d+ d0 Temperature/);
  });

  test('s (store to device) - basic', () => {
    const source = `
      let d1 = 1
      s(d1, "Setting", 100)
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('define d1 1');
    expect(asm).toContain('100');
    expect(asm).toMatch(/s d1 Setting 100/);
  });

  test('multiple operations in sequence', () => {
    const source = `
      let d0 = 0
      let d1 = 1
      let temp = l(d0, "Temperature")
      s(d1, "Setting", 100)
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('l r');
    expect(asm).toContain('s d');
  });
});

describe('IC10 Bindings - Hash Operations', () => {
  test('lb (load by hash) - basic', () => {
    const source = `
      let avgTemp = lb(12345, "Temperature")
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('move r');
    expect(asm).toContain('12345');
    expect(asm).toMatch(/lb r\d+ r.*? Temperature/);
  });

  test('sb (store by hash) - basic', () => {
    const source = `
      sb(67890, "On", 1)
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('67890');
    expect(asm).toContain('move r');
    expect(asm).toContain('1');
    expect(asm).toMatch(/sb r.*? On (r\d+|\d+)/);
  });
});

describe('IC10 Bindings - Network Operations', () => {
  test('lbn (load by network) - average', () => {
    const source = `
      let avgTemp = lbn("Furnace", "MainFurnace", "Temperature", "Average")
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('lbn');
    expect(asm).toContain('HASH("Furnace")');
    expect(asm).toContain('HASH("MainFurnace")');
    expect(asm).toContain('Temperature');
    expect(asm).toContain('Average');
  });

  test('sbn (store by network) - basic', () => {
    const source = `
      sbn("LEDDisplay", "StatusDisplay", "Setting", 100)
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('100');
    expect(asm).toContain('sbn');
    expect(asm).toContain('HASH("LEDDisplay")');
    expect(asm).toContain('HASH("StatusDisplay")');
    expect(asm).toContain('Setting');
  });
});

describe('IC10 Bindings - Complex Examples', () => {
  test('temperature control with conditionals', () => {
    const source = `
      let maxTemp = 500
      let d0 = 0
      let d1 = 1
      let currentTemp = l(d0, "Temperature")

      if currentTemp > maxTemp {
        s(d1, "On", 0)
      } else {
        s(d1, "On", 1)
      }
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('l r');
    expect(asm).toMatch(/b(le|gt)/);
    expect(asm).toContain('s d');
  });

  test('arithmetic with loaded values', () => {
    const source = `
      let d0 = 0
      let d1 = 1
      let d2 = 2
      let temp1 = l(d0, "Temperature")
      let temp2 = l(d1, "Temperature")
      let sum = temp1 + temp2
      s(d2, "Setting", sum)
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('l r');
    expect(asm).toMatch(/add r\d+ r\d+ r\d+/);
    expect(asm).toContain('s d');
  });

  test('hash load with arithmetic', () => {
    const source = `
      let d0 = 0
      let hashTemp = lb(12345, "Temperature")
      let delta = hashTemp - 100
      s(d0, "Setting", delta)
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('lb');
    expect(asm).toMatch(/sub r\d+ r\d+ \d+/);
    expect(asm).toMatch(/s d.* Setting/);
  });

  test('average calculation from multiple sensors', () => {
    const source = `
      let d0 = 0
      let d1 = 1
      let d2 = 2
      let d3 = 3
      let temp1 = l(d0, "Temperature")
      let temp2 = l(d1, "Temperature")
      let temp3 = l(d2, "Temperature")
      let sum = temp1 + temp2 + temp3
      let avg = sum / 3
      s(d3, "Setting", avg)
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    // Check for load instructions with Temperature property
    const loadMatches = asm.match(/l r\d+ d.*? Temperature/g);
    expect(loadMatches).not.toBeNull();
    expect(loadMatches.length).toBeGreaterThanOrEqual(3);
    expect(asm).toMatch(/add r\d+/);
    expect(asm).toMatch(/div r\d+ r\d+ 3/);
    expect(asm).toMatch(/s d.* Setting/);
  });
});

describe('IC10 Bindings - Error Cases', () => {
  test('string literal as standalone expression fails', () => {
    const source = `
      let x = "Temperature"
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Error");
    expect(result._0).toContain("String literals can only be used as IC10 function arguments");
  });

  test('function call with wrong number of arguments', () => {
    const source = `
      let d0 = 0
      let temp = l(d0)
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Error");
  });

  test('missing comma between arguments', () => {
    const source = `
      let d0 = 0
      let temp = l(d0 "Temperature")
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Error");
  });
});

describe('IC10 Bindings - Real-world Scenarios', () => {
  test('temperature control loop', () => {
    const source = `
      let maxTemp = 500
      let minTemp = 300
      let d0 = 0
      let d1 = 1
      let d2 = 2

      while true {
        let currentTemp = l(d0, "Temperature")

        if currentTemp > maxTemp {
          s(d1, "On", 0)
          s(d2, "On", 1)
        } else {
          if currentTemp < minTemp {
            s(d1, "On", 1)
            s(d2, "On", 0)
          }
        }

        %raw("yield")
      }
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toMatch(/label\d+:/);
    expect(asm).toContain('yield');
    expect(asm).toMatch(/j label\d+/);
    expect(asm).toContain('l r');
    expect(asm).toContain('s d');
  });

  test('network-based average temperature monitoring', () => {
    const source = `
      let d0 = 0
      let avgTemp = lbn("Sensor", "TemperatureSensors", "Temperature", "Average")

      if avgTemp > 400 {
        sbn("Cooler", "RoomCoolers", "On", 1)
      } else {
        sbn("Cooler", "RoomCoolers", "On", 0)
      }
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('lbn');
    expect(asm).toContain('HASH("Sensor")');
    expect(asm).toContain('Average');
    expect(asm).toContain('sbn');
    expect(asm).toContain('HASH("Cooler")');
  });

  test('pressure and temperature monitoring', () => {
    const source = `
      let d0 = 0
      let temp = l(d0, "Temperature")
      let pressure = l(d0, "Pressure")
      let combined = temp + pressure
      s(d0, "Setting", combined)
    `;
    const result = Compiler.compile(source, { includeComments: false });
    expect(result.TAG).toBe("Ok");

    const asm = result._0;
    expect(asm).toContain('Temperature');
    expect(asm).toContain('Pressure');
    expect(asm).toMatch(/add r\d+ r\d+ r\d+/);
  });
});
