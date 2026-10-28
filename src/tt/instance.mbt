///|
/// Instance search for trait arguments.
fn ensure_impls(cxt : Cxt, tr : String) -> Unit raise ElabError {
  match st.impl_sigs.get(tr) {
    Some(names) =>
      for n in names.copy() {
        ensure(cxt, n)
      }
    None => ()
  }
}

///|
/// Instances available from a local instance `t : ty`, including its
/// superclass instances.
fn instance_paths(
  t : Tm,
  ty : Val,
  out : Array[(Tm, Val)],
  depth : Int,
) -> Unit {
  out.push((t, ty))
  if depth > 8 {
    return
  }
  match force(ty) {
    VData(tr, [(self_v, _)]) =>
      match st.traits.get(tr) {
        Some(info) =>
          for s in info.supers {
            // `?self` is replaced by the goal's Self argument (fix_super_self)
            let acc = tr + "::super$" + s
            instance_paths(
              App(App(Global(acc), Global("?self"), Impl), t, Inst),
              VData(s, [(self_v, Expl)]),
              out,
              depth + 1,
            )
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn search_instance(cxt : Cxt, goal : Val, depth : Int) -> Tm? raise ElabError {
  if depth > 8 {
    return None
  }
  let (tr, gsp) = match force(goal) {
    VData(tr, sp) if st.traits.contains(tr) => (tr, sp)
    _ => return None
  }
  ensure_impls(cxt, tr)
  // an opaque (imported, unknown) trait has no methods: build its instance
  if st.opaque_traits.contains(tr) {
    return Some(App(Global(tr + "::mk"), cxt.quote(gsp[0].0), Impl))
  }
  // local instances
  for l = cxt.lvl - 1; l >= 0; l = l - 1 {
    let paths : Array[(Tm, Val)] = []
    instance_paths(Var(cxt.lvl - 1 - l), cxt.types[l], paths, 0)
    for p in paths {
      match force(p.1) {
        VData(tr2, _) if tr2 == tr =>
          if cxt.try_unify(goal, p.1) {
            return Some(fix_super_self(cxt, p.0, gsp))
          }
        _ => ()
      }
    }
  }
  // global instances
  for name in st.instances.get(tr).unwrap_or([]) {
    let g = global_entry(cxt, name)
    let snap = snapshot_metas()
    let mut t = Global(name)
    let mut ty = g.vty
    let subgoals : Array[(Tm, Val)] = []
    while force(ty) is VPi(_, i, _, a, cl) && i != Expl {
      let m = cxt.fresh_meta()
      if i == Inst {
        subgoals.push((m, a))
      }
      t = App(t, m, i)
      ty = inst(cl, cxt.eval(m))
    }
    if cxt.try_unify(goal, ty) {
      let mut ok = true
      for sg in subgoals {
        match search_instance(cxt, cxt.subst(sg.1), depth + 1) {
          Some(s) =>
            if !cxt.try_unify(cxt.eval(sg.0), cxt.eval(s)) {
              ok = false
            }
          None => ok = false
        }
        if !ok {
          break
        }
      }
      if ok {
        return Some(t)
      }
    }
    restore_metas(snap)
  }
  None
}

///|
/// Superclass projections need the `Self` argument; fill it in from the goal.
fn fix_super_self(cxt : Cxt, t : Tm, gsp : Spine) -> Tm {
  match t {
    App(App(Global(acc), Global("?self"), Impl), inner, Inst) =>
      App(
        App(Global(acc), cxt.quote(gsp[0].0), Impl),
        fix_super_self(cxt, inner, gsp),
        Inst,
      )
    _ => t
  }
}

///|
/// Try to solve a pending instance argument. Returns false if it must be
/// postponed (its type is not known yet).
fn solve_instance(p : PendingInst, final_ : Bool) -> Bool raise ElabError {
  let cxt = p.cxt
  match force(cxt.eval(p.meta)) {
    VFlex(_, _) => ()
    _ => return true
  }
  let goal = force(cxt.subst(p.ty))
  let blocked = match goal {
    VData(_, sp) => sp.length() > 0 && force(sp[0].0) is VFlex(_, _)
    _ => true
  }
  if blocked {
    if final_ {
      cxt.fail(
        "cannot infer the type of an instance argument: " + cxt.show(goal),
      )
    }
    return false
  }
  match search_instance(cxt, goal, 0) {
    Some(t) => {
      cxt.unify(cxt.eval(p.meta), cxt.eval(t))
      true
    }
    None => cxt.fail("no instance of " + cxt.show(goal))
  }
}

///|
fn solve_pending(final_ : Bool) -> Unit raise ElabError {
  let mut progress = true
  while progress {
    progress = false
    let ps = st.pending.copy()
    st.pending.clear()
    for p in ps {
      if solve_instance(p, false) {
        progress = true
      } else {
        st.pending.push(p)
      }
    }
  }
  if final_ {
    let ps = st.pending.copy()
    st.pending.clear()
    for p in ps {
      ignore(solve_instance(p, true))
    }
  }
}
