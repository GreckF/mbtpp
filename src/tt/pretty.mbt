///|
/// Pretty printing of core terms in MoonBit++ syntax.
fn short_name(n : String) -> String {
  match con_info(n) {
    Some(_) =>
      match n.rev_find("::") {
        Some(i) => n.unsafe_substring(start=i + 2, end=n.length())
        None => n
      }
    None => n
  }
}

///|
fn fresh_name(names : Array[String], x : String) -> String {
  if x == "_" || !names.contains(x) {
    x
  } else {
    let mut k = 1
    while names.contains(x + k.to_string()) {
      k = k + 1
    }
    x + k.to_string()
  }
}

///|
fn flatten_app(t : Tm) -> (Tm, Array[(Tm, Icit)]) {
  let args : Array[(Tm, Icit)] = []
  let mut h = t
  while h is App(f, a, i) {
    args.push((a, i))
    h = f
  }
  args.rev_in_place()
  (h, args)
}

///|
fn nat_lit(t : Tm) -> Int? {
  match flatten_app(t) {
    (Global("Nat::Z"), []) => Some(0)
    (Global("Nat::S"), [(a, Expl)]) =>
      match nat_lit(a) {
        Some(n) => Some(n + 1)
        None => None
      }
    _ => None
  }
}

///|
fn show_lit(l : Lit) -> String {
  match l {
    LInt(n) => n.to_string()
    LStr(s) => s.escape()
    LChar(c) => c.to_string().escape()
    LBool(b) => b.to_string()
    LUnit => "()"
  }
}

///|
fn show_pat(names : Array[String], p : CPat) -> (String, Array[String]) {
  // Returns the printed pattern and the names it binds (in slot order).
  match p {
    CPVar(x) => {
      let y = fresh_name(names, x)
      (y, [y])
    }
    CPWild => ("_", ["_"])
    CPLit(l) => (show_lit(l), ["_"])
    CPCon(c, ps) => {
      let bound = ["_"]
      let shown : Array[String] = []
      let mut ns = names
      for q in ps {
        let (s, bs) = show_pat(ns, q)
        shown.push(s)
        for b in bs {
          bound.push(b)
        }
        ns = concat(ns, bs)
      }
      let s = if ps.length() == 0 {
        short_name(c)
      } else {
        short_name(c) + "(" + shown.join(", ") + ")"
      }
      (s, bound)
    }
  }
}

///|
fn op_symbol(n : String) -> String? {
  let m = match n.rev_find("::") {
    Some(i) => n.unsafe_substring(start=i + 2, end=n.length())
    None => return None
  }
  match m {
    "op_add" => Some("+")
    "op_sub" => Some("-")
    "op_mul" => Some("*")
    "op_div" => Some("/")
    "op_mod" => Some("%")
    "op_equal" => Some("==")
    "op_lt" => Some("<")
    "op_le" => Some("<=")
    "op_gt" => Some(">")
    "op_ge" => Some(">=")
    _ => None
  }
}

///|
pub fn show_tm(names : Array[String], t : Tm) -> String {
  show_prec(names, t, 0)
}

///|
fn paren(b : Bool, s : String) -> String {
  if b {
    "(" + s + ")"
  } else {
    s
  }
}

///|
fn show_prec(names : Array[String], t : Tm, prec : Int) -> String {
  match t {
    Var(ix) => {
      let i = names.length() - 1 - ix
      if i >= 0 && i < names.length() {
        names[i]
      } else {
        "#" + ix.to_string()
      }
    }
    Global("Nat::Z") => "0"
    Global(n) => short_name(n)
    Meta(m) => "?" + m.to_string()
    InsertedMeta(m, _) => "?" + m.to_string()
    U => "Type"
    PropU => "Prop"
    Lit(l) => show_lit(l)
    App(_, _, _) => {
      match nat_lit(t) {
        Some(n) => return n.to_string()
        None => ()
      }
      let (h, args) = flatten_app(t)
      match (h, args) {
        (Global("Id"), [_, (a, Expl), (b, Expl)]) =>
          return paren(
            prec > 1,
            show_prec(names, a, 2) + " === " + show_prec(names, b, 2),
          )
        _ => ()
      }
      let hide_impl = match h {
        Global(n) => !(data_info(n) is Some(_))
        _ => false
      }
      let impls : Array[String] = []
      let expls : Array[String] = []
      for a in args {
        match a.1 {
          Expl => expls.push(show_prec(names, a.0, 0))
          _ => if !hide_impl { impls.push(show_prec(names, a.0, 0)) }
        }
      }
      // `T::op_add(a, b)` is shown as `a + b`
      match (h, expls.length()) {
        (Global(n), 2) =>
          match op_symbol(n) {
            Some(op) => {
              let ex = args.filter(a => a.1 == Expl)
              return paren(
                prec > 1,
                show_prec(names, ex[0].0, 2) +
                " " +
                op +
                " " +
                show_prec(names, ex[1].0, 2),
              )
            }
            None => ()
          }
        _ => ()
      }
      let mut s = show_prec(names, h, 3)
      if impls.length() > 0 {
        s = s + "[" + impls.join(", ") + "]"
      }
      if expls.length() > 0 {
        s = s + "(" + expls.join(", ") + ")"
      }
      s
    }
    Pi(_, _, _, _, _) => {
      let mut ns = names
      let mut cur = t
      let impls : Array[String] = []
      let expls : Array[String] = []
      // implicit binders followed by one explicit group
      while cur is Pi(x, i, g, a, b) {
        if i != Expl && expls.length() > 0 {
          break
        }
        if i == Expl && g && expls.length() > 0 {
          break
        }
        let y = fresh_name(ns, x)
        let ann = if y == "_" {
          show_prec(ns, a, 0)
        } else {
          y + " : " + show_prec(ns, a, 0)
        }
        match i {
          Expl => expls.push(ann)
          _ => impls.push(ann)
        }
        ns = push1(ns, y)
        cur = b
      }
      let mut s = ""
      if impls.length() > 0 {
        s = "[" + impls.join(", ") + "]"
      }
      if expls.length() > 0 {
        s = s + "(" + expls.join(", ") + ")"
      }
      paren(prec > 0, s + " -> " + show_prec(ns, cur, 0))
    }
    Lam(_, _, _, _) => {
      let mut ns = names
      let mut cur = t
      let xs : Array[String] = []
      while cur is Lam(x, i, _, b) {
        let y = fresh_name(ns, x)
        xs.push(if i == Expl { y } else { "[" + y + "]" })
        ns = push1(ns, y)
        cur = b
      }
      paren(prec > 0, "(" + xs.join(", ") + ") => " + show_prec(ns, cur, 0))
    }
    Let(x, _, v, b) => {
      let y = fresh_name(names, x)
      "{ let " +
      y +
      " = " +
      show_prec(names, v, 0) +
      "; " +
      show_prec(push1(names, y), b, 0) +
      " }"
    }
    Match(scr, cls) => {
      let arms = cls.map(cl => {
        let mut ns = names
        let ps : Array[String] = []
        for p in cl.pats {
          let (s, bs) = show_pat(ns, p)
          ps.push(s)
          ns = concat(ns, bs)
        }
        let lhs = if ps.length() == 1 {
          ps[0]
        } else {
          "(" + ps.join(", ") + ")"
        }
        lhs + " => " + show_prec(ns, cl.body, 0)
      })
      let s = if scr.length() == 1 {
        show_prec(names, scr[0], 3)
      } else {
        "(" + scr.map(x => show_prec(names, x, 0)).join(", ") + ")"
      }
      "match " + s + " { " + arms.join("; ") + " }"
    }
    Raises(a, e) => show_prec(names, a, 1) + " raise " + show_prec(names, e, 1)
    ArrayLit(es) => "[" + es.map(x => show_prec(names, x, 0)).join(", ") + "]"
    _ => "<stmt>"
  }
}
