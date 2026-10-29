///|
/// Pattern and condition sugar: or-patterns, `as` on variables, `e is p`
/// conditions and `try ... noraise`.

///|
/// The alternatives of a pattern without or-patterns, each with the aliases
/// `(x, y)` (`x` names the value of variable `y`) of `y as x`.
fn pat_alts(
  cxt : Cxt,
  p : @parser.Pat,
) -> Array[(@parser.Pat, Array[(String, String)])] raise ElabError {
  match p {
    PVar(_, _) | PWild(_) | PLit(_, _) => [(p, [])]
    PCon(q, c, impl_ps, expl_ps) => {
      let ni = impl_ps.map(ps => ps.length()).unwrap_or(0)
      let subs = impl_ps.unwrap_or([]) + expl_ps
      sub_alts(cxt, subs).map(a => {
        let (ps, al) = a
        let impl2 = impl_ps.map(_ => ps[0:ni].to_array())
        (@parser.PCon(q, c, impl2, ps[ni:].to_array()), al)
      })
    }
    PTuple(q, ps) => sub_alts(cxt, ps).map(a => (@parser.PTuple(q, a.0), a.1))
    POr(q, a, b) => {
      let xs = pat_alts(cxt, a)
      let ys = pat_alts(cxt, b)
      let vs = alt_vars(xs[0])
      for y in ys {
        if alt_vars(y) != vs {
          cxt
          .at(q)
          .fail(
            "the alternatives of an or-pattern must bind the same variables",
          )
        }
      }
      xs + ys
    }
    PAs(q, inner, x) =>
      pat_alts(cxt, inner).map(a => {
        let (ip, al) = a
        match ip {
          PWild(_) => (@parser.PVar(q, x), al)
          PVar(_, y) | PAs(_, _, y) => (ip, al + [(x, y)])
          _ => (@parser.PAs(q, ip, x), al)
        }
      })
  }
}

///|
/// The alternatives of a sequence of patterns (their cartesian product).
fn sub_alts(
  cxt : Cxt,
  ps : Array[@parser.Pat],
) -> Array[(Array[@parser.Pat], Array[(String, String)])] raise ElabError {
  let mut out : Array[(Array[@parser.Pat], Array[(String, String)])] = [
    ([], []),
  ]
  for p in ps {
    let alts = pat_alts(cxt, p)
    let next = []
    for prefix in out {
      for a in alts {
        next.push((prefix.0 + [a.0], prefix.1 + a.1))
      }
    }
    out = next
  }
  out
}

///|
/// The variables bound by an alternative, sorted.
fn alt_vars(a : (@parser.Pat, Array[(String, String)])) -> Array[String] {
  let out : Array[String] = a.1.map(x => x.0)
  pat_vars(a.0, out)
  out.sort()
  out
}

///|
fn pat_vars(p : @parser.Pat, out : Array[String]) -> Unit {
  match p {
    PVar(_, x) => out.push(x)
    PWild(_) | PLit(_, _) => ()
    PCon(_, _, i, e) => {
      for q in i.unwrap_or([]) {
        pat_vars(q, out)
      }
      for q in e {
        pat_vars(q, out)
      }
    }
    PTuple(_, ps) =>
      for q in ps {
        pat_vars(q, out)
      }
    POr(_, a, _) => pat_vars(a, out)
    PAs(_, q, x) => {
      out.push(x)
      pat_vars(q, out)
    }
  }
}

///|
/// Expand the or-patterns of match arms into one arm per alternative (with
/// the same guard and body), and `y as x` into `y` with `let x = y`.
fn expand_arms(
  cxt : Cxt,
  arms : Array[@parser.Arm],
) -> Array[@parser.Arm] raise ElabError {
  let out : Array[@parser.Arm] = []
  for arm in arms {
    for a in pat_alts(cxt, arm.pat) {
      let (pat, al) = a
      let wrap = (e : @parser.Expr) => {
        if al.length() == 0 {
          return e
        }
        let p = e.pos()
        let stmts : Array[@parser.Stmt] = al.map(xy => {
          @parser.SLet(p, PVar(p, xy.0), None, EVar(p, xy.1))
        })
        stmts.push(SExpr(p, e))
        @parser.EBlock(p, stmts)
      }
      out.push({
        pos: arm.pos,
        pat,
        cond: arm.cond.map(wrap),
        rhs: arm.rhs.map(wrap),
      })
    }
  }
  out
}

///|
/// Does the `&&` chain of a condition test a pattern (`e is p`)?
fn has_is(c : @parser.Expr) -> Bool {
  match c {
    EIs(_, _, _) => true
    EBin(_, "&&", a, b) => has_is(a) || has_is(b)
    _ => false
  }
}

///|
fn conjuncts(c : @parser.Expr, out : Array[@parser.Expr]) -> Unit {
  match c {
    EBin(_, "&&", a, b) => {
      conjuncts(a, out)
      conjuncts(b, out)
    }
    _ => out.push(c)
  }
}

///|
/// `if c { t } else { f }` for a condition `c` with pattern tests: each
/// `e is p` becomes a match whose first arm continues with the rest of the
/// chain (so the variables of `p` are in scope there and in `t`), the
/// boolean conditions after it being its guard. `f` is repeated, once per
/// pattern test.
fn cond_expr(
  c : @parser.Expr,
  t : @parser.Expr,
  f : @parser.Expr,
) -> @parser.Expr {
  let cs : Array[@parser.Expr] = []
  conjuncts(c, cs)
  // the boolean conditions from `i` to the next pattern test
  let bools = (i : Int32) => {
    let mut k = i
    let mut e : @parser.Expr? = None
    while k < cs.length() && !(cs[k] is EIs(_, _, _)) {
      e = match e {
        None => Some(cs[k])
        Some(a) => Some(EBin(cs[k].pos(), "&&", a, cs[k]))
      }
      k = k + 1
    }
    (e, k)
  }
  fn go(i : Int32) -> @parser.Expr {
    if i >= cs.length() {
      return t
    }
    match cs[i] {
      EIs(p, e, pat) => {
        let (g, k) = bools(i + 1)
        EMatch(p, e, None, [
          { pos: p, pat, cond: g, rhs: Some(go(k)), },
          { pos: p, pat: PWild(p), cond: None, rhs: Some(f), },
        ])
      }
      other => {
        let (g, k) = bools(i)
        EIf(other.pos(), g.unwrap(), go(k), Some(f))
      }
    }
  }

  go(0)
}

///|
/// `try body catch { arms } noraise { ok }`: the handlers and the `noraise`
/// arms run outside of the `try`, so
/// `match (try { Ok(body) } catch { p => Err(rhs) }) { Ok(v) => match v { ok }; Err(r) => r }`.
fn try_noraise(
  p : Pos,
  body : @parser.Expr,
  arms : Array[@parser.Arm],
  ok : Array[@parser.Arm],
) -> @parser.Expr {
  let v = fresh_name_gen("__ok")
  let r = fresh_name_gen("__err")
  let wrap = (c : String, e : @parser.Expr) => {
    @parser.EApp(e.pos(), EVar(e.pos(), "Result::" + c), None, Some([e]))
  }
  let handlers = arms.map(a => { ..a, rhs: a.rhs.map(e => wrap("Err", e)), })
  EMatch(p, ETry(p, wrap("Ok", body), handlers, None), None, [
    {
      pos: p,
      pat: PCon(p, "Result::Ok", None, [PVar(p, v)]),
      cond: None,
      rhs: Some(EMatch(p, EVar(p, v), None, ok)),
    },
    {
      pos: p,
      pat: PCon(p, "Result::Err", None, [PVar(p, r)]),
      cond: None,
      rhs: Some(EVar(p, r)),
    },
  ])
}

///|
/// The expansion of an expression that is sugar for another.
fn sugar(e : @parser.Expr) -> @parser.Expr? {
  match e {
    EIf(p, c, t, el) if has_is(c) =>
      Some(cond_expr(c, t, el.unwrap_or(ELit(p, LUnit))))
    EIs(p, _, _) | EBin(p, "&&", _, _) if has_is(e) =>
      Some(cond_expr(e, ELit(p, LBool(true)), ELit(p, LBool(false))))
    ETry(p, body, arms, Some(ok)) => Some(try_noraise(p, body, arms, ok))
    _ => None
  }
}
