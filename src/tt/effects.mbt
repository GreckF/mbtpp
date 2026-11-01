///|
/// Algebraic effects (see doc/mbtpp/effects.md).
///
/// An effect `effect E[T] { Op(A) -> R }` is a struct `E[T]` with one field
/// per operation, the capability: `Op : (A) -> R` for an operation whose
/// handlers resume in tail position. A `try` with arms for the operations of
/// `E` binds a capability `%cap:E` around its body, whose fields run the
/// arms (the tail `resume(v)` returns `v`); `perform Op(x)` calls the field
/// of the innermost capability. A top-level function whose type has the
/// effect `!E[T]` takes the capability as an instance argument, found at
/// each call among the capabilities in scope. Lambdas capture the
/// capabilities in scope: handlers are lexically scoped.
///
/// In a codomain, effects are kept with the errors: `T!E1 + E2 + e raise
/// Err` is `T raise %Effs[%Row[E1, %Row[E2, e]], Err]` (`%NoRaise` without
/// errors, `%RowNil` at the end of a row without an effect variable).

///|
priv struct OpInfo {
  eff : String
  ctl : Bool
  nparams : Int32
}

///|
/// Operation name -> its effect.
let effect_ops : Map[String, OpInfo] = {}

///|
/// Effect name -> its operations, in order.
let effect_decls : Map[String, Array[String]] = {}

///|
fn reset_effects() -> Unit {
  effect_ops.clear()
  effect_decls.clear()
}

///|
pub fn is_effect(name : String) -> Bool {
  effect_decls.contains(name)
}

///|
/// The name of the capability of the effect `eff` in a context.
fn cap_name(eff : String) -> String {
  "%cap:" + eff
}

///|
/// Replace the effect declarations by their capability structs.
fn expand_effects(
  decls : Array[@parser.Decl],
) -> Array[@parser.Decl] raise ElabError {
  decls.map(d => expand_effect(d))
}

///|
fn expand_effect(d : @parser.Decl) -> @parser.Decl raise ElabError {
  match d {
    DPub(inner) => DPub(expand_effect(inner))
    DMbt(p, n, ro, inner) => DMbt(p, n, ro, expand_effect(inner))
    DLimit(p, n, inner) => DLimit(p, n, expand_effect(inner))
    DEffect(ed) => {
      let ops : Array[String] = []
      for op in ed.ops {
        if effect_ops.contains(op.name) {
          raise ElabError(
            op.pos,
            "the operation " +
            op.name +
            " is already declared by the effect " +
            effect_ops[op.name].eff,
          )
        }
        effect_ops.set(op.name, {
          eff: ed.name,
          ctl: op.ctl,
          nparams: op.params.length(),
        })
        ops.push(op.name)
      }
      effect_decls.set(ed.name, ops)
      let fields = ed.ops.map(op => {
        let ty : @parser.Expr = if op.ctl {
          EVar(op.pos, "Int")
        } else {
          EPi(op.pos, [], Some(op.params), op.ret, None)
        }
        (op.pos, op.name, ty)
      })
      DStruct({
        pos: ed.pos,
        name: ed.name,
        impl_params: ed.params,
        params: None,
        fields,
      })
    }
    _ => d
  }
}

// ---------------------------------------------------------------------------
// Rows

///|
/// The items of a row in a surface type `%Row[E1, %Row[E2, tail]]`, and its
/// tail.
fn row_exprs(row : @parser.Expr) -> (Array[@parser.Expr], @parser.Expr) {
  let items : Array[@parser.Expr] = []
  let mut r = row
  while r is EApp(_, EVar(_, "%Row"), Some([item, rest]), _) {
    items.push(item)
    r = rest
  }
  (items, r)
}

///|
/// The effects (without the effect variable) of a surface codomain effect
/// `%Effs[row, err]`.
fn declared_effects(raises : @parser.Expr?) -> Array[@parser.Expr] {
  match raises {
    Some(EApp(_, EVar(_, "%Effs"), Some([row, _]), _)) => row_exprs(row).0
    _ => []
  }
}

///|
/// The name of an effect in a row.
fn effect_head(e : @parser.Expr) -> String? {
  match e {
    EVar(_, n) | EApp(_, EVar(_, n), _, _) => Some(n)
    _ => None
  }
}

///|
/// The instance parameters of a top-level function for the effects declared
/// in its type (elaborated in `cxt`, where its implicit parameters are
/// bound).
fn cap_binders(
  cxt : Cxt,
  raises : @parser.Expr?,
) -> (Cxt, Array[(String, Icit, Tm)]) raise ElabError {
  let mut c = cxt
  let bs : Array[(String, Icit, Tm)] = []
  for item in declared_effects(raises) {
    let n = match effect_head(item) {
      Some(n) if is_effect(n) => n
      _ => c.at(item.pos()).fail("not an effect: " + show_expr_head(item))
    }
    let ty = check_type(c.at(item.pos()), item)
    bs.push((cap_name(n), Inst, ty))
    c = c.bind(cap_name(n), c.eval(ty))
  }
  (c, bs)
}

///|
fn show_expr_head(e : @parser.Expr) -> String {
  effect_head(e).unwrap_or("this type")
}

///|
/// The level of the innermost variable named `x`.
fn lookup_level(cxt : Cxt, x : String) -> Int32? {
  for l = cxt.lvl - 1; l >= 0; l = l - 1 {
    if cxt.names[l] == x {
      return Some(l)
    }
  }
  None
}

///|
/// Solve an instance argument whose type is the capability of an effect:
/// the innermost capability in scope.
fn solve_cap(p : PendingInst, eff : String, goal : Val) -> Bool raise ElabError {
  let cxt = p.cxt
  match lookup_level(cxt, cap_name(eff)) {
    Some(l) => {
      cxt.unify(goal, cxt.types[l])
      cxt.unify(cxt.eval(p.meta), v_var(l))
      true
    }
    None =>
      cxt.fail(
        "this call performs the effect " +
        eff +
        ", which no enclosing `try` handles and the function does not declare",
      )
  }
}

// ---------------------------------------------------------------------------
// perform

///|
fn elab_perform(
  cxt : Cxt,
  pos : Pos,
  op : String,
  args : Array[@parser.Expr],
) -> (Tm, Val) raise ElabError {
  let info = match effect_ops.get(op) {
    Some(i) => i
    None => cxt.fail(op + " is not an operation of an effect")
  }
  if info.ctl {
    cxt.fail("`ctl` operations are not supported yet")
  }
  if args.length() != info.nparams {
    cxt.fail(
      op +
      " takes " +
      info.nparams.to_string() +
      " argument(s), got " +
      args.length().to_string(),
    )
  }
  match lookup_level(cxt, cap_name(info.eff)) {
    Some(l) => require_effect(cxt, cxt.types[l])
    None =>
      cxt.fail(
        "perform " +
        op +
        ": no enclosing `try` handles the effect " +
        info.eff +
        " and the function does not declare it",
      )
  }
  infer(
    cxt,
    EApp(pos, EField(pos, EVar(pos, cap_name(info.eff)), op), None, Some(args)),
  )
}

// ---------------------------------------------------------------------------
// Handlers

///|
/// The operation an arm of a `try` handles, if any.
fn arm_op(arm : @parser.Arm) -> (String, Array[@parser.Pat])? {
  let mut p = arm.pat
  while p is PAs(_, q, _) {
    p = q
  }
  match p {
    PCon(_, name, _, args) if effect_ops.contains(name) => Some((name, args))
    _ => None
  }
}

///|
/// Rewrite the tail `resume(v)` of the arm of a tail-resumptive operation
/// into `v`. Every path must end with `resume`.
fn tail_resume(e : @parser.Expr) -> @parser.Expr raise ElabError {
  let no_resume = (p : Pos) => {
    raise ElabError(
      p, "the handler of this operation must end with `resume(…)` (declare the operation with `ctl` to resume elsewhere, or not at all)",
    )
  }
  match e {
    EApp(p, EVar(_, "resume"), None, Some(args)) =>
      match args.length() {
        0 => ELit(p, LUnit)
        1 => args[0]
        _ => ETuple(p, args)
      }
    EBlock(p, stmts) =>
      match stmts.last() {
        Some(SExpr(sp, last)) => {
          let out = stmts.copy()
          out[out.length() - 1] = SExpr(sp, tail_resume(last))
          EBlock(p, out)
        }
        _ => no_resume(p)
      }
    EIf(p, c, t, Some(f)) => EIf(p, c, tail_resume(t), Some(tail_resume(f)))
    EMatch(p, s, r, arms) =>
      EMatch(
        p,
        s,
        r,
        arms.map(a => { ..a, rhs: a.rhs.map(x => tail_resume(x)), }),
      )
    _ => no_resume(e.pos())
  }
}

///|
/// `try body catch { arms }` where some arms handle operations: the
/// capabilities of the handled effects are bound around the body. The other
/// arms handle errors.
fn elab_handle(
  cxt : Cxt,
  pos : Pos,
  body : @parser.Expr,
  arms : Array[@parser.Arm],
  goal : Val?,
) -> (Tm, Val) raise ElabError {
  // the handled effects, in order, and the arms of each operation
  let effs : Array[String] = []
  let op_arms : Map[String, Array[@parser.Arm]] = {}
  let err_arms : Array[@parser.Arm] = []
  for arm in arms {
    match arm_op(arm) {
      Some((op, _)) => {
        let e = effect_ops[op].eff
        if !effs.contains(e) {
          effs.push(e)
        }
        map_push(op_arms, op, arm)
      }
      None => err_arms.push(arm)
    }
  }
  // the capabilities' types; their parameters are found from the body
  let cap_tys : Array[Val] = []
  let mut bc = cxt
  for e in effs {
    let nparams = match globals.get(e) {
      Some(_) => type_arity(e)
      None => {
        ensure(cxt, e)
        type_arity(e)
      }
    }
    let ty_e : @parser.Expr = if nparams == 0 {
      EVar(pos, e)
    } else {
      EApp(pos, EVar(pos, e), Some(Array::make(nparams, EHole(pos))), None)
    }
    let ty = cxt.eval(check_type(cxt, ty_e))
    cap_tys.push(ty)
    bc = bc.bind(cap_name(e), ty)
  }
  bc = { ..bc, handled: [..cxt.handled, ..effs], }
  // the body, then the error arms
  let inner = if err_arms.length() > 0 {
    @parser.ETry(pos, body, err_arms, None)
  } else {
    body
  }
  let (tb, ty) = match goal {
    Some(g) => (check(bc, inner, g), g)
    None => infer_ins(bc, inner)
  }
  // the capabilities, in the context outside of the body: an operation in
  // an arm goes to an outer handler
  let caps : Array[Tm] = []
  for k = 0; k < effs.length(); k = k + 1 {
    let e = effs[k]
    let fields : Array[(String, @parser.Expr)] = []
    for op in effect_decls[e] {
      let f = match op_arms.get(op) {
        Some(oas) => op_closure(cxt, pos, op, oas)
        // not handled here: an outer handler's
        None =>
          match lookup_level(cxt, cap_name(e)) {
            Some(_) => EField(pos, EVar(pos, cap_name(e)), op)
            None =>
              cxt.fail(
                "this handler of " +
                e +
                " does not handle " +
                op +
                ", and no outer handler does",
              )
          }
      }
      fields.push((op, f))
    }
    caps.push(
      check({ ..cxt, arm_lams: true, }, EStruct(pos, fields), cap_tys[k]),
    )
  }
  let mut t = tb
  for k = effs.length() - 1; k >= 0; k = k - 1 {
    t = Let(cap_name(effs[k]), quote(cxt.lvl + k, cap_tys[k]), caps[k], t)
  }
  (t, ty)
}

///|
/// The number of (implicit) type parameters of a struct.
fn type_arity(name : String) -> Int32 {
  match globals.get(name) {
    Some(g) => {
      let mut n = 0
      let mut t = g.ty
      while t is Pi(_, _, _, _, b) {
        n = n + 1
        t = b
      }
      n
    }
    None => 0
  }
}

///|
/// The field of a capability for the operation `op`, from its arms: a
/// function of the operation's arguments that matches them against the
/// arms' patterns.
fn op_closure(
  cxt : Cxt,
  pos : Pos,
  op : String,
  oas : Array[@parser.Arm],
) -> @parser.Expr raise ElabError {
  let info = effect_ops[op]
  if info.ctl {
    cxt.at(oas[0].pos).fail("`ctl` operations are not supported yet")
  }
  let params : Array[@parser.Binder] = []
  let xs : Array[@parser.Expr] = []
  for k = 0; k < info.nparams; k = k + 1 {
    let x = "%arg" + k.to_string()
    params.push({ pos, name: x, ty: None, kind: Positional, })
    xs.push(EVar(pos, x))
  }
  let arms2 : Array[@parser.Arm] = []
  for a in oas {
    let rhs = match a.rhs {
      Some(r) => tail_resume(r)
      None => cxt.at(a.pos).fail("missing handler body")
    }
    if mentions(rhs, "resume") {
      cxt
      .at(a.pos)
      .fail(
        "`resume` can only be the last step of the handler of this operation (declare it with `ctl` to resume elsewhere)",
      )
    }
    let args = match arm_op(a) {
      Some((_, ps)) => ps
      None => []
    }
    if args.length() != info.nparams {
      cxt
      .at(a.pos)
      .fail(
        op +
        " takes " +
        info.nparams.to_string() +
        " argument(s), got " +
        args.length().to_string(),
      )
    }
    // `Op(p) as x`: `x` is not useful for an operation; keep the pattern
    let pat : @parser.Pat = match args.length() {
      0 => PWild(a.pos)
      1 => args[0]
      _ => PTuple(a.pos, args)
    }
    arms2.push({ pos: a.pos, pat, cond: a.cond, rhs: Some(rhs), })
  }
  let scrut : @parser.Expr = match xs.length() {
    0 => ELit(pos, LUnit)
    1 => xs[0]
    _ => ETuple(pos, xs)
  }
  ELam(pos, [], params, None, EMatch(pos, scrut, None, arms2))
}

// ---------------------------------------------------------------------------
// Effect rows: checking what code may perform

///|
fn row_nil() -> Val {
  VData("%RowNil", [])
}

///|
fn row_cons(item : Val, rest : Val) -> Val {
  VData("%Row", [(item, Impl), (rest, Impl)])
}

///|
/// The items of a row, and its tail (`%RowNil`, or an effect variable).
fn row_flat(row : Val) -> (Array[Val], Val) {
  let items : Array[Val] = []
  let mut r = force(row)
  while r is VData("%Row", [(item, _), (rest, _)]) {
    items.push(item)
    r = force(rest)
  }
  (items, r)
}

///|
/// The effect row of a codomain (`%RowNil` without effects).
fn codomain_row(ty : Val) -> Val {
  match force(ty) {
    VRaises(_, e) =>
      match force(e) {
        VData("%Effs", [(row, _), _]) => row
        _ => row_nil()
      }
    _ => row_nil()
  }
}

///|
/// The effect name of a row item (`None` for an effect variable).
fn item_effect(item : Val) -> String? {
  match force(item) {
    VData(n, _) if is_effect(n) => Some(n)
    _ => None
  }
}

///|
/// The code being checked performs `item` (an effect, or an effect
/// variable): it must be handled by an enclosing `try` of the same function,
/// or be in the row of the function. A row ending with a meta (a lambda
/// whose type is being inferred) is extended.
fn require_effect(cxt : Cxt, item : Val) -> Unit raise ElabError {
  let item = force(item)
  if item is VData("%RowNil", _) {
    return
  }
  if item is VFlex(_, _) {
    // an effect variable nothing constrains: no effect
    cxt.unify(item, row_nil())
    return
  }
  let name = item_effect(item)
  match name {
    Some(n) if cxt.handled.contains(n) => return
    _ => ()
  }
  let (items, tail) = row_flat(cxt.eff_row)
  for it in items {
    if item_effect(it) == name && cxt.try_unify(it, item) {
      return
    }
  }
  if name is None && cxt.try_unify(tail, item) {
    return
  }
  // the new tail lives where the old one does: same arguments
  if tail is VFlex(_, sp) {
    cxt.unify(tail, row_cons(item, VFlex(new_meta(), sp)))
    return
  }
  cxt.fail(
    "this performs " +
    cxt.show(item) +
    ", which is not handled here and not in the effects of the function (add `!" +
    cxt.show(item) +
    "` to its type)",
  )
}

///|
/// The code being checked calls a function with the effects `row`.
fn require_row(cxt : Cxt, row : Val) -> Unit raise ElabError {
  let (items, tail) = row_flat(row)
  for it in items {
    require_effect(cxt, it)
  }
  require_effect(cxt, tail)
}

///|
/// Unify two effect rows, as sets: the items of the same effect are unified,
/// and the rest goes to the other row's tail when it is a meta.
fn unify_rows(ts : LTypes, r1 : Val, r2 : Val) -> Unit raise UnifyError {
  let (items1, tail1) = row_flat(r1)
  let (items2, tail2) = row_flat(r2)
  let used = Array::make(items2.length(), false)
  let left1 : Array[Val] = []
  for a in items1 {
    let mut found = false
    for k = 0; k < items2.length(); k = k + 1 {
      if !used[k] && item_effect(a) == item_effect(items2[k]) {
        unify(ts, a, items2[k])
        used[k] = true
        found = true
        break
      }
    }
    if !found {
      left1.push(a)
    }
  }
  let left2 : Array[Val] = []
  for k = 0; k < items2.length(); k = k + 1 {
    if !used[k] {
      left2.push(items2[k])
    }
  }
  let build = (xs : Array[Val], tail : Val) => {
    let mut r = tail
    for i = xs.length() - 1; i >= 0; i = i - 1 {
      r = row_cons(xs[i], r)
    }
    r
  }
  if left1.length() == 0 && left2.length() == 0 {
    // tails are `%RowNil`, effect variables or metas
    match (tail1, tail2) {
      (VData("%RowNil", _), VData("%RowNil", _)) => ()
      (VData("%RowNil", _), VRigid(_, _))
      | (VRigid(_, _), VData("%RowNil", _)) =>
        raise UnifyError("different effects")
      _ => unify(ts, tail1, tail2)
    }
  } else if left1.length() == 0 && tail1 is VFlex(_, _) {
    unify(ts, tail1, build(left2, tail2))
  } else if left2.length() == 0 && tail2 is VFlex(_, _) {
    unify(ts, tail2, build(left1, tail1))
  } else {
    raise UnifyError("different effects")
  }
}

///|
fn is_row(v : Val) -> Bool {
  v is VData("%Row" | "%RowNil", _)
}

// ---------------------------------------------------------------------------
// Effect polymorphism without annotation

///|
/// A function parameter `f : (A) -> B` without effects that does not escape
/// the call (the body only calls it, or passes it, or a lambda that only does
/// so, directly as an argument) may have any effects: the function gets an
/// effect variable `e`, added to the parameter's type and to its own. The
/// signature with `e` is the function's type.
fn auto_effects(fd : @parser.FnDecl) -> @parser.FnDecl {
  if fd.is_lemma {
    return fd
  }
  let body = match fd.body {
    BodyExpr(b) => b
    BodyExtern(_) => return fd
  }
  let params = match fd.params {
    Some(ps) => ps
    None => return fd
  }
  // not for async functions, and only when the function has no effect
  // variable of its own
  match fd.raises {
    Some(EApp(_, EVar(_, "%Async"), _, _)) => return fd
    Some(EApp(_, EVar(_, "%Effs"), Some([row, _]), _)) =>
      if !(row_exprs(row).1 is EVar(_, "%RowNil")) {
        return fd
      }
    _ => ()
  }
  let transparent = params.map(p => {
    match p.ty {
      Some(EPi(_, _, _, _, raises)) =>
        !(raises is Some(EApp(_, EVar(_, "%Effs" | "%Async"), _, _))) &&
        !escapes(body, p.name)
      _ => false
    }
  })
  if !transparent.iter().any(b => b) {
    return fd
  }
  let mut e = "e"
  let mut k = 1
  while fd.impl_params.iter().any(b => b.name == e) ||
        params.iter().any(b => b.name == e) {
    e = "e" + k.to_string()
    k = k + 1
  }
  let pos = fd.pos
  let with_e = (raises : @parser.Expr?) => {
    let err : @parser.Expr = match raises {
      Some(EApp(_, EVar(_, "%Effs"), Some([_, err]), _)) => err
      Some(err) => err
      None => EVar(pos, "%NoRaise")
    }
    let row : @parser.Expr = match raises {
      Some(EApp(_, EVar(_, "%Effs"), Some([row, _]), _)) => {
        let (items, _) = row_exprs(row)
        let mut r : @parser.Expr = EVar(pos, e)
        for i = items.length() - 1; i >= 0; i = i - 1 {
          r = EApp(pos, EVar(pos, "%Row"), Some([items[i], r]), None)
        }
        r
      }
      _ => EVar(pos, e)
    }
    Some(@parser.EApp(pos, EVar(pos, "%Effs"), Some([row, err]), None))
  }
  let params2 = params.mapi((i, p) => {
    if transparent[i] {
      match p.ty {
        Some(EPi(pp, impls, expl, cod, raises)) =>
          { ..p, ty: Some(EPi(pp, impls, expl, cod, with_e(raises))), }
        _ => p
      }
    } else {
      p
    }
  })
  {
    ..fd,
    impl_params: [
      ..fd.impl_params,
      { pos, name: e, ty: None, kind: Positional, },
    ],
    params: Some(params2),
    raises: with_e(fd.raises),
  }
}

///|
/// Does the parameter `x` (a function) escape in `e`: is it used other than
/// called, or passed directly as an argument (alone, or in a lambda that is
/// itself such an argument)?
fn escapes(e : @parser.Expr, x : String) -> Bool {
  let arg_escapes = (a : @parser.Expr) => {
    match a {
      EVar(_, y) if y == x => false
      ELam(_, _, ps, _, b) => !ps.iter().any(p => p.name == x) && escapes(b, x)
      _ => escapes(a, x)
    }
  }
  match e {
    EVar(_, y) => y == x
    EApp(_, EVar(_, y), _, args) if y == x =>
      args.unwrap_or([]).iter().any(arg_escapes)
    EApp(_, f, impls, args) =>
      escapes(f, x) ||
      impls.unwrap_or([]).iter().any(a => escapes(a, x)) ||
      args.unwrap_or([]).iter().any(arg_escapes)
    EMethod(_, recv, _, _, args) =>
      escapes(recv, x) || args.iter().any(arg_escapes)
    EBlock(_, stmts) => stmts.iter().any(s => stmt_escapes(s, x))
    EIf(_, c, t, f) =>
      escapes(c, x) ||
      escapes(t, x) ||
      f.map(g => escapes(g, x)).unwrap_or(false)
    EMatch(_, s, _, arms) => escapes(s, x) || arms_escape(arms, x)
    ETry(_, b, arms, ok) =>
      escapes(b, x) ||
      arms_escape(arms, x) ||
      ok.map(o => arms_escape(o, x)).unwrap_or(false)
    EBin(_, _, a, b) => escapes(a, x) || escapes(b, x)
    EUn(_, _, a) | EAnn(_, a, _) | EField(_, a, _) => escapes(a, x)
    EReturn(_, v) => v.map(a => escapes(a, x)).unwrap_or(false)
    ELit(_, _) | EHole(_) | EType(_) | EProp(_) => false
    // anything else: any use is an escape
    _ => mentions(e, x)
  }
}

///|
fn arms_escape(arms : Array[@parser.Arm], x : String) -> Bool {
  arms
  .iter()
  .any(a => {
    a.cond.map(c => escapes(c, x)).unwrap_or(false) ||
    a.rhs.map(r => escapes(r, x)).unwrap_or(false)
  })
}

///|
fn stmt_escapes(s : @parser.Stmt, x : String) -> Bool {
  match s {
    SExpr(_, e) | SDefer(_, e) => escapes(e, x)
    SLet(_, _, _, v) | SLetMut(_, _, _, v) => escapes(v, x)
    SWhile(_, c, b) => escapes(c, x) || escapes(b, x)
    SForIn(_, _, it, b) => escapes(it, x) || escapes(b, x)
    SFor(_, inits, c, steps, b) =>
      inits.iter().any(i => escapes(i.1, x)) ||
      c.map(g => escapes(g, x)).unwrap_or(false) ||
      steps.iter().any(i => escapes(i.1, x)) ||
      escapes(b, x)
    SLoopX(_, _, inner, nb) =>
      stmt_escapes(inner, x) || nb.map(g => escapes(g, x)).unwrap_or(false)
    SGuard(_, c, el) =>
      escapes(c, x) || el.map(g => escapes(g, x)).unwrap_or(false)
    SAssign(_, _, _, v) => escapes(v, x)
    _ => mention_walk_stmt(s, x)
  }
}

///|
fn mention_walk_stmt(s : @parser.Stmt, x : String) -> Bool {
  let found = Ref::new(false)
  mention_walk_s(s, x, found)
  found.val
}

///|
/// Is the variable bound by `Pi(x, _, _, _, b)` only used in effect rows of
/// `b` (an effect variable)? It is erased by the native code.
pub fn only_in_rows(b : Tm) -> Bool {
  !used_outside_rows(b, 0)
}

///|
fn used_outside_rows(t : Tm, ix : Int32) -> Bool {
  match t {
    Var(j) => j == ix
    Raises(a, App(App(Global("%Effs"), _, _), err, _)) =>
      used_outside_rows(a, ix) || used_outside_rows(err, ix)
    App(f, a, _) => used_outside_rows(f, ix) || used_outside_rows(a, ix)
    Pi(_, _, _, a, b) =>
      used_outside_rows(a, ix) || used_outside_rows(b, ix + 1)
    Lam(_, _, _, b) => used_outside_rows(b, ix + 1)
    Let(_, a, v, b) =>
      used_outside_rows(a, ix) ||
      used_outside_rows(v, ix) ||
      used_outside_rows(b, ix + 1)
    Raises(a, e) => used_outside_rows(a, ix) || used_outside_rows(e, ix)
    // anything else: a use, to be safe
    Global(_) | U | PropU | Lit(_) => false
    _ => true
  }
}
