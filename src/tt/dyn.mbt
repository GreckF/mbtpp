///|
/// Trait objects. `&Tr` is the dependent struct
///
///     struct &Tr { ty : Type; inst : Tr(ty); val : ty }
///
/// generated on first use: a value of some type with its instance of `Tr`.
/// A value whose type has an instance is packed where an `&Tr` is expected
/// (`let x : &Show = 1`), and `&Tr` has an instance of `Tr` (and of its
/// supertraits) whose methods call those of the packed instance, so methods
/// (`x.to_string()`) and bounds (`println(x)`) work as for any type.
///
/// As in MoonBit, the trait must be object safe: `Self : Type`, and every
/// method (of the trait and its supertraits) takes `Self` as its first
/// parameter only, and is not generic.
fn dyn_name(tr : String) -> String {
  "&" + tr
}

///|
/// Does the de Bruijn index `ix` occur in `t`?
fn tm_occurs(t : Tm, ix : Int32) -> Bool {
  match t {
    Var(i) => i == ix
    Pi(_, _, _, a, b) => tm_occurs(a, ix) || tm_occurs(b, ix + 1)
    Lam(_, _, _, b) => tm_occurs(b, ix + 1)
    App(f, a, _) => tm_occurs(f, ix) || tm_occurs(a, ix)
    Raises(a, b) => tm_occurs(a, ix) || tm_occurs(b, ix)
    _ => false
  }
}

///|
/// Why trait `tr` cannot be used for trait objects (`None`: it can).
fn object_safety_problem(tr : String) -> String? {
  match st.traits.get(tr) {
    Some({ kind: U, .. }) => ()
    Some(_) => return Some("its Self is not a type")
    None => return Some(tr + " is not a trait")
  }
  for s in trait_supers(tr) {
    match object_safety_problem(s) {
      Some(why) => return Some("its supertrait " + s + ": " + why)
      None => ()
    }
  }
  for m in trait_method_names(tr) {
    // the method's type in the context [Self, inst]
    match trait_method_type(tr, m) {
      Some(Pi(_, Expl, _, Var(1), rest)) if !tm_occurs(rest, 2) => ()
      Some(Pi(_, Impl, _, _, _)) =>
        return Some("the method " + m + " is generic")
      _ =>
        return Some(
          "the method " + m + " does not take Self as its first parameter only",
        )
    }
  }
  None
}

///|
/// Declare `&tr` (once), with its instances.
fn ensure_dyn(cxt : Cxt, tr : String) -> Unit raise ElabError {
  let d = dyn_name(tr)
  if globals.contains(d) {
    return
  }
  ensure(cxt, tr)
  match object_safety_problem(tr) {
    Some(why) => cxt.fail("&" + tr + " is not a trait object type: " + why)
    None => ()
  }
  let p = cxt.pos
  elab_struct_decl({
    pos: p,
    name: d,
    impl_params: [],
    params: None,
    fields: [
      (p, "ty", EType(p)),
      (p, "inst", EApp(p, EVar(p, tr), None, Some([EVar(p, "ty")]))),
      (p, "val", EVar(p, "ty")),
    ],
  })
  // the instances of `tr` and of its supertraits
  let top = (a0 : Tm) => App(Global(d + "::inst"), a0, Expl)
  dyn_instances(d, tr, top)
}

///|
/// The instance of `tr` for `d` (and those of its supertraits), whose
/// packed instance is `get_inst(x)` for a value `x : d`.
fn dyn_instances(d : String, tr : String, get_inst : (Tm) -> Tm) -> Unit {
  let key = "impl$" + tr + "$" + d
  if globals.contains(key) {
    return
  }
  register(
    key,
    App(Global(tr), Global(d), Expl),
    GFunc(Some(dyn_dict(d, tr, get_inst)), false, 0),
  )
  map_push(st.instances, tr, key)
  map_push(st.instance_heads, tr, d)
  for s in trait_supers(tr) {
    dyn_instances(d, s, super_inst(d, tr, s, get_inst))
  }
}

///|
/// `tr::super$s[x.ty](get_inst(x))`: the instance of the supertrait.
fn super_inst(
  d : String,
  tr : String,
  s : String,
  get_inst : (Tm) -> Tm,
) -> (Tm) -> Tm {
  a0 => {
    App(
      App(Global(tr + "::super$" + s), App(Global(d + "::ty"), a0, Expl), Impl),
      get_inst(a0),
      Inst,
    )
  }
}

///|
/// The dictionary of `tr` at `Self = d`: each method unpacks its first
/// argument and calls the packed instance's method.
fn dyn_dict(d : String, tr : String, get_inst : (Tm) -> Tm) -> Tm {
  let args : Array[(Tm, Icit)] = [(Global(d), Impl)]
  for f in data_info(tr).unwrap().fields.unwrap() {
    if f.has_prefix("super$") {
      let s = f.unsafe_substring(start=6, end=f.length())
      args.push((dyn_dict(d, s, super_inst(d, tr, s, get_inst)), Expl))
      continue
    }
    // the number of explicit parameters of the method
    let mut n = 0
    let mut t = trait_method_type(tr, f).unwrap()
    while t is Pi(_, Expl, _, _, b) {
      n = n + 1
      t = b
    }
    let a0 = Var(n - 1)
    let mut call = App(
      App(Global(tr + "::" + f), App(Global(d + "::ty"), a0, Expl), Impl),
      get_inst(a0),
      Inst,
    )
    call = App(call, App(Global(d + "::val"), a0, Expl), Expl)
    for i = 1; i < n; i = i + 1 {
      call = App(call, Var(n - 1 - i), Expl)
    }
    let mut body = call
    for i = n - 1; i >= 0; i = i - 1 {
      body = Lam("a" + i.to_string(), Expl, i == 0, body)
    }
    args.push((body, Expl))
  }
  apps(Global(tr + "::mk"), args)
}

///|
/// Pack `t : aty` where an `&tr` is expected and `aty` is not one.
fn pack_dyn(cxt : Cxt, t : Tm, aty : Val, ty : Val) -> Tm? raise ElabError {
  match force(ty) {
    VData(d, []) if d.has_prefix("&") && head_name(aty) != Some(d) => {
      let tr = d.unsafe_substring(start=1, end=d.length())
      let a = cxt.quote(aty)
      let m = cxt.fresh_meta()
      add_pending(cxt, m, cxt.eval(App(Global(tr), a, Expl)))
      Some(apps(Global(d + "::mk"), [(a, Expl), (m, Expl), (t, Expl)]))
    }
    _ => None
  }
}
