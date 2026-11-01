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
  if lookup_level(cxt, cap_name(info.eff)) is None {
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
    caps.push(check(cxt, EStruct(pos, fields), cap_tys[k]))
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
