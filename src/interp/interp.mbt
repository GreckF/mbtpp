///|
/// A tree-walking interpreter for elaborated core terms.
pub(all) enum RVal {
  RLit(@tt.Lit)
  /// Constructor with its own arguments (datatype parameters dropped).
  RCon(String, Array[RVal])
  /// A constructor or primitive waiting for more arguments.
  RPartial(Partial, Array[(RVal, @tt.Icit)])
  RClo(REnv, @tt.Tm)
  RArr(Array[RVal])
  /// Types and other erased values.
  RType
}

///|
pub(all) enum Partial {
  PCon(String, Int, Int)
  PPrim(String, Int)
}

///|
pub(all) enum REnv {
  ENil
  ECons(Ref[RVal], REnv)
}

///|
priv suberror Ctl {
  CBreak
  CContinue
  CReturn(RVal)
  CRaise(RVal)
  CAbort(String)
}

///|
pub suberror RunError {
  RunError(String)
}

///|
priv struct Machine {
  cache : Map[String, RVal]
  write : (String) -> Unit
}

///|
fn lookup(env : REnv, ix : Int) -> Ref[RVal] raise Ctl {
  let mut e = env
  let mut k = ix
  while true {
    match e {
      ECons(r, rest) => {
        if k == 0 {
          return r
        }
        k = k - 1
        e = rest
      }
      ENil => raise CAbort("unbound variable")
    }
  }
  raise CAbort("unbound variable")
}

///|
pub fn show_rval(v : RVal) -> String {
  match v {
    RLit(LStr(s)) => s.escape()
    RLit(LChar(c)) => c.to_string().escape()
    RLit(LInt(n)) => n.to_string()
    RLit(LBool(b)) => b.to_string()
    RLit(LUnit) => "()"
    RLit(LDouble(d)) => d.to_string()
    RCon(c, args) => {
      let short = match c.rev_find("::") {
        Some(i) => c.unsafe_substring(start=i + 2, end=c.length())
        None => c
      }
      if args.length() == 0 {
        short
      } else {
        short + "(" + args.map(show_rval).join(", ") + ")"
      }
    }
    RArr(xs) => "[" + xs.map(show_rval).join(", ") + "]"
    RClo(_, _) | RPartial(_, _) => "<function>"
    RType => "<type>"
  }
}

///|
fn Machine::global(self : Machine, n : String) -> RVal raise Ctl {
  match self.cache.get(n) {
    Some(v) => return v
    None => ()
  }
  let v = match @tt.globals.get(n) {
    Some(g) =>
      match g.kind {
        GFunc(Some(body), _, _) => self.eval(ENil, body)
        GFunc(None, _, _) => raise CAbort("function " + n + " has no body")
        GData(_) => RType
        GCon(ci) =>
          if ci.nparams + ci.nargs == 0 {
            RCon(n, [])
          } else {
            RPartial(PCon(n, ci.nparams, ci.nparams + ci.nargs), [])
          }
        GPrim(p, 0) => self.prim(p, [])
        GPrim(p, arity) => RPartial(PPrim(p, arity), [])
      }
    None => raise CAbort("unknown global " + n)
  }
  self.cache.set(n, v)
  v
}

///|
fn truthy(v : RVal) -> Bool raise Ctl {
  match v {
    RLit(LBool(b)) => b
    _ => raise CAbort("expected a boolean")
  }
}

///|
fn rmatch(p : @tt.CPat, v : RVal, out : Array[RVal]) -> Bool {
  out.push(v)
  match p {
    CPVar(_) | CPWild => true
    CPCon(c, ps) =>
      match v {
        RCon(c2, args) if c2 == c && args.length() == ps.length() => {
          for k = 0; k < ps.length(); k = k + 1 {
            if !rmatch(ps[k], args[k], out) {
              return false
            }
          }
          true
        }
        _ => false
      }
    CPLit(l) =>
      match v {
        RLit(l2) => l == l2
        _ => false
      }
  }
}

///|
fn push_env(env : REnv, vs : Array[RVal]) -> REnv {
  let mut e = env
  for v in vs {
    e = ECons(Ref::new(v), e)
  }
  e
}

///|
fn Machine::run_clauses(
  self : Machine,
  env : REnv,
  vs : Array[RVal],
  cls : Array[@tt.Clause],
) -> RVal? raise Ctl {
  for cl in cls {
    let out : Array[RVal] = []
    let mut ok = true
    for k = 0; k < cl.pats.length(); k = k + 1 {
      if !rmatch(cl.pats[k], vs[k], out) {
        ok = false
        break
      }
    }
    if ok {
      return Some(self.eval(push_env(env, out), cl.body))
    }
  }
  None
}

///|
fn Machine::eval(self : Machine, env : REnv, t : @tt.Tm) -> RVal raise Ctl {
  match t {
    Var(ix) => lookup(env, ix).val
    Global(n) => self.global(n)
    Meta(_)
    | InsertedMeta(_, _)
    | Pi(_, _, _, _, _)
    | U
    | PropU
    | Raises(_, _) => RType
    Lam(_, _, _, _) => RClo(env, t)
    App(f, a, i) => {
      let fv = self.eval(env, f)
      let av = self.eval(env, a)
      self.apply(fv, av, i)
    }
    Let(_, _, v, b) | LetMut(_, _, v, b) => {
      let x = self.eval(env, v)
      self.eval(ECons(Ref::new(x), env), b)
    }
    Lit(l) => RLit(l)
    Match(ss, cls) => {
      let vs = ss.map(s => self.eval(env, s))
      match self.run_clauses(env, vs, cls) {
        Some(v) => v
        None => raise CAbort("no match for " + vs.map(show_rval).join(", "))
      }
    }
    Assign(ix, v) => {
      let x = self.eval(env, v)
      lookup(env, ix).val = x
      RLit(LUnit)
    }
    While(c, b, step) => {
      while truthy(self.eval(env, c)) {
        ignore(self.eval(env, b)) catch {
          CBreak => break
          CContinue => ()
          e => raise e
        }
        ignore(self.eval(env, step))
      }
      RLit(LUnit)
    }
    Break => raise CBreak
    Continue => raise CContinue
    Return(v) => raise CReturn(self.eval(env, v))
    Raise(v) => raise CRaise(self.eval(env, v))
    Try(b, cls) =>
      self.eval(env, b) catch {
        CRaise(err) =>
          match self.run_clauses(env, [err], cls) {
            Some(v) => v
            None => raise CRaise(err)
          }
        e => raise e
      }
    ArrayLit(es) => RArr(es.map(e => self.eval(env, e)))
    Seq(a, b) => {
      ignore(self.eval(env, a))
      self.eval(env, b)
    }
  }
}

///|
fn Machine::apply(
  self : Machine,
  f : RVal,
  a : RVal,
  i : @tt.Icit,
) -> RVal raise Ctl {
  match f {
    RClo(env, Lam(_, _, _, body)) => {
      let env2 = ECons(Ref::new(a), env)
      match body {
        Lam(_, _, _, _) => RClo(env2, body)
        _ =>
          self.eval(env2, body) catch {
            CReturn(v) => v
            e => raise e
          }
      }
    }
    RPartial(PCon(n, np, total), args) => {
      let args2 = args.copy()
      args2.push((a, i))
      if args2.length() == total {
        RCon(n, args2[np:].to_array().map(x => x.0))
      } else {
        RPartial(PCon(n, np, total), args2)
      }
    }
    RPartial(PPrim(p, arity), args) => {
      let args2 = args.copy()
      args2.push((a, i))
      if args2.length() == arity {
        self.prim(p, args2.filter(x => x.1 == Expl).map(x => x.0))
      } else {
        RPartial(PPrim(p, arity), args2)
      }
    }
    RType => RType
    _ => raise CAbort("cannot apply " + show_rval(f))
  }
}

///|
fn Machine::prim(
  self : Machine,
  p : String,
  args : Array[RVal],
) -> RVal raise Ctl {
  match (p, args) {
    ("%print", [RLit(LStr(s))]) => {
      (self.write)(s)
      RLit(LUnit)
    }
    ("%error_to_string", [e]) => RLit(LStr(show_rval(e)))
    (p, _) if p.has_prefix("@mbt:") =>
      raise CAbort(
        "cannot run the imported MoonBit function " +
        p.unsafe_substring(start=5, end=p.length()) +
        " in the interpreter (imports are only type checked)",
      )
    ("%panic", _) => raise CAbort("panic")
    ("%abort", [RLit(LStr(s))]) => raise CAbort(s)
    ("%array_make", [RLit(LInt(n)), x]) => RArr(Array::make(n, x))
    ("%array_new", _) => RArr([])
    ("%array_length", [RArr(xs)]) => RLit(LInt(xs.length()))
    ("%array_get", [RArr(xs), RLit(LInt(i))]) =>
      if i >= 0 && i < xs.length() {
        xs[i]
      } else {
        raise CAbort("index out of bounds: " + i.to_string())
      }
    ("%array_set", [RArr(xs), RLit(LInt(i)), x]) =>
      if i >= 0 && i < xs.length() {
        xs[i] = x
        RLit(LUnit)
      } else {
        raise CAbort("index out of bounds: " + i.to_string())
      }
    ("%array_push", [RArr(xs), x]) => {
      xs.push(x)
      RLit(LUnit)
    }
    _ => {
      let lits : Array[@tt.Lit] = []
      for a in args {
        match a {
          RLit(l) => lits.push(l)
          _ => raise CAbort("bad arguments to primitive " + p)
        }
      }
      match @tt.prim_pure(p, lits) {
        Some(l) => RLit(l)
        None =>
          if p == "%int_div" || p == "%int_mod" {
            raise CAbort("division by zero")
          } else {
            raise CAbort("primitive " + p + " failed")
          }
      }
    }
  }
}

///|
/// Run `main` of the program that was last type checked.
pub fn run_main(write : (String) -> Unit) -> Unit raise RunError {
  let m = { cache: {}, write }
  let body = match @tt.global_body("main") {
    Some(b) => b
    None => raise RunError("no main function")
  }
  ignore(m.eval(ENil, body)) catch {
    CReturn(_) => ()
    CRaise(e) => raise RunError("uncaught error: " + show_rval(e))
    CAbort(msg) => raise RunError("runtime error: " + msg)
    CBreak | CContinue => raise RunError("break/continue outside of a loop")
  }
}

///|
/// Evaluate a global constant (for tests).
pub fn eval_global(name : String) -> String raise RunError {
  let m = { cache: {}, write: _ => () }
  show_rval(m.global(name)) catch {
    CRaise(e) => raise RunError("uncaught error: " + show_rval(e))
    CAbort(msg) => raise RunError("runtime error: " + msg)
    _ => raise RunError("control flow escaped")
  }
}
