///|
/// Running functions with mutable state during type checking. A call of a
/// function whose body has `let mut`, loops, `return`, `raise`, ... is run
/// like the interpreter would run it. The call becomes the value it returns
/// only if the run finishes: a decision on an unknown value (a variable),
/// an error that escapes, an array, an imported MoonBit function or an
/// async function keep the whole call folded, as before. The result depends
/// on the arguments only, so it may stand for the call. `print` is skipped:
/// output does not change the result.

///|
priv suberror ExecStop {
  /// The run cannot go on: the call stays folded.
  XStuck
  Brk
  Cont
  Ret(Val)
  Thrown(Val)
}

///|
/// The variables of a run: their current values, and whether they are
/// `let mut`.
priv struct XEnv {
  vals : Array[Ref[Val]]
  muts : Array[Bool]
}

///|
fn XEnv::push(self : XEnv, v : Val, is_mut : Bool) -> XEnv {
  let vals = self.vals.copy()
  vals.push(Ref::new(v))
  let muts = self.muts.copy()
  muts.push(is_mut)
  { vals, muts, }
}

///|
fn XEnv::snapshot(self : XEnv) -> Env {
  self.vals.map(r => r.val)
}

///|
fn XEnv::slot(self : XEnv, ix : Int32) -> Int32 {
  self.vals.length() - 1 - ix
}

///|
/// Primitives with effects or on mutable data: a run that uses them stays
/// folded (`%print` is skipped where its result is not used).
fn effectful_prim(p : String) -> Bool {
  p.has_prefix("@mbt:") ||
  p.has_prefix("%array") ||
  p == "%print" ||
  p == "%panic" ||
  p == "%abort"
}

///|
/// Does a value use an effectful primitive (or a mutable array)? With
/// `print_ok`, a pending `print` is allowed (a discarded result).
fn has_effect(v : Val, print_ok : Bool) -> Bool {
  let sp_eff = (sp : Spine) => sp.iter().any(a => has_effect(a.0, false))
  match v {
    VPrim(n, sp) =>
      match globals.get(n) {
        Some({ kind: GPrim(p, _), .. }) =>
          if p == "%print" && print_ok {
            false
          } else {
            effectful_prim(p) || sp_eff(sp)
          }
        _ => sp_eff(sp)
      }
    VRigid(_, sp)
    | VFlex(_, sp)
    | VGlobal(_, sp)
    | VData(_, sp)
    | VCon(_, sp) => sp_eff(sp)
    VMatch(env, vs, _, sp) =>
      env.iter().any(x => has_effect(x, false)) ||
      vs.iter().any(x => has_effect(x, false)) ||
      sp_eff(sp)
    // a function with mutable state is only run when called
    VLam(_, _, _, cl) =>
      contains_imperative(cl.body) ||
      cl.env.iter().any(x => has_effect(x, false))
    VPi(_, _, _, a, cl) =>
      has_effect(a, false) || cl.env.iter().any(x => has_effect(x, false))
    VRaises(a, e) => has_effect(a, false) || has_effect(e, false)
    VStuck(_, _, _) | VArrLit(_) => true
    VU | VProp | VLit(_) => false
  }
}

///|
/// Does `t` contain a lambda that uses a `let mut` variable of the run? Its
/// value would be captured, not shared, so such a run stays folded.
fn captures_mut(t : Tm, xe : XEnv, depth : Int32, in_lam : Bool) -> Bool {
  let go = (x : Tm, d : Int32) => captures_mut(x, xe, depth + d, in_lam)
  match t {
    Var(ix) =>
      in_lam && ix >= depth && xe.muts.get(xe.slot(ix - depth)).unwrap_or(false)
    Lam(_, _, _, b) => captures_mut(b, xe, depth + 1, true)
    App(f, a, _) => go(f, 0) || go(a, 0)
    Pi(_, _, _, a, b) => go(a, 0) || go(b, 1)
    Let(_, a, v, b) | LetMut(_, a, v, b) => go(a, 0) || go(v, 0) || go(b, 1)
    Match(ss, cls) =>
      ss.iter().any(s => go(s, 0)) ||
      cls
      .iter()
      .any(cl => {
        let k = pats_slots(cl.pats)
        cl.cond.map(c => go(c, k)).unwrap_or(false) || go(cl.body, k)
      })
    Try(b, cls) =>
      go(b, 0) ||
      cls
      .iter()
      .any(cl => {
        let k = pats_slots(cl.pats)
        cl.cond.map(c => go(c, k)).unwrap_or(false) || go(cl.body, k)
      })
    Raises(a, e) => go(a, 0) || go(e, 0)
    Assign(_, v) | Return(v) | Raise(v) => go(v, 0)
    While(c, b, s) => go(c, 0) || go(b, 0) || go(s, 0)
    Seq(a, b) => go(a, 0) || go(b, 0)
    ArrayLit(es) => es.iter().any(e => go(e, 0))
    _ => false
  }
}

///|
/// Run a call of the function `n` (body `body`, `arity` parameters) on the
/// spine `sp`; `None` if it does not finish (the call stays folded).
fn exec_call(n : String, body : Tm, arity : Int32, sp : Spine) -> Val? {
  if is_async_global(n) || time_up() {
    return None
  }
  last_unfolded.val = Some(n)
  let mut xe : XEnv = { vals: [], muts: [], }
  let mut b = body
  for k = 0; k < arity; k = k + 1 {
    match b {
      Lam(_, _, _, rest) => {
        xe = xe.push(sp[k].0, false)
        b = rest
      }
      _ => return None
    }
  }
  let res = exec(xe, b) catch {
    Ret(v) => v
    _ => return None
  }
  if has_effect(res, false) {
    return None
  }
  Some(app_spine(res, sp[arity:].to_array()))
}

///|
fn unit_val() -> Val {
  VLit(LUnit)
}

///|
/// Run `t`.
fn exec(xe : XEnv, t : Tm) -> Val raise ExecStop {
  if time_up() {
    raise XStuck
  }
  if !contains_imperative(t) && !calls_run(t) {
    // a pure term: evaluate it with the current values of the variables
    if captures_mut(t, xe, 0, false) {
      raise XStuck
    }
    return eval(xe.snapshot(), t)
  }
  match t {
    LetMut(_, _, v, b) => exec(xe.push(exec(xe, v), true), b)
    Let(_, _, v, b) => exec(xe.push(exec(xe, v), false), b)
    Assign(ix, v) => {
      let x = exec(xe, v)
      xe.vals[xe.slot(ix)].val = x
      unit_val()
    }
    Seq(a, b) => {
      let x = exec(xe, a)
      if has_effect(x, true) {
        raise XStuck
      }
      exec(xe, b)
    }
    While(c, body, step) => {
      while true {
        if time_up() {
          raise XStuck
        }
        match force(exec(xe, c)) {
          VLit(LBool(true)) => ()
          VLit(LBool(false)) => break
          _ => raise XStuck
        }
        let go_on = try {
          ignore(exec(xe, body))
          true
        } catch {
          Brk => false
          Cont => true
          e => raise e
        }
        if !go_on {
          break
        }
        ignore(exec(xe, step))
      }
      unit_val()
    }
    Break => raise Brk
    Continue => raise Cont
    Return(v) => raise Ret(exec(xe, v))
    Raise(v) => raise Thrown(exec(xe, v))
    Try(b, cls) =>
      exec(xe, b) catch {
        Thrown(err) =>
          match exec_clauses(xe, [err], cls) {
            Some(v) => v
            None => raise Thrown(err)
          }
        e => raise e
      }
    Match(ss, cls) => {
      let vs = ss.map(s => exec(xe, s))
      match exec_clauses(xe, vs, cls) {
        Some(v) => v
        None => raise XStuck
      }
    }
    // a call of a function that is run (it has mutable state or raises):
    // its errors reach the `try`s of this run
    App(_, _, _) if run_head(t) is Some((n, body, arity)) => {
      let (_, args) = flatten_app(t)
      let vals = args.map(a => (exec(xe, a.0), a.1))
      if time_up() {
        raise XStuck
      }
      last_unfolded.val = Some(n)
      let mut ce : XEnv = { vals: [], muts: [], }
      let mut b = body
      for k = 0; k < arity; k = k + 1 {
        match b {
          Lam(_, _, _, rest) => {
            ce = ce.push(vals[k].0, false)
            b = rest
          }
          _ => raise XStuck
        }
      }
      let r = exec(ce, b) catch {
        Ret(v) => v
        Brk | Cont => raise XStuck
        e => raise e
      }
      app_spine(r, vals[arity:].to_array())
    }
    App(f, a, i) => {
      let fv = exec(xe, f)
      let av = exec(xe, a)
      match force(fv) {
        // a lambda with mutable state: run its body
        VLam(_, _, _, cl) if contains_imperative(cl.body) => {
          let ce : XEnv = {
            vals: cl.env.map(v => Ref::new(v)),
            muts: cl.env.map(_ => false),
          }
          exec(ce.push(av, false), cl.body) catch {
            Ret(v) => v
            Brk | Cont => raise XStuck
            e => raise e
          }
        }
        _ => app_val(fv, av, i)
      }
    }
    Lam(_, _, _, _) =>
      if captures_mut(t, xe, 0, false) {
        raise XStuck
      } else {
        eval(xe.snapshot(), t)
      }
    // arrays are mutable: not run
    ArrayLit(_) => raise XStuck
    _ => raise XStuck
  }
}

///|
/// Run the first clause that matches `vs`; `None` if none does.
fn exec_clauses(
  xe : XEnv,
  vs : Array[Val],
  cls : Array[Clause],
) -> Val? raise ExecStop {
  for cl in cls {
    let out : Array[Val] = []
    let mut ok = true
    for k = 0; k < cl.pats.length(); k = k + 1 {
      match match_pat(cl.pats[k], vs[k], out) {
        Matched => ()
        Failed => {
          ok = false
          break
        }
        Stuck => raise XStuck
      }
    }
    if !ok {
      continue
    }
    let mut xe2 = xe
    for v in out {
      xe2 = xe2.push(v, false)
    }
    match cl.cond {
      Some(g) =>
        match force(exec(xe2, g)) {
          VLit(LBool(true)) => ()
          VLit(LBool(false)) => continue
          _ => raise XStuck
        }
      None => ()
    }
    return Some(exec(xe2, cl.body))
  }
  None
}

///|
/// A saturated call of a function that a run runs itself (with mutable state,
/// or raising errors): its name, body and arity.
fn run_head(t : Tm) -> (String, Tm, Int32)? {
  let (h, args) = flatten_app(t)
  match h {
    Global(n) =>
      match globals.get(n) {
        Some({ kind: GFunc(Some(body), imp, arity), .. }) if args.length() >=
          arity &&
          arity > 0 &&
          (imp || fn_raises(n, arity)) &&
          !is_async_global(n) => Some((n, body, arity))
        _ => None
      }
    _ => None
  }
}

///|
/// Does the function `n` (of `arity` parameters) raise errors?
fn fn_raises(n : String, arity : Int32) -> Bool {
  match globals.get(n) {
    Some(g) => {
      let mut t = g.ty
      for _ in 0..<arity {
        match t {
          Pi(_, _, _, _, b) => t = b
          _ => return false
        }
      }
      t is Raises(_, e) && tm_effect(e).1 is Some(_)
    }
    None => false
  }
}

///|
/// Does `t` call (outside of lambdas) a function that a run runs itself?
fn calls_run(t : Tm) -> Bool {
  match t {
    App(f, a, _) => run_head(t) is Some(_) || calls_run(f) || calls_run(a)
    Let(_, _, v, b) => calls_run(v) || calls_run(b)
    Match(ss, cls) =>
      ss.iter().any(calls_run) ||
      cls
      .iter()
      .any(cl => cl.cond.map(calls_run).unwrap_or(false) || calls_run(cl.body))
    _ => false
  }
}
