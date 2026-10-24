// IR generation: AST -> IR.
//
// Design:
// - Every expression produces a `value`. Scalars live in operands (vregs or
//   immediates); variants are a tag operand plus `maxArgs` payload operands, so
//   variant values live in registers and can be bound, passed and returned.
// - `ref(...)` allocates a mutable cell (one vreg per scalar slot). Reading
//   `.contents` copies the cell; the register allocator coalesces copies away
//   whenever the cell does not change while the copy is alive.
// - Conditions are lowered straight to IC10 branches (`genCond`), never to a
//   compare + test pair.
// - Functions are inlined when called once, when tiny, or when they receive
//   compile-time values (devices, strings, refs, functions). Otherwise they are
//   compiled once into their own block and called with `jal`; argument and
//   result slots are ordinary vregs, so whole-program register allocation keeps
//   caller and callee registers apart.
// - Device pins, logic types and strings are compile-time values.

open AST

let file = "IRGen.res"

type kind = KInt | KFloat | KUnknown

type variantType = {
  typeName: string,
  ctors: array<AST.ctorDecl>,
  maxArgs: int,
}

type rec value =
  | VScalar(IR.operand, kind)
  | VVariant(variantType, IR.operand, array<IR.operand>)
  | VDevice(IR.device)
  | VString(string)
  | VUnit
  | VFun(funInfo)
  | VRef(cell)

and cell =
  | CScalar(IR.vreg, kind)
  | CVariant(variantType, IR.vreg, array<IR.vreg>)

and funInfo = {
  fname: string,
  params: array<AST.param>,
  body: AST.expr,
  env: env,
  floc: loc,
  mutable compiled: option<compiledFun>,
}

and compiledFun = {
  label: string,
  paramCells: array<cell>,
  result: option<cell>,
}

and env = Belt.Map.String.t<value>

type ctx = {
  mutable buf: array<IR.instr>,
  mutable nextVReg: int,
  mutable nextLabel: int,
  types: Dict.t<variantType>,
  ctors: Dict.t<(variantType, int)>,
  defines: Dict.t<bool>,
  defs: array<IR.instr>,
  functions: array<IR.block>,
  labels: Dict.t<bool>,
  callCounts: Dict.t<int>,
  vregNames: Dict.t<string>,
  warnings: array<Errors.t>,
  mutable active: array<string>, // functions being inlined or compiled (recursion check)
  aliases: bool, // emit `alias name pin` for top-level device bindings
}

let fail = (~fn, ~loc, ~hint=?, message) => Errors.fail(~file, ~fn, ~loc, ~hint?, message)

let warn = (ctx, ~fn, ~loc, ~hint=?, message) =>
  ctx.warnings->Array.push(Errors.warning(~file, ~fn, ~loc, ~hint?, message))

let emit = (ctx, i: IR.instr) => ctx.buf->Array.push(i)

let newVReg = (ctx, ~name=?) => {
  let v = ctx.nextVReg
  ctx.nextVReg = v + 1
  switch name {
  | Some(n) => ctx.vregNames->Dict.set(Int.toString(v), n)
  | None => ()
  }
  v
}

let newLabel = (ctx, prefix) => {
  let n = ctx.nextLabel
  ctx.nextLabel = n + 1
  let l = `${prefix}${Int.toString(n)}`
  ctx.labels->Dict.set(l, true)
  l
}

let combine = (a: kind, b: kind): kind =>
  switch (a, b) {
  | (KFloat, _) | (_, KFloat) => KFloat
  | (KInt, _) | (_, KInt) => KInt
  | _ => KUnknown
  }

let kindOfTypeName = (t: string): kind =>
  switch t {
  | "int" | "bool" => KInt
  | "float" => KFloat
  | _ => KUnknown
  }

let isRegisterLike = (name: string) => RegExp.test(/^(r\d+|d\d|db|sp|ra|dr\d+)$/, name)

let describeValue = (v: value) =>
  switch v {
  | VScalar(_) => "a number"
  | VVariant(t, _, _) => `a value of type '${t.typeName}'`
  | VDevice(_) => "a device"
  | VString(_) => "a string"
  | VUnit => "unit"
  | VFun(f) => `the function '${f.fname}'`
  | VRef(_) => "a ref (use .contents to read it)"
  }

let scalar = (v: value, ~fn, ~loc, ~what="value"): (IR.operand, kind) =>
  switch v {
  | VScalar(op, k) => (op, k)
  | other => fail(~fn, ~loc, `expected a number for ${what}, got ${describeValue(other)}`)
  }

// ---------------------------------------------------------------------------
// Cells (mutable storage behind refs, function parameters and results)

let cellFor = (ctx, v: value, ~fn, ~loc, ~name=?): cell =>
  switch v {
  | VScalar(_, k) => CScalar(newVReg(ctx, ~name?), k)
  | VVariant(t, _, _) =>
    let tag = newVReg(ctx, ~name?)
    let payload = Array.fromInitializer(~length=t.maxArgs, _ => newVReg(ctx, ~name?))
    CVariant(t, tag, payload)
  | other => fail(~fn, ~loc, `cannot store ${describeValue(other)} in a register`)
  }

let ctorArity = (t: variantType, tag: int) =>
  switch t.ctors[tag] {
  | Some(c) => Array.length(c.argTypes)
  | None => t.maxArgs
  }

let storeCell = (ctx, c: cell, v: value, ~fn, ~loc) =>
  switch (c, v) {
  | (CScalar(dst, _), VScalar(op, _)) => emit(ctx, Move(dst, op))
  | (CVariant(t, tagReg, payloadRegs), VVariant(t2, tag, payload)) if t.typeName == t2.typeName =>
    emit(ctx, Move(tagReg, tag))
    let slots = switch tag {
    | Num(n) => ctorArity(t, Float.toInt(n))
    | _ => t.maxArgs
    }
    for i in 0 to slots - 1 {
      emit(ctx, Move(payloadRegs->Array.getUnsafe(i), payload->Array.getUnsafe(i)))
    }
  | (CScalar(_), other) => fail(~fn, ~loc, `expected a number, got ${describeValue(other)}`)
  | (CVariant(t, _, _), other) =>
    fail(~fn, ~loc, `expected a value of type '${t.typeName}', got ${describeValue(other)}`)
  }

// Read a cell into fresh registers (the cell may change later)
let loadCell = (ctx, c: cell): value =>
  switch c {
  | CScalar(src, k) =>
    let d = newVReg(ctx)
    emit(ctx, Move(d, VReg(src)))
    VScalar(VReg(d), k)
  | CVariant(t, tagReg, payloadRegs) =>
    let tag = newVReg(ctx)
    emit(ctx, Move(tag, VReg(tagReg)))
    let payload = payloadRegs->Array.map(r => {
      let d = newVReg(ctx)
      emit(ctx, Move(d, VReg(r)))
      IR.VReg(d)
    })
    VVariant(t, VReg(tag), payload)
  }

// View a cell as a value without copying (for slots that are stable while used)
let viewCell = (c: cell): value =>
  switch c {
  | CScalar(r, k) => VScalar(VReg(r), k)
  | CVariant(t, tag, payload) => VVariant(t, VReg(tag), payload->Array.map(r => IR.VReg(r)))
  }

let sameShape = (c: cell, v: value) =>
  switch (c, v) {
  | (CScalar(_), VScalar(_)) => true
  | (CVariant(t, _, _), VVariant(t2, _, _)) => t.typeName == t2.typeName
  | _ => false
  }

// ---------------------------------------------------------------------------
// AST helpers

let rec astSize = (e: expr): int =>
  switch e.desc {
  | Number(_) | Bool(_) | String(_) | Unit | Ident(_) | Raw(_) => 1
  | Constructor(_, args) | Call(_, args) => 1 + args->Array.reduce(0, (acc, a) => acc + astSize(a))
  | Unary(_, a) | Deref(a) | Fun(_, a) | Labeled(_, a) => 1 + astSize(a)
  | Binary(_, a, b) | Assign(a, b) | While(a, b) => 1 + astSize(a) + astSize(b)
  | If(c, t, el) => 1 + astSize(c) + astSize(t) + el->Option.mapOr(0, astSize)
  | For(_, a, b, _, c) => 1 + astSize(a) + astSize(b) + astSize(c)
  | Block(stmts) => stmts->Array.reduce(0, (acc, s) => acc + stmtSize(s))
  | Switch(s, cases) =>
    1 + astSize(s) + cases->Array.reduce(0, (acc, c) => acc + 1 + astSize(c.body))
  }
and stmtSize = s =>
  switch s {
  | Let(_, e, _) => astSize(e)
  | TypeDecl(_) | Open(_) => 0
  | Module(_, stmts, _) => stmts->Array.reduce(0, (acc, s) => acc + stmtSize(s))
  | Expr(e) => astSize(e)
  }

let rec countCalls = (counts: Dict.t<int>, e: expr) => {
  let go = countCalls(counts, ...)
  switch e.desc {
  | Call(name, args) =>
    counts->Dict.set(name, counts->Dict.get(name)->Option.getOr(0) + 1)
    args->Array.forEach(go)
  | Number(_) | Bool(_) | String(_) | Unit | Ident(_) | Raw(_) => ()
  | Constructor(_, args) => args->Array.forEach(go)
  | Unary(_, a) | Deref(a) | Fun(_, a) | Labeled(_, a) => go(a)
  | Binary(_, a, b) | Assign(a, b) | While(a, b) =>
    go(a)
    go(b)
  | If(c, t, el) =>
    go(c)
    go(t)
    el->Option.forEach(go)
  | For(_, a, b, _, c) =>
    go(a)
    go(b)
    go(c)
  | Block(stmts) => stmts->Array.forEach(s => countCallsStmt(counts, s))
  | Switch(s, cases) =>
    go(s)
    cases->Array.forEach(c => {
      c.guard->Option.forEach(go)
      go(c.body)
    })
  }
}
and countCallsStmt = (counts, s) =>
  switch s {
  | Let(_, e, _) | Expr(e) => countCalls(counts, e)
  | TypeDecl(_) | Open(_) => ()
  | Module(_, stmts, _) => stmts->Array.forEach(s => countCallsStmt(counts, s))
  }

// Builtins without side effects (safe to evaluate eagerly, e.g. in `select`)
let pureBuiltins = [
  "l",
  "lb",
  "lbn",
  "ls",
  "lbs",
  "lbns",
  "lr",
  "hash",
  "device",
  "isSet",
  "isNotSet",
  "abs",
  "sqrt",
  "floor",
  "ceil",
  "round",
  "trunc",
  "sin",
  "cos",
  "tan",
  "asin",
  "acos",
  "atan",
  "atan2",
  "exp",
  "log",
  "min",
  "max",
  "select",
  "lerp",
  "toFloat",
  "toInt",
  "pow",
  "log10",
  "log2",
  "cbrt",
  "sign",
  "hypot",
  "clamp",
  "mod",
  "isNaN",
  "equal",
  "bitAnd",
  "bitOr",
  "bitXor",
  "bitNot",
  "shiftLeft",
  "shiftRight",
  "shiftRightUnsigned",
  "approx",
  "approxZero",
]

// Strip module qualifiers the bindings may be called through
let normalizeBuiltin = (name: string): string =>
  switch name {
  | "Math.abs" | "Math.Int.abs" => "abs"
  | "Math.sqrt" => "sqrt"
  | "Math.floor" => "floor"
  | "Math.ceil" => "ceil"
  | "Math.round" => "round"
  | "Math.trunc" => "trunc"
  | "Math.sin" => "sin"
  | "Math.cos" => "cos"
  | "Math.tan" => "tan"
  | "Math.asin" => "asin"
  | "Math.acos" => "acos"
  | "Math.atan" => "atan"
  | "Math.atan2" => "atan2"
  | "Math.exp" => "exp"
  | "Math.log" => "log"
  | "Math.min" | "Math.Int.min" => "min"
  | "Math.max" | "Math.Int.max" => "max"
  | "Math.random" => "rand"
  | "Int.toFloat" | "Float.fromInt" => "toFloat"
  | "Float.toInt" | "Int.fromFloat" => "toInt"
  | "Math.Int.floor" => "floor"
  | "Math.Int.ceil" => "ceil"
  | "Math.Int.round" => "round"
  | "Math.Int.trunc" => "trunc"
  | "Math.pow" | "Math.Int.pow" => "pow"
  | "Math.log10" => "log10"
  | "Math.log2" => "log2"
  | "Math.cbrt" => "cbrt"
  | "Math.sign" => "sign"
  | "Math.hypot" => "hypot"
  | "Float.clamp" | "Int.clamp" => "clamp"
  | "Float.mod" | "Int.mod" | "mod" => "mod"
  | "Float.isNaN" => "isNaN"
  | "Float.equal" | "Int.equal" => "equal"
  | "Int.bitwiseAnd" | "land" => "bitAnd"
  | "Int.bitwiseOr" | "lor" => "bitOr"
  | "Int.bitwiseXor" | "lxor" => "bitXor"
  | "Int.bitwiseNot" | "lnot" => "bitNot"
  | "Int.shiftLeft" | "lsl" => "shiftLeft"
  | "Int.shiftRight" | "asr" => "shiftRight"
  | "Int.shiftRightUnsigned" | "lsr" => "shiftRightUnsigned"
  | other =>
    if other->String.startsWith("IC10.") {
      other->String.sliceToEnd(~start=5)
    } else {
      other
    }
  }

// `Logic.temperature` -> ("l", "Temperature", false), `Slot.setOccupied` -> ("ss", "Occupied", true)
let accessor = (name: string): option<(string, string, bool)> => {
  let decode = (acc: string, read: string, write: string) => {
    // setX is a setter only when X is capitalised: Logic.setting reads Setting
    let isUpper = c => c != "" && c == String.toUpperCase(c) && c != String.toLowerCase(c)
    let (isSet, base) = if acc->String.startsWith("set") && isUpper(String.charAt(acc, 3)) {
      (true, acc->String.sliceToEnd(~start=3))
    } else {
      (false, acc)
    }
    let base = base->String.endsWith("_") ? base->String.slice(~start=0, ~end=String.length(base) - 1) : base
    if String.length(base) == 0 {
      None
    } else {
      let logicType = isSet ? base : String.toUpperCase(String.charAt(base, 0)) ++ base->String.sliceToEnd(~start=1)
      Some((isSet ? write : read, logicType, isSet))
    }
  }
  if name->String.startsWith("Logic.") {
    decode(name->String.sliceToEnd(~start=6), "l", "s")
  } else if name->String.startsWith("Slot.") {
    decode(name->String.sliceToEnd(~start=5), "ls", "ss")
  } else if name->String.startsWith("IC10.Logic.") {
    decode(name->String.sliceToEnd(~start=11), "l", "s")
  } else if name->String.startsWith("IC10.Slot.") {
    decode(name->String.sliceToEnd(~start=10), "ls", "ss")
  } else {
    None
  }
}

// "Furnace.Idle" -> Some("Idle"); "Furnace.temperature" -> None
let qualifiedCtor = (name: string): option<string> =>
  switch name->String.lastIndexOf(".") {
  | -1 => None
  | i =>
    let last = name->String.sliceToEnd(~start=i + 1)
    let c = String.charAt(last, 0)
    c >= "A" && c <= "Z" ? Some(last) : None
  }

let rec isPure = (env: env, e: expr): bool => {
  let go = isPure(env, ...)
  switch e.desc {
  | Number(_) | Bool(_) | String(_) | Unit | Ident(_) => true
  | Constructor(_, args) => args->Array.every(go)
  | Unary(_, a) | Deref(a) | Labeled(_, a) => go(a)
  | Binary(_, a, b) => go(a) && go(b)
  | If(c, t, Some(el)) => go(c) && go(t) && go(el)
  | Block([Expr(x)]) => go(x)
  | Call(name, args) =>
    switch env->Belt.Map.String.get(name) {
    | Some(_) => false
    | None =>
      switch accessor(name) {
      | Some((_, _, false)) => args->Array.every(go)
      | Some((_, _, true)) => false
      | None => pureBuiltins->Array.includes(normalizeBuiltin(name)) && args->Array.every(go)
      }
    }
  | If(_, _, None)
  | Block(_)
  | Switch(_)
  | While(_)
  | For(_)
  | Assign(_)
  | Fun(_)
  | Raw(_) => false
  }
}

let rec unwrapBlock = (e: expr): expr =>
  switch e.desc {
  | Block([Expr(x)]) => unwrapBlock(x)
  | _ => e
  }

let tokenRe = /^[A-Za-z][A-Za-z0-9_]*$/

// ---------------------------------------------------------------------------
// Expressions

let rec gen = (ctx, env: env, e: expr, ~want: bool): value => {
  let fn = "gen"
  switch e.desc {
  | Number(n, isFloat) => VScalar(Num(n), isFloat ? KFloat : KInt)
  | Bool(b) => VScalar(Num(b ? 1. : 0.), KInt)
  | String(s) => VString(s)
  | Unit => VUnit
  | Ident(name) =>
    switch (env->Belt.Map.String.get(name), qualifiedCtor(name)) {
    | (None, Some(ctor)) => genConstructor(ctx, env, ctor, [], e.loc)
    | _ => lookup(env, name, e.loc)
    }
  | Constructor(name, args) => genConstructor(ctx, env, name, args, e.loc)
  | Unary(op, a) => genUnary(ctx, env, op, a, e.loc)
  | Binary(And | Or, _, _) => genLogicalValue(ctx, env, e)
  | Binary(op, a, b) => genBinary(ctx, env, op, a, b, e.loc)
  | Call(name, args) => genCall(ctx, env, name, args, e.loc, ~want)
  | If(c, t, el) => genIf(ctx, env, c, t, el, ~want, ~loc=e.loc)
  | Block(stmts) => genBlock(ctx, env, stmts, ~want, ~topLevel=false)
  | Switch(s, cases) => genSwitch(ctx, env, s, cases, ~want, ~loc=e.loc)
  | While(c, body) =>
    let top = newLabel(ctx, "while")
    let exit = newLabel(ctx, "endwhile")
    emit(ctx, Label(top))
    genCond(ctx, env, c, exit)
    let _ = gen(ctx, env, body, ~want=false)
    emit(ctx, Goto(top))
    emit(ctx, Label(exit))
    VUnit
  | For(var, from, to_, down, body) =>
    let (fromOp, _) = scalar(
      gen(ctx, env, from, ~want=true),
      ~fn,
      ~loc=from.loc,
      ~what="loop start",
    )
    let (toOp, _) = scalar(gen(ctx, env, to_, ~want=true), ~fn, ~loc=to_.loc, ~what="loop end")
    let i = newVReg(ctx, ~name=var)
    emit(ctx, Move(i, fromOp))
    let top = newLabel(ctx, "for")
    let exit = newLabel(ctx, "endfor")
    emit(ctx, Label(top))
    emit(ctx, Branch(down ? Lt : Gt, VReg(i), toOp, exit))
    let _ = gen(ctx, env->Belt.Map.String.set(var, VScalar(VReg(i), KInt)), body, ~want=false)
    emit(ctx, Binary(i, down ? Sub : Add, VReg(i), Num(1.)))
    emit(ctx, Goto(top))
    emit(ctx, Label(exit))
    VUnit
  | Deref(target) =>
    switch gen(ctx, env, target, ~want=true) {
    | VRef(c) => loadCell(ctx, c)
    | other => fail(~fn, ~loc=e.loc, `.contents expects a ref, got ${describeValue(other)}`)
    }
  | Assign(target, valueExpr) =>
    let refExpr = switch target.desc {
    | Deref(inner) => inner
    | _ => target
    }
    let c = switch gen(ctx, env, refExpr, ~want=true) {
    | VRef(c) => c
    | other =>
      fail(
        ~fn,
        ~loc=target.loc,
        `cannot assign to ${describeValue(other)}`,
        ~hint="only refs are mutable: let x = ref(0); x := 1",
      )
    }
    let v = gen(ctx, env, valueExpr, ~want=true)
    storeCell(ctx, c, v, ~fn, ~loc=valueExpr.loc)
    VUnit
  | Fun(_) =>
    fail(~fn, ~loc=e.loc, "anonymous functions are only supported as `let name = (...) => ...`")
  | Labeled(name, _) =>
    fail(~fn, ~loc=e.loc, `labeled argument ~${name} is only allowed inside a function call`)
  | Raw(text) =>
    emit(ctx, Raw(text))
    VUnit
  }
}

and lookup = (env: env, name: string, loc): value =>
  switch env->Belt.Map.String.get(name) {
  | Some(v) => v
  | None =>
    switch name {
    | "d0" | "d1" | "d2" | "d3" | "d4" | "d5" | "db" => VDevice(Pin(name))
    | _ if name->String.startsWith("Prefab.") || name->String.startsWith("IC10.Prefab.") =>
      let acc = name->String.sliceToEnd(~start=String.lastIndexOf(name, ".") + 1)
      switch PrefabTable.table->Dict.get(acc) {
      | Some(("", h)) => VScalar(Num(h), KInt)
      | Some((prefab, _)) => VScalar(Hash(prefab), KInt)
      | None =>
        fail(
          ~fn="lookup",
          ~loc,
          `unknown prefab '${acc}'`,
          ~hint="Prefab names are the game's prefab names in lowerCamelCase, e.g. Prefab.structureTankSmall",
        )
      }
    | "Math.Constants.pi" => VScalar(Num(Math.Constants.pi), KFloat)
    | "Math.Constants.e" => VScalar(Num(Math.Constants.e), KFloat)
    | _ =>
      let hint = if pureBuiltins->Array.includes(normalizeBuiltin(name)) {
        Some(`'${name}' is a builtin function; call it with arguments`)
      } else {
        None
      }
      fail(~fn="lookup", ~loc, ~hint?, `unknown identifier '${name}'`)
    }
  }

and genConstructor = (ctx, env, name, args: array<expr>, loc): value => {
  let fn = "genConstructor"
  switch ctx.ctors->Dict.get(name) {
  | Some((t, tag)) =>
    let arity = ctorArity(t, tag)
    if Array.length(args) != arity {
      fail(
        ~fn,
        ~loc,
        `constructor ${name} expects ${Int.toString(arity)} argument(s), got ${Int.toString(
            Array.length(args),
          )}`,
      )
    }
    let payload = Array.fromInitializer(~length=t.maxArgs, i =>
      switch args[i] {
      | Some(a) =>
        let (op, _) = scalar(
          gen(ctx, env, a, ~want=true),
          ~fn,
          ~loc=a.loc,
          ~what="constructor payload",
        )
        op
      | None => IR.Num(0.)
      }
    )
    VVariant(t, Num(Int.toFloat(tag)), payload)
  | None =>
    switch name {
    | "Average" | "Sum" | "Minimum" | "Maximum" =>
      fail(~fn, ~loc, `batch mode ${name} can only be used as an argument of lb/lbn/lbs/lbns`)
    | "None" | "Some" | "Ok" | "Error" =>
      fail(~fn, ~loc, `${name}: option/result are not supported`)
    | _ =>
      fail(~fn, ~loc, `unknown constructor '${name}'`, ~hint="declare it: type t = A | B(float)")
    }
  }
}

and genUnary = (ctx, env, op: unop, a: expr, loc): value => {
  let fn = "genUnary"
  let inverse = (op: binop): option<binop> =>
    switch op {
    | Lt => Some(Ge)
    | Le => Some(Gt)
    | Gt => Some(Le)
    | Ge => Some(Lt)
    | Eq => Some(Ne)
    | Ne => Some(Eq)
    | _ => None
    }
  switch (op, a.desc) {
  // !(a < b) is a single `sge`
  | (Not, Binary(cmp, x, y)) if inverse(cmp) != None =>
    genBinary(ctx, env, inverse(cmp)->Option.getOrThrow, x, y, loc)
  | _ =>
    let (o, k) = scalar(gen(ctx, env, a, ~want=true), ~fn, ~loc)
    switch op {
    | Neg =>
      switch o {
      | Num(n) => VScalar(Num(-.n), k)
      | _ =>
        let d = newVReg(ctx)
        emit(ctx, Binary(d, Sub, Num(0.), o))
        VScalar(VReg(d), k)
      }
    | Not =>
      let d = newVReg(ctx)
      emit(ctx, Compare(d, Eq, o, Num(0.)))
      VScalar(VReg(d), KInt)
    | BitNot =>
      let d = newVReg(ctx)
      emit(ctx, Unary(d, BitNot, o))
      VScalar(VReg(d), KInt)
    }
  }
}

// Operands of a comparison, such that `left CMP right` is the condition.
// Variant equality compares tags (and payloads when the constructor is known).
and comparison = (ctx, env, op: binop, a: expr, b: expr, loc): (
  IR.cmpOp,
  IR.operand,
  IR.operand,
) => {
  let fn = "comparison"
  let va = gen(ctx, env, a, ~want=true)
  let vb = gen(ctx, env, b, ~want=true)
  switch (va, vb) {
  | (VScalar(oa, _), VScalar(ob, _)) => (cmpOf(op), oa, ob)
  | (VVariant(t1, tagA, pa), VVariant(t2, tagB, pb)) if t1.typeName == t2.typeName =>
    if op != Eq && op != Ne {
      fail(~fn, ~loc, "variants can only be compared with == and !=")
    }
    if t1.maxArgs == 0 {
      (cmpOf(op), tagA, tagB)
    } else {
      let slots = switch (tagA, tagB) {
      | (Num(k), _) | (_, Num(k)) => ctorArity(t1, Float.toInt(k))
      | _ =>
        fail(
          ~fn,
          ~loc,
          "comparing two variant values with payloads is not supported",
          ~hint="compare against a constructor, or use switch",
        )
      }
      if slots == 0 {
        (cmpOf(op), tagA, tagB)
      } else {
        let acc = newVReg(ctx)
        emit(ctx, Compare(acc, Eq, tagA, tagB))
        for i in 0 to slots - 1 {
          let e = newVReg(ctx)
          emit(ctx, Compare(e, Eq, pa->Array.getUnsafe(i), pb->Array.getUnsafe(i)))
          emit(ctx, Binary(acc, And, VReg(acc), VReg(e)))
        }
        (op == Eq ? Ne : Eq, VReg(acc), Num(0.))
      }
    }
  | (VScalar(_), other) | (other, _) => fail(~fn, ~loc, `cannot compare ${describeValue(other)}`)
  }
}

and genBinary = (ctx, env, op: binop, a: expr, b: expr, loc): value =>
  switch op {
  | Lt | Le | Gt | Ge | Eq | Ne =>
    let (c, oa, ob) = comparison(ctx, env, op, a, b, loc)
    let d = newVReg(ctx)
    emit(ctx, Compare(d, c, oa, ob))
    VScalar(VReg(d), KInt)
  | _ => genArith(ctx, env, op, a, b, loc)
  }

and genArith = (ctx, env, op: binop, a: expr, b: expr, loc): value => {
  let fn = "genArith"
  let (oa, ka) = scalar(gen(ctx, env, a, ~want=true), ~fn, ~loc=a.loc)
  let (ob, kb) = scalar(gen(ctx, env, b, ~want=true), ~fn, ~loc=b.loc)
  let k = combine(ka, kb)
  let bin = (irOp, kind) => {
    let d = newVReg(ctx)
    emit(ctx, Binary(d, irOp, oa, ob))
    VScalar(VReg(d), kind)
  }
  let cmp = irOp => {
    let d = newVReg(ctx)
    emit(ctx, Compare(d, irOp, oa, ob))
    VScalar(VReg(d), KInt)
  }
  switch op {
  | Add => bin(Add, k)
  | Sub => bin(Sub, k)
  | Mul => bin(Mul, k)
  | Div =>
    switch bin(Div, k) {
    | VScalar(VReg(q), KInt) =>
      // ReScript int division truncates; IC10 `div` does not
      let t = newVReg(ctx)
      emit(ctx, Unary(t, Trunc, VReg(q)))
      VScalar(VReg(t), KInt)
    | v => v
    }
  | Mod => bin(Mod, k)
  | Pow => genPow(ctx, oa, ob, k)
  | Lt => cmp(Lt)
  | Le => cmp(Le)
  | Gt => cmp(Gt)
  | Ge => cmp(Ge)
  | Eq => cmp(Eq)
  | Ne => cmp(Ne)
  | BitAnd => bin(And, KInt)
  | BitOr => bin(Or, KInt)
  | BitXor => bin(Xor, KInt)
  | Shl => bin(Sll, KInt)
  | Shr => bin(Sra, KInt)
  | Ushr => bin(Srl, KInt)
  | And | Or => fail(~fn, ~loc, "internal error: logical operator reached genBinary")
  }
}

and genPow = (ctx, base: IR.operand, exponent: IR.operand, k: kind): value => {
  switch exponent {
  | Num(0.) => VScalar(Num(1.), k)
  | Num(1.) => VScalar(base, k)
  | Num(0.5) =>
    let d = newVReg(ctx)
    emit(ctx, Unary(d, Sqrt, base))
    VScalar(VReg(d), k)
  | Num(n) if NumUtil.isInteger(n) && n >= 2. && n <= 4. =>
    let acc = ref(base)
    for _ in 2 to Float.toInt(n) {
      let d = newVReg(ctx)
      emit(ctx, Binary(d, Mul, acc.contents, base))
      acc := VReg(d)
    }
    VScalar(acc.contents, k)
  | _ =>
    // a ** b = exp(b * log(a))
    let lg = newVReg(ctx)
    emit(ctx, Unary(lg, Log, base))
    let m = newVReg(ctx)
    emit(ctx, Binary(m, Mul, exponent, VReg(lg)))
    let r = newVReg(ctx)
    emit(ctx, Unary(r, Exp, VReg(m)))
    if k == KInt {
      let rr = newVReg(ctx)
      emit(ctx, Unary(rr, Round, VReg(r)))
      VScalar(VReg(rr), k)
    } else {
      VScalar(VReg(r), k)
    }
  }
}

// `a && b` / `a || b` used as a value
and genLogicalValue = (ctx, env, e: expr): value => {
  let fn = "genLogicalValue"
  switch e.desc {
  | Binary((And | Or) as op, a, b) =>
    if isPure(env, b) {
      let (oa, _) = scalar(gen(ctx, env, a, ~want=true), ~fn, ~loc=a.loc)
      let (ob, _) = scalar(gen(ctx, env, b, ~want=true), ~fn, ~loc=b.loc)
      let d = newVReg(ctx)
      emit(ctx, Binary(d, op == And ? And : Or, oa, ob))
      VScalar(VReg(d), KInt)
    } else {
      // short-circuit: evaluate b only when needed
      let d = newVReg(ctx)
      let done = newLabel(ctx, op == And ? "and" : "or")
      emit(ctx, Move(d, Num(op == And ? 0. : 1.)))
      if op == And {
        genCond(ctx, env, a, done)
      } else {
        genCondTrue(ctx, env, a, done)
      }
      let (ob, _) = scalar(gen(ctx, env, b, ~want=true), ~fn, ~loc=b.loc)
      emit(ctx, Move(d, ob))
      emit(ctx, Label(done))
      VScalar(VReg(d), KInt)
    }
  | _ => gen(ctx, env, e, ~want=true)
  }
}

// Jump to `falseLabel` when `e` is false; fall through when true
and genCond = (ctx, env, e: expr, falseLabel: string) => {
  let fn = "genCond"
  switch e.desc {
  | Bool(true) => ()
  | Bool(false) => emit(ctx, Goto(falseLabel))
  | Unary(Not, a) => genCondTrue(ctx, env, a, falseLabel)
  | Binary(And, a, b) =>
    genCond(ctx, env, a, falseLabel)
    genCond(ctx, env, b, falseLabel)
  | Binary(Or, a, b) =>
    let ok = newLabel(ctx, "or")
    genCondTrue(ctx, env, a, ok)
    genCond(ctx, env, b, falseLabel)
    emit(ctx, Label(ok))
  | Binary((Lt | Le | Gt | Ge | Eq | Ne) as op, a, b) =>
    let (c, oa, ob) = comparison(ctx, env, op, a, b, e.loc)
    emit(ctx, Branch(IR.invertCmp(c), oa, ob, falseLabel))
  | Call(_) if specialBranch(ctx, env, e, ~negate=true, falseLabel) => ()
  | _ =>
    let (o, _) = scalar(gen(ctx, env, e, ~want=true), ~fn, ~loc=e.loc, ~what="condition")
    emit(ctx, Branch(Eq, o, Num(0.), falseLabel))
  }
}

// Conditions with a dedicated IC10 branch: isSet/isNotSet (bdse/bdns), isNaN (bnan),
// approx (bap/bna), approxZero (bapz/bnaz). `negate`: jump when the condition is false.
// Returns false when `e` is not such a call (nothing emitted).
and specialBranch = (ctx, env, e: expr, ~negate: bool, label: string): bool => {
  let fn = "specialBranch"
  switch e.desc {
  | Call(name, args) if env->Belt.Map.String.get(name) == None =>
    let positional = args->Array.filter(a =>
      switch a.desc {
      | Labeled(_) => false
      | _ => true
      }
    )
    let pinOf = a =>
      switch gen(ctx, env, a, ~want=true) {
      | VDevice(Pin(p)) => p
      | other => fail(~fn, ~loc=a.loc, `expected a device pin, got ${describeValue(other)}`)
      }
    let num = a => fst(scalar(gen(ctx, env, a, ~want=true), ~fn, ~loc=a.loc))
    switch (normalizeBuiltin(name), positional) {
    | ("isSet", [d]) =>
      emit(ctx, BranchIf(negate ? "bdns" : "bdse", [ADev(pinOf(d))], label))
      true
    | ("isNotSet", [d]) =>
      emit(ctx, BranchIf(negate ? "bdse" : "bdns", [ADev(pinOf(d))], label))
      true
    | ("isNaN", [x]) if !negate =>
      emit(ctx, BranchIf("bnan", [AOp(num(x))], label))
      true
    | ("approx", [a, b, eps]) =>
      let (oa, ob, oe) = (num(a), num(b), num(eps))
      emit(ctx, BranchIf(negate ? "bna" : "bap", [AOp(oa), AOp(ob), AOp(oe)], label))
      true
    | ("approxZero", [a, eps]) =>
      let (oa, oe) = (num(a), num(eps))
      emit(ctx, BranchIf(negate ? "bnaz" : "bapz", [AOp(oa), AOp(oe)], label))
      true
    | _ => false
    }
  | _ => false
  }
}

// Jump to `trueLabel` when `e` is true; fall through when false
and genCondTrue = (ctx, env, e: expr, trueLabel: string) => {
  let fn = "genCondTrue"
  switch e.desc {
  | Bool(true) => emit(ctx, Goto(trueLabel))
  | Bool(false) => ()
  | Unary(Not, a) => genCond(ctx, env, a, trueLabel)
  | Binary(Or, a, b) =>
    genCondTrue(ctx, env, a, trueLabel)
    genCondTrue(ctx, env, b, trueLabel)
  | Binary(And, a, b) =>
    let skip = newLabel(ctx, "and")
    genCond(ctx, env, a, skip)
    genCondTrue(ctx, env, b, trueLabel)
    emit(ctx, Label(skip))
  | Binary((Lt | Le | Gt | Ge | Eq | Ne) as op, a, b) =>
    let (c, oa, ob) = comparison(ctx, env, op, a, b, e.loc)
    emit(ctx, Branch(c, oa, ob, trueLabel))
  | Call(_) if specialBranch(ctx, env, e, ~negate=false, trueLabel) => ()
  | _ =>
    let (o, _) = scalar(gen(ctx, env, e, ~want=true), ~fn, ~loc=e.loc, ~what="condition")
    emit(ctx, Branch(Ne, o, Num(0.), trueLabel))
  }
}

and cmpOf = (op: binop): IR.cmpOp =>
  switch op {
  | Lt => Lt
  | Le => Le
  | Gt => Gt
  | Ge => Ge
  | Eq => Eq
  | _ => Ne
  }

// Result storage shared by the branches of if/switch
and mergeInto = (ctx, result: ref<option<cell>>, v: value, ~unitResult: ref<bool>, ~fn, ~loc) =>
  switch v {
  | VUnit => unitResult := true
  | VScalar(_) | VVariant(_) =>
    let c = switch result.contents {
    | Some(c) =>
      if !sameShape(c, v) {
        fail(~fn, ~loc, `branches return different types (${describeValue(v)})`)
      }
      c
    | None =>
      let c = cellFor(ctx, v, ~fn, ~loc)
      result := Some(c)
      c
    }
    storeCell(ctx, c, v, ~fn, ~loc)
  | other => fail(~fn, ~loc, `a branch cannot return ${describeValue(other)}`)
  }

and resultValue = (result: ref<option<cell>>, unitResult: ref<bool>): value =>
  switch result.contents {
  | Some(c) if !unitResult.contents => viewCell(c)
  | _ => VUnit
  }

and isSimpleScalar = (env: env, e: expr): bool => {
  let e = unwrapBlock(e)
  switch e.desc {
  | Number(_) | Bool(_) => true
  | Ident(name) =>
    switch env->Belt.Map.String.get(name) {
    | Some(VScalar(_)) => true
    | _ => false
    }
  | Unary(Neg, a) => isSimpleScalar(env, a)
  | Binary(Add | Sub | Mul, a, b) =>
    astSize(e) <= 3 && isSimpleScalar(env, a) && isSimpleScalar(env, b)
  | _ => false
  }
}

and genIf = (ctx, env, c: expr, t: expr, el: option<expr>, ~want, ~loc): value => {
  let fn = "genIf"
  let literalBool = (e: expr) =>
    switch unwrapBlock(e).desc {
    | Number(1., false) | Bool(true) => Some(true)
    | Number(0., false) | Bool(false) => Some(false)
    | _ => None
    }
  switch el {
  // `c ? 1 : 0` is the condition itself, `c ? 0 : 1` its negation
  | Some(elseE) if want && literalBool(t) == Some(true) && literalBool(elseE) == Some(false) =>
    genCondValue(ctx, env, c)
  | Some(elseE) if want && literalBool(t) == Some(false) && literalBool(elseE) == Some(true) =>
    genCondValue(ctx, env, {...c, desc: Unary(Not, c)})
  | Some(elseE) if want && isPure(env, c) && isSimpleScalar(env, t) && isSimpleScalar(env, elseE) =>
    // branch-free: select dst cond a b
    let (oc, _) = scalar(genCondValue(ctx, env, c), ~fn, ~loc=c.loc, ~what="condition")
    let (oa, ka) = scalar(gen(ctx, env, unwrapBlock(t), ~want=true), ~fn, ~loc=t.loc)
    let (ob, kb) = scalar(gen(ctx, env, unwrapBlock(elseE), ~want=true), ~fn, ~loc=elseE.loc)
    let d = newVReg(ctx)
    emit(ctx, Select(d, oc, oa, ob))
    VScalar(VReg(d), combine(ka, kb))
  | _ =>
    let elseL = newLabel(ctx, "else")
    genCond(ctx, env, c, elseL)
    let result = ref(None)
    let unitResult = ref(false)
    let tv = gen(ctx, env, t, ~want)
    if want {
      mergeInto(ctx, result, tv, ~unitResult, ~fn, ~loc=t.loc)
    }
    switch el {
    | None =>
      emit(ctx, Label(elseL))
      VUnit
    | Some(elseE) =>
      let endL = newLabel(ctx, "endif")
      emit(ctx, Goto(endL))
      emit(ctx, Label(elseL))
      let ev = gen(ctx, env, elseE, ~want)
      if want {
        mergeInto(ctx, result, ev, ~unitResult, ~fn, ~loc=elseE.loc)
      }
      emit(ctx, Label(endL))
      want ? resultValue(result, unitResult) : VUnit
    }
  }
}

// Condition as a 0/1 value
and genCondValue = (ctx, env, c: expr): value =>
  switch c.desc {
  | Binary(And | Or, _, _) => genLogicalValue(ctx, env, c)
  | _ => gen(ctx, env, c, ~want=true)
  }

and genBlock = (ctx, env, stmts: array<stmt>, ~want, ~topLevel): value => {
  let (v, _, _) = genStmts(ctx, env, stmts, ~want, ~topLevel, ~prefix="")
  v
}

// Returns the block's value, the environment after it and the names it bound.
// `prefix` ("Furnace.") qualifies function and define names declared inside a module.
and genStmts = (ctx, env, stmts: array<stmt>, ~want, ~topLevel, ~prefix): (
  value,
  env,
  array<string>,
) => {
  let fn = "genStmts"
  let envRef = ref(env)
  let bound = []
  let bind = (name, v) => {
    envRef := envRef.contents->Belt.Map.String.set(name, v)
    if !(bound->Array.includes(name)) {
      bound->Array.push(name)
    }
  }
  let last = ref(VUnit)
  let n = Array.length(stmts)
  stmts->Array.forEachWithIndex((s, i) => {
    let isLast = i == n - 1
    switch s {
    | Let(name, valueExpr, loc) =>
      bind(name, genLet(ctx, envRef.contents, name, valueExpr, loc, ~topLevel, ~prefix))
      last := VUnit
    | TypeDecl(name, ctors, loc) =>
      registerType(ctx, name, ctors, loc)
      last := VUnit
    | Module(name, inner, _) =>
      let (_, innerEnv, names) = genStmts(
        ctx,
        envRef.contents,
        inner,
        ~want=false,
        ~topLevel,
        ~prefix=prefix ++ name ++ ".",
      )
      names->Array.forEach(n =>
        switch innerEnv->Belt.Map.String.get(n) {
        | Some(v) => bind(name ++ "." ++ n, v)
        | None => ()
        }
      )
      last := VUnit
    | Open(name, loc) =>
      if name != "IC10" {
        let p = name ++ "."
        let found = ref(false)
        envRef.contents->Belt.Map.String.forEach((k, v) =>
          if k->String.startsWith(p) {
            found := true
            bind(k->String.sliceToEnd(~start=String.length(p)), v)
          }
        )
        if !found.contents {
          fail(~fn, ~loc, `unknown module '${name}'`)
        }
      }
      last := VUnit
    | Expr(e) => last := gen(ctx, envRef.contents, e, ~want=want && isLast)
    }
  })
  (last.contents, envRef.contents, bound)
}

and registerType = (ctx, name, ctors: array<ctorDecl>, loc) => {
  let fn = "registerType"
  let maxArgs = ctors->Array.reduce(0, (m, c) => Math.Int.max(m, Array.length(c.argTypes)))
  let t = {typeName: name, ctors, maxArgs}
  ctx.types->Dict.set(name, t)
  ctors->Array.forEachWithIndex((c, tag) => {
    switch ctx.ctors->Dict.get(c.cname) {
    | Some((other, _)) if other.typeName != name =>
      warn(
        ctx,
        ~fn,
        ~loc=c.cloc,
        `constructor ${c.cname} shadows the one from type '${other.typeName}'`,
      )
    | _ => ()
    }
    ctx.ctors->Dict.set(c.cname, (t, tag))
  })
  if Array.length(ctors) == 0 {
    fail(~fn, ~loc, `type '${name}' has no constructors`)
  }
}

and genLet = (ctx, env, name, valueExpr: expr, loc, ~topLevel, ~prefix): value => {
  // defines and aliases inside modules carry the module path: Furnace_limit
  let defName = (prefix ++ name)->String.replaceAll(".", "_")
  let canDefine = topLevel && !isRegisterLike(defName) && ctx.defines->Dict.get(defName) == None
  switch valueExpr.desc {
  | Fun(params, body) =>
    VFun({fname: prefix ++ name, params, body, env, floc: loc, compiled: None})
  | Number(n, isFloat) if canDefine =>
    ctx.defines->Dict.set(defName, true)
    ctx.defs->Array.push(DefNum(defName, n))
    VScalar(Name(defName), isFloat ? KFloat : KInt)
  // `let furnace = device("d0")` / `let furnace = d0` with --alias
  | Call("device", [{desc: String(("d0" | "d1" | "d2" | "d3" | "d4" | "d5" | "db") as pin)}])
  | Ident(("d0" | "d1" | "d2" | "d3" | "d4" | "d5" | "db") as pin) if ctx.aliases && canDefine =>
    ctx.defines->Dict.set(defName, true)
    ctx.defs->Array.push(Native("alias", None, [ATok(defName), ADev(pin)], true))
    VDevice(Pin(defName))
  | Call("hash", [{desc: String(s)}]) if canDefine =>
    ctx.defines->Dict.set(defName, true)
    ctx.defs->Array.push(DefHash(defName, s))
    VScalar(Name(defName), KInt)
  | _ =>
    let v = gen(ctx, env, valueExpr, ~want=true)
    switch v {
    | VScalar(VReg(r), _) =>
      if ctx.vregNames->Dict.get(Int.toString(r)) == None {
        ctx.vregNames->Dict.set(Int.toString(r), name)
      }
    | VRef(CScalar(r, _)) => ctx.vregNames->Dict.set(Int.toString(r), name)
    | VRef(CVariant(_, tag, payload)) =>
      ctx.vregNames->Dict.set(Int.toString(tag), name)
      payload->Array.forEach(r => ctx.vregNames->Dict.set(Int.toString(r), name))
    | _ => ()
    }
    v
  }
}

// ---------------------------------------------------------------------------
// switch

and patternTags = (ctx, t: variantType, p: pattern): option<array<int>> =>
  switch p.pdesc {
  | PWild | PVar(_) => None
  | PConstr(name, _) =>
    switch ctx.ctors->Dict.get(name) {
    | Some((t2, tag)) if t2.typeName == t.typeName => Some([tag])
    | _ =>
      fail(
        ~fn="genSwitch",
        ~loc=p.ploc,
        `constructor ${name} does not belong to type '${t.typeName}'`,
      )
    }
  | POr(a, b) =>
    switch (patternTags(ctx, t, a), patternTags(ctx, t, b)) {
    | (Some(x), Some(y)) => Some(Array.concat(x, y))
    | _ => None
    }
  | PNumber(_) | PBool(_) =>
    fail(~fn="genSwitch", ~loc=p.ploc, `expected a constructor of '${t.typeName}'`)
  }

and payloadIrrefutable = (p: pattern): bool =>
  switch p.pdesc {
  | PWild | PVar(_) => true
  | PConstr(_, subs) =>
    subs->Array.every(s =>
      switch s.pdesc {
      | PWild | PVar(_) => true
      | _ => false
      }
    )
  | POr(a, b) => payloadIrrefutable(a) && payloadIrrefutable(b)
  | PNumber(_) | PBool(_) => false
  }

and hasBindings = (p: pattern): bool =>
  switch p.pdesc {
  | PVar(_) => true
  | PWild | PNumber(_) | PBool(_) => false
  | PConstr(_, subs) => subs->Array.some(hasBindings)
  | POr(a, b) => hasBindings(a) || hasBindings(b)
  }

// Emit the test for `p` against `v`, jumping to `failL` on mismatch.
// `skipTag`: the tag is already known to match (exhaustiveness).
and genPatternTest = (ctx, v: value, p: pattern, failL: string, ~skipTag: bool): array<(
  string,
  value,
)> => {
  let fn = "genPatternTest"
  switch (p.pdesc, v) {
  | (PWild, _) => []
  | (PVar(name), _) => [(name, v)]
  | (POr(a, b), _) =>
    if hasBindings(p) {
      fail(~fn, ~loc=p.ploc, "or-patterns cannot bind variables")
    }
    if !skipTag {
      let ok = newLabel(ctx, "match")
      let tryB = newLabel(ctx, "alt")
      let _ = genPatternTest(ctx, v, a, tryB, ~skipTag=false)
      emit(ctx, Goto(ok))
      emit(ctx, Label(tryB))
      let _ = genPatternTest(ctx, v, b, failL, ~skipTag=false)
      emit(ctx, Label(ok))
    }
    []
  | (PConstr(name, subs), VVariant(t, tag, payload)) =>
    let k = switch ctx.ctors->Dict.get(name) {
    | Some((t2, k)) if t2.typeName == t.typeName => k
    | _ => fail(~fn, ~loc=p.ploc, `constructor ${name} does not belong to type '${t.typeName}'`)
    }
    let ctor = t.ctors->Array.getUnsafe(k)
    let arity = Array.length(ctor.argTypes)
    if Array.length(subs) != arity {
      fail(~fn, ~loc=p.ploc, `constructor ${name} has ${Int.toString(arity)} argument(s)`)
    }
    if !skipTag {
      emit(ctx, Branch(Ne, tag, Num(Int.toFloat(k)), failL))
    }
    let bindings = []
    subs->Array.forEachWithIndex((sub, i) => {
      let slot = payload->Array.getUnsafe(i)
      let kind = kindOfTypeName(ctor.argTypes->Array.getUnsafe(i))
      switch sub.pdesc {
      | PWild => ()
      | PVar(n) => bindings->Array.push((n, VScalar(slot, kind)))
      | PNumber(x) => emit(ctx, Branch(Ne, slot, Num(x), failL))
      | PBool(b) => emit(ctx, Branch(Ne, slot, Num(b ? 1. : 0.), failL))
      | PConstr(_) | POr(_) =>
        fail(~fn, ~loc=sub.ploc, "nested patterns in payloads are not supported")
      }
    })
    bindings
  | (PNumber(x), VScalar(o, _)) =>
    emit(ctx, Branch(Ne, o, Num(x), failL))
    []
  | (PBool(b), VScalar(o, _)) =>
    emit(ctx, Branch(Ne, o, Num(b ? 1. : 0.), failL))
    []
  | (PConstr(name, _), other) =>
    fail(~fn, ~loc=p.ploc, `pattern ${name} cannot match ${describeValue(other)}`)
  | (PNumber(_) | PBool(_), other) =>
    fail(~fn, ~loc=p.ploc, `literal pattern cannot match ${describeValue(other)}`)
  }
}

and genSwitch = (ctx, env, scrutinee: expr, cases: array<matchCase>, ~want, ~loc): value => {
  let fn = "genSwitch"
  let sv = gen(ctx, env, scrutinee, ~want=true)
  let endL = newLabel(ctx, "endswitch")
  let result = ref(None)
  let unitResult = ref(false)
  // tags not yet handled by an unconditional case (variants only)
  let remaining = switch sv {
  | VVariant(t, _, _) => Some(ref(Array.fromInitializer(~length=Array.length(t.ctors), i => i)))
  | _ => None
  }
  let exhausted = ref(false)
  cases->Array.forEach(c => {
    if exhausted.contents {
      warn(ctx, ~fn, ~loc=c.caseLoc, "this case is unreachable")
    } else {
      let next = newLabel(ctx, "case")
      let (skipTag, coveredTags) = switch (sv, remaining) {
      | (VVariant(t, _, _), Some(rem)) =>
        switch patternTags(ctx, t, c.pattern) {
        | None => (true, rem.contents)
        | Some(tags) =>
          let rest = rem.contents->Array.filter(x => !(tags->Array.includes(x)))
          (Array.length(rest) == 0, tags)
        }
      | _ => (false, [])
      }
      let bindings = genPatternTest(ctx, sv, c.pattern, next, ~skipTag)
      let caseEnv = bindings->Array.reduce(env, (acc, (n, v)) => acc->Belt.Map.String.set(n, v))
      c.guard->Option.forEach(g => genCond(ctx, caseEnv, g, next))
      let v = gen(ctx, caseEnv, c.body, ~want)
      if want {
        mergeInto(ctx, result, v, ~unitResult, ~fn, ~loc=c.body.loc)
      }
      emit(ctx, Goto(endL))
      emit(ctx, Label(next))
      // update exhaustiveness bookkeeping
      let unconditional = c.guard == None && payloadIrrefutable(c.pattern)
      switch remaining {
      | Some(rem) if unconditional =>
        rem := rem.contents->Array.filter(x => !(coveredTags->Array.includes(x)))
        if Array.length(rem.contents) == 0 {
          exhausted := true
        }
      | _ =>
        switch c.pattern.pdesc {
        | PWild | PVar(_) if c.guard == None => exhausted := true
        | _ => ()
        }
      }
    }
  })
  if !exhausted.contents {
    switch (sv, remaining) {
    | (VVariant(t, _, _), Some(rem)) =>
      let missing = rem.contents->Array.map(i => (t.ctors->Array.getUnsafe(i)).cname)
      warn(ctx, ~fn, ~loc, `switch is not exhaustive; missing: ${missing->Array.join(", ")}`)
    | _ => ()
    }
  }
  emit(ctx, Label(endL))
  want ? resultValue(result, unitResult) : VUnit
}

// ---------------------------------------------------------------------------
// Calls

and genCall = (ctx, env, name, args: array<expr>, loc, ~want): value => {
  let fn = "genCall"
  if name == "ref" {
    switch args {
    | [a] =>
      let v = gen(ctx, env, a, ~want=true)
      let c = cellFor(ctx, v, ~fn, ~loc)
      storeCell(ctx, c, v, ~fn, ~loc)
      VRef(c)
    | _ => fail(~fn, ~loc, "ref() expects exactly one argument")
    }
  } else {
    switch env->Belt.Map.String.get(name) {
    | Some(VFun(info)) => callUser(ctx, env, info, args, loc, ~want)
    | Some(other) => fail(~fn, ~loc, `'${name}' is ${describeValue(other)}, not a function`)
    | None =>
      switch (accessor(name), qualifiedCtor(name)) {
      | (Some((op, logicType, isSet)), _) =>
        // Logic.x(d) -> l(d, "X"); Logic.setX(d, v) -> s(d, "X", v); Slot.x(d, i) -> ls(d, i, "X")
        let str = {desc: String(logicType), loc}
        let rewritten = switch (op, isSet, args) {
        | ("l", false, [d]) => Some([d, str])
        | ("s", true, [d, v]) => Some([d, str, v])
        | ("ls", false, [d, i]) => Some([d, i, str])
        | ("ss", true, [d, i, v]) => Some([d, i, str, v])
        | _ => None
        }
        switch rewritten {
        | Some(a) => genBuiltin(ctx, env, op, a, loc)->Option.getOrThrow
        | None =>
          fail(~fn, ~loc, `${name}() got ${Int.toString(Array.length(args))} argument(s)`)
        }
      | (None, Some(ctor)) => genConstructor(ctx, env, ctor, args, loc)
      | (None, None) =>
        switch genBuiltin(ctx, env, normalizeBuiltin(name), args, loc) {
        | Some(v) => v
        | None => fail(~fn, ~loc, `unknown function '${name}'`)
        }
      }
    }
  }
}

// Put call arguments in parameter order: labeled ones by name, the rest positionally
and matchArguments = (info: funInfo, args: array<expr>, loc): array<expr> => {
  let fn = "callUser"
  let labeled = Dict.make()
  let positional = []
  args->Array.forEach(a =>
    switch a.desc {
    | Labeled(name, e) =>
      if labeled->Dict.get(name) != None {
        fail(~fn, ~loc=a.loc, `argument ~${name} is given twice`)
      }
      if !(info.params->Array.some(p => p.labeled && p.pname == name)) {
        fail(~fn, ~loc=a.loc, `function '${info.fname}' has no labeled parameter ~${name}`)
      }
      labeled->Dict.set(name, e)
    | _ => positional->Array.push(a)
    }
  )
  let next = ref(0)
  let out = info.params->Array.map(p =>
    if p.labeled {
      switch labeled->Dict.get(p.pname) {
      | Some(e) => e
      | None => fail(~fn, ~loc, `function '${info.fname}' needs argument ~${p.pname}`)
      }
    } else {
      switch positional[next.contents] {
      | Some(e) =>
        next := next.contents + 1
        e
      | None =>
        fail(
          ~fn,
          ~loc,
          `function '${info.fname}' expects ${Int.toString(
              info.params->Array.filter(p => !p.labeled)->Array.length,
            )} positional argument(s), got ${Int.toString(Array.length(positional))}`,
        )
      }
    }
  )
  if next.contents < Array.length(positional) {
    fail(
      ~fn,
      ~loc,
      `function '${info.fname}' expects ${Int.toString(next.contents)} positional argument(s), got ${Int.toString(
          Array.length(positional),
        )}`,
    )
  }
  out
}

and callUser = (ctx, env, info: funInfo, args: array<expr>, loc, ~want): value => {
  let fn = "callUser"
  let args = matchArguments(info, args, loc)
  let arity = Array.length(info.params)
  if Array.length(args) != arity {
    fail(
      ~fn,
      ~loc,
      `function '${info.fname}' expects ${Int.toString(arity)} argument(s), got ${Int.toString(
          Array.length(args),
        )}`,
    )
  }
  if ctx.active->Array.includes(info.fname) {
    fail(
      ~fn,
      ~loc,
      `recursive call to '${info.fname}' is not supported`,
      ~hint="IC10 has no call stack frames; use a while loop",
    )
  }
  let argVals = args->Array.map(a => gen(ctx, env, a, ~want=true))
  let compileTimeArg = argVals->Array.some(v =>
    switch v {
    | VDevice(_) | VString(_) | VRef(_) | VFun(_) => true
    | _ => false
    }
  )
  let calls = ctx.callCounts->Dict.get(info.fname)->Option.getOr(0)
  let inline = compileTimeArg || calls <= 1 || astSize(info.body) <= 6
  if inline {
    let bodyEnv =
      info.params->Array.reduceWithIndex(info.env, (acc, p, i) =>
        acc->Belt.Map.String.set(p.pname, argVals->Array.getUnsafe(i))
      )
    ctx.active = Array.concat(ctx.active, [info.fname])
    let v = gen(ctx, bodyEnv, info.body, ~want)
    ctx.active = ctx.active->Array.filter(n => n != info.fname)
    v
  } else {
    let compiled = ensureCompiled(ctx, info, argVals, loc)
    argVals->Array.forEachWithIndex((v, i) => {
      let c = compiled.paramCells->Array.getUnsafe(i)
      if !sameShape(c, v) {
        fail(
          ~fn,
          ~loc,
          `argument ${Int.toString(
              i + 1,
            )} of '${info.fname}' has a different type than in other calls`,
        )
      }
      storeCell(ctx, c, v, ~fn, ~loc)
    })
    emit(ctx, Call(compiled.label))
    switch compiled.result {
    | Some(c) => loadCell(ctx, c)
    | None => VUnit
    }
  }
}

and functionLabel = (ctx, name: string): string => {
  let name = name->String.replaceAll(".", "_")
  let base = if isRegisterLike(name) || ctx.defines->Dict.get(name) != None {
    "fn_" ++ name
  } else {
    name
  }
  let label = ref(base)
  let i = ref(1)
  while ctx.labels->Dict.get(label.contents) != None {
    label := `${base}_${Int.toString(i.contents)}`
    i := i.contents + 1
  }
  ctx.labels->Dict.set(label.contents, true)
  label.contents
}

and ensureCompiled = (ctx, info: funInfo, argVals: array<value>, loc): compiledFun => {
  let fn = "ensureCompiled"
  switch info.compiled {
  | Some(c) => c
  | None =>
    let label = functionLabel(ctx, info.fname)
    let paramCells = info.params->Array.mapWithIndex((p, i) => {
      let annotated = p.ptype->Option.flatMap(t => ctx.types->Dict.get(t))
      switch (annotated, argVals->Array.getUnsafe(i)) {
      | (Some(t), _) => cellFor(ctx, VVariant(t, Num(0.), []), ~fn, ~loc=p.paramLoc, ~name=p.pname)
      | (None, v) => cellFor(ctx, v, ~fn, ~loc=p.paramLoc, ~name=p.pname)
      }
    })
    let saved = ctx.buf
    ctx.buf = [Label(label)]
    ctx.active = Array.concat(ctx.active, [info.fname])
    let bodyEnv =
      info.params->Array.reduceWithIndex(info.env, (acc, p, i) =>
        acc->Belt.Map.String.set(p.pname, viewCell(paramCells->Array.getUnsafe(i)))
      )
    let v = gen(ctx, bodyEnv, info.body, ~want=true)
    let result = switch v {
    | VUnit => None
    | VScalar(_) | VVariant(_) =>
      let c = cellFor(ctx, v, ~fn, ~loc=info.body.loc, ~name=info.fname ++ "()")
      storeCell(ctx, c, v, ~fn, ~loc=info.body.loc)
      Some(c)
    | other => fail(~fn, ~loc=info.body.loc, `a function cannot return ${describeValue(other)}`)
    }
    let isLeaf = !(
      ctx.buf->Array.some(i =>
        switch i {
        | Call(_) => true
        | _ => false
        }
      )
    )
    if isLeaf {
      emit(ctx, Return)
    } else {
      // jal overwrites ra: keep our return address in a register
      let saveRa = newVReg(ctx, ~name=info.fname ++ ".ra")
      ctx.buf->Array.splice(~start=1, ~remove=0, ~insert=[IR.Move(saveRa, Special("ra"))])
      emit(ctx, ReturnVia(saveRa))
    }
    ctx.active = ctx.active->Array.filter(n => n != info.fname)
    ctx.functions->Array.push({name: label, instructions: ctx.buf})
    ctx.buf = saved
    let compiled = {label, paramCells, result}
    info.compiled = Some(compiled)
    compiled
  }
}

// ---------------------------------------------------------------------------
// Builtins (IC10 instructions exposed through src/compiler/IC10.res)

and genBuiltin = (ctx, env, name: string, allArgs: array<expr>, loc): option<value> => {
  let fn = "genBuiltin"
  // labeled arguments are only meaningful for a few stdlib functions
  let labeled = Dict.make()
  let args = allArgs->Array.filter(a =>
    switch a.desc {
    | Labeled(l, e) =>
      labeled->Dict.set(l, e)
      false
    | _ => true
    }
  )
  let labeledArg = l => labeled->Dict.get(l)
  let allowedLabels = switch name {
  | "clamp" => ["min", "max"]
  | "pow" => ["exp"]
  | _ => []
  }
  labeled
  ->Dict.keysToArray
  ->Array.forEach(l =>
    if !(allowedLabels->Array.includes(l)) {
      fail(~fn, ~loc, `${name}() has no labeled argument ~${l}`)
    }
  )
  let expectArgs = n =>
    if Array.length(args) != n {
      fail(
        ~fn,
        ~loc,
        `${name}() expects ${Int.toString(n)} argument(s), got ${Int.toString(Array.length(args))}`,
      )
    }
  let arg = i => args->Array.getUnsafe(i)
  let argValue = i => gen(ctx, env, arg(i), ~want=true)
  let argScalar = i =>
    fst(
      scalar(
        argValue(i),
        ~fn,
        ~loc=arg(i).loc,
        ~what=`argument ${Int.toString(i + 1)} of ${name}()`,
      ),
    )
  let argScalarK = i =>
    scalar(argValue(i), ~fn, ~loc=arg(i).loc, ~what=`argument ${Int.toString(i + 1)} of ${name}()`)
  let argDevice = i =>
    switch argValue(i) {
    | VDevice(d) => d
    | other =>
      fail(
        ~fn,
        ~loc=arg(i).loc,
        `${name}() expects a device, got ${describeValue(other)}`,
        ~hint="let sensor = device(\"d0\")",
      )
    }
  let argPin = i =>
    switch argDevice(i) {
    | Pin(p) => p
    | _ => fail(~fn, ~loc=arg(i).loc, `${name}() only works with device pins (d0..d5, db)`)
    }
  let argToken = i => {
    let a = arg(i)
    let t = switch a.desc {
    | String(s) | Constructor(s, []) => s
    | Number(n, _) => Float.toString(n)
    | _ =>
      switch gen(ctx, env, a, ~want=true) {
      | VString(s) => s
      | other =>
        fail(
          ~fn,
          ~loc=a.loc,
          `${name}() expects a literal name here (e.g. "Temperature"), got ${describeValue(other)}`,
        )
      }
    }
    if !RegExp.test(tokenRe, t) && Float.fromString(t) == None {
      fail(~fn, ~loc=a.loc, `'${t}' is not a valid IC10 name`)
    }
    t
  }
  let dst = () => newVReg(ctx)
  let inRegister = (o: IR.operand): IR.operand =>
    switch o {
    | VReg(_) => o
    | _ =>
      let r = dst()
      emit(ctx, Move(r, o))
      VReg(r)
    }
  let native = (op, ~out, ~effects, nargs) => {
    let d = out ? Some(dst()) : None
    emit(ctx, Native(op, d, nargs, effects))
    switch d {
    | Some(r) => VScalar(VReg(r), KFloat)
    | None => VUnit
    }
  }
  // kind: None keeps the argument's kind (abs, toFloat-like ops)
  let unary = (op: IR.unOp, kind: option<kind>) => {
    expectArgs(1)
    let (a, ka) = argScalarK(0)
    let d = dst()
    emit(ctx, Unary(d, op, a))
    Some(VScalar(VReg(d), kind->Option.getOr(ka)))
  }
  let binary = (op: IR.binOp) => {
    expectArgs(2)
    let (a, ka) = argScalarK(0)
    let (b, kb) = argScalarK(1)
    let d = dst()
    emit(ctx, Binary(d, op, a, b))
    Some(VScalar(VReg(d), combine(ka, kb)))
  }
  switch name {
  | "device" =>
    expectArgs(1)
    switch arg(0).desc {
    | String(("d0" | "d1" | "d2" | "d3" | "d4" | "d5" | "db") as p) => Some(VDevice(Pin(p)))
    | _ =>
      fail(~fn, ~loc, `device() expects "d0".."d5" or "db"`)
    }
  | "batch" =>
    expectArgs(1)
    Some(VDevice(Batch(argScalar(0))))
  | "named" =>
    expectArgs(2)
    let h = argScalar(0)
    let n = argScalar(1)
    Some(VDevice(BatchNamed(h, n)))
  | "lm" =>
    expectArgs(3)
    let d = argDevice(0)
    let prop = argToken(1)
    let mode = argToken(2)
    switch d {
    | Pin(_) => fail(~fn, ~loc, "lm() reads batch devices; for a pin use l()")
    | Batch(_) | BatchNamed(_) =>
      let r = dst()
      emit(ctx, DeviceLoad(r, d, prop, Some(mode)))
      Some(VScalar(VReg(r), KFloat))
    }
  | "hash" =>
    expectArgs(1)
    switch arg(0).desc {
    | String(s) => Some(VScalar(Hash(s), KInt))
    | _ => fail(~fn, ~loc, "hash() expects a string literal")
    }
  | "l" =>
    expectArgs(2)
    let d = argDevice(0)
    let prop = argToken(1)
    let r = dst()
    // a batch device reads the Maximum over the network; lm() picks another mode
    let mode = switch d {
    | Pin(_) => None
    | Batch(_) | BatchNamed(_) => Some("Maximum")
    }
    emit(ctx, DeviceLoad(r, d, prop, mode))
    Some(VScalar(VReg(r), KFloat))
  | "s" =>
    expectArgs(3)
    let d = argDevice(0)
    let prop = argToken(1)
    let v = argScalar(2)
    emit(ctx, DeviceStore(d, prop, v))
    Some(VUnit)
  | "lb" =>
    expectArgs(3)
    let h = argScalar(0)
    let prop = argToken(1)
    let mode = argToken(2)
    let r = dst()
    emit(ctx, DeviceLoad(r, Batch(h), prop, Some(mode)))
    Some(VScalar(VReg(r), KFloat))
  | "lbn" =>
    expectArgs(4)
    let h = argScalar(0)
    let n = argScalar(1)
    let prop = argToken(2)
    let mode = argToken(3)
    let r = dst()
    emit(ctx, DeviceLoad(r, BatchNamed(h, n), prop, Some(mode)))
    Some(VScalar(VReg(r), KFloat))
  | "sb" =>
    expectArgs(3)
    let h = argScalar(0)
    let prop = argToken(1)
    let v = argScalar(2)
    emit(ctx, DeviceStore(Batch(h), prop, v))
    Some(VUnit)
  | "sbn" =>
    expectArgs(4)
    let h = argScalar(0)
    let n = argScalar(1)
    let prop = argToken(2)
    let v = argScalar(3)
    emit(ctx, DeviceStore(BatchNamed(h, n), prop, v))
    Some(VUnit)
  | "ls" =>
    expectArgs(3)
    let p = argPin(0)
    let slot = argScalar(1)
    let prop = argToken(2)
    Some(native("ls", ~out=true, ~effects=false, [ADev(p), AOp(slot), ATok(prop)]))
  | "ss" =>
    // the game only accepts a register as the value of ss
    expectArgs(4)
    let p = argPin(0)
    let slot = argScalar(1)
    let prop = argToken(2)
    let v = inRegister(argScalar(3))
    Some(native("ss", ~out=false, ~effects=true, [ADev(p), AOp(slot), ATok(prop), AOp(v)]))
  | "lbs" =>
    expectArgs(4)
    let h = argScalar(0)
    let slot = argScalar(1)
    let prop = argToken(2)
    let mode = argToken(3)
    Some(native("lbs", ~out=true, ~effects=false, [AOp(h), AOp(slot), ATok(prop), ATok(mode)]))
  | "lbns" =>
    expectArgs(5)
    let h = argScalar(0)
    let n = argScalar(1)
    let slot = argScalar(2)
    let prop = argToken(3)
    let mode = argToken(4)
    Some(
      native(
        "lbns",
        ~out=true,
        ~effects=false,
        [AOp(h), AOp(n), AOp(slot), ATok(prop), ATok(mode)],
      ),
    )
  | "sbs" =>
    expectArgs(4)
    let h = argScalar(0)
    let slot = argScalar(1)
    let prop = argToken(2)
    let v = inRegister(argScalar(3)) // the game only accepts a register here
    Some(native("sbs", ~out=false, ~effects=true, [AOp(h), AOp(slot), ATok(prop), AOp(v)]))
  | "lr" =>
    expectArgs(3)
    let p = argPin(0)
    let mode = argToken(1)
    let reagent = argScalar(2)
    Some(native("lr", ~out=true, ~effects=false, [ADev(p), ATok(mode), AOp(reagent)]))
  | "isSet" =>
    expectArgs(1)
    let p = argPin(0)
    let r = native("sdse", ~out=true, ~effects=false, [ADev(p)])
    Some(
      switch r {
      | VScalar(o, _) => VScalar(o, KInt)
      | v => v
      },
    )
  | "isNotSet" =>
    expectArgs(1)
    let p = argPin(0)
    let r = native("sdns", ~out=true, ~effects=false, [ADev(p)])
    Some(
      switch r {
      | VScalar(o, _) => VScalar(o, KInt)
      | v => v
      },
    )
  | "yield" =>
    expectArgs(0)
    Some(native("yield", ~out=false, ~effects=true, []))
  | "sleep" =>
    expectArgs(1)
    let t = argScalar(0)
    Some(native("sleep", ~out=false, ~effects=true, [AOp(t)]))
  | "push" =>
    expectArgs(1)
    let v = argScalar(0)
    Some(native("push", ~out=false, ~effects=true, [AOp(v)]))
  | "pop" =>
    expectArgs(0)
    Some(native("pop", ~out=true, ~effects=true, []))
  | "peek" =>
    expectArgs(0)
    Some(native("peek", ~out=true, ~effects=false, []))
  | "get" =>
    expectArgs(2)
    let p = argPin(0)
    let addr = argScalar(1)
    Some(native("get", ~out=true, ~effects=false, [ADev(p), AOp(addr)]))
  | "put" =>
    expectArgs(3)
    let p = argPin(0)
    let addr = argScalar(1)
    let v = argScalar(2)
    Some(native("put", ~out=false, ~effects=true, [ADev(p), AOp(addr), AOp(v)]))
  | "getd" =>
    expectArgs(2)
    let id = argScalar(0)
    let addr = argScalar(1)
    Some(native("getd", ~out=true, ~effects=false, [AOp(id), AOp(addr)]))
  | "putd" =>
    expectArgs(3)
    let id = argScalar(0)
    let addr = argScalar(1)
    let v = argScalar(2)
    Some(native("putd", ~out=false, ~effects=true, [AOp(id), AOp(addr), AOp(v)]))
  | "abs" => unary(Abs, None)
  | "sqrt" => unary(Sqrt, Some(KFloat))
  | "floor" => unary(Floor, Some(KFloat))
  | "ceil" => unary(Ceil, Some(KFloat))
  | "round" => unary(Round, Some(KFloat))
  | "trunc" => unary(Trunc, Some(KFloat))
  | "sin" => unary(Sin, Some(KFloat))
  | "cos" => unary(Cos, Some(KFloat))
  | "tan" => unary(Tan, Some(KFloat))
  | "asin" => unary(Asin, Some(KFloat))
  | "acos" => unary(Acos, Some(KFloat))
  | "atan" => unary(Atan, Some(KFloat))
  | "exp" => unary(Exp, Some(KFloat))
  | "log" => unary(Log, Some(KFloat))
  | "toInt" => unary(Trunc, Some(KInt))
  | "toFloat" =>
    expectArgs(1)
    let a = argScalar(0)
    Some(VScalar(a, KFloat))
  | "min" => binary(Min)
  | "max" => binary(Max)
  | "atan2" => binary(Atan2)
  | "mod" => binary(Mod)
  | "bitAnd" => binary(And)
  | "bitOr" => binary(Or)
  | "bitXor" => binary(Xor)
  | "shiftLeft" => binary(Sll)
  | "shiftRight" => binary(Sra)
  | "shiftRightUnsigned" => binary(Srl)
  | "bitNot" => unary(BitNot, Some(KInt))
  | "equal" =>
    expectArgs(2)
    let a = argScalar(0)
    let b = argScalar(1)
    let d = dst()
    emit(ctx, Compare(d, Eq, a, b))
    Some(VScalar(VReg(d), KInt))
  | "isNaN" =>
    expectArgs(1)
    let a = argScalar(0)
    let r = native("snan", ~out=true, ~effects=false, [AOp(a)])
    Some(
      switch r {
      | VScalar(o, _) => VScalar(o, KInt)
      | v => v
      },
    )
  | "approx" =>
    // sap: |a - b| <= max(eps * max(|a|, |b|), float.epsilon * 8)
    expectArgs(3)
    let a = argScalar(0)
    let b = argScalar(1)
    let eps = argScalar(2)
    let r = native("sap", ~out=true, ~effects=false, [AOp(a), AOp(b), AOp(eps)])
    Some(
      switch r {
      | VScalar(o, _) => VScalar(o, KInt)
      | v => v
      },
    )
  | "approxZero" =>
    expectArgs(2)
    let a = argScalar(0)
    let eps = argScalar(1)
    let r = native("sapz", ~out=true, ~effects=false, [AOp(a), AOp(eps)])
    Some(
      switch r {
      | VScalar(o, _) => VScalar(o, KInt)
      | v => v
      },
    )
  | "hcf" =>
    expectArgs(0)
    Some(native("hcf", ~out=false, ~effects=true, []))
  | "pow" =>
    // Math.pow(x, ~exp)
    expectArgs(1)
    let (base, kb) = argScalarK(0)
    let (exponent, ke) = switch labeledArg("exp") {
    | Some(e) => scalar(gen(ctx, env, e, ~want=true), ~fn, ~loc=e.loc, ~what="~exp of pow()")
    | None => fail(~fn, ~loc, "pow() needs ~exp")
    }
    Some(genPow(ctx, base, exponent, combine(kb, ke)))
  | "log10" | "log2" =>
    expectArgs(1)
    let a = argScalar(0)
    let lg = dst()
    emit(ctx, Unary(lg, Log, a))
    let d = dst()
    emit(ctx, Binary(d, Div, VReg(lg), Num(name == "log10" ? Math.log(10.) : Math.log(2.))))
    Some(VScalar(VReg(d), KFloat))
  | "cbrt" =>
    // sign(x) * |x| ** (1/3)
    expectArgs(1)
    let a = argScalar(0)
    let ab = dst()
    emit(ctx, Unary(ab, Abs, a))
    let lg = dst()
    emit(ctx, Unary(lg, Log, VReg(ab)))
    let m = dst()
    emit(ctx, Binary(m, Div, VReg(lg), Num(3.)))
    let r = dst()
    emit(ctx, Unary(r, Exp, VReg(m)))
    let neg = dst()
    emit(ctx, Binary(neg, Sub, Num(0.), VReg(r)))
    let lt = dst()
    emit(ctx, Compare(lt, Lt, a, Num(0.)))
    let d = dst()
    emit(ctx, Select(d, VReg(lt), VReg(neg), VReg(r)))
    Some(VScalar(VReg(d), KFloat))
  | "sign" =>
    expectArgs(1)
    let (a, k) = argScalarK(0)
    let gt = dst()
    emit(ctx, Compare(gt, Gt, a, Num(0.)))
    let lt = dst()
    emit(ctx, Compare(lt, Lt, a, Num(0.)))
    let d = dst()
    emit(ctx, Binary(d, Sub, VReg(gt), VReg(lt)))
    Some(VScalar(VReg(d), k))
  | "hypot" =>
    expectArgs(2)
    let a = argScalar(0)
    let b = argScalar(1)
    let aa = dst()
    emit(ctx, Binary(aa, Mul, a, a))
    let bb = dst()
    emit(ctx, Binary(bb, Mul, b, b))
    let sum = dst()
    emit(ctx, Binary(sum, Add, VReg(aa), VReg(bb)))
    let d = dst()
    emit(ctx, Unary(d, Sqrt, VReg(sum)))
    Some(VScalar(VReg(d), KFloat))
  | "clamp" =>
    // Float.clamp(~min=?, ~max=?, x)
    expectArgs(1)
    let (x, k) = argScalarK(0)
    let cur = ref(x)
    switch labeledArg("max") {
    | Some(e) =>
      let (hi, _) = scalar(gen(ctx, env, e, ~want=true), ~fn, ~loc=e.loc, ~what="~max of clamp()")
      let d = dst()
      emit(ctx, Binary(d, Min, cur.contents, hi))
      cur := VReg(d)
    | None => ()
    }
    switch labeledArg("min") {
    | Some(e) =>
      let (lo, _) = scalar(gen(ctx, env, e, ~want=true), ~fn, ~loc=e.loc, ~what="~min of clamp()")
      let d = dst()
      emit(ctx, Binary(d, Max, cur.contents, lo))
      cur := VReg(d)
    | None => ()
    }
    Some(VScalar(cur.contents, k))
  | "rand" =>
    expectArgs(0)
    Some(native("rand", ~out=true, ~effects=true, []))
  | "lerp" =>
    // a + (b - a) * t  (the game has no lerp instruction)
    expectArgs(3)
    let a = argScalar(0)
    let b = argScalar(1)
    let t = argScalar(2)
    let d1 = dst()
    emit(ctx, Binary(d1, Sub, b, a))
    let d2 = dst()
    emit(ctx, Binary(d2, Mul, VReg(d1), t))
    let d3 = dst()
    emit(ctx, Binary(d3, Add, a, VReg(d2)))
    Some(VScalar(VReg(d3), KFloat))
  | "select" =>
    expectArgs(3)
    let c = argScalar(0)
    let (a, ka) = argScalarK(1)
    let (b, kb) = argScalarK(2)
    let d = dst()
    emit(ctx, Select(d, c, a, b))
    Some(VScalar(VReg(d), combine(ka, kb)))
  | "ignore" =>
    expectArgs(1)
    let _ = gen(ctx, env, arg(0), ~want=false)
    Some(VUnit)
  | _ => None
  }
}

// ---------------------------------------------------------------------------

// Returns the IR, warnings and a vreg -> source name map (for diagnostics).
let generate = (program: AST.program, ~aliases=false): (IR.t, array<Errors.t>, Dict.t<string>) => {
  let ctx = {
    buf: [],
    nextVReg: 0,
    nextLabel: 0,
    types: Dict.make(),
    ctors: Dict.make(),
    defines: Dict.make(),
    defs: [],
    functions: [],
    labels: Dict.make(),
    callCounts: Dict.make(),
    vregNames: Dict.make(),
    warnings: [],
    active: [],
    aliases,
  }
  program->Array.forEach(s => countCallsStmt(ctx.callCounts, s))
  let _ = genBlock(ctx, Belt.Map.String.empty, program, ~want=false, ~topLevel=true)
  let main: IR.block = {name: "main", instructions: Array.concat(ctx.defs, ctx.buf)}
  (Array.concat([main], ctx.functions), ctx.warnings, ctx.vregNames)
}
