///|
/// Bidirectional elaboration of expressions.
priv struct ElabState {
  /// Constructor short name -> qualified names.
  cons_by_short : Map[String, Array[String]]
  /// Trait method name -> traits declaring it.
  trait_methods : Map[String, Array[String]]
  /// Trait -> instance globals.
  instances : Map[String, Array[String]]
  /// Trait -> head type names of its instances (syntactic).
  instance_heads : Map[String, Array[String]]
  /// Trait -> (self kind, supers, methods).
  traits : Map[String, TraitInfo]
  /// Traits of imported packages that are not known here: every type is
  /// taken to implement them.
  opaque_traits : Array[String]
  /// Deferred elaboration of declarations, by global name.
  thunks : Map[String, () -> Unit raise ElabError]
  /// Trait -> instance signature thunk names.
  impl_sigs : Map[String, Array[String]]
  /// Tagged parameters of top-level functions (one entry per explicit
  /// parameter).
  labels : Map[String, Array[LabelInfo]]
  running : Array[String]
  pending : Array[PendingInst]
  /// Metas standing for the types of unannotated implicit binders, with the
  /// number of variables they abstract over; defaulted to `Type`.
  type_defaults : Array[(Int, Int)]
  mut fresh : Int
}

///|
/// How an explicit parameter of a top-level function is passed.
priv enum LabelInfo {
  LPos
  /// `x~ : T`
  LReq(String)
  /// `x~ : T = e`; the default is computed by the given helper function.
  LDefault(String, String)
  /// `x? : T`
  LOpt(String)
}

///|
priv struct TraitInfo {
  kind : Tm
  supers : Array[String]
  methods : Array[String]
}

///|
priv struct PendingInst {
  cxt : Cxt
  meta : Tm
  ty : Val
}

///|
let st : ElabState = {
  cons_by_short: {},
  trait_methods: {},
  instances: {},
  instance_heads: {},
  traits: {},
  opaque_traits: [],
  thunks: {},
  impl_sigs: {},
  labels: {},
  running: [],
  pending: [],
  type_defaults: [],
  fresh: 0,
}

///|
fn reset_elab() -> Unit {
  st.cons_by_short.clear()
  st.trait_methods.clear()
  st.instances.clear()
  st.instance_heads.clear()
  st.traits.clear()
  st.opaque_traits.clear()
  st.thunks.clear()
  st.impl_sigs.clear()
  st.labels.clear()
  st.running.clear()
  st.pending.clear()
  st.type_defaults.clear()
  st.fresh = 0
}

///|
fn fresh_name_gen(base : String) -> String {
  st.fresh = st.fresh + 1
  base + "$" + st.fresh.to_string()
}

///|
fn[K : Hash + Eq, V] map_push(m : Map[K, Array[V]], k : K, v : V) -> Unit {
  match m.get(k) {
    Some(a) => a.push(v)
    None => m.set(k, [v])
  }
}

///|
/// Run the deferred elaboration of `name` if there is one.
fn ensure(cxt : Cxt, name : String) -> Unit raise ElabError {
  if st.running.contains(name) {
    if !globals.contains(name) {
      cxt.fail("cyclic definition involving " + name)
    }
    return
  }
  match st.thunks.get(name) {
    Some(th) => {
      st.thunks.remove(name)
      st.running.push(name)
      th() catch {
        e => {
          ignore(st.running.pop())
          raise e
        }
      }
      ignore(st.running.pop())
    }
    None => ()
  }
}

///|
fn global_entry(cxt : Cxt, name : String) -> GEntry raise ElabError {
  ensure(cxt, name)
  match globals.get(name) {
    Some(g) => g
    None => cxt.fail("unknown name " + name)
  }
}

///|
fn is_trait(cxt : Cxt, name : String) -> Bool raise ElabError {
  if st.traits.contains(name) {
    return true
  }
  if st.thunks.contains(name) {
    ensure(cxt, name)
  }
  st.traits.contains(name)
}

///|
fn head_name(ty : Val) -> String? {
  match force(ty) {
    VData(n, _) => Some(n)
    _ => None
  }
}

///|
/// Resolve a global name. Constructors may be referred to by their short
/// name; `expected` (the head of the expected type) disambiguates.
fn resolve_name(
  cxt : Cxt,
  x : String,
  prefer_type : Bool,
  expected : String?,
) -> String raise ElabError {
  ensure(cxt, x)
  let exact = globals.contains(x)
  let cands = st.cons_by_short.get(x).unwrap_or([])
  if cands.length() == 0 || (exact && prefer_type) {
    if exact {
      return x
    }
    cxt.fail("unknown name " + x)
  }
  let chosen = match expected {
    Some(h) =>
      match cands.iter().find_first(c => c.has_prefix(h + "::")) {
        Some(c) => Some(c)
        None => None
      }
    None => None
  }
  let c = match chosen {
    Some(c) => c
    None =>
      if cands.length() == 1 {
        cands[0]
      } else if exact {
        return x
      } else {
        cxt.fail(
          "ambiguous constructor " +
          x +
          ": " +
          cands.join(", ") +
          " (add a type annotation or qualify it)",
        )
      }
  }
  ensure(cxt, c)
  c
}

// ---------------------------------------------------------------------------
// Implicit arguments

///|
fn add_pending(cxt : Cxt, m : Tm, ty : Val) -> Unit raise ElabError {
  let p : PendingInst = { cxt, meta: m, ty }
  if !solve_instance(p, false) {
    st.pending.push(p)
  }
}

///|
/// Apply `t : ty` to fresh metas for its leading implicit arguments.
fn insert(cxt : Cxt, t : Tm, ty : Val) -> (Tm, Val) raise ElabError {
  let mut t = t
  let mut ty = ty
  while force(ty) is VPi(_, i, _, a, cl) && i != Expl {
    let m = cxt.fresh_meta()
    if i == Inst {
      add_pending(cxt, m, a)
    }
    t = App(t, m, i)
    ty = inst(cl, cxt.eval(m))
  }
  (t, ty)
}

///|
fn infer_ins(cxt : Cxt, e : @parser.Expr) -> (Tm, Val) raise ElabError {
  let (t, ty) = infer(cxt, e)
  insert(cxt, t, ty)
}

// ---------------------------------------------------------------------------
// Types

///|
fn check_type(cxt : Cxt, e : @parser.Expr) -> Tm raise ElabError {
  check_type_sort(cxt, e).0
}

///|
/// Elaborate a type, returning whether it is a proposition.
fn check_type_sort(cxt : Cxt, e : @parser.Expr) -> (Tm, Bool) raise ElabError {
  let cxt = cxt.at(e.pos())
  // names in type position prefer types over constructors
  let (t, a) = match e {
    EVar(_, _) => {
      let (t, a, _) = infer_head(cxt, e, Some(VU))
      insert(cxt, t, a)
    }
    EApp(_, f, i, x) => {
      let (t, a) = elab_app(cxt, f, i, x, Some(VU))
      insert(cxt, t, a)
    }
    ETuple(_, es) => (tuple_type(cxt, es), VU)
    _ => infer_ins(cxt, e)
  }
  match force(a) {
    VU => (t, false)
    VProp => (t, true)
    other => {
      cxt.unify(VU, other)
      (t, false)
    }
  }
}

///|
fn default_type_meta(cxt : Cxt) -> Tm {
  let m = cxt.fresh_meta()
  if m is InsertedMeta(id, mask) {
    st.type_defaults.push((id, mask.iter().filter(b => b).count()))
  }
  m
}

///|
/// Elaborate implicit binders `[x, y : A, M : Trait]`, returning the extended
/// context and the binders (name, icit, type).
fn elab_impl_binders(
  cxt : Cxt,
  bs : Array[@parser.Binder],
) -> (Cxt, Array[(String, Icit, Tm)]) raise ElabError {
  let mut c = cxt
  let out : Array[(String, Icit, Tm)] = []
  for b in bs {
    let c0 = c.at(b.pos)
    match b.ty {
      Some(t) if trait_bounds(c0, t) is Some(trs) => {
        // `T : Eq + Show`: T, then one instance argument per trait
        let info = st.traits.get(trs[0]).unwrap()
        out.push((b.name, Impl, info.kind))
        c = c.bind(b.name, c.eval(info.kind))
        for k = 0; k < trs.length(); k = k + 1 {
          let inst_ty = App(Global(trs[k]), Var(k), Expl)
          out.push(("_inst_" + b.name, Inst, inst_ty))
          c = c.bind("_inst_" + b.name, c.eval(inst_ty))
        }
      }
      Some(t) => {
        let a = check_type(c0, t)
        out.push((b.name, Impl, a))
        c = c.bind(b.name, c.eval(a))
      }
      None => {
        let a = default_type_meta(c0)
        out.push((b.name, Impl, a))
        c = c.bind(b.name, c.eval(a))
      }
    }
  }
  (c, out)
}

///|
/// `Tr` or `Tr1 + Tr2 + ...` where every `Tr` is a trait.
fn trait_bounds(cxt : Cxt, e : @parser.Expr) -> Array[String]? raise ElabError {
  match e {
    EVar(_, tr) => if is_trait(cxt, tr) { Some([tr]) } else { None }
    EBin(_, "+", a, b) =>
      match (trait_bounds(cxt, a), trait_bounds(cxt, b)) {
        (Some(x), Some(y)) => Some(concat(x, y))
        _ => None
      }
    _ => None
  }
}

///|
/// Elaborate explicit parameters `(x : A, B)`; `() ` is a single `Unit`
/// parameter.
fn elab_expl_binders(
  cxt : Cxt,
  bs : Array[@parser.Binder],
) -> (Cxt, Array[(String, Icit, Tm)]) raise ElabError {
  let mut c = cxt
  let out : Array[(String, Icit, Tm)] = []
  if bs.length() == 0 {
    out.push(("_", Expl, Global("Unit")))
    return (c.bind("_", VData("Unit", [])), out)
  }
  for b in bs {
    let c0 = c.at(b.pos)
    let a = match b.ty {
      Some(t) => check_type(c0, t)
      None => c0.fresh_meta()
    }
    let a = if b.kind is Optional {
      ensure(c0, "Option")
      App(Global("Option"), a, Impl)
    } else {
      a
    }
    out.push((b.name, Expl, a))
    c = c.bind(b.name, c.eval(a))
  }
  (c, out)
}

///|
fn pis(bs : Array[(String, Icit, Tm)], cod : Tm) -> Tm {
  let mut t = cod
  let mut first_expl = 0
  for k = 0; k < bs.length(); k = k + 1 {
    if bs[k].1 == Expl {
      first_expl = k
      break
    }
  }
  for k = bs.length() - 1; k >= 0; k = k - 1 {
    let (x, i, a) = bs[k]
    t = Pi(x, i, i == Expl && k == first_expl, a, t)
  }
  t
}

///|
fn lams(bs : Array[(String, Icit, Tm)], body : Tm) -> Tm {
  let mut t = body
  let mut first_expl = 0
  for k = 0; k < bs.length(); k = k + 1 {
    if bs[k].1 == Expl {
      first_expl = k
      break
    }
  }
  for k = bs.length() - 1; k >= 0; k = k - 1 {
    let (x, i, _) = bs[k]
    t = Lam(x, i, i == Expl && k == first_expl, t)
  }
  t
}

///|
fn infer_pi(
  cxt : Cxt,
  impls : Array[@parser.Binder],
  expl : Array[@parser.Binder]?,
  cod : @parser.Expr,
  raises : @parser.Expr?,
) -> (Tm, Val) raise ElabError {
  let (c1, bs1) = elab_impl_binders(cxt, impls)
  let (c2, bs2) = match expl {
    Some(bs) => elab_expl_binders(c1, bs)
    None => (c1, [])
  }
  let (ct, is_prop) = check_type_sort(c2, cod)
  let ct = match raises {
    Some(r) => Raises(ct, check_type(c2, r))
    None => ct
  }
  (pis(concat(bs1, bs2), ct), if is_prop { VProp } else { VU })
}

// ---------------------------------------------------------------------------
// Application

///|
priv enum Arg {
  AE(@parser.Expr)
  AV(Tm, Val)
  /// The default value of a tagged parameter, computed by a helper.
  ADefault(String)
}

///|
fn check_arg(cxt : Cxt, a : Arg, ty : Val) -> Tm raise ElabError {
  match a {
    AE(ETagged(p, x, _, _)) =>
      cxt.at(p).fail("this function has no labelled parameter " + x)
    ADefault(_) => cxt.fail("internal error: unexpected default argument")
    AE(e) => check(cxt, e, ty)
    AV(t, aty) => {
      let (t, aty) = insert_until(cxt, t, aty, ty)
      cxt.unify(ty, aty)
      t
    }
  }
}

///|
/// Insert implicit arguments unless the expected type is itself implicit.
fn insert_until(
  cxt : Cxt,
  t : Tm,
  aty : Val,
  ty : Val,
) -> (Tm, Val) raise ElabError {
  match force(ty) {
    VPi(_, i, _, _, _) if i != Expl => (t, aty)
    _ => insert(cxt, t, aty)
  }
}

///|
/// Number of explicit binders in the argument group at the head of `ty`.
fn group_size(ty : Val, lvl : Int) -> Int {
  let mut n = 0
  let mut t = force(ty)
  let mut l = lvl
  while t is VPi(_, Expl, g, _, cl) {
    if n > 0 && g {
      break
    }
    n = n + 1
    t = force(inst(cl, v_var(l)))
    l = l + 1
  }
  n
}

///|
fn app_core(
  cxt : Cxt,
  head : Tm,
  head_ty : Val,
  skip_params : Int,
  impl_args : Array[@parser.Expr]?,
  expl_args : Array[Arg]?,
) -> (Tm, Val) raise ElabError {
  let mut t = head
  let mut ty = head_ty
  let impls = impl_args.unwrap_or([])
  let mut k = 0
  let mut skip = skip_params
  let impl_terms : Array[(Tm, Icit)] = []
  while force(ty) is VPi(_, i, _, a, cl) && i != Expl {
    let arg = if i == Inst {
      let m = cxt.fresh_meta()
      add_pending(cxt, m, a)
      m
    } else if skip > 0 {
      skip = skip - 1
      cxt.fresh_meta()
    } else if k < impls.length() {
      k = k + 1
      check(cxt, impls[k - 1], a)
    } else {
      cxt.fresh_meta()
    }
    impl_terms.push((arg, i))
    t = App(t, arg, i)
    ty = inst(cl, cxt.eval(arg))
  }
  if k < impls.length() {
    cxt.fail("too many implicit arguments")
  }
  match expl_args {
    None => (t, ty)
    Some(args) => {
      if force(ty) is VFlex(_, _) {
        let ms : Array[(String, Icit, Tm)] = []
        for j = 0; j < args.length(); j = j + 1 {
          ms.push(("x" + j.to_string(), Expl, cxt.fresh_meta()))
        }
        if args.length() == 0 {
          ms.push(("_", Expl, Global("Unit")))
        }
        let fty = pis(ms, cxt.fresh_meta())
        cxt.unify(cxt.eval(fty), ty)
      }
      let n = group_size(ty, cxt.lvl)
      if n == 0 {
        cxt.fail("not a function: " + cxt.show(ty))
      }
      let labels = match head {
        Global(name) => st.labels.get(name)
        _ => None
      }
      let args = match labels {
        Some(infos) if infos.length() == n => place_tagged(cxt, infos, args)
        _ => args
      }
      let args = if args.length() == 0 && n == 1 && labels is None {
        [AV(Lit(LUnit), VData("Unit", []))]
      } else {
        args
      }
      if args.length() != n {
        cxt.fail(
          "expected " +
          n.to_string() +
          " argument(s), got " +
          args.length().to_string(),
        )
      }
      // Lambdas are checked last, so that the other arguments can
      // determine the types of their parameters.
      let deferred : Array[(Tm, @parser.Expr, Val)] = []
      let expl_terms : Array[(Tm, Icit)] = []
      for a in args {
        match force(ty) {
          VPi(_, _, _, dom, cl) => {
            let arg = match a {
              ADefault(helper) =>
                apps(
                  Global(helper),
                  concat(concat(impl_terms, expl_terms), [(Lit(LUnit), Expl)]),
                )
              AE(ELam(_, _, ps, _, _) as e) if ps.iter().any(p => p.ty is None) => {
                let m = cxt.fresh_meta()
                deferred.push((m, e, dom))
                m
              }
              _ => check_arg(cxt, a, dom)
            }
            expl_terms.push((arg, Expl))
            t = App(t, arg, Expl)
            ty = inst(cl, cxt.eval(arg))
          }
          _ => cxt.fail("not a function")
        }
      }
      for d in deferred {
        let (m, e, dom) = d
        let lt = check(cxt, e, dom)
        cxt.unify(cxt.eval(m), cxt.eval(lt))
      }
      match force(ty) {
        VRaises(r, _) => {
          if !cxt.can_raise {
            cxt.fail(
              "this call may raise an error; use it inside `try` or in a function declared with `raise`",
            )
          }
          (t, r)
        }
        _ => (t, ty)
      }
    }
  }
}

///|
/// Put tagged arguments (`label=e`, `label~`, `label?=e`) in the positions of
/// their parameters, and fill in omitted ones (default values, `None`).
fn place_tagged(
  cxt : Cxt,
  infos : Array[LabelInfo],
  args : Array[Arg],
) -> Array[Arg] raise ElabError {
  let slots : Array[Arg?] = infos.map(_ => None)
  let mut next = 0
  for a in args {
    match a {
      AE(ETagged(p, x, e, opt)) => {
        let c = cxt.at(p)
        let mut k = -1
        for j = 0; j < infos.length(); j = j + 1 {
          match infos[j] {
            LReq(l) | LDefault(l, _) | LOpt(l) if l == x => k = j
            _ => ()
          }
        }
        if k < 0 {
          c.fail("no labelled parameter " + x)
        }
        if slots[k] is Some(_) {
          c.fail("argument " + x + " is given twice")
        }
        slots[k] = Some(
          match (infos[k], opt) {
            (LOpt(_), true) => AE(e)
            (LOpt(_), false) =>
              AE(EApp(p, EVar(p, "Option::Some"), None, Some([e])))
            (_, true) =>
              c.fail(
                "`" + x + "?=` is only for parameters declared `" + x + "?`",
              )
            _ => AE(e)
          },
        )
      }
      _ => {
        while next < infos.length() &&
              !(infos[next] is LPos && slots[next] is None) {
          next = next + 1
        }
        if next >= infos.length() {
          cxt.fail("too many positional arguments")
        }
        slots[next] = Some(a)
        next = next + 1
      }
    }
  }
  let out : Array[Arg] = []
  for k = 0; k < infos.length(); k = k + 1 {
    match (slots[k], infos[k]) {
      (Some(a), _) => out.push(a)
      (None, LPos) => cxt.fail("missing positional argument")
      (None, LReq(l)) => cxt.fail("missing labelled argument " + l + "~")
      (None, LDefault(_, helper)) => out.push(ADefault(helper))
      (None, LOpt(_)) => out.push(AE(EVar(cxt.pos, "Option::None")))
    }
  }
  out
}

///|
fn nparams_of(name : String) -> Int {
  match con_info(name) {
    Some(ci) => ci.nparams
    None => 0
  }
}

///|
/// Elaborate the head of an application.
fn infer_head(
  cxt : Cxt,
  f : @parser.Expr,
  expected : Val?,
) -> (Tm, Val, Int) raise ElabError {
  match f {
    EVar(p, x) if !x.contains("::") && cxt.lookup(x) is Some(l) => {
      ignore(p)
      (Var(cxt.lvl - 1 - l), cxt.types[l], 0)
    }
    EVar(p, x) => {
      let c = cxt.at(p)
      let prefer_type = match expected {
        Some(e) => force(e) is (VU | VProp)
        None => false
      }
      let h = match expected {
        Some(e) => head_name(e)
        None => None
      }
      let n = resolve_name(c, x, prefer_type, h)
      let g = global_entry(c, n)
      (Global(n), g.vty, nparams_of(n))
    }
    _ => {
      let (t, ty) = infer(cxt, f)
      (t, ty, 0)
    }
  }
}

///|
fn elab_app(
  cxt : Cxt,
  f : @parser.Expr,
  impl_args : Array[@parser.Expr]?,
  expl_args : Array[@parser.Expr]?,
  expected : Val?,
) -> (Tm, Val) raise ElabError {
  // An ambiguous constructor name: try each candidate on the arguments.
  match (f, expected.bind(head_name)) {
    (EVar(p, x), None) if !x.contains("::") &&
      cxt.lookup(x) is None &&
      !globals.contains(x) &&
      st.cons_by_short.get(x).unwrap_or([]).length() > 1 => {
      let errs : Array[String] = []
      for c in st.cons_by_short.get(x).unwrap() {
        let snap = snapshot_metas()
        let npend = st.pending.length()
        try {
          return elab_app(cxt, EVar(p, c), impl_args, expl_args, expected)
        } catch {
          ElabError(_, msg) => {
            restore_metas(snap)
            while st.pending.length() > npend {
              ignore(st.pending.pop())
            }
            errs.push(c + ": " + msg)
          }
        }
      }
      cxt.fail(
        "no constructor named " + x + " fits here:\n  " + errs.join("\n  "),
      )
    }
    _ => ()
  }
  let (ht, hty, np) = infer_head(cxt, f, expected)
  // `xs[i]` is indexing unless `xs` takes implicit arguments.
  match (impl_args, expl_args) {
    (Some(idx), None) if idx.length() == 1 && np == 0 =>
      match force(hty) {
        VPi(_, i, _, _, _) if i != Expl => ()
        VU | VProp => ()
        _ => return elab_method(cxt, ht, hty, "op_get", None, [AE(idx[0])])
      }
    _ => ()
  }
  app_core(cxt, ht, hty, np, impl_args, expl_args.map(as_ => as_.map(AE(_))))
}

// ---------------------------------------------------------------------------
// Methods and operators

///|
fn resolve_method(
  cxt : Cxt,
  recv_ty : Val,
  m : String,
) -> String? raise ElabError {
  let h = head_name(recv_ty)
  match h {
    Some(h) => {
      let name = h + "::" + m
      ensure(cxt, name)
      if globals.contains(name) {
        return Some(name)
      }
    }
    None => ()
  }
  let trs = st.trait_methods.get(m).unwrap_or([])
  let cands : Array[String] = []
  for tr in trs {
    let ok = match h {
      Some(h) => st.instance_heads.get(tr).unwrap_or([]).contains(h)
      None => true
    }
    if ok {
      cands.push(tr)
    }
  }
  if cands.length() == 0 && trs.length() == 1 {
    cands.push(trs[0])
  }
  if cands.length() == 1 {
    let name = cands[0] + "::" + m
    ensure(cxt, name)
    Some(name)
  } else {
    None
  }
}

///|
fn elab_method(
  cxt : Cxt,
  recv : Tm,
  recv_ty : Val,
  m : String,
  impl_args : Array[@parser.Expr]?,
  args : Array[Arg],
) -> (Tm, Val) raise ElabError {
  let (recv, recv_ty) = insert(cxt, recv, recv_ty)
  match resolve_method(cxt, recv_ty, m) {
    Some(name) => {
      let g = global_entry(cxt, name)
      app_core(
        cxt,
        Global(name),
        g.vty,
        0,
        impl_args,
        Some([AV(recv, recv_ty), ..args]),
      )
    }
    None => cxt.fail("no method " + m + " for type " + cxt.show(recv_ty))
  }
}

///|
fn op_method(op : String) -> String {
  match op {
    "+" => "op_add"
    "-" => "op_sub"
    "*" => "op_mul"
    "/" => "op_div"
    "%" => "op_mod"
    "==" => "op_equal"
    "<" => "op_lt"
    "<=" => "op_le"
    ">" => "op_gt"
    ">=" => "op_ge"
    "&" => "op_land"
    "|" => "op_lor"
    "^" => "op_lxor"
    _ => "op_unknown"
  }
}

///|
fn bool_ty() -> Val {
  VData("Bool", [])
}

///|
fn if_tm(c : Tm, t : Tm, e : Tm) -> Tm {
  Match([c], [
    { pats: [CPLit(LBool(true))], body: t },
    { pats: [CPWild], body: e },
  ])
}

///|
/// Check `e` in a context extended by one (unnamed) slot.
fn check_under_slot(
  cxt : Cxt,
  e : @parser.Expr,
  ty : Val,
  slot_ty : Val,
  slot : Val,
) -> Tm raise ElabError {
  check(cxt.define_local("_", slot_ty, slot), e, ty)
}

///|
fn infer_bin(
  cxt : Cxt,
  op : String,
  a : @parser.Expr,
  b : @parser.Expr,
) -> (Tm, Val) raise ElabError {
  match op {
    "===" => {
      let (ta, ty) = infer_ins(cxt, a)
      let tb = check(cxt, b, ty)
      let t = apps(Global("Id"), [(cxt.quote(ty), Impl), (ta, Expl), (tb, Expl)])
      (t, VProp)
    }
    "&&" | "||" => {
      let ta = check(cxt, a, bool_ty())
      let tb = check_under_slot(
        cxt,
        b,
        bool_ty(),
        bool_ty(),
        VLit(LBool(op == "&&")),
      )
      let t = if op == "&&" {
        if_tm(ta, tb, Lit(LBool(false)))
      } else {
        if_tm(ta, Lit(LBool(true)), tb)
      }
      (t, bool_ty())
    }
    "!=" => {
      let (t, _) = infer_bin(cxt, "==", a, b)
      (if_tm(t, Lit(LBool(false)), Lit(LBool(true))), bool_ty())
    }
    "<" | "<=" | ">" | ">=" => {
      let (ta, aty) = infer_ins(cxt, a)
      match resolve_method(cxt, aty, op_method(op)) {
        Some(_) => elab_method(cxt, ta, aty, op_method(op), None, [AE(b)])
        None => {
          let (c, _) = elab_method(cxt, ta, aty, "compare", None, [AE(b)])
          let int_ty = VData("Int", [])
          elab_method(cxt, c, int_ty, op_method(op), None, [
            AV(Lit(LInt(0)), int_ty),
          ])
        }
      }
    }
    _ => {
      let (ta, aty) = infer_ins(cxt, a)
      elab_method(cxt, ta, aty, op_method(op), None, [AE(b)])
    }
  }
}

// ---------------------------------------------------------------------------
// Checking

///|
fn nat_tm(n : Int) -> Tm {
  let mut t = Global("Nat::Z")
  for _ in 0..<n {
    t = App(Global("Nat::S"), t, Expl)
  }
  t
}

///|
pub fn check(cxt0 : Cxt, e : @parser.Expr, ty0 : Val) -> Tm raise ElabError {
  let cxt = cxt0.at(e.pos())
  let ty = force(ty0)
  match (e, ty) {
    (ELam(_, impls, ps, ret, body), _) =>
      check_lam(cxt, impls, ps, ret, body, ty)
    (EHole(_), _) => cxt.fresh_meta()
    (
      EVar(_, _)
      | EApp(_, _, _, _)
      | EField(_, _, _)
      | EMethod(_, _, _, _, _),
      VPi(_, i, _, _, _),
    ) if i != Expl => {
      // A term whose type is itself implicitly quantified is used as is
      // (e.g. `Option` against `[T] -> Type`); otherwise insert implicit
      // lambdas around it.
      let (t, aty) = match e {
        EVar(_, _) => {
          let (t, aty, _) = infer_head(cxt, e, None)
          (t, aty)
        }
        _ => infer(cxt, e)
      }
      match force(aty) {
        VPi(_, j, _, _, _) if j != Expl => {
          cxt.unify(ty, aty)
          t
        }
        _ => {
          let mut c = cxt
          let mut cur = ty
          let wrap : Array[(String, Icit, Tm)] = []
          while force(cur) is VPi(x, i, _, a, cl) && i != Expl {
            let v = v_var(c.lvl)
            c = c.bind("?" + x, a)
            wrap.push((x, i, Global("?")))
            cur = inst(cl, v)
          }
          let (t2, aty2) = insert_until(
            c,
            tm_shift(t, wrap.length(), 0),
            aty,
            cur,
          )
          c.unify(cur, aty2)
          wrap_lams(wrap.map(w => (w.0, w.1, false)), t2)
        }
      }
    }
    (_, VPi(x, i, _, a, cl)) if i != Expl => {
      let v = v_var(cxt.lvl)
      let name = if i == Inst { "_inst_" + x } else { "?" + x }
      let c2 = cxt.bind(name, a)
      Lam(x, i, false, check(c2, e, inst(cl, v)))
    }
    (EBlock(_, stmts), _) => check_block(cxt, stmts, Some(ty)).0
    (EIf(_, c, t, el), _) => {
      let tc = check(cxt, c, bool_ty())
      let tt = check_under_slot(cxt, t, ty, bool_ty(), VLit(LBool(true)))
      let te = match el {
        Some(x) => check_under_slot(cxt, x, ty, bool_ty(), VLit(LBool(false)))
        None => {
          cxt.unify(ty, VData("Unit", []))
          Lit(LUnit)
        }
      }
      if_tm(tc, tt, te)
    }
    (EMatch(_, scr, ret, arms), _) =>
      elab_match(cxt, scr, ret, arms, Some(ty)).0
    (ELit(_, LInt(n)), VData("Nat", [])) =>
      if n < 0 {
        cxt.fail("negative natural number")
      } else {
        nat_tm(n)
      }
    (EStruct(_, fields), _) => elab_struct(cxt, fields, Some(ty)).0
    // `1 + 1 : Nat`: the expected type determines the left operand
    (EBin(_, "+" | "-" | "*" | "/" | "%" as op, a, b), VData(h, _)) if h !=
      "Int" &&
      a is ELit(_, LInt(_)) => {
      let ta = check(cxt, a, ty)
      let (t, aty) = elab_method(cxt, ta, ty, op_method(op), None, [AE(b)])
      cxt.unify(ty, aty)
      t
    }
    (EArray(_, es), VData("Array", [(a, _)])) =>
      ArrayLit(es.map(x => check(cxt, x, a)))
    (ETuple(_, es), VU) => tuple_type(cxt, es)
    (ETuple(_, es), _) => elab_tuple(cxt, es, Some(ty)).0
    (EApp(_, f, i, x), _) => {
      let (t, aty) = elab_app(cxt, f, i, x, Some(ty))
      let (t, aty) = insert_until(cxt, t, aty, ty)
      cxt.unify(ty, aty)
      t
    }
    (EVar(_, _), _) => {
      let (t, aty, _) = infer_head(cxt, e, Some(ty))
      let (t, aty) = insert_until(cxt, t, aty, ty)
      cxt.unify(ty, aty)
      t
    }
    (ERaise(_, x), _) => elab_raise(cxt, x)
    (EReturn(_, x), _) => elab_return(cxt, x)
    (EBreak(_), _) | (EContinue(_), _) => {
      if !cxt.in_loop {
        cxt.fail("break/continue outside of a loop")
      }
      if e is EBreak(_) {
        Break
      } else {
        Continue
      }
    }
    (ETry(_, body, arms), _) => elab_try(cxt, body, arms, Some(ty)).0
    (EMonad(_, b), _) => check(cxt, desugar_monad(b), ty)
    (EProof(_, tacs), _) => run_tactics(cxt, tacs, ty)
    _ => {
      let (t, aty) = infer(cxt, e)
      let (t, aty) = insert_until(cxt, t, aty, ty)
      cxt.unify(ty, aty)
      t
    }
  }
}

///|
fn check_lam(
  cxt0 : Cxt,
  impls : Array[@parser.Binder],
  ps : Array[@parser.Binder],
  ret : @parser.Expr?,
  body : @parser.Expr,
  ty0 : Val,
) -> Tm raise ElabError {
  reject_tagged(cxt0, ps)
  let mut cxt = cxt0
  let mut ty = force(ty0)
  if ty is VFlex(_, _) {
    let (_, lty) = infer_lam_type(cxt, impls, ps, ret)
    cxt.unify(ty, lty)
    ty = force(ty)
  }
  let wrap : Array[(String, Icit, Tm)] = []
  let mut k = 0
  while ty is VPi(x, i, _, a, cl) && i != Expl {
    let name = if i == Inst {
      "_inst_" + x
    } else if k < impls.length() {
      let b = impls[k]
      k = k + 1
      match b.ty {
        Some(t) => cxt.unify(cxt.eval(check_type(cxt.at(b.pos), t)), a)
        None => ()
      }
      b.name
    } else {
      "?" + x
    }
    let v = v_var(cxt.lvl)
    cxt = cxt.bind(name, a)
    wrap.push((name, i, Global("?")))
    ty = force(inst(cl, v))
  }
  if k < impls.length() {
    cxt.fail("too many implicit parameters for " + cxt.show(ty0))
  }
  let n = group_size(ty, cxt.lvl)
  let ps = if ps.length() == 0 {
    [({ pos: cxt.pos, name: "_", ty: None, kind: Positional } : @parser.Binder)]
  } else {
    ps
  }
  if n != ps.length() {
    cxt.fail(
      "this function takes " +
      ps.length().to_string() +
      " parameter(s) but the expected type is " +
      cxt0.show(ty0),
    )
  }
  for p in ps {
    match ty {
      VPi(_, _, _, a, cl) => {
        match p.ty {
          Some(t) => cxt.unify(cxt.eval(check_type(cxt.at(p.pos), t)), a)
          None => ()
        }
        let v = v_var(cxt.lvl)
        cxt = cxt.bind(p.name, a)
        wrap.push((p.name, Expl, Global("?")))
        ty = force(inst(cl, v))
      }
      _ => cxt.fail("not a function type")
    }
  }
  match ret {
    Some(r) => cxt.unify(cxt.eval(check_type(cxt, r)), ty)
    None => ()
  }
  let (body_ty, can_raise) = match ty {
    VRaises(a, _) => (a, true)
    _ => (ty, false)
  }
  let bc = { ..cxt, can_raise, ret_ty: Some(body_ty), in_loop: false }
  lams(wrap, check(bc, body, body_ty))
}

///|
/// As in MoonBit, only top-level functions have tagged parameters.
fn reject_tagged(cxt : Cxt, ps : Array[@parser.Binder]) -> Unit raise ElabError {
  for p in ps {
    if !(p.kind is Positional) {
      cxt
      .at(p.pos)
      .fail("only top-level functions can have labelled parameters")
    }
  }
}

///|
fn infer_lam_type(
  cxt : Cxt,
  impls : Array[@parser.Binder],
  ps : Array[@parser.Binder],
  ret : @parser.Expr?,
) -> (Tm, Val) raise ElabError {
  reject_tagged(cxt, ps)
  let (c1, bs1) = elab_impl_binders(cxt, impls)
  let (c2, bs2) = elab_expl_binders(c1, ps)
  let r = match ret {
    Some(r) => check_type(c2, r)
    None => c2.fresh_meta()
  }
  let t = pis(concat(bs1, bs2), r)
  (t, cxt.eval(t))
}

// ---------------------------------------------------------------------------
// Inference

///|
pub fn infer(cxt0 : Cxt, e : @parser.Expr) -> (Tm, Val) raise ElabError {
  let cxt = cxt0.at(e.pos())
  match e {
    EVar(_, _) => {
      let (t, ty, _) = infer_head(cxt, e, None)
      (t, ty)
    }
    EHole(_) => {
      let a = cxt.fresh_meta()
      (cxt.fresh_meta(), cxt.eval(a))
    }
    EType(_) => (U, VU)
    EProp(_) => (PropU, VU)
    ELit(_, l) => (Lit(l), lit_type(l))
    EInterp(_, parts) => {
      let mut acc : @parser.Expr = ELit(cxt.pos, LStr(""))
      for p in parts {
        let x : @parser.Expr = match p {
          IStr(s) => ELit(cxt.pos, LStr(s))
          IExpr(x) => EMethod(x.pos(), x, "to_string", None, [])
        }
        acc = EBin(cxt.pos, "+", acc, x)
      }
      infer(cxt, acc)
    }
    EApp(_, f, i, x) => elab_app(cxt, f, i, x, None)
    EPi(_, impls, expl, cod, raises) => infer_pi(cxt, impls, expl, cod, raises)
    ELam(_, impls, ps, ret, _) => {
      let (_, ty) = infer_lam_type(cxt, impls, ps, ret)
      (check(cxt, e, ty), ty)
    }
    EBlock(_, stmts) => check_block(cxt, stmts, None)
    EIf(_, c, t, el) =>
      match el {
        Some(x) => {
          let tc = check(cxt, c, bool_ty())
          let (tt, ty) = infer_ins(
            cxt.define_local("_", bool_ty(), VLit(LBool(true))),
            t,
          )
          let te = check_under_slot(cxt, x, ty, bool_ty(), VLit(LBool(false)))
          (if_tm(tc, tt, te), ty)
        }
        None => {
          let unit = VData("Unit", [])
          (check(cxt, e, unit), unit)
        }
      }
    EMatch(_, scr, ret, arms) => elab_match(cxt, scr, ret, arms, None)
    EAnn(_, x, t) => {
      let a = cxt.eval(check_type(cxt, t))
      (check(cxt, x, a), a)
    }
    EField(_, x, f) => {
      let (t, ty) = infer_ins(cxt, x)
      elab_field(cxt, t, ty, f)
    }
    EMethod(_, x, m, i, args) => {
      let (t, ty) = infer_ins(cxt, x)
      elab_method(cxt, t, ty, m, i, args.map(AE(_)))
    }
    EBin(_, op, a, b) => infer_bin(cxt, op, a, b)
    EUn(_, "-", x) => {
      let (t, ty) = infer_ins(cxt, x)
      elab_method(cxt, t, ty, "op_neg", None, [])
    }
    EUn(_, _, x) => {
      let t = check(cxt, x, bool_ty())
      (if_tm(t, Lit(LBool(false)), Lit(LBool(true))), bool_ty())
    }
    ETuple(_, es) => elab_tuple(cxt, es, None)
    EArray(_, es) => {
      let a = if es.length() == 0 {
        cxt.eval(cxt.fresh_meta())
      } else {
        infer_ins(cxt, es[0]).1
      }
      let ts = es.map(x => check(cxt, x, a))
      (ArrayLit(ts), VData("Array", [(a, Impl)]))
    }
    EStruct(_, fields) => elab_struct(cxt, fields, None)
    ETry(_, body, arms) => elab_try(cxt, body, arms, None)
    ETryQ(_, x) => {
      let (t, ty) = infer_ins({ ..cxt, can_raise: true }, x)
      let err = VData("Error", [])
      let res_ty = VData("Result", [(ty, Impl), (err, Impl)])
      ensure(cxt, "Result::Ok")
      let ok = apps(Global("Result::Ok"), [
        (cxt.quote(ty), Impl),
        (Global("Error"), Impl),
        (t, Expl),
      ])
      let errv = apps(Global("Result::Err"), [
        (quote(cxt.lvl + 1, ty), Impl),
        (Global("Error"), Impl),
        (Var(0), Expl),
      ])
      (Try(ok, [{ pats: [CPVar("e")], body: errv }]), res_ty)
    }
    ERaise(_, _)
    | EReturn(_, _)
    | EBreak(_)
    | EContinue(_)
    | EProof(_, _)
    | EMonad(_, _) => {
      let a = cxt.eval(cxt.fresh_meta())
      (check(cxt, e, a), a)
    }
    EBind(_, _) => cxt.fail("`<-` can only be used inside a monad block")
    ETagged(_, x, _, _) =>
      cxt.fail("labelled argument " + x + "= can only appear in a call")
    ERange(_, _, _, _) => cxt.fail("a range can only be used in a for loop")
  }
}

///|
fn elab_raise(cxt : Cxt, x : @parser.Expr) -> Tm raise ElabError {
  if !cxt.can_raise {
    cxt.fail("`raise` outside of a function declared with `raise`")
  }
  let (t, ty) = infer_ins(cxt, x)
  match force(ty) {
    VData(d, _) if d == "Error" || (data_info(d) is Some(di) && di.is_error) =>
      ()
    _ => cxt.fail("only errors can be raised, not " + cxt.show(ty))
  }
  Raise(t)
}

///|
fn elab_return(cxt : Cxt, x : @parser.Expr?) -> Tm raise ElabError {
  match cxt.ret_ty {
    None => cxt.fail("`return` outside of a function")
    Some(r) =>
      match x {
        Some(x) => Return(check(cxt, x, r))
        None => {
          cxt.unify(r, VData("Unit", []))
          Return(Lit(LUnit))
        }
      }
  }
}

///|
fn elab_field(
  cxt : Cxt,
  t : Tm,
  ty : Val,
  f : String,
) -> (Tm, Val) raise ElabError {
  match head_name(ty) {
    Some(d) =>
      match data_info(d) {
        Some({ fields: Some(fs), .. }) if fs.contains("_" + f) || fs.contains(f) => {
          let fname = if fs.contains(f) { f } else { "_" + f }
          let name = d + "::" + fname
          let g = global_entry(cxt, name)
          app_core(cxt, Global(name), g.vty, 0, None, Some([AV(t, ty)]))
        }
        _ => cxt.fail("type " + cxt.show(ty) + " has no field " + f)
      }
    None => cxt.fail("cannot access field " + f + " of " + cxt.show(ty))
  }
}

///|
/// The tuple type `(A, B, ..)`.
fn tuple_type(cxt : Cxt, es : Array[@parser.Expr]) -> Tm raise ElabError {
  let name = "Tuple" + es.length().to_string()
  ensure(cxt, name)
  if !globals.contains(name) {
    cxt.fail("tuples of size " + es.length().to_string() + " are not supported")
  }
  apps(Global(name), es.map(e => (check_type(cxt, e), Impl)))
}

///|
fn elab_tuple(
  cxt : Cxt,
  es : Array[@parser.Expr],
  expected : Val?,
) -> (Tm, Val) raise ElabError {
  let name = "Tuple" + es.length().to_string()
  if !globals.contains(name) && !st.thunks.contains(name) {
    cxt.fail("tuples of size " + es.length().to_string() + " are not supported")
  }
  let con = name + "::mk"
  let g = global_entry(cxt, con)
  let (t, ty) = app_core(
    cxt,
    Global(con),
    g.vty,
    es.length(),
    None,
    Some(es.map(AE(_))),
  )
  match expected {
    Some(e) => cxt.unify(e, ty)
    None => ()
  }
  (t, ty)
}

///|
fn elab_struct(
  cxt : Cxt,
  fields : Array[(String, @parser.Expr)],
  expected : Val?,
) -> (Tm, Val) raise ElabError {
  let names = fields.map(f => f.0)
  let d = match expected.bind(head_name) {
    Some(d) if data_info(d) is Some({ fields: Some(_), .. }) => d
    _ => {
      let mut found : String? = None
      for name, g in globals {
        if g.kind is GData({ fields: Some(fs), is_trait: false, .. }) &&
          fs.length() == names.length() &&
          names.iter().all(n => fs.contains(n)) {
          found = Some(name)
        }
      }
      match found {
        Some(d) => d
        None => cxt.fail("no struct with fields " + names.join(", "))
      }
    }
  }
  let fs = data_info(d).unwrap().fields.unwrap()
  let args : Array[Arg] = []
  for f in fs {
    match fields.iter().find_first(x => x.0 == f) {
      Some((_, e)) => args.push(AE(e))
      None => cxt.fail("missing field " + f)
    }
  }
  for f in names {
    if !fs.contains(f) {
      cxt.fail("struct " + d + " has no field " + f)
    }
  }
  let con = d + "::mk"
  let g = global_entry(cxt, con)
  let np = nparams_of(con)
  // unify the result type first so that later fields see the parameters
  let mut t = Global(con)
  let mut ty = g.vty
  for _ in 0..<np {
    match force(ty) {
      VPi(_, i, _, _, cl) => {
        let m = cxt.fresh_meta()
        t = App(t, m, i)
        ty = inst(cl, cxt.eval(m))
      }
      _ => ()
    }
  }
  match expected {
    Some(e) => {
      let mut res = ty
      let mut l = cxt.lvl
      while force(res) is VPi(_, _, _, _, cl) {
        res = inst(cl, v_var(l))
        l = l + 1
      }
      // only unify parameters when the field types do not depend on fields
      if l == cxt.lvl || !occurs_any(l, cxt.lvl, res) {
        ignore(cxt.try_unify(e, res))
      }
    }
    None => ()
  }
  let (t, ty) = app_core(cxt, t, ty, 0, None, Some(args))
  match expected {
    Some(e) => cxt.unify(e, ty)
    None => ()
  }
  (t, ty)
}

///|
/// Does `v` mention a variable at a level in `[lo, hi)`?
fn occurs_any(hi : Int, lo : Int, v : Val) -> Bool {
  for x = lo; x < hi; x = x + 1 {
    if occurs(hi, x, v) {
      return true
    }
  }
  false
}
