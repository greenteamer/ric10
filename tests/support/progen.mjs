// Seeded random program generator for differential testing.
//
// Programs are valid ReScript over floats: inputs come from d0..d2, every
// intermediate result of interest is written to d3, so a miscompile anywhere
// (expressions, control flow, refs, out-of-line calls, register allocation)
// shows up as a different trace. Operations whose IC10 semantics knowingly
// differ from JavaScript (int overflow, `%` on negatives, 64-bit bitwise) are
// not generated.

export function mulberry32(seed) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function generateProgram(seed) {
  const rnd = mulberry32(seed);
  const pick = (xs) => xs[Math.floor(rnd() * xs.length)];
  const chance = (p) => rnd() < p;
  const int = (lo, hi) => lo + Math.floor(rnd() * (hi - lo + 1));
  const lines = [];
  let out = 0;
  let fresh = 0;
  const name = (p) => `${p}${fresh++}`;

  const constant = () => pick(["0.5", "1.", "2.", "3.", "10.", "0.25", "7.5"]);

  // scope: {vars: [...float names], refs: [...], funs: [{name, arity}], loopVar}
  const expr = (scope, depth) => {
    if (depth <= 0 || chance(0.25)) {
      const leaves = [constant, () => pick(scope.vars)];
      if (scope.refs.length) leaves.push(() => `${pick(scope.refs)}.contents`);
      if (scope.loopVar) leaves.push(() => `Int.toFloat(${scope.loopVar})`);
      return pick(leaves)();
    }
    const e = () => expr(scope, depth - 1);
    const forms = [
      () => `(${e()} +. ${e()})`,
      () => `(${e()} -. ${e()})`,
      () => `(${e()} *. ${e()})`,
      () => `(${e()} /. ${pick(["2.", "4.", "0.5", "8."])})`,
      () => `Math.max(${e()}, ${e()})`,
      () => `Math.min(${e()}, ${e()})`,
      () => `Math.abs(${e()})`,
      () => `Math.floor(${e()})`,
      () => `(${cond(scope, depth - 1)} ? ${e()} : ${e()})`,
      () => `(-.${e()})`,
    ];
    if (scope.variant) {
      forms.push(() => {
        const v = scope.variant;
        const inner = (extra) => expr({ ...scope, vars: [...scope.vars, ...extra] }, depth - 1);
        return `(switch ${v}.contents { | A(x) => ${inner(["x"])} | B(x, y) if x > y => ${inner(["x", "y"])} | B(_, y) => ${inner(["y"])} | C => ${inner([])} })`;
      });
    }
    if (scope.funs.length) {
      forms.push(() => {
        const f = pick(scope.funs);
        return `${f.name}(${Array.from({ length: f.arity }, e).join(", ")})`;
      });
    }
    return pick(forms)();
  };

  const cond = (scope, depth) => {
    const e = () => expr(scope, Math.max(0, depth - 1));
    if (depth <= 0 || chance(0.5)) return `${e()} ${pick(["<", "<=", ">", ">=", "==", "!="])} ${e()}`;
    const c = () => cond(scope, depth - 1);
    return pick([() => `(${c()} && ${c()})`, () => `(${c()} || ${c()})`, () => `!(${c()})`])();
  };

  const emit = (indent, scope) => {
    lines.push(`${indent}s(d3, "Out${out++}", ${expr(scope, 2)})`);
  };

  const block = (indent, scope, budget) => {
    const local = { ...scope, vars: [...scope.vars] };
    for (let k = 0; k < budget; k++) {
      const choice = rnd();
      if (choice < 0.3) {
        const v = name("v");
        lines.push(`${indent}let ${v} = ${expr(local, 3)}`);
        local.vars.push(v);
      } else if (choice < 0.5 && local.refs.length) {
        lines.push(`${indent}${pick(local.refs)} := ${expr(local, 3)}`);
      } else if (choice < 0.65 && budget > 1) {
        lines.push(`${indent}if ${cond(local, 2)} {`);
        block(indent + "  ", local, int(1, 2));
        if (chance(0.6)) {
          lines.push(`${indent}} else {`);
          block(indent + "  ", local, int(1, 2));
        }
        lines.push(`${indent}}`);
      } else if (choice < 0.58 && local.variant) {
        const e = () => expr(local, 2);
        const ctor = pick([() => `A(${e()})`, () => `B(${e()}, ${e()})`, () => "C"])();
        lines.push(`${indent}${local.variant} := ${ctor}`);
      } else if (choice < 0.68 && budget > 1 && !local.loopVar) {
        const w = name("w");
        lines.push(`${indent}let ${w} = ref(0)`);
        lines.push(`${indent}while ${w}.contents < ${int(1, 3)} {`);
        block(indent + "  ", local, int(1, 2));
        lines.push(`${indent}  ${w} := ${w}.contents + 1`);
        lines.push(`${indent}}`);
      } else if (choice < 0.75 && budget > 1 && !local.loopVar) {
        const i = name("i");
        lines.push(`${indent}for ${i} in 0 to ${int(1, 3)} {`);
        block(indent + "  ", { ...local, loopVar: i }, int(1, 2));
        lines.push(`${indent}}`);
      } else {
        emit(indent, local);
      }
    }
  };

  const scope = { vars: ["a", "b", "c"], refs: [], funs: [], loopVar: null, variant: null };
  lines.push(`let a = l(d0, "Setting")`, `let b = l(d1, "Setting")`, `let c = l(d2, "Setting")`);
  if (chance(0.6)) {
    lines.push(`type sh = A(float) | B(float, float) | C`);
    lines.push(`let sv = ref(${pick(["C", "A(a)", "B(b, c)"])})`);
    scope.variant = "sv";
  }

  // functions called several times end up out of line (jal)
  for (let f = 0; f < int(1, 2); f++) {
    const fname = name("f");
    const arity = int(1, 3);
    const params = Array.from({ length: arity }, (_, i) => `p${i}`);
    const fscope = { vars: [...params, "a"], refs: [], funs: [...scope.funs], loopVar: null, variant: null };
    lines.push(`let ${fname} = (${params.join(", ")}) => {`);
    const t = name("t");
    lines.push(`  let ${t} = ${expr(fscope, 3)}`);
    lines.push(`  ${expr({ ...fscope, vars: [...fscope.vars, t] }, 3)}`);
    lines.push(`}`);
    scope.funs.push({ name: fname, arity });
  }
  for (let r = 0; r < int(1, 3); r++) {
    const rname = name("r");
    lines.push(`let ${rname} = ref(${expr(scope, 2)})`);
    scope.refs.push(rname);
  }
  block("", scope, int(4, 8));
  for (const r of scope.refs) lines.push(`s(d3, "Out${out++}", ${r}.contents)`);
  // call every function a few times so none is inlined only once
  for (const f of scope.funs) {
    for (let k = 0; k < 2; k++) {
      lines.push(`s(d3, "Out${out++}", ${f.name}(${Array.from({ length: f.arity }, () => expr(scope, 1)).join(", ")}))`);
    }
  }
  return lines.join("\n") + "\n";
}

export function inputsFor(seed) {
  const rnd = mulberry32(seed * 7919 + 1);
  const v = () => Math.round((rnd() * 200 - 100) * 4) / 4;
  return { d0: { Setting: v() }, d1: { Setting: v() }, d2: { Setting: v() }, d3: {} };
}
