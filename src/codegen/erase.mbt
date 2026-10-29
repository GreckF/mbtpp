///|
/// Erasure of implicit arguments that are only needed for type checking.
///
/// An implicit parameter of a function, or an implicit field of a
/// constructor (like `n` in `Cons[n](T, Vector[T](n))`), is erased if it is
/// only used in erased positions: as an erased argument or field, or in
/// types. Starting from "everything implicit is erased", uses in relevant
/// positions are found until nothing changes (a greatest fixed point).
/// Parameters whose type is a sort are always erased, and so are proofs
/// (parameters and fields whose type is a proposition, implicit or not:
/// propositions are proof irrelevant, see tt/proofs.mbt); other instance
/// arguments and explicit arguments are never erased.
priv enum Owner {
  OFun(String, Int32)
  OCon(String, Int32)
  ONone
}

///|
priv struct Erasure {
  /// Function -> erased flags of its parameters.
  funs : Map[String, Array[Bool]]
  /// Constructor -> erased flags of its own arguments (without parameters).
  cons : Map[String, Array[Bool]]
  /// Parameters that are erased whatever their uses (type parameters,
  /// proofs).
  always : Map[String, Array[Bool]]
  /// Fields that are erased whatever their uses (proofs).
  cons_always : Map[String, Array[Bool]]
  mut changed : Bool
}

///|
fn Erasure::mark(self : Erasure, o : Owner) -> Unit {
  match o {
    OFun(f, i) =>
      match self.funs.get(f) {
        Some(flags) if flags[i] && !self.always.get(f).unwrap()[i] => {
          flags[i] = false
          self.changed = true
        }
        _ => ()
      }
    OCon(c, j) =>
      match self.cons.get(c) {
        Some(flags) if flags[j] && !self.cons_always.get(c).unwrap()[j] => {
          flags[j] = false
          self.changed = true
        }
        _ => ()
      }
    ONone => ()
  }
}

///|
fn Erasure::fun_erased(self : Erasure, f : String, i : Int32) -> Bool {
  match self.funs.get(f) {
    Some(flags) => i < flags.length() && flags[i]
    None => false
  }
}

///|
fn Erasure::con_erased(self : Erasure, c : String, j : Int32) -> Bool {
  match self.cons.get(c) {
    Some(flags) => j < flags.length() && flags[j]
    None => false
  }
}

///|
fn owner_push(env : Array[Owner], o : Owner) -> Array[Owner] {
  let e = env.copy()
  e.push(o)
  e
}

///|
/// Bind the slots of a pattern; constructor sub-patterns that inspect a
/// field make it relevant.
fn Erasure::pat(
  self : Erasure,
  p : @tt.CPat,
  slot : Owner,
  env : Array[Owner],
) -> Array[Owner] {
  let mut e = owner_push(env, slot)
  match p {
    CPCon(c, ps) =>
      for j = 0; j < ps.length(); j = j + 1 {
        let o = if self.con_erased(c, j) { OCon(c, j) } else { ONone }
        match ps[j] {
          CPCon(_, _) | CPLit(_) => self.mark(OCon(c, j))
          _ => ()
        }
        e = self.pat(ps[j], o, e)
      }
    _ => ()
  }
  e
}

///|
fn Erasure::walk(
  self : Erasure,
  env : Array[Owner],
  t : @tt.Tm,
  rel : Bool,
) -> Unit {
  match t {
    Var(ix) => if rel { self.mark(env[env.length() - 1 - ix]) }
    App(_, _, _) => {
      let (h, args) = flatten_app(t)
      match h {
        Global(n) =>
          match @tt.globals.get(n) {
            Some({ kind: GCon(ci), .. }) => {
              for k = 0; k < args.length(); k = k + 1 {
                let r = if k < ci.nparams {
                  false
                } else if k < ci.nparams + ci.nargs {
                  rel && !self.con_erased(n, k - ci.nparams)
                } else {
                  rel
                }
                self.walk(env, args[k], r)
              }
              return
            }
            Some({ kind: GPrim(_, arity), ty, .. }) => {
              let icits = binder_icits(ty, arity)
              for k = 0; k < args.length(); k = k + 1 {
                self.walk(env, args[k], rel && (k >= arity || icits[k] == Expl))
              }
              return
            }
            Some({ kind: GFunc(_, _, _), .. }) if func_arity(n) is Some(arity) => {
              for k = 0; k < args.length(); k = k + 1 {
                self.walk(
                  env,
                  args[k],
                  rel && !(k < arity && self.fun_erased(n, k)),
                )
              }
              return
            }
            _ => ()
          }
        _ => self.walk(env, h, rel)
      }
      for a in args {
        self.walk(env, a, rel)
      }
    }
    Lam(_, _, _, b) => self.walk(owner_push(env, ONone), b, rel)
    Let(_, ty, v, b) | LetMut(_, ty, v, b) => {
      // a proof is not computed
      self.walk(env, v, rel && !@tt.is_prop_head(ty))
      self.walk(owner_push(env, ONone), b, rel)
    }
    Match(ss, cls) => {
      for s in ss {
        self.walk(env, s, rel)
      }
      for cl in cls {
        if cl.pats.iter().any(has_double_pat) {
          // matched by the runtime matcher, which sees all fields
          fn all(p : @tt.CPat, e : Erasure) -> Unit {
            match p {
              CPCon(c, ps) =>
                for j = 0; j < ps.length(); j = j + 1 {
                  e.mark(OCon(c, j))
                  all(ps[j], e)
                }
              _ => ()
            }
          }

          for p in cl.pats {
            all(p, self)
          }
        }
        let mut e = env
        for p in cl.pats {
          e = self.pat(p, ONone, e)
        }
        self.walk(e, cl.body, rel)
      }
    }
    Try(b, cls) => {
      self.walk(env, b, rel)
      for cl in cls {
        let mut e = env
        for p in cl.pats {
          e = self.pat(p, ONone, e)
        }
        self.walk(e, cl.body, rel)
      }
    }
    Assign(_, v) | Return(v) | Raise(v) => self.walk(env, v, true)
    While(c, b, s) => {
      self.walk(env, c, true)
      self.walk(env, b, true)
      self.walk(env, s, true)
    }
    Seq(a, b) => {
      self.walk(env, a, true)
      self.walk(env, b, rel)
    }
    ArrayLit(es) =>
      for e in es {
        self.walk(env, e, rel)
      }
    _ => ()
  }
}

///|
/// Compute the erasure of all functions and constructors of the program.
fn compute_erasure() -> Erasure {
  let er : Erasure = {
    funs: {},
    cons: {},
    always: {},
    cons_always: {},
    changed: true,
  }
  for name, g in @tt.globals {
    match g.kind {
      GFunc(Some(_), _, _) if func_arity(name) is Some(n) => {
        let always = erased_params(name, n)
        let flags : Array[Bool] = []
        let mut t = g.ty
        for i = 0; i < n; i = i + 1 {
          match t {
            Pi(_, icit, _, _, b) => {
              flags.push(always[i] || icit == Impl)
              t = b
            }
            _ => flags.push(always[i])
          }
        }
        er.funs.set(name, flags)
        er.always.set(name, always)
      }
      GCon(ci) => {
        let proofs = @tt.proof_fields(name)
        let always : Array[Bool] = []
        let flags : Array[Bool] = []
        for j = 0; j < ci.nargs; j = j + 1 {
          let p = j < proofs.length() && proofs[j]
          always.push(p)
          flags.push(j < ci.nimpl || p)
        }
        er.cons.set(name, flags)
        er.cons_always.set(name, always)
      }
      _ => ()
    }
  }
  while er.changed {
    er.changed = false
    for name, g in @tt.globals {
      match g.kind {
        GFunc(Some(body), _, _) => {
          let n = func_arity(name).unwrap_or(0)
          let mut env : Array[Owner] = []
          let mut b = body
          for i = 0; i < n; i = i + 1 {
            match b {
              Lam(_, _, _, rest) => {
                env = owner_push(
                  env,
                  if er.fun_erased(name, i) {
                    OFun(name, i)
                  } else {
                    ONone
                  },
                )
                b = rest
              }
              _ => ()
            }
          }
          er.walk(env, b, true)
        }
        _ => ()
      }
    }
  }
  er
}
