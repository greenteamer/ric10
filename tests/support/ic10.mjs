// Minimal IC10 emulator for tests.
//
// Executes the assembly ric10 produces (and most hand-written IC10), with
// mock devices, a batch network, the 512-slot stack and tick accounting.
// It is deliberately strict: undefined labels, duplicate labels, unknown
// instructions, reads of missing logic types and programs over the line limit
// throw, so tests catch bad output instead of silently computing garbage.

import fs from "fs";
import path from "path";

const TABLE = JSON.parse(
  fs.readFileSync(path.join(import.meta.dirname, "..", "fixtures", "ic10-instructions.json"), "utf8"),
);
export const INSTRUCTIONS = TABLE.instructions;

const STACK_SIZE = 512;
const LINES_PER_TICK = 128;
const BATCH_MODES = { Average: 0, Sum: 1, Minimum: 2, Maximum: 3 };

let crcTable;
export function hash(str) {
  if (!crcTable) {
    crcTable = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      crcTable[n] = c;
    }
  }
  let crc = -1;
  for (let i = 0; i < str.length; i++) crc = crcTable[(crc ^ str.charCodeAt(i)) & 0xff] ^ (crc >>> 8);
  return (crc ^ -1) | 0; // signed int32, as the game
}

const toLong = (x) => BigInt.asIntN(64, BigInt(Math.trunc(x)));
const fromLong = (b) => Number(BigInt.asIntN(53, b));

export class IC10Error extends Error {}

export class IC10 {
  /**
   * @param {string} code assembly
   * @param {object} opts
   *   devices: { d0: {Temperature: 300, ...}, ... }   pin -> logic values
   *   network: [{ prefabHash, nameHash?, values: {...} }] devices for lb/sb
   *   byId:    { [referenceId]: { stack: [...] } }    device stacks for getd/putd
   *   strict:  throw when reading a logic type a device does not have (default true)
   *   maxLines: line limit (default 128)
   */
  constructor(code, opts = {}) {
    this.source = code;
    this.strict = opts.strict ?? true;
    this.devices = opts.devices ?? {};
    this.network = opts.network ?? [];
    this.byId = opts.byId ?? {};
    this.regs = new Array(18).fill(0);
    this.stack = new Array(STACK_SIZE).fill(0);
    this.pc = 0;
    this.halted = false;
    this.ticks = 0;
    this.steps = 0;
    this.writes = []; // {tick, target, prop, value}
    this.lines = code.split("\n");
    if (this.lines.length > (opts.maxLines ?? 128)) {
      throw new IC10Error(`program has ${this.lines.length} lines (limit ${opts.maxLines ?? 128})`);
    }
    this.labels = {};
    this.defines = {};
    this.aliases = {};
    this.program = this.lines.map((raw, i) => {
      const line = raw.replace(/#.*$/, "").trim();
      if (raw.length > 90) throw new IC10Error(`line ${i + 1} is longer than 90 characters`);
      if (line === "") return null;
      const label = line.match(/^([A-Za-z_][A-Za-z0-9_.]*):$/);
      if (label) {
        if (label[1] in this.labels) throw new IC10Error(`duplicate label '${label[1]}' on line ${i + 1}`);
        this.labels[label[1]] = i;
        return null;
      }
      const parts = line.match(/HASH\("[^"]*"\)|STR\("[^"]*"\)|\S+/g);
      const ins = { op: parts[0], args: parts.slice(1), line: i + 1 };
      this.validate(ins);
      return ins;
    });
    // defines and aliases are resolved before execution
    for (const ins of this.program) {
      if (!ins) continue;
      if (ins.op === "define") {
        if (ins.args[0] in this.defines) throw new IC10Error(`duplicate define '${ins.args[0]}'`);
        this.defines[ins.args[0]] = this.num(ins.args[1], ins);
      }
    }
  }

  // Opcode, operand count and operand kinds against the game's instruction table
  validate(ins) {
    const spec = INSTRUCTIONS[ins.op];
    if (!spec) throw new IC10Error(`line ${ins.line}: unknown instruction '${ins.op}'`);
    if (ins.args.length !== spec.operands.length) {
      throw new IC10Error(`line ${ins.line}: ${ins.op} takes ${spec.operands.length} operand(s), got ${ins.args.length}`);
    }
    const isReg = (t) => /^r(1[0-7]|[0-9])$|^sp$|^ra$/.test(t);
    const isDev = (t) => /^d[0-5]$|^db$/.test(t);
    const isNum = (t) => /^-?(\d+\.?\d*|\.\d+)(e[-+]?\d+)?$/i.test(t) || /^HASH\(/.test(t) || /^\$[0-9A-Fa-f]+$/.test(t);
    const isIdent = (t) => /^[A-Za-z_][A-Za-z0-9_.]*$/.test(t);
    ins.args.forEach((arg, i) => {
      const kinds = spec.operands[i];
      const ok = kinds.some((k) => {
        switch (k) {
          case "Register": return isReg(arg);
          case "Device": return isDev(arg);
          case "Number": return isNum(arg) || isIdent(arg); // defines and labels resolve later
          case "LogicType": case "SlotLogicType": case "BatchMode": case "ReagentMode": case "Name": return isIdent(arg) || isNum(arg);
          default: return false;
        }
      });
      // aliases are resolved at run time; accept identifiers where a register or device is expected
      if (!ok && !(isIdent(arg) && (kinds.includes("Register") || kinds.includes("Device")))) {
        throw new IC10Error(`line ${ins.line}: operand ${i + 1} of ${ins.op} must be ${kinds.join("|")}, got '${arg}'`);
      }
    });
  }

  fail(ins, msg) {
    throw new IC10Error(`line ${ins ? ins.line : this.pc + 1}: ${msg}`);
  }

  regIndex(tok) {
    if (tok === "sp") return 16;
    if (tok === "ra") return 17;
    const m = /^r(\d+)$/.exec(tok);
    if (m && +m[1] <= 17) return +m[1];
    if (tok in this.aliases && /^r/.test(this.aliases[tok])) return this.regIndex(this.aliases[tok]);
    return -1;
  }

  num(tok, ins) {
    const h = /^HASH\("(.*)"\)$/.exec(tok);
    if (h) return hash(h[1]);
    if (/^-?(\d+\.?\d*|\.\d+)(e[-+]?\d+)?$/i.test(tok)) return Number(tok);
    if (/^\$[0-9A-Fa-f]+$/.test(tok)) return parseInt(tok.slice(1), 16);
    if (tok in this.defines) return this.defines[tok];
    this.fail(ins, `cannot read value '${tok}'`);
  }

  val(tok, ins) {
    const r = this.regIndex(tok);
    if (r >= 0) return this.regs[r];
    return this.num(tok, ins);
  }

  set(tok, v, ins) {
    const r = this.regIndex(tok);
    if (r < 0) this.fail(ins, `'${tok}' is not a register`);
    this.regs[r] = v;
  }

  target(tok, ins) {
    if (tok in this.labels) return this.labels[tok];
    const r = this.regIndex(tok);
    if (r >= 0) return this.regs[r];
    if (/^-?\d+$/.test(tok)) return Number(tok);
    this.fail(ins, `undefined label '${tok}'`);
  }

  pin(tok, ins) {
    const name = this.aliases[tok] ?? tok;
    if (!/^(d[0-5]|db)$/.test(name)) this.fail(ins, `'${tok}' is not a device pin`);
    return name;
  }

  device(tok, ins) {
    const name = this.pin(tok, ins);
    if (name === "db") {
      this.devices.db ??= {};
      return this.devices.db;
    }
    const d = this.devices[name];
    if (!d) this.fail(ins, `no device on ${name}`);
    return d;
  }

  read(dev, prop, ins, label) {
    if (!(prop in dev)) {
      if (this.strict) this.fail(ins, `${label} has no logic type '${prop}'`);
      return 0;
    }
    return dev[prop];
  }

  write(dev, prop, value, label) {
    dev[prop] = value;
    this.writes.push({ tick: this.ticks, target: label, prop, value });
  }

  idStack(id, ins) {
    const dev = this.byId[id];
    if (!dev) this.fail(ins, `no device with id ${id}`);
    return (dev.stack ??= new Array(STACK_SIZE).fill(0));
  }

  batch(prefab, name) {
    return this.network.filter((d) => d.prefabHash === prefab && (name === undefined || d.nameHash === name));
  }

  aggregate(values, mode, ins) {
    const m = mode in BATCH_MODES ? BATCH_MODES[mode] : Number(mode);
    if (values.length === 0) return 0;
    switch (m) {
      case 0: return values.reduce((a, b) => a + b, 0) / values.length;
      case 1: return values.reduce((a, b) => a + b, 0);
      case 2: return Math.min(...values);
      case 3: return Math.max(...values);
      default: this.fail(ins, `bad batch mode '${mode}'`);
    }
  }

  // Execute one instruction. Returns "yield" when the tick ends.
  step() {
    if (this.pc < 0 || this.pc >= this.program.length) {
      this.halted = true;
      return "halt";
    }
    const ins = this.program[this.pc];
    this.steps++;
    if (!ins) {
      this.pc++;
      return;
    }
    const a = ins.args;
    const v = (i) => this.val(a[i], ins);
    const out = (x) => this.set(a[0], x, ins);
    let next = this.pc + 1;
    const jump = (cond, ti) => {
      if (cond) next = this.target(a[ti], ins);
    };
    const cmp = { lt: (x, y) => x < y, gt: (x, y) => x > y, le: (x, y) => x <= y, ge: (x, y) => x >= y, eq: (x, y) => x === y, ne: (x, y) => x !== y };
    let m;
    if ((m = /^s(lt|gt|le|ge|eq|ne)(z?)$/.exec(ins.op))) {
      out(cmp[m[1]](v(1), m[2] ? 0 : v(2)) ? 1 : 0);
    } else if ((m = /^b(lt|gt|le|ge|eq|ne)(z?)(al)?$/.exec(ins.op))) {
      const ok = cmp[m[1]](v(0), m[2] ? 0 : v(1));
      if (ok && m[3]) this.regs[17] = this.pc + 1;
      jump(ok, m[2] ? 1 : 2);
    } else {
      switch (ins.op) {
        case "define": break;
        case "alias": this.aliases[a[0]] = a[1]; break;
        case "move": out(v(1)); break;
        case "add": out(v(1) + v(2)); break;
        case "sub": out(v(1) - v(2)); break;
        case "mul": out(v(1) * v(2)); break;
        case "div": out(v(1) / v(2)); break;
        case "mod": { const x = v(1), y = v(2); out(x - y * Math.floor(x / y)); break; }
        case "abs": out(Math.abs(v(1))); break;
        case "sqrt": out(Math.sqrt(v(1))); break;
        case "floor": out(Math.floor(v(1))); break;
        case "ceil": out(Math.ceil(v(1))); break;
        case "round": out(Math.round(v(1))); break;
        case "trunc": out(Math.trunc(v(1))); break;
        case "sin": out(Math.sin(v(1))); break;
        case "cos": out(Math.cos(v(1))); break;
        case "tan": out(Math.tan(v(1))); break;
        case "asin": out(Math.asin(v(1))); break;
        case "acos": out(Math.acos(v(1))); break;
        case "atan": out(Math.atan(v(1))); break;
        case "atan2": out(Math.atan2(v(1), v(2))); break;
        case "exp": out(Math.exp(v(1))); break;
        case "log": out(Math.log(v(1))); break;
        case "min": out(Math.min(v(1), v(2))); break;
        case "max": out(Math.max(v(1), v(2))); break;
        case "rand": out(0.5); break;
        case "and": out(fromLong(toLong(v(1)) & toLong(v(2)))); break;
        case "or": out(fromLong(toLong(v(1)) | toLong(v(2)))); break;
        case "xor": out(fromLong(toLong(v(1)) ^ toLong(v(2)))); break;
        case "nor": out(fromLong(~(toLong(v(1)) | toLong(v(2))))); break;
        case "not": out(fromLong(~toLong(v(1)))); break;
        case "sll": case "sla": out(fromLong(toLong(v(1)) << BigInt(v(2)))); break;
        case "sra": out(fromLong(toLong(v(1)) >> BigInt(v(2)))); break;
        case "srl": out(fromLong(BigInt.asUintN(64, toLong(v(1))) >> BigInt(v(2)))); break;
        case "select": out(v(1) !== 0 ? v(2) : v(3)); break;
        case "j": next = this.target(a[0], ins); break;
        case "jal": this.regs[17] = this.pc + 1; next = this.target(a[0], ins); break;
        case "jr": next = this.pc + v(0); break;
        case "push":
          if (this.regs[16] >= STACK_SIZE) this.fail(ins, "stack overflow");
          this.stack[this.regs[16]++] = v(0);
          break;
        case "pop":
          if (this.regs[16] <= 0) this.fail(ins, "stack underflow");
          out(this.stack[--this.regs[16]]);
          break;
        case "peek": out(this.stack[this.regs[16] - 1] ?? 0); break;
        case "get": {
          if (this.pin(a[1], ins) !== "db") this.fail(ins, "only db stack is emulated");
          out(this.stack[v(2)]);
          break;
        }
        case "put": {
          if (this.pin(a[0], ins) !== "db") this.fail(ins, "only db stack is emulated");
          this.stack[v(1)] = v(2);
          break;
        }
        case "l": out(this.read(this.device(a[1], ins), a[2], ins, a[1])); break;
        case "s": this.write(this.device(a[0], ins), a[1], v(2), this.pin(a[0], ins)); break;
        case "ls": {
          const slot = (this.device(a[1], ins).slots ?? [])[v(2)];
          if (!slot) this.fail(ins, `${a[1]} has no slot ${v(2)}`);
          out(this.read(slot, a[3], ins, `${a[1]} slot ${v(2)}`));
          break;
        }
        case "ss": {
          const slot = (this.device(a[0], ins).slots ?? [])[v(1)];
          if (!slot) this.fail(ins, `${a[0]} has no slot ${v(1)}`);
          this.write(slot, a[2], v(3), `${a[0]}.slot${v(1)}`);
          break;
        }
        case "getd": out(this.idStack(v(1), ins)[v(2)]); break;
        case "putd": this.idStack(v(0), ins)[v(1)] = v(2); break;
        case "lb": out(this.aggregate(this.batch(v(1)).map((d) => this.read(d.values, a[2], ins, "batch")), a[3], ins)); break;
        case "lbn": out(this.aggregate(this.batch(v(1), v(2)).map((d) => this.read(d.values, a[3], ins, "batch")), a[4], ins)); break;
        case "sb": for (const d of this.batch(v(0))) this.write(d.values, a[1], v(2), `batch ${v(0)}`); break;
        case "sbn": for (const d of this.batch(v(0), v(1))) this.write(d.values, a[2], v(3), `batch ${v(0)}/${v(1)}`); break;
        case "lbs": out(this.aggregate(this.batch(v(1)).map((d) => this.read(d.slots[v(2)], a[3], ins, "batch slot")), a[4], ins)); break;
        case "lbns": out(this.aggregate(this.batch(v(1), v(2)).map((d) => this.read(d.slots[v(3)], a[4], ins, "batch slot")), a[5], ins)); break;
        case "sbs": for (const d of this.batch(v(0))) this.write(d.slots[v(1)], a[2], v(3), `batch ${v(0)} slot`); break;
        case "sdse": out(this.devices[this.pin(a[1], ins)] ? 1 : 0); break;
        case "sdns": out(this.devices[this.pin(a[1], ins)] ? 0 : 1); break;
        case "yield": this.pc = next; return "yield";
        case "sleep": this.pc = next; this.ticks += Math.max(0, Math.ceil(v(0) / 0.5) - 1); return "yield";
        case "hcf": this.fail(ins, "hcf");
        default: this.fail(ins, `unknown instruction '${ins.op}'`);
      }
    }
    this.pc = next;
  }

  // Run `ticks` game ticks (a tick ends at yield/sleep or after 128 lines).
  // onTick(emu, tick) runs before each tick so tests can change sensor values.
  run({ ticks = 1, onTick, maxSteps = 1_000_000 } = {}) {
    for (let t = 0; t < ticks && !this.halted; t++) {
      if (onTick) onTick(this, this.ticks);
      let lines = 0;
      while (!this.halted) {
        if (this.steps > maxSteps) throw new IC10Error("step limit exceeded");
        const r = this.step();
        if (r === "yield" || r === "halt") break;
        if (++lines >= LINES_PER_TICK) break;
      }
      this.ticks++;
    }
    return this;
  }

  // Run until the program halts (falls off the end)
  runToEnd({ maxSteps = 100_000 } = {}) {
    while (!this.halted) {
      if (this.steps > maxSteps) throw new IC10Error("program did not halt");
      this.step();
    }
    return this;
  }

  reg(n) {
    return this.regs[n];
  }
}
