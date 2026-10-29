///|
/// Normalisation by evaluation.
pub fn eval(env : Env, t : Tm) -> Val {
  // out of time (see timelimit.mbt): stop computing
  if time_up() {
    return VStuck(env, t, [])
  }
  match t {
    Var(ix) => env[env.length() - 1 - ix]
    Global(n) => global_val(n)
    Meta(m) =>
      match metas[m].sol {
        Some(v) => v
        None => VFlex(m, [])
      }
    InsertedMeta(m, mask) => {
      let mut v = match metas[m].sol {
        Some(s) => s
        None => VFlex(m, [])
      }
      for i = 0; i < mask.length(); i = i + 1 {
        if mask[i] {
          v = app_val(v, env[i], Expl)
        }
      }
      v
    }
    Lam(x, i, g, b) => VLam(x, i, g, { env, body: b, })
    App(f, a, i) => app_val(eval(env, f), eval(env, a), i)
    Pi(x, i, g, a, b) => VPi(x, i, g, eval(env, a), { env, body: b, })
    Let(_, _, v, b) => eval(env_push(env, eval(env, v)), b)
    U => VU
    PropU => VProp
    Lit(l) => VLit(l)
    Match(scruts, cls) => match_vals(env, scruts.map(s => eval(env, s)), cls)
    Raises(a, e) => VRaises(eval(env, a), eval(env, e))
    LetMut(_, _, _, _)
    | Assign(_, _)
    | While(_, _, _)
    | Break
    | Continue
    | Return(_)
    | Raise(_)
    | Try(_, _)
    | Seq(_, _)
    | Defer(_, _) => VStuck(env, t, [])
    ArrayLit(es) => VArrLit(es.map(e => eval(env, e)))
  }
}

///|
pub fn global_val(n : String) -> Val {
  match globals.get(n) {
    Some(g) =>
      match g.kind {
        GFunc(_, _, _) => VGlobal(n, [])
        GData(_) => VData(n, [])
        GCon(_) => VCon(n, [])
        GPrim(_, _) => VPrim(n, [])
      }
    None => VGlobal(n, [])
  }
}

///|
pub fn inst(cl : Closure, v : Val) -> Val {
  eval(env_push(cl.env, v), cl.body)
}

///|
fn sp_push(sp : Spine, v : Val, i : Icit) -> Spine {
  let s = sp.copy()
  s.push((v, i))
  s
}

///|
pub fn app_val(f : Val, a : Val, i : Icit) -> Val {
  match f {
    VLam(_, _, _, cl) => inst(cl, a)
    VRigid(l, sp) => VRigid(l, sp_push(sp, a, i))
    VFlex(m, sp) => VFlex(m, sp_push(sp, a, i))
    VGlobal(n, sp) => VGlobal(n, sp_push(sp, a, i))
    VData(n, sp) => VData(n, sp_push(sp, a, i))
    VCon(n, sp) => VCon(n, sp_push(sp, a, i))
    VPrim(n, sp) => reduce_prim(n, sp_push(sp, a, i))
    VMatch(env, vs, cls, sp) => VMatch(env, vs, cls, sp_push(sp, a, i))
    VStuck(env, t, sp) => VStuck(env, t, sp_push(sp, a, i))
    _ => VStuck([], Lit(LUnit), [(f, Expl), (a, i)])
  }
}

///|
pub fn app_spine(f : Val, sp : Spine) -> Val {
  let mut v = f
  for a in sp {
    v = app_val(v, a.0, a.1)
  }
  v
}

///|
fn reduce_prim(n : String, sp : Spine) -> Val {
  match globals.get(n) {
    Some({ kind: GPrim(p, arity), .. }) if sp.length() == arity => {
      let lits : Array[Lit] = []
      for a in sp {
        if a.1 == Expl {
          match force(a.0) {
            VLit(l) => lits.push(l)
            _ => return VPrim(n, sp)
          }
        }
      }
      match prim_pure(p, lits) {
        Some(l) => VLit(l)
        None => VPrim(n, sp)
      }
    }
    _ => VPrim(n, sp)
  }
}

///|
/// Weak head normal form, as far as metas and folded applications allow.
pub fn force(v : Val) -> Val {
  match v {
    VFlex(m, sp) =>
      match metas[m].sol {
        Some(s) => force(app_spine(s, sp))
        None => v
      }
    VGlobal(n, sp) =>
      match unfold(n, sp) {
        Some(w) => {
          let w = force(w)
          if is_blocked(w) {
            v
          } else {
            w
          }
        }
        None => v
      }
    VMatch(env, vs, cls, sp) =>
      match match_vals_opt(env, vs, cls) {
        Some(r) => force(app_spine(r, sp))
        None => v
      }
    VPrim(n, sp) =>
      match reduce_prim(n, sp) {
        VPrim(_, _) => v
        w => w
      }
    _ => v
  }
}

///|
/// Like `force`, but keeps global function applications folded.
pub fn force_meta(v : Val) -> Val {
  match v {
    VFlex(m, sp) =>
      match metas[m].sol {
        Some(s) => force_meta(app_spine(s, sp))
        None => v
      }
    VMatch(env, vs, cls, sp) =>
      match match_vals_opt(env, vs, cls) {
        Some(r) => force_meta(app_spine(r, sp))
        None => v
      }
    VPrim(n, sp) =>
      match reduce_prim(n, sp) {
        VPrim(_, _) => v
        w => w
      }
    _ => v
  }
}

///|
/// Results that keep a function application folded.
fn is_blocked(v : Val) -> Bool {
  match v {
    VMatch(_, _, _, _) | VPrim(_, _) | VStuck(_, _, _) => true
    _ => false
  }
}

///|
/// Functions that could not be unfolded because their bodies were not
/// elaborated yet (they are defined later), since the start of the current
/// declaration: an error may come from the order in which files are checked.
pub let unfolded_too_early : Array[String] = []

///|
fn note_no_body(n : String) -> Unit {
  if !unfolded_too_early.contains(n) {
    unfolded_too_early.push(n)
  }
}

///|
/// Unfold a global function applied to at least as many arguments as it
/// has leading lambdas.
pub fn unfold(n : String, sp : Spine) -> Val? {
  match globals.get(n) {
    Some({ kind: GFunc(Some(body), false, arity), .. }) if sp.length() >= arity => {
      last_unfolded.val = Some(n)
      Some(app_spine(eval([], body), sp))
    }
    // with mutable state: run it (see exec.mbt)
    Some({ kind: GFunc(Some(body), true, arity), .. }) if sp.length() >= arity =>
      exec_call(n, body, arity, sp)
    Some({ kind: GFunc(None, _, _), .. }) => {
      note_no_body(n)
      None
    }
    _ => None
  }
}

///|
/// Unfold regardless of the number of arguments (used by conversion).
pub fn unfold_any(n : String, sp : Spine) -> Val? {
  match globals.get(n) {
    Some({ kind: GFunc(Some(body), false, _), .. }) =>
      Some(app_spine(eval([], body), sp))
    Some({ kind: GFunc(Some(body), true, arity), .. }) if sp.length() >= arity =>
      exec_call(n, body, arity, sp)
    Some({ kind: GFunc(None, _, _), .. }) => {
      note_no_body(n)
      None
    }
    _ => None
  }
}

// ---------------------------------------------------------------------------
// Pattern matching

///|
priv enum MatchRes {
  Matched
  Failed
  Stuck
}

///|
fn match_pat(p : CPat, v : Val, out : Array[Val]) -> MatchRes {
  out.push(v)
  match p {
    CPVar(_) | CPWild => Matched
    CPCon(c, ps) =>
      match force(v) {
        VCon(c2, sp) => {
          if c2 != c {
            return Failed
          }
          let np = match con_info(c) {
            Some(ci) => ci.nparams
            None => 0
          }
          if sp.length() - np != ps.length() {
            return Stuck
          }
          let mut res = Matched
          for k = 0; k < ps.length(); k = k + 1 {
            match match_pat(ps[k], sp[np + k].0, out) {
              Failed => return Failed
              Stuck => res = Stuck
              Matched => ()
            }
          }
          res
        }
        _ => Stuck
      }
    CPLit(l) =>
      match force(v) {
        VLit(l2) => if l == l2 { Matched } else { Failed }
        _ => Stuck
      }
  }
}

///|
/// Select the first clause that matches; `None` if the match is blocked.
pub fn match_vals_opt(env : Env, vs : Array[Val], cls : Array[Clause]) -> Val? {
  for cl in cls {
    let out : Array[Val] = []
    let mut res = Matched
    for k = 0; k < cl.pats.length(); k = k + 1 {
      match match_pat(cl.pats[k], vs[k], out) {
        Failed => {
          res = Failed
          break
        }
        Stuck => res = Stuck
        Matched => ()
      }
    }
    match res {
      Matched => {
        let env2 = env.copy()
        for v in out {
          env2.push(v)
        }
        match cl.cond {
          Some(g) =>
            match force(eval(env2, g)) {
              VLit(LBool(true)) => ()
              VLit(LBool(false)) => continue
              _ => return None
            }
          None => ()
        }
        return Some(eval(env2, cl.body))
      }
      Failed => continue
      Stuck => return None
    }
  }
  None
}

///|
fn match_vals(env : Env, vs : Array[Val], cls : Array[Clause]) -> Val {
  match match_vals_opt(env, vs, cls) {
    Some(v) => v
    None => VMatch(env, vs, cls, [])
  }
}

// ---------------------------------------------------------------------------
// Quotation

///|
fn quote_sp(lvl : Int32, h : Tm, sp : Spine, full : Bool) -> Tm {
  let mut t = h
  for a in sp {
    t = App(t, quote_with(lvl, a.0, full), a.1)
  }
  t
}

///|
pub fn fresh_vars(lvl : Int32, k : Int32) -> Array[Val] {
  let out : Array[Val] = []
  for j = 0; j < k; j = j + 1 {
    out.push(v_var(lvl + j))
  }
  out
}

///|
/// Evaluate the body of a clause of a blocked match under fresh variables.
pub fn clause_body_val(env : Env, lvl : Int32, cl : Clause) -> Val {
  eval(concat(env, fresh_vars(lvl, pats_slots(cl.pats))), cl.body)
}

///|
/// Evaluate the guard of a clause of a blocked match under fresh variables.
pub fn clause_guard_val(env : Env, lvl : Int32, cl : Clause) -> Val? {
  cl.cond.map(g => eval(concat(env, fresh_vars(lvl, pats_slots(cl.pats))), g))
}

///|
pub fn quote(lvl : Int32, v : Val) -> Tm {
  quote_with(lvl, v, false)
}

///|
/// Quote, unfolding global functions where they reduce.
pub fn quote_full(lvl : Int32, v : Val) -> Tm {
  quote_with(lvl, v, true)
}

///|
fn quote_with(lvl : Int32, v : Val, full : Bool) -> Tm {
  let q = (l : Int32, x : Val) => quote_with(l, x, full)
  match (if full { force(v) } else { force_meta(v) }) {
    VRigid(l, sp) => quote_sp(lvl, Var(lvl - 1 - l), sp, full)
    VFlex(m, sp) => quote_sp(lvl, Meta(m), sp, full)
    VGlobal(n, sp) | VData(n, sp) | VCon(n, sp) | VPrim(n, sp) =>
      quote_sp(lvl, Global(n), sp, full)
    VLam(x, i, g, cl) => Lam(x, i, g, q(lvl + 1, inst(cl, v_var(lvl))))
    VPi(x, i, g, a, cl) =>
      Pi(x, i, g, q(lvl, a), q(lvl + 1, inst(cl, v_var(lvl))))
    VU => U
    VProp => PropU
    VLit(l) => Lit(l)
    VRaises(a, e) => Raises(q(lvl, a), q(lvl, e))
    VMatch(env, vs, cls, sp) => {
      let cls2 = cls.map(cl => {
        let l2 = lvl + pats_slots(cl.pats)
        {
          pats: cl.pats,
          cond: clause_guard_val(env, lvl, cl).map(g => q(l2, g)),
          body: q(l2, clause_body_val(env, lvl, cl)),
        }
      })
      quote_sp(lvl, Match(vs.map(x => q(lvl, x)), cls2), sp, full)
    }
    VStuck(_, t, sp) => quote_sp(lvl, t, sp, full)
    VArrLit(vs) => ArrayLit(vs.map(x => q(lvl, x)))
  }
}

///|
pub fn nf(env : Env, t : Tm) -> Tm {
  quote(env.length(), eval(env, t))
}
