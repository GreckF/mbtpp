///|
/// A small tactic language: `proof { intros x; exact e; ... }`.
priv struct Goal {
  cxt : Cxt
  ty : Val
  meta : Tm
}

///|
fn tm_shift(t : Tm, d : Int, c : Int) -> Tm {
  let go = (x : Tm) => tm_shift(x, d, c)
  match t {
    Var(ix) => if ix >= c { Var(ix + d) } else { t }
    Lam(x, i, g, b) => Lam(x, i, g, tm_shift(b, d, c + 1))
    App(f, a, i) => App(go(f), go(a), i)
    Pi(x, i, g, a, b) => Pi(x, i, g, go(a), tm_shift(b, d, c + 1))
    Let(x, a, v, b) => Let(x, go(a), go(v), tm_shift(b, d, c + 1))
    Match(ss, cls) =>
      Match(
        ss.map(go),
        cls.map(cl => {
          pats: cl.pats,
          body: tm_shift(cl.body, d, c + pats_slots(cl.pats)),
        }),
      )
    Raises(a, e) => Raises(go(a), go(e))
    _ => t
  }
}

///|
fn tm_eq(a : Tm, b : Tm) -> Bool {
  match (a, b) {
    (Var(x), Var(y)) => x == y
    (Global(x), Global(y)) => x == y
    (Meta(x), Meta(y)) => x == y
    (Lam(_, i, _, b1), Lam(_, j, _, b2)) => i == j && tm_eq(b1, b2)
    (App(f1, a1, i), App(f2, a2, j)) => i == j && tm_eq(f1, f2) && tm_eq(a1, a2)
    (Pi(_, i, _, a1, b1), Pi(_, j, _, a2, b2)) =>
      i == j && tm_eq(a1, a2) && tm_eq(b1, b2)
    (U, U) | (PropU, PropU) => true
    (Lit(x), Lit(y)) => x == y
    _ => false
  }
}

///|
/// Replace occurrences of `a` (shifted under binders) by the variable bound
/// at depth `d`.
fn tm_abstract(t : Tm, a : Tm, d : Int) -> (Tm, Bool) {
  if tm_eq(t, tm_shift(a, d, 0)) {
    return (Var(d), true)
  }
  let mut found = false
  let go = (x : Tm, k : Int) => {
    let (r, f) = tm_abstract(x, a, d + k)
    if f {
      found = true
    }
    r
  }
  let r = match t {
    Lam(x, i, g, b) => Lam(x, i, g, go(b, 1))
    App(f, x, i) => App(go(f, 0), go(x, 0), i)
    Pi(x, i, g, s, b) => Pi(x, i, g, go(s, 0), go(b, 1))
    Let(x, s, v, b) => Let(x, go(s, 0), go(v, 0), go(b, 1))
    Match(ss, cls) =>
      Match(
        ss.map(x => go(x, 0)),
        cls.map(cl => { pats: cl.pats, body: go(cl.body, pats_slots(cl.pats)) }),
      )
    Raises(s, e) => Raises(go(s, 0), go(e, 0))
    _ => t
  }
  (r, found)
}

///|
fn solve_goal(g : Goal, t : Tm) -> Unit raise ElabError {
  g.cxt.unify(g.cxt.eval(g.meta), g.cxt.eval(t))
}

///|
fn new_goal(cxt : Cxt, ty : Val) -> Goal {
  { cxt, ty, meta: cxt.fresh_meta() }
}

///|
fn run_tactics(
  cxt : Cxt,
  tacs : Array[@parser.Tactic],
  ty : Val,
) -> Tm raise ElabError {
  let top = new_goal(cxt, ty)
  let goals = [top]
  for tac in tacs {
    let pos = match tac {
      TIntros(p, _)
      | TExact(p, _)
      | TRfl(p)
      | TDestruct(p, _)
      | TRewrite(p, _, _)
      | TApply(p, _)
      | TAssume(p, _, _) => p
    }
    if goals.length() == 0 {
      cxt.at(pos).fail("no goals left")
    }
    let g0 = goals.remove(0)
    let g = { ..g0, cxt: g0.cxt.at(pos) }
    let new_goals : Array[Goal] = []
    match tac {
      TIntros(_, names) => {
        let mut cur = g
        let mut k = 0
        while true {
          if names.length() > 0 && k >= names.length() {
            break
          }
          match force(cur.ty) {
            VPi(x, i, gr, a, cl) => {
              let name = if k < names.length() { names[k] } else { x }
              let v = v_var(cur.cxt.lvl)
              let c2 = cur.cxt.bind(name, a)
              let next = new_goal(c2, inst(cl, v))
              solve_goal(cur, Lam(name, i, gr, next.meta))
              cur = next
              k = k + 1
            }
            _ =>
              if names.length() > 0 {
                g.cxt.fail("nothing to introduce")
              } else {
                break
              }
          }
        }
        new_goals.push(cur)
      }
      TExact(_, e) => solve_goal(g, check(g.cxt, e, g.ty))
      TRfl(p) => solve_goal(g, check(g.cxt, EVar(p, "Id::Refl"), g.ty))
      TApply(_, e) => {
        let (t0, fty) = infer(g.cxt, e)
        let mut t = t0
        let mut ty = fty
        let holes : Array[Goal] = []
        let mut done = false
        while !done {
          let snap = snapshot_metas()
          if g.cxt.try_unify(g.ty, ty) {
            done = true
            break
          }
          restore_metas(snap)
          match force(ty) {
            VPi(_, i, _, a, cl) => {
              let h = new_goal(g.cxt, a)
              if i == Expl {
                holes.push(h)
              } else if i == Inst {
                add_pending(g.cxt, h.meta, a)
              }
              t = App(t, h.meta, i)
              ty = inst(cl, g.cxt.eval(h.meta))
            }
            _ =>
              g.cxt.fail(
                "cannot apply " +
                g.cxt.show(fty) +
                " to goal " +
                g.cxt.show(g.ty),
              )
          }
        }
        solve_goal(g, t)
        for h in holes {
          if force(h.cxt.eval(h.meta)) is VFlex(_, _) {
            new_goals.push(h)
          }
        }
      }
      TDestruct(p, x) => {
        let l = match g.cxt.lookup(x) {
          Some(l) => l
          None => g.cxt.fail("unknown variable " + x)
        }
        let xty = force(g.cxt.subst(g.cxt.types[l]))
        let pats : Array[@parser.Pat] = match xty {
          VData("Bool", _) => [PLit(p, LBool(true)), PLit(p, LBool(false))]
          VData(d, _) =>
            match data_info(d) {
              Some(di) =>
                di.cons.map(c => {
                  let ci = con_info(c).unwrap()
                  let args : Array[@parser.Pat] = []
                  for k = 0; k < ci.nargs - ci.nimpl; k = k + 1 {
                    args.push(PVar(p, x + "_" + k.to_string()))
                  }
                  @parser.PCon(p, c, None, args)
                })
              None =>
                g.cxt.fail("cannot destruct a value of type " + g.cxt.show(xty))
            }
          _ => g.cxt.fail("cannot destruct a value of type " + g.cxt.show(xty))
        }
        let clauses : Array[Clause] = []
        let sval = v_var(l)
        for pat in pats {
          let out = check_pat(g.cxt, pat, xty, true, Some(sval), true)
          if out.conflict {
            continue
          }
          let h = new_goal(out.cxt, out.cxt.subst(g.ty))
          new_goals.push(h)
          clauses.push({ pats: [out.pat], body: h.meta })
        }
        solve_goal(g, Match([Var(g.cxt.lvl - 1 - l)], clauses))
      }
      TRewrite(_, h, rev) => {
        let (th, hty) = infer_ins(g.cxt, h)
        let (ety, a, b) = match force(hty) {
          VData("Id", [(t, _), (a, _), (b, _)]) => (t, a, b)
          other =>
            g.cxt.fail("rewrite needs an equation, not " + g.cxt.show(other))
        }
        // `rewrite h` (h : a === b) replaces a by b; `rewrite <- h` b by a.
        let (from, to) = if rev { (b, a) } else { (a, b) }
        let c = g.cxt
        let gt = tm_shift(c.quote(g.ty), 1, 0)
        let ft = tm_shift(c.quote(from), 1, 0)
        let (motive, found) = tm_abstract(gt, ft, 0)
        // retry on unfolded normal forms
        let (motive, found) = if found {
          (motive, found)
        } else {
          tm_abstract(
            tm_shift(quote_full(c.lvl, g.ty), 1, 0),
            tm_shift(quote_full(c.lvl, from), 1, 0),
            0,
          )
        }
        if !found {
          c.fail("rewrite: " + c.show(from) + " does not occur in the goal")
        }
        // proof of `to === from`
        let eq_tm = if rev {
          th
        } else {
          apps(Global("Id::sym"), [
            (c.quote(ety), Impl),
            (c.quote(a), Impl),
            (c.quote(b), Impl),
            (th, Expl),
          ])
        }
        let new_ty = eval(push1(c.env, to), motive)
        let c2 = c.bind(
          "_",
          VData("Id", [(ety, Impl), (to, Expl), (from, Expl)]),
        )
        let h2 = new_goal(c2, new_ty)
        new_goals.push(h2)
        solve_goal(
          g,
          Match([eq_tm], [{ pats: [CPCon("Id::Refl", [])], body: h2.meta }]),
        )
      }
      TAssume(_, x, pe) => {
        let pt = check_type(g.cxt, pe)
        let pv = g.cxt.eval(pt)
        let proof_goal = new_goal(g.cxt, pv)
        let main_goal = new_goal(g.cxt.bind(x, pv), g.ty)
        solve_goal(g, Let(x, pt, proof_goal.meta, main_goal.meta))
        new_goals.push(main_goal)
        new_goals.push(proof_goal)
      }
    }
    for k = new_goals.length() - 1; k >= 0; k = k - 1 {
      goals.insert(0, new_goals[k])
    }
  }
  if goals.length() > 0 {
    let g = goals[0]
    g.cxt.fail(
      "unsolved goal(s); the first is\n  " +
      g.cxt.show(g.ty) +
      "\nin context " +
      g.cxt.names.filter(n => n != "_").join(", "),
    )
  }
  top.meta
}
