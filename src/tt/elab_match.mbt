///|
/// Dependent pattern matching.
priv struct PatOut {
  cxt : Cxt
  pat : CPat
  slot : Int32
  conflict : Bool
  /// For constructor patterns: the constructor's return type.
  ret_ty : Val?
}

///|
fn nat_pat(p : Pos, n : Int32) -> @parser.Pat {
  if n == 0 {
    PCon(p, "Nat::Z", None, [])
  } else {
    PCon(p, "Nat::S", None, [nat_pat(p, n - 1)])
  }
}

///|
/// Check a pattern against `ty`. The pattern's slot is defined as `scrut`
/// when given (variable patterns at the top of a match); for constructor
/// patterns `refine_scrut` additionally unifies the scrutinee with the
/// constructor value. `index_unify` unifies the indices of `ty` with those of
/// the constructor.
fn check_pat(
  cxt0 : Cxt,
  p : @parser.Pat,
  ty0 : Val,
  index_unify : Bool,
  scrut : Val?,
  refine_scrut : Bool,
  as_name~ : String = "_",
) -> PatOut raise ElabError {
  let cxt = cxt0.at(p.pos())
  let ty = force(cxt.subst(ty0))
  let simple = (x : String, cp : CPat) => {
    let c2 = match scrut {
      Some(v) => cxt.define_local(x, ty, v)
      None => cxt.bind(x, ty)
    }
    { cxt: c2, pat: cp, slot: cxt.lvl, conflict: false, ret_ty: None, }
  }
  match p {
    PVar(_, x) => simple(x, CPVar(x))
    PWild(_) => simple("_", CPWild)
    // `p as x`: `x` names the slot of `p` (variables are handled by
    // `expand_arms`)
    PAs(_, PWild(q), x) =>
      check_pat(cxt, PVar(q, x), ty, index_unify, scrut, refine_scrut)
    PAs(q, PVar(_, _) | PAs(_, _, _), _) =>
      cxt.at(q).fail("a variable cannot be named twice here")
    PAs(_, inner, x) =>
      check_pat(cxt, inner, ty, index_unify, scrut, refine_scrut, as_name=x)
    POr(q, _, _) => cxt.at(q).fail("an or-pattern cannot be used here")
    PLit(q, LInt(n)) if head_name(ty) == Some("Nat") =>
      if n < 0 {
        cxt.fail("negative natural number")
      } else {
        check_pat(
          cxt,
          nat_pat(q, n),
          ty,
          index_unify,
          scrut,
          refine_scrut,
          as_name~,
        )
      }
    PLit(_, l) => {
      cxt.unify(ty, lit_type(l))
      simple(as_name, CPLit(l))
    }
    PTuple(q, ps) =>
      check_pat(
        cxt,
        PCon(q, "Tuple" + ps.length().to_string() + "::mk", None, ps),
        ty,
        index_unify,
        scrut,
        refine_scrut,
        as_name~,
      )
    PCon(cpos, name, impl_ps, expl_ps) => {
      let (d, sp) = match ty {
        VData(d, sp) => (d, sp)
        _ =>
          cxt.fail(
            "cannot match constructor " + name + " against type " + cxt.show(ty),
          )
      }
      let c = resolve_name(cxt, name, false, Some(d))
      record_global(cpos, name, c)
      let ci = match con_info(c) {
        Some(ci) if ci.data == d => ci
        _ => cxt.fail(name + " is not a constructor of " + d)
      }
      let impl_ps = impl_ps.unwrap_or([])
      if impl_ps.length() > ci.nimpl {
        cxt.fail("too many implicit arguments in pattern " + name)
      }
      if expl_ps.length() != ci.nargs - ci.nimpl {
        cxt.fail(
          "constructor " +
          name +
          " takes " +
          (ci.nargs - ci.nimpl).to_string() +
          " argument(s)",
        )
      }
      let s = cxt.lvl
      let mut cur = cxt.bind(as_name, ty)
      let mut cty = global_entry(cxt, c).vty
      let args : Spine = []
      for k = 0; k < ci.nparams; k = k + 1 {
        match force(cty) {
          VPi(_, i, _, _, cl) => {
            args.push((sp[k].0, i))
            cty = inst(cl, sp[k].0)
          }
          _ => cxt.fail("bad constructor type")
        }
      }
      let subs = []
      for k = 0; k < ci.nargs; k = k + 1 {
        if k < ci.nimpl {
          subs.push(
            if k < impl_ps.length() {
              impl_ps[k]
            } else {
              PWild(p.pos())
            },
          )
        } else {
          subs.push(expl_ps[k - ci.nimpl])
        }
      }
      let cps : Array[CPat] = []
      for k = 0; k < ci.nargs; k = k + 1 {
        match force(cty) {
          VPi(_, i, _, a, cl) => {
            let out = check_pat(cur, subs[k], a, true, None, false)
            if out.conflict {
              return {
                cxt: out.cxt,
                pat: CPWild,
                slot: s,
                conflict: true,
                ret_ty: None,
              }
            }
            cur = out.cxt
            cps.push(out.pat)
            args.push((v_var(out.slot), i))
            cty = inst(cl, v_var(out.slot))
          }
          _ => cxt.fail("bad constructor type")
        }
      }
      let ret = force(cur.subst(cty))
      let cv = VCon(c, args)
      let eqs = [(v_var(s), cv)]
      if index_unify {
        match ret {
          VData(_, rsp) =>
            for k = ci.nparams; k < sp.length() && k < rsp.length(); k = k + 1 {
              eqs.push((sp[k].0, rsp[k].0))
            }
          _ => ()
        }
      }
      match cur.refine(eqs) {
        ROk(c2) => cur = c2
        RConflict =>
          return {
            cxt: cur,
            pat: CPWild,
            slot: s,
            conflict: true,
            ret_ty: None,
          }
        RStuck(msg) =>
          cxt.fail(
            "cannot decide whether " +
            name +
            " matches " +
            cxt.show(ty) +
            " (" +
            msg +
            "); use `match e as x in T return R`",
          )
      }
      if refine_scrut {
        match scrut {
          Some(v) =>
            match cur.refine([(v, v_var(s))]) {
              ROk(c2) => cur = c2
              RConflict =>
                return {
                  cxt: cur,
                  pat: CPWild,
                  slot: s,
                  conflict: true,
                  ret_ty: None,
                }
              RStuck(_) => ()
            }
          None => ()
        }
      }
      {
        cxt: cur,
        pat: CPCon(c, cps),
        slot: s,
        conflict: false,
        ret_ty: Some(ret),
      }
    }
  }
}

///|
fn is_subsingleton(cxt : Cxt, d : String) -> Bool raise ElabError {
  let di = data_info(d).unwrap()
  if di.cons.length() > 1 {
    return false
  }
  for c in di.cons {
    let ci = con_info(c).unwrap()
    let mut ty = global_entry(cxt, c).vty
    let mut ts : LTypes = []
    for k = 0; k < ci.nparams + ci.nargs; k = k + 1 {
      match force(ty) {
        VPi(_, _, _, a, cl) => {
          if k >= ci.nparams && !is_prop_type(ts, a) {
            return false
          }
          let v = v_var(ts.length())
          ts = concat(ts, [Some(a)])
          ty = inst(cl, v)
        }
        _ => break
      }
    }
  }
  true
}

///|
/// Does a pattern look at the constructor of the value?
fn splits(p : @parser.Pat) -> Bool {
  match p {
    PCon(_, _, _, _) | PTuple(_, _) | PLit(_, _) => true
    PAs(_, q, _) => splits(q)
    POr(_, a, b) => splits(a) || splits(b)
    PVar(_, _) | PWild(_) => false
  }
}

///|
fn check_prop_elim(
  cxt : Cxt,
  tys : Array[Val],
  arms : Array[Array[@parser.Pat]],
  goal : Val,
) -> Unit raise ElabError {
  for k = 0; k < tys.length(); k = k + 1 {
    match force(tys[k]) {
      VData(d, _) =>
        match data_info(d) {
          Some(di) if di.is_prop => {
            let splits = arms.iter().any(ps => splits(ps[k]))
            if splits &&
              !is_prop_type(cxt.ltypes(), goal) &&
              !is_subsingleton(cxt, d) {
              cxt.fail(
                "cannot eliminate a proof of " +
                d +
                " into a type that is not a proposition",
              )
            }
          }
          _ => ()
        }
      _ => ()
    }
  }
}

///|
fn elab_match(
  cxt : Cxt,
  scr : @parser.Expr,
  ret : @parser.MatchRet?,
  arms : Array[@parser.Arm],
  goal : Val?,
) -> (Tm, Val) raise ElabError {
  let arms = expand_arms(cxt, arms)
  // `match (a, b) { (p, q) => ... }` matches on several scrutinees
  let scrs = match scr {
    ETuple(_, es) if ret is None &&
      arms
      .iter()
      .all(a => {
        match a.pat {
          PTuple(_, ps) => ps.length() == es.length()
          PWild(_) => true
          _ => false
        }
      }) => es
    _ => [scr]
  }
  let pats = arms.map(a => {
    match a.pat {
      PTuple(_, ps) if scrs.length() > 1 => ps
      PWild(q) if scrs.length() > 1 => scrs.map(_ => @parser.PWild(q))
      p => [p]
    }
  })
  match ret {
    Some(mr) => elab_match_ret(cxt, scr, mr, arms, goal)
    None => {
      let goal = match goal {
        Some(g) => g
        None => cxt.eval(cxt.fresh_meta())
      }
      let sts = scrs.map(s => infer_ins(cxt, s))
      let svals = sts.map(x => cxt.eval(x.0))
      let clauses : Array[Clause] = []
      for j = 0; j < arms.length(); j = j + 1 {
        let arm = arms[j]
        let mut cur = cxt.at(arm.pos)
        let cps : Array[CPat] = []
        let mut conflict = false
        for i = 0; i < scrs.length(); i = i + 1 {
          let out = check_pat(
            cur,
            pats[j][i],
            sts[i].1,
            true,
            Some(svals[i]),
            true,
          )
          cur = out.cxt
          if out.conflict {
            conflict = true
            break
          }
          cps.push(out.pat)
        }
        match (conflict, arm.rhs) {
          (true, _) => ()
          (false, None) =>
            if arm.cond is Some(_) {
              cur.fail("an impossible pattern cannot have a guard")
            } else if !has_empty_var(cur) {
              cur.fail("this pattern is not impossible")
            }
          (false, Some(rhs)) => {
            let cond = arm.cond.map(g => check(cur, g, bool_ty()))
            let body = check(cur, rhs, cur.subst(goal))
            clauses.push({ pats: cps, cond, body, })
          }
        }
      }
      check_prop_elim(cxt, sts.map(x => x.1), pats, goal)
      // coverage, generalising scrutinees that are not variables
      let mut cc = cxt
      let problem : Array[Val] = []
      for i = 0; i < scrs.length(); i = i + 1 {
        match force(svals[i]) {
          VRigid(x, []) if cxt.bound[x] => problem.push(svals[i])
          _ => {
            problem.push(v_var(cc.lvl))
            cc = cc.bind("_", sts[i].1)
          }
        }
      }
      coverage(cc, problem, clauses)
      (Match(sts.map(x => x.0), clauses), goal)
    }
  }
}

///|
/// Flatten the arguments of `D[..](..)(..)` in order.
fn flat_args(e : @parser.Expr, out : Array[@parser.Expr]) -> Unit {
  match e {
    EApp(_, f, i, x) => {
      flat_args(f, out)
      match i {
        Some(xs) =>
          for a in xs {
            out.push(a)
          }
        None => ()
      }
      match x {
        Some(xs) =>
          for a in xs {
            out.push(a)
          }
        None => ()
      }
    }
    _ => ()
  }
}

///|
fn elab_match_ret(
  cxt : Cxt,
  scr : @parser.Expr,
  mr : @parser.MatchRet,
  arms : Array[@parser.Arm],
  goal : Val?,
) -> (Tm, Val) raise ElabError {
  let (ts, a) = infer_ins(cxt, scr)
  let sval = cxt.eval(ts)
  let (d, sp) = match force(a) {
    VData(d, sp) => (d, sp)
    other => cxt.fail("cannot match on a value of type " + cxt.show(other))
  }
  let di = data_info(d).unwrap()
  let np = di.nparams
  // index variables and the `as` variable
  let names : Array[String] = []
  match mr.in_ty {
    Some(t) => {
      let args = []
      flat_args(t, args)
      let k0 = args.length() - di.nindices
      if k0 < 0 {
        cxt.fail("the `in` clause must name all indices of " + d)
      }
      for k = k0; k < args.length(); k = k + 1 {
        names.push(
          match args[k] {
            EVar(_, x) => x
            _ => "_"
          },
        )
      }
    }
    None =>
      for _ in 0..<di.nindices {
        names.push("_")
      }
  }
  let mut cm = cxt
  let mut dty = global_entry(cxt, d).vty
  let tsp : Spine = []
  for k = 0; k < np + di.nindices; k = k + 1 {
    match force(dty) {
      VPi(_, i, _, dom, cl) =>
        if k < np {
          tsp.push((sp[k].0, i))
          dty = inst(cl, sp[k].0)
        } else {
          let v = v_var(cm.lvl)
          cm = cm.bind(names[k - np], dom)
          tsp.push((v, i))
          dty = inst(cl, v)
        }
      _ => cxt.fail("bad datatype")
    }
  }
  cm = cm.bind(mr.as_name.unwrap_or("_"), VData(d, tsp))
  let r = match (mr.ret, goal) {
    (Some(r), _) => check_type(cm, r)
    (None, Some(g)) => quote(cm.lvl, g)
    (None, None) =>
      cxt.fail("cannot infer the type of this match; add `return`")
  }
  let idx_scrut = sp[np:].to_array().map(x => x.0)
  let res_ty = eval(concat(concat(cxt.env, idx_scrut), [sval]), r)
  match goal {
    Some(g) => cxt.unify(g, res_ty)
    None => ()
  }
  let clauses : Array[Clause] = []
  let arms = expand_arms(cxt, arms)
  for arm in arms {
    let out = check_pat(cxt.at(arm.pos), arm.pat, a, false, Some(sval), false)
    if out.conflict {
      continue
    }
    let rhs = match arm.rhs {
      Some(x) => x
      None => out.cxt.fail("this pattern is not impossible")
    }
    let (idx, xv) = match out.ret_ty {
      Some(VData(_, rsp)) =>
        (rsp[np:].to_array().map(x => x.0), v_var(out.slot))
      _ => (idx_scrut, sval)
    }
    let env = concat(concat(out.cxt.env[0:cxt.lvl].to_array(), idx), [xv])
    let g = out.cxt.subst(eval(env, r))
    let cond = arm.cond.map(e => check(out.cxt, e, bool_ty()))
    clauses.push({ pats: [out.pat], cond, body: check(out.cxt, rhs, g), })
  }
  check_prop_elim(cxt, [a], arms.map(x => [x.pat]), res_ty)
  // coverage over a generalised scrutinee
  let mut cc = cxt
  let gsp : Spine = []
  let mut dty = global_entry(cxt, d).vty
  for k = 0; k < np + di.nindices; k = k + 1 {
    match force(dty) {
      VPi(_, i, _, dom, cl) =>
        if k < np {
          gsp.push((sp[k].0, i))
          dty = inst(cl, sp[k].0)
        } else {
          let v = v_var(cc.lvl)
          cc = cc.bind("_", dom)
          gsp.push((v, i))
          dty = inst(cl, v)
        }
      _ => ()
    }
  }
  let x = v_var(cc.lvl)
  cc = cc.bind("_", VData(d, gsp))
  coverage(cc, [x], clauses)
  (Match([ts], clauses), res_ty)
}

// ---------------------------------------------------------------------------
// Coverage

///|
priv enum Cov {
  CYes
  CNo
  CBlocked(Int32)
  CUnknown
}

///|
fn cov_pat(cxt : Cxt, p : CPat, v : Val) -> Cov {
  let w = force(cxt.subst(v))
  match p {
    CPVar(_) | CPWild => CYes
    CPCon(c, ps) =>
      match w {
        VCon(c2, sp) => {
          if c2 != c {
            return CNo
          }
          let np = nparams_of(c)
          let rs : Array[Cov] = []
          for k = 0; k < ps.length() && np + k < sp.length(); k = k + 1 {
            rs.push(cov_pat(cxt, ps[k], sp[np + k].0))
          }
          cov_combine(rs)
        }
        VRigid(l, []) if cxt.bound[l] => CBlocked(l)
        _ => CUnknown
      }
    CPLit(l) =>
      match (w, l) {
        (VLit(l2), _) => if l == l2 { CYes } else { CNo }
        (_, LUnit) => CYes
        (VRigid(x, []), LBool(_)) if cxt.bound[x] => CBlocked(x)
        _ => CNo
      }
  }
}

///|
fn cov_combine(rs : Array[Cov]) -> Cov {
  if rs.iter().any(r => r is CNo) {
    return CNo
  }
  for r in rs {
    match r {
      CYes => ()
      other => return other
    }
  }
  CYes
}

///|
fn split_var(cxt : Cxt, l : Int32) -> Array[Cxt]? raise ElabError {
  let ty = force(cxt.subst(cxt.types[l]))
  match ty {
    VData("Bool", _) =>
      Some([
        cxt.define_var(l, VLit(LBool(true))),
        cxt.define_var(l, VLit(LBool(false))),
      ])
    VData(d, sp) =>
      match data_info(d) {
        Some(di) if !di.builtin => {
          let out : Array[Cxt] = []
          for c in di.cons {
            let ci = con_info(c).unwrap()
            let mut cty = global_entry(cxt, c).vty
            let args : Spine = []
            let mut cur = cxt
            for k = 0; k < ci.nparams + ci.nargs; k = k + 1 {
              match force(cty) {
                VPi(_, i, _, a, cl) =>
                  if k < ci.nparams {
                    args.push((sp[k].0, i))
                    cty = inst(cl, sp[k].0)
                  } else {
                    let v = v_var(cur.lvl)
                    cur = cur.bind("_", a)
                    args.push((v, i))
                    cty = inst(cl, v)
                  }
                _ => ()
              }
            }
            let cv = VCon(c, args)
            let eqs = [(v_var(l), cv)]
            match force(cur.subst(cty)) {
              VData(_, rsp) =>
                for k = ci.nparams
                    k < sp.length() && k < rsp.length()
                    k = k + 1 {
                  eqs.push((sp[k].0, rsp[k].0))
                }
              _ => ()
            }
            match cur.refine(eqs) {
              ROk(c2) => out.push(c2)
              RConflict => ()
              RStuck(_) =>
                match cur.refine([(v_var(l), cv)]) {
                  ROk(c2) => out.push(c2)
                  _ => ()
                }
            }
          }
          Some(out)
        }
        _ => None
      }
    _ => None
  }
}

///|
fn cover(
  cxt : Cxt,
  problem : Array[Val],
  clauses : Array[Clause],
  missing : Array[String],
  depth : Int32,
) -> Unit raise ElabError {
  let show_problem = () => {
    let s = problem.map(v => cxt.show(cxt.subst(v)))
    if s.length() == 1 {
      s[0]
    } else {
      "(" + s.join(", ") + ")"
    }
  }
  if depth > 64 {
    missing.push(show_problem() + " (too deep)")
    return
  }
  for cl in clauses {
    // a guarded clause may not match
    if cl.cond is Some(_) {
      continue
    }
    let rs : Array[Cov] = []
    for k = 0; k < problem.length(); k = k + 1 {
      rs.push(cov_pat(cxt, cl.pats[k], problem[k]))
    }
    match cov_combine(rs) {
      CYes => return
      CNo => continue
      CBlocked(l) =>
        match split_var(cxt, l) {
          Some(cases) => {
            for c2 in cases {
              cover(c2, problem, clauses, missing, depth + 1)
            }
            return
          }
          None => {
            missing.push(show_problem())
            return
          }
        }
      CUnknown => {
        missing.push(show_problem() + " (cannot decide)")
        return
      }
    }
  }
  if !has_empty_var(cxt) {
    missing.push(show_problem())
  }
}

///|
/// Does some bound variable have a type without possible constructors (like
/// `Fin(0)`)? Then the context is contradictory.
fn has_empty_var(cxt : Cxt) -> Bool raise ElabError {
  for l = 0; l < cxt.lvl; l = l + 1 {
    if cxt.bound[l] {
      match force(cxt.subst(cxt.types[l])) {
        VData(d, _) if d != "Bool" =>
          match split_var(cxt, l) {
            Some([]) => return true
            _ => ()
          }
        _ => ()
      }
    }
  }
  false
}

///|
fn coverage(
  cxt : Cxt,
  problem : Array[Val],
  clauses : Array[Clause],
) -> Unit raise ElabError {
  let missing : Array[String] = []
  cover(cxt, problem, clauses, missing, 0)
  if missing.length() > 0 {
    cxt.fail(
      "match is not exhaustive; missing case(s):\n  " + missing.join("\n  "),
    )
  }
}

// ---------------------------------------------------------------------------
// try / catch

///|
fn elab_try(
  cxt : Cxt,
  body : @parser.Expr,
  arms : Array[@parser.Arm],
  goal : Val?,
) -> (Tm, Val) raise ElabError {
  let bc = { ..cxt, can_raise: true, }
  let (tb, ty) = match goal {
    Some(g) => (check(bc, body, g), g)
    None => infer_ins(bc, body)
  }
  let clauses : Array[Clause] = []
  for arm in expand_arms(cxt, arms) {
    let c = cxt.at(arm.pos)
    let mut head = arm.pat
    while head is PAs(_, q, _) {
      head = q
    }
    let ety = match head {
      PCon(_, name, _, _) => {
        let con = resolve_name(c, name, false, None)
        match con_info(con) {
          Some(ci) => VData(ci.data, [])
          None => c.fail(name + " is not an error constructor")
        }
      }
      _ => VData("Error", [])
    }
    let out = check_pat(c, arm.pat, ety, true, None, false)
    let rhs = match arm.rhs {
      Some(x) => x
      None => c.fail("missing handler body")
    }
    let cond = arm.cond.map(e => check(out.cxt, e, bool_ty()))
    clauses.push({ pats: [out.pat], cond, body: check(out.cxt, rhs, ty), })
  }
  (Try(tb, clauses), ty)
}
