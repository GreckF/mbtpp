///|
/// Unification with pattern-unification of metavariables and definitional
/// proof irrelevance.
pub suberror UnifyError {
  UnifyError(String)
}

///|
/// Partial renaming from the context of a meta's solution (`dom` variables)
/// to the current context (`cod` variables).
priv struct PRen {
  occ : Int
  dom : Int
  cod : Int
  ren : Map[Int, Int]
}

///|
fn lift_pren(p : PRen) -> PRen {
  let ren = p.ren.copy()
  ren.set(p.cod, p.dom)
  { occ: p.occ, dom: p.dom + 1, cod: p.cod + 1, ren }
}

///|
fn lift_pren_n(p : PRen, k : Int) -> PRen {
  let mut q = p
  for _ in 0..<k {
    q = lift_pren(q)
  }
  q
}

///|
/// Duplicated variables are left out of the renaming. With `prune`, so are
/// arguments that are not variables (e.g. values that a variable was refined
/// to by pattern matching): the solution may then not mention them, which is
/// correct but not most general, so it is only tried last.
fn invert(
  lvl : Int,
  m : Int,
  sp : Spine,
  prune : Bool,
) -> PRen raise UnifyError {
  let ren : Map[Int, Int] = {}
  let dup : Array[Int] = []
  for k = 0; k < sp.length(); k = k + 1 {
    match force(sp[k].0) {
      VRigid(x, []) => if ren.contains(x) { dup.push(x) } else { ren.set(x, k) }
      _ =>
        if !prune {
          raise UnifyError("meta spine is not a list of distinct variables")
        }
    }
  }
  for x in dup {
    ren.remove(x)
  }
  { occ: m, dom: sp.length(), cod: lvl, ren }
}

///|
fn rename_sp(p : PRen, h : Tm, sp : Spine) -> Tm raise UnifyError {
  let mut t = h
  for a in sp {
    t = App(t, rename(p, a.0), a.1)
  }
  t
}

///|
fn rename(p : PRen, v : Val) -> Tm raise UnifyError {
  match force_meta(v) {
    VFlex(m, sp) =>
      if m == p.occ {
        raise UnifyError("occurs check")
      } else {
        rename_sp(p, Meta(m), sp)
      }
    VRigid(x, sp) =>
      match p.ren.get(x) {
        Some(y) => rename_sp(p, Var(p.dom - 1 - y), sp)
        None => raise UnifyError("variable escapes its scope")
      }
    VGlobal(n, sp) as w =>
      rename_sp(p, Global(n), sp) catch {
        e =>
          match unfold_any(n, sp) {
            Some(u) => {
              let u = force(u)
              if u is VGlobal(_, _) {
                raise e
              }
              ignore(w)
              rename(p, u)
            }
            None => raise e
          }
      }
    VData(n, sp) | VCon(n, sp) | VPrim(n, sp) => rename_sp(p, Global(n), sp)
    VLam(x, i, g, cl) =>
      Lam(x, i, g, rename(lift_pren(p), inst(cl, v_var(p.cod))))
    VPi(x, i, g, a, cl) =>
      Pi(x, i, g, rename(p, a), rename(lift_pren(p), inst(cl, v_var(p.cod))))
    VU => U
    VProp => PropU
    VLit(l) => Lit(l)
    VRaises(a, e) => Raises(rename(p, a), rename(p, e))
    VMatch(env, vs, cls, sp) => {
      let scr = vs.map(x => rename(p, x))
      let cls2 = cls.map(cl => {
        let k = pats_slots(cl.pats)
        {
          pats: cl.pats,
          body: rename(lift_pren_n(p, k), clause_body_val(env, p.cod, cl)),
        }
      })
      rename_sp(p, Match(scr, cls2), sp)
    }
    VArrLit(vs) => ArrayLit(vs.map(x => rename(p, x)))
    VStuck(_, _, _) =>
      raise UnifyError("cannot solve a meta with an imperative term")
  }
}

///|
fn solve(
  lvl : Int,
  m : Int,
  sp : Spine,
  rhs : Val,
  prune? : Bool = false,
) -> Unit raise UnifyError {
  let p = invert(lvl, m, sp, prune)
  let mut t = rename(p, rhs)
  for k = sp.length() - 1; k >= 0; k = k - 1 {
    t = Lam("x" + k.to_string(), sp[k].1, true, t)
  }
  metas[m].sol = Some(eval([], t))
}

///|
/// Solve `?m sp = rhs`; if `sp` is not a pattern, fall back to a first-order
/// approximation (`?m a = F b a` gives `?m = F b`), which is how higher-kinded
/// arguments like `M[T] = Option[Int]` are inferred.
fn solve_fo(
  ts : LTypes,
  m : Int,
  sp : Spine,
  rhs : Val,
) -> Unit raise UnifyError {
  let lvl = ts.length()
  solve(lvl, m, sp, rhs) catch {
    e => {
      let (mk, sp2) : ((Spine) -> Val, Spine) = match rhs {
        VData(n, sp2) => (s => VData(n, s), sp2)
        VCon(n, sp2) => (s => VCon(n, s), sp2)
        VRigid(x, sp2) => (s => VRigid(x, s), sp2)
        VGlobal(n, sp2) => (s => VGlobal(n, s), sp2)
        _ => return solve(lvl, m, sp, rhs, prune=true)
      }
      for j = 1; j <= sp.length() && j <= sp2.length(); j = j + 1 {
        let snap = snapshot_metas()
        try {
          let n1 = sp.length() - j
          let n2 = sp2.length() - j
          solve(lvl, m, sp[0:n1].to_array(), mk(sp2[0:n2].to_array()))
          for q = 0; q < j; q = q + 1 {
            unify(ts, sp[n1 + q].0, sp2[n2 + q].0)
          }
          return
        } catch {
          _ => restore_metas(snap)
        }
      }
      // last resort: leave out the arguments that are not variables
      solve(lvl, m, sp, rhs, prune=true) catch {
        _ => raise e
      }
    }
  }
}

///|
/// Types of the local variables (when known), used for proof irrelevance.
pub type LTypes = Array[Val?]

///|
fn types_push(ts : LTypes, t : Val?) -> LTypes {
  let r = ts.copy()
  r.push(t)
  r
}

///|
fn unify_sp(ts : LTypes, sp1 : Spine, sp2 : Spine) -> Unit raise UnifyError {
  if sp1.length() != sp2.length() {
    raise UnifyError("spine length mismatch")
  }
  for k = 0; k < sp1.length(); k = k + 1 {
    unify(ts, sp1[k].0, sp2[k].0)
  }
}

///|
pub fn unify(ts : LTypes, t : Val, u : Val) -> Unit raise UnifyError {
  let snap = snapshot_metas()
  unify_struct(ts, t, u) catch {
    e => {
      restore_metas(snap)
      if is_proof(ts, t) && is_proof(ts, u) {
        ()
      } else {
        raise e
      }
    }
  }
}

///|
fn unify_struct(ts : LTypes, t0 : Val, u0 : Val) -> Unit raise UnifyError {
  let lvl = ts.length()
  let t = force(t0)
  let u = force(u0)
  match (t, u) {
    (VLam(_, _, _, c1), VLam(_, _, _, c2)) =>
      unify(types_push(ts, None), inst(c1, v_var(lvl)), inst(c2, v_var(lvl)))
    (VLam(_, i, _, c1), other) | (other, VLam(_, i, _, c1)) =>
      unify(
        types_push(ts, None),
        inst(c1, v_var(lvl)),
        app_val(other, v_var(lvl), i),
      )
    (VPi(_, i1, g1, a1, c1), VPi(_, i2, g2, a2, c2)) => {
      if i1 != i2 || (i1 == Expl && g1 != g2) {
        raise UnifyError("binder mismatch")
      }
      unify(ts, a1, a2)
      unify(
        types_push(ts, Some(a1)),
        inst(c1, v_var(lvl)),
        inst(c2, v_var(lvl)),
      )
    }
    (VU, VU) | (VProp, VProp) => ()
    (VLit(a), VLit(b)) => if a != b { raise UnifyError("literal mismatch") }
    (VRaises(a1, e1), VRaises(a2, e2)) => {
      unify(ts, a1, a2)
      ignore(e1)
      ignore(e2)
    }
    (VRigid(x, sp1), VRigid(y, sp2)) if x == y => unify_sp(ts, sp1, sp2)
    (VFlex(m, sp1), VFlex(n, sp2)) if m == n =>
      unify_sp(ts, sp1, sp2) catch {
        _ => solve(lvl, m, sp1, u)
      }
    (VFlex(m, sp), other) | (other, VFlex(m, sp)) => solve_fo(ts, m, sp, other)
    (VData(a, sp1), VData(b, sp2)) | (VCon(a, sp1), VCon(b, sp2)) if a == b =>
      unify_sp(ts, sp1, sp2)
    (VPrim(a, sp1), VPrim(b, sp2)) if a == b => unify_sp(ts, sp1, sp2)
    (VArrLit(xs), VArrLit(ys)) if xs.length() == ys.length() =>
      for k = 0; k < xs.length(); k = k + 1 {
        unify(ts, xs[k], ys[k])
      }
    (VGlobal(a, sp1), VGlobal(b, sp2)) => {
      if a == b {
        let snap = snapshot_metas()
        try {
          unify_sp(ts, sp1, sp2)
          return
        } catch {
          _ => restore_metas(snap)
        }
      }
      match (unfold_any(a, sp1), unfold_any(b, sp2)) {
        (Some(x), Some(y)) => unify_struct(ts, x, y)
        (Some(x), None) => unify_struct(ts, x, u)
        (None, Some(y)) => unify_struct(ts, t, y)
        (None, None) => raise UnifyError("different functions")
      }
    }
    (VGlobal(a, sp), other) | (other, VGlobal(a, sp)) =>
      match unfold_any(a, sp) {
        Some(x) =>
          match force(x) {
            VGlobal(_, _) => raise UnifyError("stuck function")
            x2 => unify_struct(ts, x2, other)
          }
        None => raise UnifyError("stuck function")
      }
    (VMatch(env1, vs1, cls1, sp1), VMatch(env2, vs2, cls2, sp2)) => {
      if cls1.length() != cls2.length() || vs1.length() != vs2.length() {
        raise UnifyError("different matches")
      }
      for k = 0; k < vs1.length(); k = k + 1 {
        unify(ts, vs1[k], vs2[k])
      }
      for k = 0; k < cls1.length(); k = k + 1 {
        let n = pats_slots(cls1[k].pats)
        if n != pats_slots(cls2[k].pats) {
          raise UnifyError("different matches")
        }
        let mut ts2 = ts
        for _ in 0..<n {
          ts2 = types_push(ts2, None)
        }
        unify(
          ts2,
          clause_body_val(env1, lvl, cls1[k]),
          clause_body_val(env2, lvl, cls2[k]),
        )
      }
      unify_sp(ts, sp1, sp2)
    }
    _ => raise UnifyError("mismatch")
  }
}

// ---------------------------------------------------------------------------
// Types of values, for proof irrelevance

///|
fn instantiate(ty : Val, sp : Spine) -> Val? {
  let mut t = ty
  for a in sp {
    match force(t) {
      VPi(_, _, _, _, cl) => t = inst(cl, a.0)
      _ => return None
    }
  }
  Some(t)
}

///|
pub fn type_of(ts : LTypes, v : Val) -> Val? {
  match force(v) {
    VRigid(l, sp) =>
      if l < ts.length() {
        match ts[l] {
          Some(ty) => instantiate(ty, sp)
          None => None
        }
      } else {
        None
      }
    VGlobal(n, sp) | VData(n, sp) | VCon(n, sp) | VPrim(n, sp) =>
      match globals.get(n) {
        Some(g) => instantiate(g.vty, sp)
        None => None
      }
    VLit(l) => Some(lit_type(l))
    _ => None
  }
}

///|
pub fn lit_type(l : Lit) -> Val {
  match l {
    LInt(_) => VData("Int", [])
    LStr(_) => VData("String", [])
    LChar(_) => VData("Char", [])
    LBool(_) => VData("Bool", [])
    LDouble(_) => VData("Double", [])
    LUnit => VData("Unit", [])
  }
}

///|
pub fn is_prop_type(ts : LTypes, ty : Val) -> Bool {
  match force(ty) {
    VData(d, sp) =>
      match data_info(d) {
        Some(di) => di.is_prop && sp.length() >= di.nparams + di.nindices
        None => false
      }
    VPi(_, _, _, a, cl) =>
      is_prop_type(types_push(ts, Some(a)), inst(cl, v_var(ts.length())))
    VU | VProp | VLit(_) | VLam(_, _, _, _) | VRaises(_, _) => false
    other =>
      match type_of(ts, other) {
        Some(s) => force(s) is VProp
        None => false
      }
  }
}

///|
pub fn is_proof(ts : LTypes, v : Val) -> Bool {
  match type_of(ts, v) {
    Some(ty) => is_prop_type(ts, ty)
    None => false
  }
}
