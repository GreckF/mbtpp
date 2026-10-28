///|
/// Typed (native) translation. A function whose parameters and result have
/// types that MoonBit can represent directly, and whose body stays in a
/// first-order fragment, is translated to an ordinary MoonBit function over
/// native types (`f_t`); the uniform version `f` becomes a wrapper that
/// converts its arguments and result. Other functions keep the uniform
/// translation. Native types: `Int`, `Double`, `Bool`, `Char`, `String`,
/// `Unit` and datatypes without parameters or indices whose fields are
/// native (they become MoonBit enums).
priv enum NTy {
  NInt
  NDouble
  NBool
  NChar
  NString
  NUnit
  NEnum(String)
  /// The type of `break`, `continue`, `return`, ... (any type).
  NAny
} derive(Eq)

///|
priv struct TSig {
  /// Parameter index -> native type (`None` for erased parameters).
  params : Array[NTy?]
  result : NTy
}

///|
priv enum TLocal {
  TVar(String, NTy)
  TMut(String, NTy)
  TNone
}

///|
fn tpush(env : Array[TLocal], l : TLocal) -> Array[TLocal] {
  let e = env.copy()
  e.push(l)
  e
}

///|
fn unify_nty(a : NTy, b : NTy) -> NTy? {
  match (a, b) {
    (NAny, t) | (t, NAny) => Some(t)
    _ => if a == b { Some(a) } else { None }
  }
}

///|
/// Can datatype `d` be a native MoonBit enum?
fn Gen::enum_ok(self : Gen, d : String) -> Bool {
  match self.enums_ok.get(d) {
    Some(b) => return b
    None => ()
  }
  let ok = match @tt.data_info(d) {
    Some(di) =>
      !di.builtin &&
      !di.is_prop &&
      !di.is_trait &&
      !di.is_error &&
      di.nparams == 0 &&
      di.nindices == 0 &&
      !d.has_prefix("@") &&
      di.cons.length() > 0
    None => false
  }
  if !ok {
    self.enums_ok.set(d, false)
    return false
  }
  // assume it is (recursive types), then check the fields
  self.enums_ok.set(d, true)
  let di = @tt.data_info(d).unwrap()
  for c in di.cons {
    match self.con_fields(c) {
      Some(_) => ()
      None => {
        self.enums_ok.set(d, false)
        return false
      }
    }
  }
  true
}

///|
/// The native types of the fields of a constructor of a native datatype.
fn Gen::con_fields(self : Gen, c : String) -> Array[NTy]? {
  let ci = match @tt.con_info(c) {
    Some(ci) => ci
    None => return None
  }
  if ci.nimpl > 0 || ci.nparams > 0 {
    return None
  }
  let mut t = @tt.globals.get(c).unwrap().ty
  let out : Array[NTy] = []
  for _ in 0..<ci.nargs {
    match t {
      Pi(_, Expl, _, a, b) =>
        match self.native_ty(a) {
          Some(nt) => {
            out.push(nt)
            t = b
          }
          None => return None
        }
      _ => return None
    }
  }
  Some(out)
}

///|
fn Gen::native_ty(self : Gen, t : @tt.Tm) -> NTy? {
  match t {
    Global("Int") => Some(NInt)
    Global("Double") => Some(NDouble)
    Global("Bool") => Some(NBool)
    Global("Char") => Some(NChar)
    Global("String") => Some(NString)
    Global("Unit") => Some(NUnit)
    Global(d) => if self.enum_ok(d) { Some(NEnum(d)) } else { None }
    _ => None
  }
}

///|
/// The constructor name in a native enum (upper case, as MoonBit requires).
fn native_con(c : String) -> String {
  let s = short_con(c)
  match s.get_char(0) {
    Some(ch) if ch >= 'a' && ch <= 'z' =>
      Int::unsafe_to_char(ch.to_int() - 32).to_string() +
      s.unsafe_substring(start=1, end=s.length())
    _ => s
  }
}

///|
fn enum_name(d : String) -> String {
  let buf = StringBuilder::new()
  for c in d {
    if is_ident_char(c) {
      buf.write_char(c)
    } else {
      buf.write_char('_')
    }
  }
  "E_" + buf.to_string()
}

///|
fn enum_fn(d : String, what : String) -> String {
  let buf = StringBuilder::new()
  for c in d {
    if c >= 'A' && c <= 'Z' {
      buf.write_char(Int::unsafe_to_char(c.to_int() + 32))
    } else if is_ident_char(c) {
      buf.write_char(c)
    } else {
      buf.write_char('_')
    }
  }
  buf.to_string() + "_" + what
}

///|
fn Gen::mbt_ty(self : Gen, t : NTy) -> String {
  match t {
    NInt => "Int"
    NDouble => "Double"
    NBool => "Bool"
    NChar => "Char"
    NString => "String"
    NUnit | NAny => "Unit"
    NEnum(d) => {
      self.need_enum(d)
      enum_name(d)
    }
  }
}

///|
/// Convert native `e` of type `t` to a `Value`.
fn Gen::to_value(self : Gen, t : NTy, e : String) -> String {
  match t {
    NInt => "VInt(" + e + ")"
    NDouble => "VDouble(" + e + ")"
    NBool => "VBool(" + e + ")"
    NChar => "VChar(" + e + ")"
    NString => "VStr(" + e + ")"
    NUnit | NAny => "{ ignore(" + e + "); VUnit }"
    NEnum(d) => {
      self.need_enum(d)
      enum_fn(d, "to_value") + "(" + e + ")"
    }
  }
}

///|
/// Convert the `Value` `e` to the native type `t`.
fn Gen::of_value(self : Gen, t : NTy, e : String) -> String {
  match t {
    NInt => "as_int(" + e + ")"
    NDouble => "as_double(" + e + ")"
    NBool => "as_bool(" + e + ")"
    NChar => "as_char(" + e + ")"
    NString => "as_str(" + e + ")"
    NUnit | NAny => "as_unit(" + e + ")"
    NEnum(d) => {
      self.need_enum(d)
      enum_fn(d, "of_value") + "(" + e + ")"
    }
  }
}

///|
/// Emit a native enum (once) with its conversions.
fn Gen::need_enum(self : Gen, d : String) -> Unit {
  if self.dry || self.enums_done.contains(d) {
    return
  }
  self.enums_done.push(d)
  let di = @tt.data_info(d).unwrap()
  let en = enum_name(d)
  let decl = StringBuilder::new()
  let to = StringBuilder::new()
  let of = StringBuilder::new()
  decl.write_string("\n/// MoonBit++ " + d + "\nenum " + en + " {\n")
  to.write_string(
    "\nfn " +
    enum_fn(d, "to_value") +
    "(x : " +
    en +
    ") -> Value {\n  match x {\n",
  )
  of.write_string(
    "\nfn " +
    enum_fn(d, "of_value") +
    "(v : Value) -> " +
    en +
    " raise {\n  match v {\n",
  )
  for c in di.cons {
    let fields = self.con_fields(c).unwrap()
    let cn = native_con(c)
    let vars = fields.mapi((k, _) => "a" + k.to_string())
    let args = if fields.length() == 0 {
      ""
    } else {
      "(" + vars.join(", ") + ")"
    }
    decl.write_string(
      "  " +
      cn +
      (if fields.length() == 0 {
        ""
      } else {
        "(" + fields.map(f => self.mbt_ty(f)).join(", ") + ")"
      }) +
      "\n",
    )
    to.write_string(
      "    " +
      en +
      "::" +
      cn +
      args +
      " => VCon(" +
      c.escape() +
      ", [" +
      fields.mapi((k, f) => self.to_value(f, vars[k])).join(", ") +
      "])\n",
    )
    of.write_string(
      "    VCon(" +
      c.escape() +
      ", [" +
      vars.join(", ") +
      "]) => " +
      en +
      "::" +
      cn +
      (if fields.length() == 0 {
        ""
      } else {
        "(" + fields.mapi((k, f) => self.of_value(f, vars[k])).join(", ") + ")"
      }) +
      "\n",
    )
  }
  decl.write_string("}\n")
  to.write_string("  }\n}\n")
  of.write_string(
    "    _ => rt_fail(\"expected a " + d + ", got \" + show_value(v))\n  }\n}\n",
  )
  self.enum_defs.write_string(
    decl.to_string() + to.to_string() + of.to_string(),
  )
}

///|
/// The native signature of a global function, if it has one.
fn Gen::native_sig(self : Gen, name : String) -> TSig? {
  let n = match func_arity(name) {
    Some(n) => n
    None => return None
  }
  let mut t = @tt.globals.get(name).unwrap().ty
  let params : Array[NTy?] = []
  for i = 0; i < n; i = i + 1 {
    match t {
      Pi(_, icit, _, a, b) => {
        if self.er.fun_erased(name, i) {
          params.push(None)
        } else if icit != Expl {
          return None
        } else {
          match self.native_ty(a) {
            Some(nt) => params.push(Some(nt))
            None => return None
          }
        }
        t = b
      }
      _ => return None
    }
  }
  let result = match t {
    Raises(r, _) => r
    _ => t
  }
  match self.native_ty(result) {
    Some(r) => Some({ params, result: r })
    None => None
  }
}

///|
/// Native templates of primitives: (template, argument types, result type).
let native_prims : Map[String, (String, Array[NTy], NTy)] = {
  "%int_add": ("($0 + $1)", [NInt, NInt], NInt),
  "%int_sub": ("($0 - $1)", [NInt, NInt], NInt),
  "%int_mul": ("($0 * $1)", [NInt, NInt], NInt),
  "%int_div": ("int_div($0, $1)", [NInt, NInt], NInt),
  "%int_mod": ("int_mod($0, $1)", [NInt, NInt], NInt),
  "%int_neg": ("(-$0)", [NInt], NInt),
  "%int_eq": ("($0 == $1)", [NInt, NInt], NBool),
  "%int_lt": ("($0 < $1)", [NInt, NInt], NBool),
  "%int_le": ("($0 <= $1)", [NInt, NInt], NBool),
  "%int_gt": ("($0 > $1)", [NInt, NInt], NBool),
  "%int_ge": ("($0 >= $1)", [NInt, NInt], NBool),
  "%int_compare": ("$0.compare($1)", [NInt, NInt], NInt),
  "%int_to_string": ("$0.to_string()", [NInt], NString),
  "%int_to_double": ("$0.to_double()", [NInt], NDouble),
  "%double_add": ("($0 + $1)", [NDouble, NDouble], NDouble),
  "%double_sub": ("($0 - $1)", [NDouble, NDouble], NDouble),
  "%double_mul": ("($0 * $1)", [NDouble, NDouble], NDouble),
  "%double_div": ("($0 / $1)", [NDouble, NDouble], NDouble),
  "%double_neg": ("(-$0)", [NDouble], NDouble),
  "%double_eq": ("($0 == $1)", [NDouble, NDouble], NBool),
  "%double_lt": ("($0 < $1)", [NDouble, NDouble], NBool),
  "%double_le": ("($0 <= $1)", [NDouble, NDouble], NBool),
  "%double_gt": ("($0 > $1)", [NDouble, NDouble], NBool),
  "%double_ge": ("($0 >= $1)", [NDouble, NDouble], NBool),
  "%double_compare": ("$0.compare($1)", [NDouble, NDouble], NInt),
  "%double_to_string": ("$0.to_string()", [NDouble], NString),
  "%double_to_int": ("$0.to_int()", [NDouble], NInt),
  "%str_add": ("($0 + $1)", [NString, NString], NString),
  "%str_eq": ("($0 == $1)", [NString, NString], NBool),
  "%str_compare": ("$0.compare($1)", [NString, NString], NInt),
  "%str_length": ("$0.length()", [NString], NInt),
  "%bool_eq": ("($0 == $1)", [NBool, NBool], NBool),
  "%bool_not": ("(!$0)", [NBool], NBool),
  "%bool_to_string": ("$0.to_string()", [NBool], NString),
  "%char_eq": ("($0 == $1)", [NChar, NChar], NBool),
  "%char_compare": ("$0.compare($1)", [NChar, NChar], NInt),
  "%char_to_int": ("$0.to_int()", [NChar], NInt),
  "%char_to_string": ("$0.to_string()", [NChar], NString),
  "%print": ("rt_write($0)", [NString], NUnit),
}

///|
/// A term outside the typed fragment.
priv suberror NotTyped

///|
fn unify_t(a : NTy, b : NTy) -> NTy raise NotTyped {
  match unify_nty(a, b) {
    Some(t) => t
    None => raise NotTyped
  }
}

///|
fn Gen::typed_args(
  self : Gen,
  env : Array[TLocal],
  args : Array[@tt.Tm],
  tys : Array[NTy],
) -> Array[String] raise NotTyped {
  if args.length() != tys.length() {
    raise NotTyped
  }
  let out : Array[String] = []
  for k = 0; k < args.length(); k = k + 1 {
    let (c, t) = self.typed(env, args[k])
    ignore(unify_t(t, tys[k]))
    out.push(c)
  }
  out
}

///|
fn Gen::typed_app(
  self : Gen,
  env : Array[TLocal],
  t : @tt.Tm,
) -> (String, NTy) raise NotTyped {
  let (h, args) = flatten_app(t)
  let n = match h {
    Global(n) => n
    _ => raise NotTyped
  }
  let g = match @tt.globals.get(n) {
    Some(g) => g
    None => raise NotTyped
  }
  match g.kind {
    GCon(ci) => {
      if args.length() != ci.nparams + ci.nargs || !self.enum_ok(ci.data) {
        raise NotTyped
      }
      let fields = self.con_fields(n).unwrap()
      let cs = self.typed_args(env, args, fields)
      self.need_enum(ci.data)
      (
        enum_name(ci.data) + "::" + native_con(n) + "(" + cs.join(", ") + ")",
        NEnum(ci.data),
      )
    }
    GPrim(p, k) if args.length() == k => {
      let (tpl, tys, res) = match native_prims.get(p) {
        Some(x) => x
        None => raise NotTyped
      }
      let icits = binder_icits(g.ty, k)
      let expl : Array[@tt.Tm] = []
      for i = 0; i < k; i = i + 1 {
        if icits[i] == Expl {
          expl.push(args[i])
        }
      }
      (subst_args(tpl, self.typed_args(env, expl, tys)), res)
    }
    GFunc(_, _, _) =>
      match self.native_sig(n) {
        Some(sig) if args.length() == sig.params.length() => {
          let ps : Array[@tt.Tm] = []
          let tys : Array[NTy] = []
          for i = 0; i < args.length(); i = i + 1 {
            match sig.params[i] {
              Some(nt) => {
                ps.push(args[i])
                tys.push(nt)
              }
              None => ()
            }
          }
          let cs = self.typed_args(env, ps, tys)
          let id = self.gid(n)
          if self.typed_set.contains(n) {
            (id + "_t(" + cs.join(", ") + ")", sig.result)
          } else {
            // through the uniform version
            let vs = cs.mapi((i, c) => self.to_value(tys[i], c))
            (
              self.of_value(sig.result, id + "(" + vs.join(", ") + ")"),
              sig.result,
            )
          }
        }
        _ => raise NotTyped
      }
    _ => raise NotTyped
  }
}

///|
/// A native pattern; `names` receives the slots (in slot order).
fn Gen::typed_pat(
  self : Gen,
  p : @tt.CPat,
  ty : NTy,
  names : Array[TLocal],
) -> String raise NotTyped {
  match p {
    CPVar(x) => {
      let n = self.name(x)
      names.push(TVar(n, ty))
      var_marker + n + end_marker
    }
    CPWild => {
      let n = self.name("w")
      names.push(TVar(n, ty))
      var_marker + n + end_marker
    }
    CPCon(c, ps) => {
      let d = match ty {
        NEnum(d) => d
        _ => raise NotTyped
      }
      let fields = match self.con_fields(c) {
        Some(f) => f
        None => raise NotTyped
      }
      let n = self.name(native_con(c))
      names.push(TVar(n, ty))
      let subs : Array[String] = []
      for j = 0; j < ps.length(); j = j + 1 {
        subs.push(self.typed_pat(ps[j], fields[j], names))
      }
      let args = if subs.length() == 0 {
        ""
      } else {
        "(" + subs.join(", ") + ")"
      }
      "(" +
      enum_name(d) +
      "::" +
      native_con(c) +
      args +
      as_marker +
      n +
      end_marker +
      ")"
    }
    CPLit(l) => {
      let n = self.name("lit")
      names.push(TVar(n, ty))
      let lp = match (l, ty) {
        (LInt(k), NInt) =>
          if k < 0 {
            "(" + k.to_string() + ")"
          } else {
            k.to_string()
          }
        (LStr(s), NString) => s.escape()
        (LChar(c), NChar) => char_lit(c)
        (LBool(b), NBool) => b.to_string()
        (LUnit, NUnit) => "()"
        _ => raise NotTyped
      }
      "(" + lp + as_marker + n + end_marker + ")"
    }
  }
}

///|
/// A native expression used as a statement.
fn stmt(code : String, t : NTy) -> String {
  match t {
    NUnit | NAny => code
    _ => "ignore(" + code + ")"
  }
}

///|
/// Translate a term of the typed fragment.
fn Gen::typed(
  self : Gen,
  env : Array[TLocal],
  t : @tt.Tm,
) -> (String, NTy) raise NotTyped {
  match t {
    Var(ix) =>
      match env[env.length() - 1 - ix] {
        TVar(n, ty) | TMut(n, ty) => (n, ty)
        TNone => raise NotTyped
      }
    Lit(LInt(k)) =>
      (if k < 0 { "(" + k.to_string() + ")" } else { k.to_string() }, NInt)
    Lit(LDouble(d)) => (double_lit(d), NDouble)
    Lit(LStr(s)) => (s.escape(), NString)
    Lit(LChar(c)) => (char_lit(c), NChar)
    Lit(LBool(b)) => (b.to_string(), NBool)
    Lit(LUnit) => ("()", NUnit)
    Global(n) =>
      match @tt.globals.get(n) {
        Some({ kind: GCon(ci), .. }) if ci.nparams + ci.nargs == 0 &&
          self.enum_ok(ci.data) => {
          self.need_enum(ci.data)
          (enum_name(ci.data) + "::" + native_con(n), NEnum(ci.data))
        }
        _ => raise NotTyped
      }
    App(_, _, _) => self.typed_app(env, t)
    Let(x, _, v, b) => {
      let (cv, tv) = self.typed(env, v)
      let n = self.name(x)
      let (cb, tb) = self.typed(tpush(env, TVar(n, tv)), b)
      (
        "{\nlet " + n + " : " + self.mbt_ty(tv) + " = " + cv + "\n" + cb + "\n}",
        tb,
      )
    }
    LetMut(x, _, v, b) => {
      let (cv, tv) = self.typed(env, v)
      let n = self.name(x)
      let (cb, tb) = self.typed(tpush(env, TMut(n, tv)), b)
      (
        "{\nlet mut " +
        n +
        " : " +
        self.mbt_ty(tv) +
        " = " +
        cv +
        "\n" +
        cb +
        "\n}",
        tb,
      )
    }
    Assign(ix, v) =>
      match env[env.length() - 1 - ix] {
        TMut(n, ty) => {
          let (cv, tv) = self.typed(env, v)
          ignore(unify_t(ty, tv))
          ("{\n" + n + " = " + cv + "\n}", NUnit)
        }
        _ => raise NotTyped
      }
    Match(ss, cls) =>
      match if_parts(ss, cls) {
        Some((c, a, b)) => {
          let (cc, tc) = self.typed(env, c)
          ignore(unify_t(tc, NBool))
          let env2 = tpush(env, TNone)
          let (ca, ta) = self.typed(env2, a)
          let (cb, tb) = self.typed(env2, b)
          (
            "if " + cc + " {\n" + ca + "\n} else {\n" + cb + "\n}",
            unify_t(ta, tb),
          )
        }
        None => {
          let scr : Array[(String, NTy)] = []
          for s in ss {
            scr.push(self.typed(env, s))
          }
          let buf = StringBuilder::new()
          let subject = if scr.length() == 1 {
            scr[0].0
          } else {
            "(" + scr.map(x => x.0).join(", ") + ")"
          }
          buf.write_string("match " + subject + " {\n")
          let mut ty = NAny
          for cl in cls {
            let names : Array[TLocal] = []
            let ps : Array[String] = []
            for k = 0; k < cl.pats.length(); k = k + 1 {
              ps.push(self.typed_pat(cl.pats[k], scr[k].1, names))
            }
            let mut env2 = env
            for nm in names {
              env2 = tpush(env2, nm)
            }
            let (cb, tb) = self.typed(env2, cl.body)
            ty = unify_t(ty, tb)
            let lhs = if ps.length() == 1 {
              ps[0]
            } else {
              "(" + ps.join(", ") + ")"
            }
            buf.write_string(resolve_bindings(lhs, cb) + " => " + cb + "\n")
          }
          buf.write_string("_ => rt_fail(\"no match\")\n}")
          (buf.to_string(), ty)
        }
      }
    While(c, b, step) => {
      let (cc, tc) = self.typed(env, c)
      ignore(unify_t(tc, NBool))
      // `continue` must still run the step
      if !(step is Lit(LUnit)) && has_continue(b) {
        raise NotTyped
      }
      let (cb, tb) = self.typed(env, b)
      let (cs, ts) = self.typed(env, step)
      (
        "while " + cc + " {\n" + stmt(cb, tb) + "\n" + stmt(cs, ts) + "\n}",
        NUnit,
      )
    }
    Break => ("break", NAny)
    Continue => ("continue", NAny)
    Return(v) => {
      let (cv, tv) = self.typed(env, v)
      match self.cur_result {
        Some(r) => ignore(unify_t(r, tv))
        None => raise NotTyped
      }
      ("return " + cv, NAny)
    }
    Seq(a, b) => {
      let (ca, ta) = self.typed(env, a)
      let (cb, tb) = self.typed(env, b)
      ("{\n" + stmt(ca, ta) + "\n" + cb + "\n}", tb)
    }
    _ => raise NotTyped
  }
}

///|
fn has_continue(t : @tt.Tm) -> Bool {
  match t {
    Continue => true
    While(_, _, _) | Lam(_, _, _, _) => false
    App(f, a, _) => has_continue(f) || has_continue(a)
    Let(_, _, v, b) | LetMut(_, _, v, b) => has_continue(v) || has_continue(b)
    Match(ss, cls) =>
      ss.iter().any(has_continue) || cls.iter().any(cl => has_continue(cl.body))
    Seq(a, b) => has_continue(a) || has_continue(b)
    Assign(_, v) | Return(v) => has_continue(v)
    _ => false
  }
}

///|
/// The native translation of a function (its body and signature), if it is
/// in the typed fragment.
fn Gen::typed_fn(self : Gen, name : String) -> String? {
  let sig = match self.native_sig(name) {
    Some(s) => s
    None => return None
  }
  let body = match @tt.globals.get(name) {
    Some({ kind: GFunc(Some(b), _, _), .. }) => b
    _ => return None
  }
  let mut env : Array[TLocal] = []
  let params : Array[String] = []
  let mut b = body
  for i = 0; i < sig.params.length(); i = i + 1 {
    match b {
      Lam(x, _, _, rest) => {
        match sig.params[i] {
          Some(nt) => {
            let p = self.name(x)
            params.push(p + " : " + self.mbt_ty(nt))
            env = tpush(env, TVar(p, nt))
          }
          None => env = tpush(env, TNone)
        }
        b = rest
      }
      _ => return None
    }
  }
  self.cur_result = Some(sig.result)
  let res = try? self.typed(env, b)
  self.cur_result = None
  match res {
    Ok((code, ty)) =>
      match unify_nty(ty, sig.result) {
        Some(_) => {
          let id = self.gid(name)
          Some(
            "fn " +
            id +
            "_t(" +
            params.join(", ") +
            ") -> " +
            self.mbt_ty(sig.result) +
            " raise {\n" +
            code +
            "\n}\n",
          )
        }
        None => None
      }
    Err(_) => None
  }
}

///|
/// Decide which functions get a native translation: start with all
/// functions with a native signature and remove those whose body is not in
/// the fragment, until nothing changes (callers depend on callees).
fn Gen::compute_typed(self : Gen) -> Unit {
  for name, _ in @tt.globals {
    if self.native_sig(name) is Some(_) {
      self.typed_set.push(name)
    }
  }
  let mut changed = true
  while changed {
    changed = false
    let keep : Array[String] = []
    for n in self.typed_set {
      if self.typed_fn(n) is Some(_) {
        keep.push(n)
      } else {
        changed = true
      }
    }
    self.typed_set.clear()
    for n in keep {
      self.typed_set.push(n)
    }
  }
}
