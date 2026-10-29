///|
/// `#mbt` functions: compiled to public MoonBit functions with their own
/// names (`pub fn f[T0 : Tr](x : Int, y~ : Tree[T0]) -> Int`), which call
/// the native translation. Their bodies must be in the native fragment; a
/// function that is not is a compile error explaining the first term that
/// is not native. A function that does not `raise` in MoonBit++ does not
/// raise in MoonBit either: a run-time failure inside it aborts.

///|
/// Names of the functions of the runtime (an exported function may not
/// take one).
fn runtime_fns() -> Array[String] {
  let out : Array[String] = []
  for line in runtime_src.split("\n") {
    let l = line.to_string()
    let rest = if l.has_prefix("fn[") {
      match l.find("] ") {
        Some(i) => l.unsafe_substring(start=i + 2, end=l.length())
        None => continue
      }
    } else if l.has_prefix("fn ") {
      l.unsafe_substring(start=3, end=l.length())
    } else {
      continue
    }
    match rest.find("(") {
      Some(i) => out.push(rest.unsafe_substring(start=0, end=i))
      None => ()
    }
  }
  out
}

///|
/// Every `#mbt` function must have a native translation.
fn Gen::check_mbt_fns(self : Gen) -> Unit raise CodegenError {
  // and the functions generated with `Value` (data.mbt)
  let reserved = [..runtime_fns(), "con_name", "con_fields"]
  for f, mname in @tt.mbt_fns {
    if reserved.contains(mname) || mname == "main" {
      raise CodegenError(
        "#mbt fn " +
        f +
        ": the name " +
        mname +
        " is taken by the runtime of compiled programs (use #mbt(\"name\"))",
      )
    }
    if self.typed_set.contains(f) {
      continue
    }
    let why = match self.native_sig(f) {
      None =>
        "its signature has no native translation (a type parameter with a bound must occur in a parameter or in the result type)"
      Some(_) => {
        self.diagnose = true
        self.culprit = None
        ignore(self.typed_fn(f))
        self.diagnose = false
        match self.culprit {
          Some(c) => "its body is not in the native fragment: " + c
          None => "its body is not in the native fragment"
        }
      }
    }
    raise CodegenError(
      "#mbt fn " + f + " cannot be compiled to MoonBit: " + why,
    )
  }
}

///|
/// Strip the counter of a generated local name: `x_12` -> `x`.
fn source_name(n : String) -> String {
  match n.rev_find("_") {
    Some(i) if i > 0 => n.unsafe_substring(start=0, end=i)
    _ => n
  }
}

///|
/// Why the term `t` is not in the native fragment.
fn Gen::explain(self : Gen, env : Array[TLocal], t : @tt.Tm) -> String {
  let names = env.map(l => {
    match l {
      TVar(n, _) | TMut(n, _) => source_name(n)
      TType(_) => "T"
      TNone => "_"
    }
  })
  let shown = @tt.show_tm(names, t)
  let shown = if shown.length() > 60 {
    shown.unsafe_substring(start=0, end=57) + "..."
  } else {
    shown
  }
  let (h, _) = flatten_app(t)
  let why = match h {
    Global(g) =>
      match @tt.globals.get(g) {
        Some({ kind: GFunc(_, _, _), .. }) =>
          match g.rev_find("::") {
            Some(i) if @tt.data_info(g.unsafe_substring(start=0, end=i))
              is Some({ is_trait: true, .. }) =>
              Some(
                g +
                " is a method of the trait " +
                g.unsafe_substring(start=0, end=i) +
                ", which is not #mbt",
              )
            _ =>
              if self.native_sig(g) is None {
                Some(
                  g +
                  " has no native signature (a type without a MoonBit type, or a bound that is not #mbt)",
                )
              } else if !self.typed_set.contains(g) {
                Some(g + " is not in the native fragment")
              } else {
                None
              }
          }
        Some({ kind: GPrim(p, _), .. }) if !p.has_prefix("@mbt:") =>
          Some("the primitive " + g + " has no native translation")
        Some({ kind: GCon(ci), .. }) if !self.enum_ok(ci.data) =>
          Some("the type " + ci.data + " is not native")
        _ => None
      }
    _ => None
  }
  match why {
    Some(w) => "in `" + shown + "`, " + w
    None => "`" + shown + "`"
  }
}

///|
let mbt_keywords : Array[String] = [
  "as", "break", "catch", "const", "continue", "else", "enum", "extern", "false",
  "fn", "for", "guard", "if", "impl", "in", "is", "let", "loop", "match", "mut",
  "pub", "priv", "raise", "return", "struct", "test", "trait", "true", "try", "type",
  "typealias", "while", "with", "async", "defer", "readonly", "local",
]

///|
/// Does the codomain of a function type of `n` parameters raise?
fn result_raises(ty : @tt.Tm, n : Int32) -> Bool {
  let mut t = ty
  for _ in 0..<n {
    match t {
      Pi(_, _, _, _, b) => t = b
      _ => return false
    }
  }
  t is Raises(_, _)
}

///|
/// Emit the public MoonBit function of a `#mbt` function (a no-op for
/// other functions).
fn Gen::export_fn(self : Gen, name : String, sig : TSig) -> Unit {
  let mname = match @tt.mbt_fns.get(name) {
    Some(m) => m
    None => return
  }
  let g = @tt.globals.get(name).unwrap()
  let body = match g.kind {
    GFunc(Some(b), _, _) => b
    _ => return
  }
  let labels = @tt.param_labels(name).unwrap_or([])
  let n = sig.params.length()
  // source names of the parameters
  let srcs : Array[String] = []
  let mut b = body
  for _ in 0..<n {
    match b {
      Lam(x, _, _, rest) => {
        srcs.push(x)
        b = rest
      }
      _ => srcs.push("_")
    }
  }
  let decls : Array[String] = []
  let args : Array[String] = []
  let used : Array[String] = []
  let mut expl = 0
  let expl_total = sig.params.filter(p => p is Some(_)).length()
  for i = 0; i < n; i = i + 1 {
    guard sig.params[i] is Some(nt) else { continue }
    let label = if expl < labels.length() { labels[expl] } else { None }
    expl = expl + 1
    // `fn f()` takes a `Unit` in MoonBit++
    if nt == NUnit && expl_total == 1 && label is None {
      args.push("()")
      continue
    }
    let x = match label {
      Some((l, _)) => l
      None => {
        let s = srcs[i]
        if is_ident(s) &&
          !mbt_keywords.contains(s) &&
          !used.contains(s) &&
          s != "_" {
          s
        } else {
          "a" + i.to_string()
        }
      }
    }
    used.push(x)
    args.push(x)
    decls.push(
      match label {
        Some((_, false)) => x + "~ : " + self.mbt_ty(nt)
        Some((_, true)) =>
          match nt {
            // `x? : T`: MoonBit++ sees an `Option[T]`, as MoonBit does
            NEnum(_, [inner]) => x + "? : " + self.mbt_ty(inner)
            _ => x + " : " + self.mbt_ty(nt)
          }
        None => x + " : " + self.mbt_ty(nt)
      },
    )
  }
  let raises = result_raises(g.ty, n)
  let gen = if sig.ntvars == 0 {
    ""
  } else {
    "[" + self.tvars_with_bounds(sig.ntvars, sig.bounds) + "]"
  }
  let call = self.gid(name) + "_t(" + args.join(", ") + ")"
  let body_code = if raises {
    call
  } else {
    // control flow and failures are errors of the native code
    "try {\n" +
    call +
    "\n} catch {\nCAbort(m) => abort(m)\ne => abort(e.to_string())\n}"
  }
  self.defs.write_string(
    "\n///|\n/// MoonBit++ " +
    name +
    "\npub fn" +
    gen +
    " " +
    mname +
    "(" +
    decls.join(", ") +
    ") -> " +
    self.mbt_ty(sig.result) +
    (if raises { " raise" } else { "" }) +
    " {\n" +
    body_code +
    "\n}\n",
  )
}
