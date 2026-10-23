// JavaScript side of IC10.runtime.res: the same device model as the emulator,
// driven by ReScript code compiled to JS by the real ReScript compiler.
import { hash } from "./ic10.mjs";

export class StopSimulation extends Error {}

const num = (v) => (typeof v === "boolean" ? (v ? 1 : 0) : v);
const MODES = { Average: 0, Sum: 1, Minimum: 2, Maximum: 3 };

export class JsChip {
  constructor({ devices = {}, network = [], byId = {}, ticks = Infinity, onTick } = {}) {
    this.devices = devices;
    this.network = network;
    this.byId = byId;
    this.maxTicks = ticks;
    this.onTick = onTick;
    this.ticks = 0;
    this.writes = [];
    this.stack = new Array(512).fill(0);
    this.sp = 0;
    if (onTick) onTick(this, 0);
  }

  device(pin) {
    return { pin };
  }
  hash(s) {
    return hash(s);
  }
  batchDevice(prefab) {
    return { prefab };
  }
  namedDevice(prefab, name) {
    return { prefab, name };
  }
  lm(d, p, mode) {
    if (d.prefab === undefined) throw new Error("lm needs a batch device");
    return this.lb(d.prefab, d.name, p, mode);
  }
  resolve(d) {
    if (d.prefab !== undefined) throw new Error("a batch device has no pin");
    if (d.pin === "db") return [(this.devices.db ??= {}), "db"];
    const dev = this.devices[d.pin];
    if (!dev) throw new Error(`no device on ${d.pin}`);
    return [dev, d.pin];
  }
  read(dev, prop, label) {
    if (!(prop in dev)) throw new Error(`${label} has no logic type '${prop}'`);
    return dev[prop];
  }
  log(target, prop, value) {
    this.writes.push({ tick: this.ticks, target, prop, value });
  }
  l(d, p) {
    if (d.prefab !== undefined) return this.lb(d.prefab, d.name, p, "Maximum");
    const [dev, label] = this.resolve(d);
    return this.read(dev, p, label);
  }
  s(d, p, v) {
    if (d.prefab !== undefined) return this.sb(d.prefab, d.name, p, v);
    const [dev, label] = this.resolve(d);
    dev[p] = num(v);
    this.log(label, p, num(v));
  }
  ls(d, i, p) {
    const [dev, label] = this.resolve(d);
    return this.read(dev.slots[i], p, `${label} slot ${i}`);
  }
  ss(d, i, p, v) {
    const [dev, label] = this.resolve(d);
    dev.slots[i][p] = num(v);
    this.log(`${label}.slot${i}`, p, num(v));
  }
  isSet(d) {
    return d.pin === "db" || this.devices[d.pin] !== undefined;
  }
  batch(h, n) {
    return this.network.filter((x) => x.prefabHash === h && (n === undefined || x.nameHash === n));
  }
  lb(h, n, p, mode) {
    const values = this.batch(h, n).map((x) => this.read(x.values, p, "batch"));
    if (values.length === 0) return 0;
    switch (MODES[mode]) {
      case 0: return values.reduce((a, b) => a + b, 0) / values.length;
      case 1: return values.reduce((a, b) => a + b, 0);
      case 2: return Math.min(...values);
      case 3: return Math.max(...values);
    }
  }
  sb(h, n, p, v) {
    for (const x of this.batch(h, n)) {
      x.values[p] = num(v);
      this.log(n === undefined ? `batch ${h}` : `batch ${h}/${n}`, p, num(v));
    }
  }
  push(v) { this.stack[this.sp++] = num(v); }
  pop() { return this.stack[--this.sp]; }
  peek() { return this.stack[this.sp - 1]; }
  get(_d, a) { return this.stack[a]; }
  put(_d, a, v) { this.stack[a] = num(v); }
  idStack(id) {
    const dev = this.byId[id];
    if (!dev) throw new Error(`no device with id ${id}`);
    return (dev.stack ??= new Array(512).fill(0));
  }
  getd(id, a) { return this.idStack(id)[a]; }
  putd(id, a, v) { this.idStack(id)[a] = num(v); }

  hcf() {
    throw new StopSimulation();
  }
  approx(a, b, c) {
    return Math.abs(a - b) <= Math.max(c * Math.max(Math.abs(a), Math.abs(b)), 1.401298e-45 * 8);
  }
  approxZero(a, c) {
    return Math.abs(a) <= Math.max(c * Math.abs(a), 1.401298e-45 * 8);
  }
  yield() {
    this.ticks++;
    if (this.ticks >= this.maxTicks) throw new StopSimulation();
    if (this.onTick) this.onTick(this, this.ticks);
  }
  sleep(seconds) {
    this.ticks += Math.max(0, Math.ceil(seconds / 0.5) - 1);
    this.yield();
  }
}
