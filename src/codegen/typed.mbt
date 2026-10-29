///|
/// Typed (native) translation. A function whose parameters and result have
/// types that MoonBit can represent directly, and whose body stays in a
/// first-order fragment, is translated to an ordinary (possibly generic)
/// MoonBit function over native types (`f_t`); the uniform version `f`
/// becomes a wrapper converting its arguments and result, with the type
/// parameters instantiated to `Value`. Other functions keep the uniform
/// translation.
///
/// Native types: `Int`, `Double`, `Bool`, `Char`, `String`, `Unit`, type
/// parameters, and datatypes whose parameters are types and whose (not
/// erased) fields are native. Indices and erased fields disappear: e.g.
/// `Vector[T](n)` becomes the MoonBit enum `E_Vector[T0]` with constructors
/// `Nil` and `Cons(T0, E_Vector[T0])`. A `#mbt` datatype is the MoonBit type
/// of its name (generated with that name, or an existing one), and a bound
/// `[T : Tr]` with a `#mbt` trait is a MoonBit bound (see traits.mbt).
priv enum NTy {
  NInt
  NDouble
  NInt64
  NUInt
  NUInt64
  NByte
  NFloat
  NBool
  NChar
  NString
  NUnit
  NEnum(String, Array[NTy])
  /// An opaque MoonBit type (`Json`, `@bigint.BigInt`, `@hashmap.HashMap[K, V]`),
  /// used as is.
  NForeign(String, Array[NTy])
  /// The k-th type parameter (of the enum or function being translated).
  NVar(Int32)
  /// A function type `(A, B) -> C` (one argument group).
  NFun(Array[NTy], NTy)
  /// An async function type `async (A, B) -> C`: native only (`Value`
  /// functions are synchronous).
  NAsyncFun(Array[NTy], NTy)
  /// The type of `break`, `continue`, `return`, ... (any type).
  NAny
  /// `Self` in a trait declaration.
  NSelf
} derive(Eq)

///|
priv struct TSig {
  /// Parameter index -> native type (`None` for erased parameters).
  params : Array[NTy?]
  /// For each parameter: the index of the type parameter it is, if any.
  tparams : Array[Int32?]
  ntvars : Int32
  result : NTy
  /// `#mbt` trait bounds of the type parameters.
  bounds : Array[(Int32, String)]
}

///|
priv enum TLocal {
  TVar(String, NTy)
  TMut(String, NTy)
  /// A type parameter, standing for the given native type.
  TType(NTy)
  TNone
}

///|
/// What a variable of a type expression stands for.
priv enum TyCtx {
  TyIs(NTy)
  TyOther
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
fn subst_nty(t : NTy, args : Array[NTy]) -> NTy {
  match t {
    NVar(k) => if k < args.length() { args[k] } else { t }
    NEnum(d, xs) => NEnum(d, xs.map(x => subst_nty(x, args)))
    NForeign(d, xs) => NForeign(d, xs.map(x => subst_nty(x, args)))
    NFun(ps, r) => NFun(ps.map(x => subst_nty(x, args)), subst_nty(r, args))
    NAsyncFun(ps, r) =>
      NAsyncFun(ps.map(x => subst_nty(x, args)), subst_nty(r, args))
    _ => t
  }
}

///|
fn has_var(t : NTy) -> Bool {
  match t {
    NVar(_) => true
    NEnum(_, xs) | NForeign(_, xs) => xs.iter().any(has_var)
    NFun(ps, r) | NAsyncFun(ps, r) => ps.iter().any(has_var) || has_var(r)
    _ => false
  }
}

///|
/// Does the type parameter `k` occur in `t`?
fn has_tvar(t : NTy, k : Int32) -> Bool {
  match t {
    NVar(j) => j == k
    NEnum(_, xs) | NForeign(_, xs) => xs.iter().any(x => has_tvar(x, k))
    NFun(ps, r) | NAsyncFun(ps, r) =>
      ps.iter().any(x => has_tvar(x, k)) || has_tvar(r, k)
    _ => false
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
      (!d.has_prefix("@") || is_mbt_type(d)) &&
      di.cons.length() > 0 &&
      data_params_are_types(d, di.nparams)
    None => false
  }
  if !ok {
    self.enums_ok.set(d, false)
    return false
  }
  // assume it is (recursive types), then check the fields
  self.enums_ok.set(d, true)
  for c in @tt.data_info(d).unwrap().cons {
    if self.con_fields(c) is None {
      self.enums_ok.set(d, false)
      return false
    }
  }
  true
}

///|
/// Are all parameters of datatype `d` of type `Type`?
fn data_params_are_types(d : String, n : Int32) -> Bool {
  let mut t = @tt.globals.get(d).unwrap().ty
  for _ in 0..<n {
    match t {
      Pi(_, _, _, U, b) => t = b
      _ => return false
    }
  }
  true
}

///|
/// The native types of the own fields of a constructor (`None` for erased
/// fields), in terms of the datatype's parameters (`NVar`).
fn Gen::con_fields(self : Gen, c : String) -> Array[NTy?]? {
  let ci = match @tt.con_info(c) {
    Some(ci) => ci
    None => return None
  }
  let mut t = @tt.globals.get(c).unwrap().ty
  let ctx : Array[TyCtx] = []
  for k = 0; k < ci.nparams; k = k + 1 {
    match t {
      Pi(_, _, _, _, b) => {
        ctx.push(TyIs(NVar(k)))
        t = b
      }
      _ => return None
    }
  }
  let out : Array[NTy?] = []
  for j = 0; j < ci.nargs; j = j + 1 {
    match t {
      Pi(_, _, _, a, b) => {
        if self.er.con_erased(c, j) {
          out.push(None)
        } else {
          match self.native_ty_in(ctx, a) {
            Some(nt) => out.push(Some(nt))
            None => return None
          }
        }
        ctx.push(TyOther)
        t = b
      }
      _ => return None
    }
  }
  Some(out)
}

///|
/// The native type denoted by a type term, in a context saying what its
/// variables stand for.
fn Gen::native_ty_in(self : Gen, ctx : Array[TyCtx], t : @tt.Tm) -> NTy? {
  match t {
    Var(ix) => {
      let i = ctx.length() - 1 - ix
      if i >= 0 && ctx[i] is TyIs(nt) {
        Some(nt)
      } else {
        None
      }
    }
    Global("Int") => Some(NInt)
    Global("Double") => Some(NDouble)
    Global("Int64") => Some(NInt64)
    Global("UInt") => Some(NUInt)
    Global("UInt64") => Some(NUInt64)
    Global("Byte") => Some(NByte)
    Global("Float") => Some(NFloat)
    Global("Bool") => Some(NBool)
    Global("Char") => Some(NChar)
    Global("String") => Some(NString)
    Global("Unit") => Some(NUnit)
    Pi(_, Expl, true, _, _) => {
      // one explicit argument group; the result may not depend on it
      let ps : Array[NTy] = []
      let ctx2 = ctx.copy()
      let mut cur = t
      let mut first = true
      while cur is Pi(_, Expl, g, a, b) && (first || !g) {
        first = false
        match self.native_ty_in(ctx2, a) {
          Some(nt) => ps.push(nt)
          None => return None
        }
        ctx2.push(TyOther)
        cur = b
      }
      let (r, is_async) = match cur {
        Raises(r, e) => (r, @tt.tm_effect(e).0)
        _ => (cur, false)
      }
      match self.native_ty_in(ctx2, r) {
        Some(nr) if is_async => Some(NAsyncFun(ps, nr))
        Some(nr) => Some(NFun(ps, nr))
        None => None
      }
    }
    _ => {
      let (h, args) = flatten_app(t)
      match h {
        Global(d) if @tt.is_foreign_type(d) => {
          let np = @tt.data_info(d).unwrap().nparams
          if args.length() < np {
            return None
          }
          let targs : Array[NTy] = []
          for k = 0; k < np; k = k + 1 {
            match self.native_ty_in(ctx, args[k]) {
              Some(a) => targs.push(a)
              None => return None
            }
          }
          Some(NForeign(d, targs))
        }
        Global(d) if self.enum_ok(d) => {
          let np = @tt.data_info(d).unwrap().nparams
          if args.length() < np {
            return None
          }
          let targs : Array[NTy] = []
          for k = 0; k < np; k = k + 1 {
            match self.native_ty_in(ctx, args[k]) {
              Some(a) => targs.push(a)
              None => return None
            }
          }
          Some(NEnum(d, targs))
        }
        _ => None
      }
    }
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
      buf.write_char(Int32::unsafe_to_char(c.to_int() + 32))
    } else if is_ident_char(c) {
      buf.write_char(c)
    } else {
      buf.write_char('_')
    }
  }
  buf.to_string() + "_" + what
}

///|
/// The constructor name in a native enum (upper case, as MoonBit requires).
fn native_con(c : String) -> String {
  let s = short_con(c)
  match s.get_char(0) {
    Some(ch) if ch >= 'a' && ch <= 'z' =>
      Int32::unsafe_to_char(ch.to_int() - 32).to_string() +
      s.unsafe_substring(start=1, end=s.length())
    _ => s
  }
}

///|
fn tvar(k : Int32) -> String {
  "T" + k.to_string()
}

///|
fn Gen::mbt_ty(self : Gen, t : NTy) -> String {
  match t {
    NInt => "Int"
    NDouble => "Double"
    NInt64 => "Int64"
    NUInt => "UInt"
    NUInt64 => "UInt64"
    NByte => "Byte"
    NFloat => "Float"
    NBool => "Bool"
    NChar => "Char"
    NString => "String"
    NUnit | NAny => "Unit"
    NSelf => "Self"
    NVar(k) => tvar(k)
    NFun(ps, r) =>
      "(" + self.mbt_params(ps) + ") -> " + self.mbt_ty(r) + " raise"
    NAsyncFun(ps, r) =>
      "async (" + self.mbt_params(ps) + ") -> " + self.mbt_ty(r) + " raise"
    NEnum(d, args) => {
      self.need_enum(d)
      if args.length() == 0 {
        data_name(d)
      } else {
        data_name(d) + "[" + args.map(a => self.mbt_ty(a)).join(", ") + "]"
      }
    }
    NForeign(d, args) =>
      if args.length() == 0 {
        d
      } else {
        d + "[" + args.map(a => self.mbt_ty(a)).join(", ") + "]"
      }
  }
}

///|
/// The variant of `Foreign` boxing values of the opaque MoonBit type `ty` in
/// the uniform representation.
fn Gen::foreign_variant(self : Gen, ty : String) -> String {
  if !self.foreign.contains(ty) {
    self.foreign.set(ty, "F" + self.foreign.length().to_string())
    self.foreign_order.push(ty)
  }
  self.foreign.get(ty).unwrap()
}

///|
/// Convert native `e` of type `t` to a `Value`. `convs[k]` converts values
/// of the type parameter k (`None`: they are already `Value`s).
fn Gen::to_value(
  self : Gen,
  t : NTy,
  e : String,
  convs : Array[String]?,
) -> String {
  match t {
    NInt => "VInt(" + e + ")"
    NDouble => "VDouble(" + e + ")"
    NInt64 => "VInt64(" + e + ")"
    NUInt => "VUInt(" + e + ")"
    NUInt64 => "VUInt64(" + e + ")"
    NByte => "VByte(" + e + ")"
    NFloat => "VFloat(" + e + ")"
    NBool => "VBool(" + e + ")"
    NChar => "VChar(" + e + ")"
    NString => "VStr(" + e + ")"
    NUnit | NAny => "{ ignore(" + e + "); VUnit }"
    NSelf => e
    NVar(k) =>
      match convs {
        Some(cs) => cs[k] + "(" + e + ")"
        None => e
      }
    // not convertible (see `convertible`)
    NAsyncFun(_, _) => "abort(\"an async function as a Value\")"
    NFun(ps, r) => {
      // a curried Value function calling the native one
      let f = self.name("f")
      let xs = ps.map(_ => self.name("a"))
      let call = f +
        "(" +
        (if unit_only(ps) {
          ""
        } else {
          ps.mapi((i, p) => self.of_value(p, xs[i], convs)).join(", ")
        }) +
        ")"
      let mut code = self.to_value(r, call, convs)
      for i = xs.length() - 1; i >= 0; i = i - 1 {
        code = "VFun(" + xs[i] + " => " + code + ")"
      }
      "{\nlet " + f + " = " + e + "\n" + code + "\n}"
    }
    NEnum(d, args) => {
      self.need_enum(d)
      let fs = args.map(a => {
        let x = self.name("x")
        let c = self.to_value(a, x, convs)
        // not `(x => x)`: `moon fmt` turns it into `x => { x }`, a record
        if c == x {
          "value_id"
        } else {
          "(" + x + " => " + c + ")"
        }
      })
      enum_fn(d, "to_value") + "(" + [e, ..fs].join(", ") + ")"
    }
    // only types without arguments are converted (see `convertible`)
    NForeign(_, _) =>
      "VForeign(" + self.foreign_variant(self.mbt_ty(t)) + "(" + e + "))"
  }
}

///|
/// Convert the `Value` `e` to the native type `t` (see `to_value`).
fn Gen::of_value(
  self : Gen,
  t : NTy,
  e : String,
  convs : Array[String]?,
) -> String {
  match t {
    NInt => "as_int(" + e + ")"
    NDouble => "as_double(" + e + ")"
    NInt64 => "as_int64(" + e + ")"
    NUInt => "as_uint(" + e + ")"
    NUInt64 => "as_uint64(" + e + ")"
    NByte => "as_byte(" + e + ")"
    NFloat => "as_float(" + e + ")"
    NBool => "as_bool(" + e + ")"
    NChar => "as_char(" + e + ")"
    NString => "as_str(" + e + ")"
    NUnit | NAny => "as_unit(" + e + ")"
    NSelf => e
    NVar(k) =>
      match convs {
        Some(cs) => cs[k] + "(" + e + ")"
        None => e
      }
    NAsyncFun(_, _) => "abort(\"an async function from a Value\")"
    NFun(ps, r) => {
      // a native function applying the Value function
      let f = self.name("f")
      let xs = ps.map(_ => self.name("a"))
      let mut call = f
      for i = 0; i < xs.length(); i = i + 1 {
        call = "apply(" + call + ", " + self.to_value(ps[i], xs[i], convs) + ")"
      }
      // `() -> T`: the argument is `()`
      if unit_only(ps) {
        call = "apply(" + f + ", VUnit)"
      }
      "{\nlet " +
      f +
      " = " +
      e +
      "\n(" +
      (if unit_only(ps) { "" } else { xs.join(", ") }) +
      ") => " +
      self.of_value(r, call, convs) +
      "\n}"
    }
    NEnum(d, args) => {
      self.need_enum(d)
      let fs = args.map(a => {
        let x = self.name("x")
        let c = self.of_value(a, x, convs)
        // not `(x => x)`: `moon fmt` turns it into `x => { x }`, a record
        if c == x {
          "value_id_raise"
        } else {
          "(" + x + " => " + c + ")"
        }
      })
      enum_fn(d, "of_value") + "(" + [e, ..fs].join(", ") + ")"
    }
    NForeign(_, _) => {
      let ty = self.mbt_ty(t)
      "(match " +
      e +
      " {\nVForeign(" +
      self.foreign_variant(ty) +
      "(x)) => x\nv => rt_fail(\"expected a value of type " +
      ty +
      ", got \" + show_value(v))\n})"
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
  let n = di.nparams
  let tvs : Array[String] = []
  for k = 0; k < n; k = k + 1 {
    tvs.push(tvar(k))
  }
  let gen = if n == 0 { "" } else { "[" + tvs.join(", ") + "]" }
  let en = data_name(d) + gen
  let to_convs = tvs.mapi((k, _) => "to" + k.to_string())
  let of_convs = tvs.mapi((k, _) => "of" + k.to_string())
  let to_params = tvs.mapi((k, tv) => to_convs[k] + " : (" + tv + ") -> Value")
  let of_params = tvs.mapi((k, tv) => {
    of_convs[k] + " : (Value) -> " + tv + " raise"
  })
  let decl = StringBuilder::new()
  let to = StringBuilder::new()
  let of = StringBuilder::new()
  let is_struct = is_mbt_struct(d)
  // an existing MoonBit type is not declared
  let emit_decl = match @tt.mbt_info(d) {
    Some(info) => info.defined
    None => true
  }
  decl.write_string(
    "\n/// MoonBit++ " +
    d +
    "\n" +
    (if is_mbt_type(d) { "pub(all) " } else { "" }) +
    (if is_struct { "struct " } else { "enum " }) +
    en +
    " {\n",
  )
  to.write_string(
    "\nfn" +
    gen +
    " " +
    enum_fn(d, "to_value") +
    "(" +
    ["x : " + en, ..to_params].join(", ") +
    ") -> Value {\n  match x {\n",
  )
  of.write_string(
    "\nfn" +
    gen +
    " " +
    enum_fn(d, "of_value") +
    "(" +
    ["v : Value", ..of_params].join(", ") +
    ") -> " +
    en +
    " raise {\n  match v {\n",
  )
  for c in di.cons {
    let fields = self.con_fields(c).unwrap()
    let cn = native_con(c)
    let kept : Array[(String, NTy)] = []
    let vpats : Array[String] = []
    for j = 0; j < fields.length(); j = j + 1 {
      match fields[j] {
        Some(ft) => {
          let x = "a" + j.to_string()
          kept.push((x, ft))
          vpats.push(x)
        }
        None => ()
      }
    }
    let args = if kept.length() == 0 {
      ""
    } else {
      "(" + kept.map(k => k.0).join(", ") + ")"
    }
    if is_struct {
      let names = struct_fields(d)
      for k = 0; k < kept.length(); k = k + 1 {
        decl.write_string(
          "  " + names[k] + " : " + self.mbt_ty(kept[k].1) + "\n",
        )
      }
    } else {
      decl.write_string(
        "  " +
        cn +
        (if kept.length() == 0 {
          ""
        } else {
          "(" + kept.map(k => self.mbt_ty(k.1)).join(", ") + ")"
        }) +
        "\n",
      )
    }
    ignore(args)
    to.write_string(
      "    " +
      con_pat(d, c, kept.map(k => k.0)) +
      " => " +
      self.con_code(c, kept.map(k => self.to_value(k.1, k.0, Some(to_convs)))) +
      "\n",
    )
    of.write_string(
      "    " +
      self.con_code(c, vpats) +
      " => " +
      con_expr(d, c, kept.map(k => self.of_value(k.1, k.0, Some(of_convs)))) +
      "\n",
    )
  }
  // traits that MoonBit derives (`derive(ToJson)` of a `#mbt` type)
  let derives = @tt.mbt_derives.get(d).unwrap_or([])
  decl.write_string(
    if derives.length() == 0 {
      "}\n"
    } else {
      "} derive(" + derives.join(", ") + ")\n"
    },
  )
  to.write_string("  }\n}\n")
  of.write_string(
    "    _ => rt_fail(\"expected a " + d + ", got \" + show_value(v))\n  }\n}\n",
  )
  let into = self.data_convertible(d, true, [])
  self.write_to(
    self.file_of(d),
    (if emit_decl { decl.to_string() } else { "" }) +
    to.to_string() +
    (if into { of.to_string() } else { "" }),
  )
}

///|
/// The native signature of a global function, if it has one: its type
/// parameters are the erased implicit parameters of type `Type`.
fn Gen::native_sig(self : Gen, name : String) -> TSig? {
  let n = match func_arity(name) {
    Some(n) => n
    None => return None
  }
  let mut t = @tt.globals.get(name).unwrap().ty
  let params : Array[NTy?] = []
  let tparams : Array[Int32?] = []
  let ctx : Array[TyCtx] = []
  let bounds : Array[(Int32, String)] = []
  let mut ntvars = 0
  for i = 0; i < n; i = i + 1 {
    match t {
      Pi(_, Inst, _, a, b) if !self.er.fun_erased(name, i) => {
        // a `#mbt` bound: MoonBit finds the instance
        match bound_of(ctx, a) {
          Some(bd) => bounds.push(bd)
          None => return None
        }
        params.push(None)
        tparams.push(None)
        ctx.push(TyOther)
        t = b
      }
      Pi(_, icit, _, a, b) => {
        if self.er.fun_erased(name, i) {
          params.push(None)
          if a is U {
            tparams.push(Some(ntvars))
            ctx.push(TyIs(NVar(ntvars)))
            ntvars = ntvars + 1
          } else {
            tparams.push(None)
            ctx.push(TyOther)
          }
        } else if icit != Expl {
          return None
        } else {
          match self.native_ty_in(ctx, a) {
            Some(nt) => params.push(Some(nt))
            None => return None
          }
          tparams.push(None)
          ctx.push(TyOther)
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
  match self.native_ty_in(ctx, result) {
    Some(r) => {
      // MoonBit infers the type parameters from the arguments and result
      for bd in bounds {
        if !has_tvar(r, bd.0) &&
          !params.iter().any(p => p is Some(pt) && has_tvar(pt, bd.0)) {
          return None
        }
      }
      Some({ params, tparams, ntvars, result: r, bounds, })
    }
    None => None
  }
}

///|
/// Native templates of primitives: (template, argument types, result type).
let native_prims : Map[String, (String, Array[NTy], NTy)] = {
  "%int_add": ("($0 + $1)", [NInt, NInt], NInt),
  "%int_sub": ("($0 - $1)", [NInt, NInt], NInt),
  "%int_mul": ("($0 * $1)", [NInt, NInt], NInt),
  "%int_land": ("($0 & $1)", [NInt, NInt], NInt),
  "%int_lor": ("($0 | $1)", [NInt, NInt], NInt),
  "%int_lxor": ("($0 ^ $1)", [NInt, NInt], NInt),
  "%int_shl": ("($0 << $1)", [NInt, NInt], NInt),
  "%int_shr": ("($0 >> $1)", [NInt, NInt], NInt),
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
  "%int64_add": ("($0 + $1)", [NInt64, NInt64], NInt64),
  "%int64_sub": ("($0 - $1)", [NInt64, NInt64], NInt64),
  "%int64_mul": ("($0 * $1)", [NInt64, NInt64], NInt64),
  "%int64_div": ("($0 / $1)", [NInt64, NInt64], NInt64),
  "%int64_mod": ("($0 % $1)", [NInt64, NInt64], NInt64),
  "%int64_neg": ("(-$0)", [NInt64], NInt64),
  "%int64_land": ("($0 & $1)", [NInt64, NInt64], NInt64),
  "%int64_lor": ("($0 | $1)", [NInt64, NInt64], NInt64),
  "%int64_lxor": ("($0 ^ $1)", [NInt64, NInt64], NInt64),
  "%int64_shl": ("($0 << $1)", [NInt64, NInt], NInt64),
  "%int64_shr": ("($0 >> $1)", [NInt64, NInt], NInt64),
  "%int64_eq": ("($0 == $1)", [NInt64, NInt64], NBool),
  "%int64_lt": ("($0 < $1)", [NInt64, NInt64], NBool),
  "%int64_le": ("($0 <= $1)", [NInt64, NInt64], NBool),
  "%int64_gt": ("($0 > $1)", [NInt64, NInt64], NBool),
  "%int64_ge": ("($0 >= $1)", [NInt64, NInt64], NBool),
  "%int64_compare": ("$0.compare($1)", [NInt64, NInt64], NInt),
  "%int64_to_string": ("$0.to_string()", [NInt64], NString),
  "%int64_hash": ("$0.hash()", [NInt64], NInt),
  "%uint_add": ("($0 + $1)", [NUInt, NUInt], NUInt),
  "%uint_sub": ("($0 - $1)", [NUInt, NUInt], NUInt),
  "%uint_mul": ("($0 * $1)", [NUInt, NUInt], NUInt),
  "%uint_div": ("($0 / $1)", [NUInt, NUInt], NUInt),
  "%uint_mod": ("($0 % $1)", [NUInt, NUInt], NUInt),
  "%uint_land": ("($0 & $1)", [NUInt, NUInt], NUInt),
  "%uint_lor": ("($0 | $1)", [NUInt, NUInt], NUInt),
  "%uint_lxor": ("($0 ^ $1)", [NUInt, NUInt], NUInt),
  "%uint_shl": ("($0 << $1)", [NUInt, NInt], NUInt),
  "%uint_shr": ("($0 >> $1)", [NUInt, NInt], NUInt),
  "%uint_eq": ("($0 == $1)", [NUInt, NUInt], NBool),
  "%uint_lt": ("($0 < $1)", [NUInt, NUInt], NBool),
  "%uint_le": ("($0 <= $1)", [NUInt, NUInt], NBool),
  "%uint_gt": ("($0 > $1)", [NUInt, NUInt], NBool),
  "%uint_ge": ("($0 >= $1)", [NUInt, NUInt], NBool),
  "%uint_compare": ("$0.compare($1)", [NUInt, NUInt], NInt),
  "%uint_to_string": ("$0.to_string()", [NUInt], NString),
  "%uint_hash": ("$0.hash()", [NUInt], NInt),
  "%uint64_add": ("($0 + $1)", [NUInt64, NUInt64], NUInt64),
  "%uint64_sub": ("($0 - $1)", [NUInt64, NUInt64], NUInt64),
  "%uint64_mul": ("($0 * $1)", [NUInt64, NUInt64], NUInt64),
  "%uint64_div": ("($0 / $1)", [NUInt64, NUInt64], NUInt64),
  "%uint64_mod": ("($0 % $1)", [NUInt64, NUInt64], NUInt64),
  "%uint64_land": ("($0 & $1)", [NUInt64, NUInt64], NUInt64),
  "%uint64_lor": ("($0 | $1)", [NUInt64, NUInt64], NUInt64),
  "%uint64_lxor": ("($0 ^ $1)", [NUInt64, NUInt64], NUInt64),
  "%uint64_shl": ("($0 << $1)", [NUInt64, NInt], NUInt64),
  "%uint64_shr": ("($0 >> $1)", [NUInt64, NInt], NUInt64),
  "%uint64_eq": ("($0 == $1)", [NUInt64, NUInt64], NBool),
  "%uint64_lt": ("($0 < $1)", [NUInt64, NUInt64], NBool),
  "%uint64_le": ("($0 <= $1)", [NUInt64, NUInt64], NBool),
  "%uint64_gt": ("($0 > $1)", [NUInt64, NUInt64], NBool),
  "%uint64_ge": ("($0 >= $1)", [NUInt64, NUInt64], NBool),
  "%uint64_compare": ("$0.compare($1)", [NUInt64, NUInt64], NInt),
  "%uint64_to_string": ("$0.to_string()", [NUInt64], NString),
  "%uint64_hash": ("$0.hash()", [NUInt64], NInt),
  "%byte_add": ("($0 + $1)", [NByte, NByte], NByte),
  "%byte_sub": ("($0 - $1)", [NByte, NByte], NByte),
  "%byte_mul": ("($0 * $1)", [NByte, NByte], NByte),
  "%byte_div": ("($0 / $1)", [NByte, NByte], NByte),
  "%byte_mod": ("($0 % $1)", [NByte, NByte], NByte),
  "%byte_land": ("($0 & $1)", [NByte, NByte], NByte),
  "%byte_lor": ("($0 | $1)", [NByte, NByte], NByte),
  "%byte_lxor": ("($0 ^ $1)", [NByte, NByte], NByte),
  "%byte_shl": ("($0 << $1)", [NByte, NInt], NByte),
  "%byte_shr": ("($0 >> $1)", [NByte, NInt], NByte),
  "%byte_eq": ("($0 == $1)", [NByte, NByte], NBool),
  "%byte_lt": ("($0 < $1)", [NByte, NByte], NBool),
  "%byte_le": ("($0 <= $1)", [NByte, NByte], NBool),
  "%byte_gt": ("($0 > $1)", [NByte, NByte], NBool),
  "%byte_ge": ("($0 >= $1)", [NByte, NByte], NBool),
  "%byte_compare": ("$0.compare($1)", [NByte, NByte], NInt),
  "%byte_to_string": ("$0.to_string()", [NByte], NString),
  "%byte_hash": ("$0.hash()", [NByte], NInt),
  "%float_add": ("($0 + $1)", [NFloat, NFloat], NFloat),
  "%float_sub": ("($0 - $1)", [NFloat, NFloat], NFloat),
  "%float_mul": ("($0 * $1)", [NFloat, NFloat], NFloat),
  "%float_div": ("($0 / $1)", [NFloat, NFloat], NFloat),
  "%float_neg": ("(-$0)", [NFloat], NFloat),
  "%float_eq": ("($0 == $1)", [NFloat, NFloat], NBool),
  "%float_lt": ("($0 < $1)", [NFloat, NFloat], NBool),
  "%float_le": ("($0 <= $1)", [NFloat, NFloat], NBool),
  "%float_gt": ("($0 > $1)", [NFloat, NFloat], NBool),
  "%float_ge": ("($0 >= $1)", [NFloat, NFloat], NBool),
  "%float_compare": ("$0.compare($1)", [NFloat, NFloat], NInt),
  "%float_to_string": ("$0.to_string()", [NFloat], NString),
  "%float_hash": ("$0.hash()", [NFloat], NInt),
  "%int64_to_int": ("$0.to_int()", [NInt64], NInt),
  "%int64_to_double": ("$0.to_double()", [NInt64], NDouble),
  "%int_to_int64": ("$0.to_int64()", [NInt], NInt64),
  "%uint_to_int": ("$0.to_int()", [NUInt], NInt),
  "%uint_to_double": ("$0.to_double()", [NUInt], NDouble),
  "%int_to_uint": ("$0.to_uint()", [NInt], NUInt),
  "%uint64_to_int": ("$0.to_int()", [NUInt64], NInt),
  "%uint64_to_double": ("$0.to_double()", [NUInt64], NDouble),
  "%int_to_uint64": ("$0.to_uint64()", [NInt], NUInt64),
  "%byte_to_int": ("$0.to_int()", [NByte], NInt),
  "%byte_to_double": ("$0.to_double()", [NByte], NDouble),
  "%int_to_byte": ("$0.to_byte()", [NInt], NByte),
  "%float_to_int": ("$0.to_int()", [NFloat], NInt),
  "%float_to_double": ("$0.to_double()", [NFloat], NDouble),
  "%int_to_float": ("Float::from_int($0)", [NInt], NFloat),
  "%double_to_float": ("Float::from_double($0)", [NDouble], NFloat),
  "%int64_to_uint64": ("$0.to_uint64()", [NInt64], NUInt64),
  "%uint64_to_int64": ("$0.to_int64()", [NUInt64], NInt64),
  "%uint_to_uint64": ("$0.to_uint64()", [NUInt], NUInt64),
  "%uint64_to_uint": ("$0.to_uint()", [NUInt64], NUInt),
  "%uint_to_int64": ("$0.to_int64()", [NUInt], NInt64),
  "%byte_to_int64": ("$0.to_int64()", [NByte], NInt64),
  "%byte_to_uint": ("$0.to_uint()", [NByte], NUInt),
  "%byte_to_uint64": ("$0.to_uint64()", [NByte], NUInt64),
  "%int64_to_byte": ("$0.to_byte()", [NInt64], NByte),
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
/// The context of type expressions corresponding to a typed environment.
fn ty_ctx(env : Array[TLocal]) -> Array[TyCtx] {
  env.map(l => {
    match l {
      TType(t) => TyIs(t)
      _ => TyOther
    }
  })
}

///|
fn Gen::type_arg(
  self : Gen,
  env : Array[TLocal],
  t : @tt.Tm,
) -> NTy raise NotTyped {
  match self.native_ty_in(ty_ctx(env), t) {
    Some(nt) => nt
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
    out.push(self.typed_check(env, args[k], tys[k]))
  }
  out
}

///|
/// Translate `t` at the expected type `ty` (lambdas need it for their
/// parameters).
fn Gen::typed_check(
  self : Gen,
  env : Array[TLocal],
  t : @tt.Tm,
  ty : NTy,
) -> String raise NotTyped {
  match (t, ty) {
    (Lam(_, Expl, _, _), NFun(ps, r) | NAsyncFun(ps, r)) => {
      let is_async = ty is NAsyncFun(_, _)
      let mut e = env
      let xs : Array[String] = []
      let mut b = t
      for p in ps {
        match b {
          Lam(x, Expl, _, rest) => {
            let n = self.name(x)
            xs.push(n)
            e = tpush(e, TVar(n, p))
            b = rest
          }
          _ => raise NotTyped
        }
      }
      // `return` in the lambda returns from it
      let saved = self.cur_result
      self.cur_result = Some(r)
      let res = Ok(self.typed(e, b)) catch { err => Err(err) }
      self.cur_result = saved
      let (cb, tb) = match res {
        Ok(x) => x
        Err(_) => raise NotTyped
      }
      ignore(unify_t(tb, r))
      // `{ x }` would be a record
      let cb = if is_ident(cb) { "(" + cb + ")" } else { cb }
      // `() -> T`: no parameter in MoonBit, the variable is `()`
      let (xs, cb) = if unit_only(ps) {
        ([], "let " + xs[0] + " = ()\n" + cb)
      } else {
        (xs, cb)
      }
      let ps = if unit_only(ps) { [] } else { ps }
      if is_async {
        // an async closure (arrow functions cannot be async)
        let typed_ps = xs.mapi((i, x) => x + " : " + self.mbt_ty(ps[i]))
        return "async fn(" +
          typed_ps.join(", ") +
          ") -> " +
          self.mbt_ty(r) +
          " raise {\n" +
          cb +
          "\n}"
      }
      "(" + xs.join(", ") + ") => {\n" + cb + "\n}"
    }
    _ => {
      let (c, t2) = self.typed(env, t)
      ignore(unify_t(t2, ty))
      c
    }
  }
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
    Var(_) => {
      // calling a function value, one argument group at a time
      let (code0, ty0) = self.typed(env, h)
      let mut code = code0
      let mut ty = ty0
      let mut i = 0
      while i < args.length() {
        match ty {
          NFun(ps, r) | NAsyncFun(ps, r) if i + ps.length() <= args.length() => {
            let cs = self.typed_args(
              env,
              args[i:i + ps.length()].to_array(),
              ps,
            )
            code = if unit_only(ps) && cs[0] == "()" {
              code + "()"
            } else if unit_only(ps) {
              "{\nignore(" + cs[0] + ")\n" + code + "()\n}"
            } else {
              code + "(" + cs.join(", ") + ")"
            }
            ty = r
            i = i + ps.length()
          }
          _ => raise NotTyped
        }
      }
      return (code, ty)
    }
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
      let targs : Array[NTy] = []
      for k = 0; k < ci.nparams; k = k + 1 {
        targs.push(self.type_arg(env, args[k]))
      }
      let fields = self.con_fields(n).unwrap()
      let fargs : Array[@tt.Tm] = []
      let ftys : Array[NTy] = []
      for j = 0; j < ci.nargs; j = j + 1 {
        match fields[j] {
          Some(ft) => {
            fargs.push(args[ci.nparams + j])
            ftys.push(subst_nty(ft, targs))
          }
          None => ()
        }
      }
      let cs = self.typed_args(env, fargs, ftys)
      self.need_enum(ci.data)
      (con_expr(ci.data, n, cs), NEnum(ci.data, targs))
    }
    GPrim(p, k) if args.length() == k && p.has_prefix("@mbt:") =>
      self.typed_ffi(env, n, p, g.ty, args)
    GFunc(_, _, _) if method_of(n) is Some((tr, m)) =>
      self.typed_method(env, tr, m, args)
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
      // `1 + if c { a } else { b }` is not MoonBit
      let cs = self
        .typed_args(env, expl, tys)
        .map(c => {
          if c.has_prefix("if ") || c.has_prefix("match ") {
            "(" + c + ")"
          } else {
            c
          }
        })
      (subst_args(tpl, cs), res)
    }
    GFunc(_, _, _) =>
      match self.native_sig(n) {
        Some(sig) if args.length() == sig.params.length() => {
          // instantiate the type parameters from the type arguments
          let inst : Array[NTy] = Array::make(sig.ntvars, NAny)
          for i = 0; i < args.length(); i = i + 1 {
            match sig.tparams[i] {
              Some(k) => inst[k] = self.type_arg(env, args[i])
              None => ()
            }
          }
          let ps : Array[@tt.Tm] = []
          let tys : Array[NTy] = []
          for i = 0; i < args.length(); i = i + 1 {
            match sig.params[i] {
              Some(nt) => {
                ps.push(args[i])
                tys.push(subst_nty(nt, inst))
              }
              None => ()
            }
          }
          let res = subst_nty(sig.result, inst)
          for bd in sig.bounds {
            if !self.satisfies(inst[bd.0], bd.1) {
              raise NotTyped
            }
          }
          let cs = self.typed_args(env, ps, tys)
          let id = self.gid(n)
          if self.typed_set.contains(n) && sig.bounds.length() > 0 {
            if inst.contains(NAny) {
              raise NotTyped
            }
            // the type parameters may only occur in the bounds
            (
              "(" + id + "_t(" + cs.join(", ") + ") : " + self.mbt_ty(res) + ")",
              res,
            )
          } else if self.typed_set.contains(n) {
            (id + "_t(" + cs.join(", ") + ")", res)
          } else if !self.wrappable(sig) || @tt.is_async_global(n) {
            // (an async function has no uniform version)
            raise NotTyped
          } else {
            // through the uniform version: only with concrete types
            if has_var(res) || tys.iter().any(has_var) {
              raise NotTyped
            }
            let vs = cs.mapi((i, c) => self.to_value(tys[i], c, None))
            (self.of_value(res, id + "(" + vs.join(", ") + ")", None), res)
          }
        }
        _ => raise NotTyped
      }
    _ => raise NotTyped
  }
}

///|
/// A call of an imported MoonBit function from typed code: a direct MoonBit
/// call (no conversion), for scalar types, type parameters and functions.
/// `StringView` arguments and results are converted from and to `String`;
/// an optional argument `x? : T` given as `Some(e)` is passed as `x=e`, and
/// omitted when it is `None`.
fn Gen::typed_ffi(
  self : Gen,
  env : Array[TLocal],
  name : String,
  prim : String,
  ty : @tt.Tm,
  args : Array[@tt.Tm],
) -> (String, NTy) raise NotTyped {
  let labels = @tt.param_labels(name).unwrap_or([])
  // the declared types (with `NVar`s), and the type arguments
  let ctx : Array[TyCtx] = []
  let inst : Array[NTy] = []
  let conv : Array[String] = []
  let mut t = ty
  let mut expl = 0
  // a declared type, instantiated; its datatypes must be MoonBit types
  let decl_ty = (a : @tt.Tm) => {
    match self.native_ty_in(ctx, a) {
      Some(nt) if mbt_only(nt) => Some(subst_nty(nt, inst))
      _ => None
    }
  }
  for i = 0; i < args.length(); i = i + 1 {
    match t {
      Pi(_, Impl, _, U, b) => {
        ctx.push(TyIs(NVar(inst.length())))
        inst.push(self.type_arg(env, args[i]))
        t = b
      }
      Pi(_, Inst, _, a, b) => {
        // a `#mbt` bound: MoonBit finds the impl
        match bound_of(ctx, a) {
          Some((k, tr)) if self.satisfies(inst[k], tr) => ()
          _ => raise NotTyped
        }
        ctx.push(TyOther)
        t = b
      }
      Pi(_, Expl, _, a, b) => {
        let label = if expl < labels.length() { labels[expl] } else { None }
        expl = expl + 1
        let unit_only = a is Global("Unit") &&
          i == args.length() - 1 &&
          expl == 1
        if !unit_only {
          match label {
            Some((l, true)) => {
              // `x? : T`: the argument is `Some(e)` or `None`
              let inner = match a {
                App(Global("Option"), x, _) => x
                _ => raise NotTyped
              }
              let (h, xs) = flatten_app(args[i])
              match h {
                Global("Option::None") => ()
                Global("Option::Some") if xs.length() == 2 => {
                  let nt = match decl_ty(inner) {
                    Some(nt) => nt
                    None => raise NotTyped
                  }
                  conv.push(l + "=" + self.typed_check(env, xs[1], nt))
                }
                _ => raise NotTyped
              }
            }
            _ => {
              let code = if a is Global("StringView") {
                self.typed_check(env, args[i], NString) + "[:]"
              } else {
                match decl_ty(a) {
                  Some(nt) => self.typed_check(env, args[i], nt)
                  None => raise NotTyped
                }
              }
              conv.push(
                match label {
                  Some((l, _)) => l + "=" + code
                  None => code
                },
              )
            }
          }
        }
        ctx.push(TyOther)
        t = b
      }
      _ => raise NotTyped
    }
  }
  let (res_tm, raises) = match t {
    Raises(r, e) => (r, @tt.tm_effect(e).1 is Some(_))
    _ => (t, false)
  }
  let target = prim.unsafe_substring(start=5, end=prim.length())
  let call = match self.ffi_call(target, conv) {
    Ok(c) => c
    Err(_) => raise NotTyped
  }
  let (call, res) = if res_tm is Global("StringView") {
    (call + ".to_string()", NString)
  } else {
    match decl_ty(res_tm) {
      Some(nt) => (call, nt)
      None => raise NotTyped
    }
  }
  if raises {
    (
      "(try { " + call + " } catch { err => raise CRaise(foreign_error(err)) })",
      res,
    )
  } else {
    (call, res)
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
      let (d, targs) = match ty {
        NEnum(d, targs) => (d, targs)
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
        match fields[j] {
          Some(ft) =>
            subs.push(self.typed_pat(ps[j], subst_nty(ft, targs), names))
          None =>
            // an erased field: only variables bind it (see erase.mbt)
            names.push(TNone)
        }
      }
      let args = if subs.length() == 0 {
        ""
      } else {
        "(" + subs.join(", ") + ")"
      }
      ignore(args)
      "(" + con_pat(d, c, subs) + as_marker + n + end_marker + ")"
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
  self.typed_term(env, t) catch {
    NotTyped => {
      // the innermost term that fails is the culprit
      if self.diagnose && self.culprit is None {
        self.culprit = Some(self.explain(env, t))
      }
      raise NotTyped
    }
  }
}

///|
fn Gen::typed_term(
  self : Gen,
  env : Array[TLocal],
  t : @tt.Tm,
) -> (String, NTy) raise NotTyped {
  match t {
    Var(ix) =>
      match env[env.length() - 1 - ix] {
        TVar(n, ty) | TMut(n, ty) => (n, ty)
        _ => raise NotTyped
      }
    Lit(LInt(k)) =>
      (if k < 0 { "(" + k.to_string() + ")" } else { k.to_string() }, NInt)
    Lit(LDouble(d)) => (double_lit(d), NDouble)
    Lit(LInt64(n)) => ("(" + n.to_string() + "L)", NInt64)
    Lit(LUInt(n)) => (n.to_string() + "U", NUInt)
    Lit(LUInt64(n)) => (n.to_string() + "UL", NUInt64)
    Lit(LByte(b)) => (byte_lit(b), NByte)
    Lit(LFloat(f)) => ("(" + double_lit(f.to_double()) + " : Float)", NFloat)
    Lit(LStr(s)) => (s.escape(), NString)
    Lit(LChar(c)) => (char_lit(c), NChar)
    Lit(LBool(b)) => (b.to_string(), NBool)
    Lit(LUnit) => ("()", NUnit)
    Global(_) => self.typed_app(env, t)
    App(_, _, _) => self.typed_app(env, t)
    // a proof is not computed
    Let(_, ty, v, b) if @tt.is_prop_head(ty) ||
      (flatten_app(v).0 is Global(g) && @tt.is_proof_global(g)) =>
      self.typed(tpush(env, TNone), b)
    Let(x, ty, v, b) => {
      // a lambda gets its parameter types from the type of the `let`
      let (cv, tv) = if v is Lam(_, Expl, _, _) {
        let nt = self.type_arg(env, ty)
        (self.typed_check(env, v, nt), nt)
      } else {
        self.typed(env, v)
      }
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
    // `try { e } catch { C(x, _) => ...; _ => ... }`: errors are
    // `CRaise(v)`; a clause tests the constructor of the error and binds
    // its fields (from the `Value`)
    Try(b, cls) => {
      let (cb, tb) = self.typed(env, b)
      let err = self.name("err")
      let mut ty = tb
      let arms : Array[String] = []
      for cl in cls {
        let lets = StringBuilder::new()
        let (cond, env2) = match cl.pats {
          [CPWild | CPVar(_)] => ("true", tpush(env, TNone))
          [CPCon(c, ps)] if ps.iter().all(p => p is (CPWild | CPVar(_))) => {
            let fields = match self.con_fields(c) {
              Some(f) => f
              None => raise NotTyped
            }
            let mut env2 = tpush(env, TNone)
            // the index of the field among the fields of the `Value`
            let mut k = 0
            for j = 0; j < ps.length(); j = j + 1 {
              let erased = self.er.con_erased(c, j)
              match (ps[j], fields[j]) {
                (CPVar(x), Some(ft)) if !erased => {
                  let n = self.name(x)
                  lets.write_string(
                    "let " +
                    n +
                    " = " +
                    self.of_value(
                      ft,
                      "con_fields(" + err + ")[" + k.to_string() + "]",
                      None,
                    ) +
                    "\n",
                  )
                  env2 = tpush(env2, TVar(n, ft))
                }
                _ => env2 = tpush(env2, TNone)
              }
              if !erased {
                k = k + 1
              }
            }
            ("con_name(" + err + ") == Some(" + c.escape() + ")", env2)
          }
          _ => raise NotTyped
        }
        let cond = match cl.cond {
          Some(g) => {
            let (cg, tg) = self.typed(env2, g)
            ignore(unify_t(tg, NBool))
            cond + " && {\n" + lets.to_string() + cg + "\n}"
          }
          None => cond
        }
        let (code, t) = self.typed(env2, cl.body)
        ty = unify_t(ty, t)
        arms.push("if " + cond + " {\n" + lets.to_string() + code + "\n}")
      }
      let handler = if arms.length() == 0 {
        "raise CRaise(" + err + ")"
      } else {
        arms.join(" else ") + " else {\nraise CRaise(" + err + ")\n}"
      }
      (
        "(try {\n" +
        cb +
        "\n} catch {\nCRaise(" +
        err +
        ") => " +
        handler +
        "\ne => raise e\n})",
        ty,
      )
    }
    Match(ss, cls) =>
      match if_parts(ss, cls) {
        Some((c, a, b)) => {
          let (cc, tc) = self.typed(env, c)
          ignore(unify_t(tc, NBool))
          // MoonBit does not allow `if if ...` or `if match ...`
          let cc = if cc.has_prefix("if ") || cc.has_prefix("match ") {
            "(" + cc + ")"
          } else {
            cc
          }
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
            let when = match cl.cond {
              Some(g) => {
                let (cg, tg) = self.typed(env2, g)
                ignore(unify_t(tg, NBool))
                " if (" + cg + ")"
              }
              None => ""
            }
            let lhs = if ps.length() == 1 {
              ps[0]
            } else {
              "(" + ps.join(", ") + ")"
            }
            buf.write_string(
              resolve_bindings(lhs, cb + when) + when + " => " + cb + "\n",
            )
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
    // errors are `Value`s (`CRaise(v)`), as in uniform code
    Raise(v) => {
      let (cv, tv) = self.typed(env, v)
      if !self.convertible(tv, false) {
        raise NotTyped
      }
      ("raise CRaise(" + self.to_value(tv, cv, None) + ")", NAny)
    }
    Seq(a, b) => {
      let (ca, ta) = self.typed(env, a)
      let (cb, tb) = self.typed(env, b)
      ("{\n" + stmt(ca, ta) + "\n" + cb + "\n}", tb)
    }
    Defer(a, b) => {
      let (ca, ta) = self.typed(env, a)
      let (cb, tb) = self.typed(env, b)
      (
        "{\ndefer (try { " +
        stmt(ca, ta) +
        " } catch { _ => () })\n" +
        cb +
        "\n}",
        tb,
      )
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
    Seq(a, b) | Defer(a, b) => has_continue(a) || has_continue(b)
    Assign(_, v) | Return(v) => has_continue(v)
    _ => false
  }
}

///|
/// The native translation of a function, if it is in the typed fragment.
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
        match (sig.params[i], sig.tparams[i]) {
          (Some(nt), _) => {
            let p = self.name(x)
            params.push(p + " : " + self.mbt_ty(nt))
            env = tpush(env, TVar(p, nt))
          }
          (None, Some(k)) => env = tpush(env, TType(NVar(k)))
          (None, None) => env = tpush(env, TNone)
        }
        b = rest
      }
      _ => return None
    }
  }
  self.cur_result = Some(sig.result)
  self.cur_bounds = sig.bounds
  let res = Ok(self.typed(env, b)) catch { err => Err(err) }
  self.cur_result = None
  self.cur_bounds = []
  match res {
    Ok((code, ty)) =>
      match unify_nty(ty, sig.result) {
        Some(_) => {
          let id = self.gid(name)
          let gen = if sig.ntvars == 0 {
            ""
          } else {
            "[" + self.tvars_with_bounds(sig.ntvars, sig.bounds) + "]"
          }
          Some(
            (if @tt.is_async_global(name) { "async fn" } else { "fn" }) +
            gen +
            " " +
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
/// The definitions of a typed function: its native version, the uniform
/// wrapper (type parameters instantiated to `Value`) and its value.
fn Gen::typed_def(self : Gen, name : String) -> String {
  let code = self.typed_fn(name).unwrap()
  let sig = self.native_sig(name).unwrap()
  let id = self.gid(name)
  let n = sig.params.length()
  let params : Array[String] = []
  let conv : Array[String] = []
  let pass : Array[String] = []
  for i = 0; i < n; i = i + 1 {
    match sig.params[i] {
      Some(nt) => {
        let p = "a" + i.to_string()
        params.push(p + " : Value")
        conv.push(self.of_value(nt, p, None))
        pass.push(p)
      }
      None => ()
    }
  }
  let call = self.to_value(sig.result, id + "_t(" + conv.join(", ") + ")", None)
  "\n/// " +
  name +
  "\n" +
  code +
  "\nfn " +
  id +
  "(" +
  params.join(", ") +
  ") -> Value raise {\n  " +
  call +
  "\n}\n\nfn " +
  id +
  "_v() -> Value {\n  " +
  curried(n, id + "(" + pass.join(", ") + ")") +
  "\n}\n"
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
  for tr in @tt.mbt_types.keys() {
    if is_mbt_trait(tr) {
      for i in @tt.instances_of(tr) {
        match self.impl_info(i) {
          // MoonBit has the impls of imports and of its own `derive`s
          Some(_) if @tt.external_instances.contains(i) => ()
          Some((_, _, self_t, _)) if impl_allowed(tr, self_t) =>
            self.mbt_impls.push(i)
          _ => ()
        }
      }
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
    // instances whose methods are not in the fragment are not MoonBit impls
    let keep_impls : Array[String] = []
    for i in self.mbt_impls {
      if self.impl_code(i) is Some(_) {
        keep_impls.push(i)
      } else {
        changed = true
      }
    }
    self.mbt_impls.clear()
    for i in keep_impls {
      self.mbt_impls.push(i)
    }
  }
}

///|
/// A function type of one `Unit` parameter is a MoonBit function without
/// parameters (MoonBit++ `() -> T` is `(Unit) -> T`).
fn unit_only(ps : Array[NTy]) -> Bool {
  ps is [NUnit]
}

///|
/// The parameter types of a native function type.
fn Gen::mbt_params(self : Gen, ps : Array[NTy]) -> String {
  if unit_only(ps) {
    ""
  } else {
    ps.map(p => self.mbt_ty(p)).join(", ")
  }
}
