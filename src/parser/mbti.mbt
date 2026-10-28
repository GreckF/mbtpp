///|
/// Import of MoonBit package interfaces (`.mbti` files).
///
/// Each item of the interface becomes a MoonBit++ declaration whose
/// functions are external (`"@mbt:<package>.<name>"`): they have a type but
/// no definition, so they never reduce during type checking. Names of the
/// package are qualified as `@alias.name`; methods of types from other
/// packages (e.g. `Array::all`) keep their `Type::method` name.
pub(all) struct MbtiResult {
  decls : Array[Decl]
  /// Items that could not be translated (first line of each).
  skipped : Array[String]
}

///|
priv struct MbtiItem {
  line : Int
  text : String
  attrs : Array[String]
}

///|
/// Split an interface into top-level items: an item starts at column 1 and
/// continues over indented lines and closing braces. Attribute lines
/// (`#deprecated`, ...) are attached to the following item.
fn mbti_items(src : String) -> (Array[String], Array[MbtiItem]) {
  let lines = src
    .split("\n")
    .map(l => l.to_string().trim_end(chars="\r").to_string())
    .to_array()
  let imports : Array[String] = []
  let items : Array[MbtiItem] = []
  let mut attrs : Array[String] = []
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    let t = line.trim(chars=" \t").to_string()
    if t == "" || t.has_prefix("//") || t.has_prefix("package ") {
      i = i + 1
      continue
    }
    if t.has_prefix("#") {
      attrs.push(t)
      i = i + 1
      continue
    }
    // `import( ... )`, or `import { ... }` in newer interfaces
    if t.has_prefix("import(") || t.has_prefix("import {") {
      let close = if t.has_prefix("import(") { ")" } else { "}" }
      i = i + 1
      while i < lines.length() &&
            lines[i].trim(chars=" \t").to_string() != close {
        let q = lines[i].trim(chars=" \t\",").to_string()
        // `"path" @alias` is possible; keep the path
        let path = match q.find("\"") {
          Some(k) => q.unsafe_substring(start=0, end=k)
          None => q
        }
        if path != "" {
          imports.push(path)
        }
        i = i + 1
      }
      i = i + 1
      continue
    }
    let start = i
    let buf = StringBuilder::new()
    buf.write_string(line)
    i = i + 1
    while i < lines.length() &&
          (
            lines[i].has_prefix(" ") ||
            lines[i].has_prefix("\t") ||
            lines[i].has_prefix("}")
          ) {
      buf.write_char('\n')
      // attributes inside an item (e.g. on trait methods) are dropped
      let inner = lines[i].trim(chars=" \t").to_string()
      if !inner.has_prefix("#") {
        buf.write_string(lines[i])
      }
      i = i + 1
    }
    items.push({ line: start + 1, text: buf.to_string(), attrs })
    attrs = []
  }
  (imports, items)
}

///|
fn last_segment(path : String) -> String {
  match path.rev_find("/") {
    Some(k) => path.unsafe_substring(start=k + 1, end=path.length())
    None => path
  }
}

///|
fn binder_names(bs : Array[Binder]) -> Array[String] {
  bs.map(b => b.name)
}

///|
/// Apply `f` to every name in a type expression.
fn map_names(e : Expr, f : (Pos, String) -> Expr) -> Expr {
  let go = (x : Expr) => map_names(x, f)
  let gob = (b : Binder) => { ..b, ty: b.ty.map(go) }
  match e {
    EVar(p, n) => f(p, n)
    EApp(p, h, i, x) =>
      EApp(p, go(h), i.map(xs => xs.map(go)), x.map(xs => xs.map(go)))
    EPi(p, impls, expl, cod, raises) =>
      EPi(
        p,
        impls.map(gob),
        expl.map(bs => bs.map(gob)),
        go(cod),
        raises.map(go),
      )
    ETuple(p, es) => ETuple(p, es.map(go))
    EBin(p, op, a, b) => EBin(p, op, go(a), go(b))
    EAnn(p, a, b) => EAnn(p, go(a), go(b))
    _ => e
  }
}

///|
/// Type names used in an expression (with the largest number of implicit
/// arguments they are applied to), not counting the names in `bound`.
fn collect_names(
  e : Expr,
  bound : Array[String],
  out : Map[String, Int],
) -> Unit {
  let go = (x : Expr) => collect_names(x, bound, out)
  match e {
    EVar(_, n) => if !bound.contains(n) && !out.contains(n) { out.set(n, 0) }
    EApp(_, EVar(_, n), Some(args), x) => {
      if !bound.contains(n) {
        let k = out.get(n).unwrap_or(0)
        out.set(n, if args.length() > k { args.length() } else { k })
      }
      args.each(go)
      x.map(xs => xs.each(go)) |> ignore
    }
    EApp(_, h, i, x) => {
      go(h)
      i.map(xs => xs.each(go)) |> ignore
      x.map(xs => xs.each(go)) |> ignore
    }
    EPi(_, impls, expl, cod, raises) => {
      let b2 = bound.copy()
      for b in impls {
        b.ty.map(go) |> ignore
        b2.push(b.name)
      }
      for b in expl.unwrap_or([]) {
        b.ty.map(t => collect_names(t, b2, out)) |> ignore
      }
      collect_names(cod, b2, out)
      raises.map(go) |> ignore
    }
    ETuple(_, es) => es.each(go)
    EBin(_, _, a, b) => {
      go(a)
      go(b)
    }
    EAnn(_, a, b) => {
      go(a)
      go(b)
    }
    _ => ()
  }
}

///|
/// Names used as trait bounds (`[T : Hash + Eq]`) in a declaration.
pub fn decl_bound_names(d : Decl) -> Array[String] {
  let out : Array[String] = []
  fn add(e : Expr, out : Array[String]) -> Unit {
    match e {
      EVar(_, n) => if !out.contains(n) { out.push(n) }
      EBin(_, "+", a, b) => {
        add(a, out)
        add(b, out)
      }
      _ => ()
    }
  }

  let bs : Array[Binder] = match d {
    DFn(fd) => fd.impl_params
    DEnum(ed) => [..ed.impl_params, ..ed.cons.map(c => c.impl_params).flatten()]
    DStruct(sd) => sd.impl_params
    DTrait(td) => td.methods.map(m => m.impl_params).flatten()
    DImpl(id) => id.impl_params
    DDef(_, _, bs, _, _) => bs
    DOpaque(_, _, _) => []
  }
  for b in bs {
    match b.ty {
      Some(t) => add(t, out)
      None => ()
    }
  }
  out
}

///|
/// Names referred to by a declaration that may be types, with their arity.
pub fn decl_type_names(d : Decl) -> Map[String, Int] {
  let out : Map[String, Int] = {}
  let tys = (bs : Array[Binder], bound : Array[String]) => for b in bs {
    b.ty.map(t => collect_names(t, bound, out)) |> ignore
  }
  match d {
    DFn(fd) => {
      let bound = ["Self", ..binder_names(fd.impl_params)]
      tys(fd.params.unwrap_or([]), bound)
      fd.ret.map(t => collect_names(t, bound, out)) |> ignore
      fd.raises.map(t => collect_names(t, bound, out)) |> ignore
    }
    DDef(_, _, bs, _, body) => collect_names(body, binder_names(bs), out)
    DEnum(ed) => {
      let bound = binder_names(ed.impl_params)
      for c in ed.cons {
        let b2 = bound + binder_names(c.impl_params)
        tys(c.params, b2)
        c.ret.map(t => collect_names(t, b2, out)) |> ignore
      }
    }
    DStruct(sd) => {
      let bound = binder_names(sd.impl_params)
      for f in sd.fields {
        collect_names(f.2, bound, out)
      }
    }
    DTrait(td) =>
      for m in td.methods {
        let bound = ["Self", ..binder_names(m.impl_params)]
        tys(m.params, bound)
        collect_names(m.ret, bound, out)
      }
    _ => ()
  }
  out
}

///|
/// Translate a MoonBit interface. `alias` is the name the package is
/// imported under, `aliases` maps package paths to the aliases of the other
/// imported packages.
pub fn parse_mbti(
  src : String,
  alias : String,
  pkg_path : String,
  aliases : Map[String, String],
) -> MbtiResult {
  let (imports, items) = mbti_items(src)
  let prefix = "@" + alias + "."
  // the interface refers to its own imports by their last path segment
  let import_alias : Map[String, String] = {}
  for path in imports {
    match aliases.get(path) {
      Some(a) => import_alias.set(last_segment(path), a)
      None => ()
    }
  }
  let raw : Array[(Decl, Array[String])] = []
  let skipped : Array[String] = []
  for item in items {
    if item.attrs.iter().any(a => a.has_prefix("#deprecated")) {
      continue
    }
    let first = match item.text.find("\n") {
      Some(k) => item.text.unsafe_substring(start=0, end=k)
      None => item.text
    }
    try {
      let p = { toks: tokenize(item.text, line0=item.line), i: 0 }
      for d in mbti_item(p, pkg_path) {
        raw.push((d, item.attrs))
      }
    } catch {
      _ => skipped.push(first)
    }
  }
  // names of the types of this package
  let local : Array[String] = []
  for r in raw {
    match r.0 {
      DEnum(ed) => local.push(ed.name)
      DStruct(sd) => local.push(sd.name)
      DTrait(td) => local.push(td.name)
      DOpaque(_, n, _) => local.push(n)
      DDef(_, n, _, _, _) if is_type_name(n) => local.push(n)
      _ => ()
    }
  }
  let qualify = (self_ty : String?) => (p : Pos, n : String) => {
    let e : Expr = if n == "Self" && self_ty is Some(t) {
      EVar(p, t)
    } else if local.contains(n) {
      EVar(p, prefix + n)
    } else if n.has_prefix("@") {
      // `@pkg.T` refers to an import of this interface
      match n.find(".") {
        Some(k) => {
          let a = n.unsafe_substring(start=1, end=k)
          match import_alias.get(a) {
            Some(u) =>
              EVar(p, "@" + u + n.unsafe_substring(start=k, end=n.length()))
            None => EVar(p, n)
          }
        }
        None => EVar(p, n)
      }
    } else {
      EVar(p, n)
    }
    e
  }
  let decls : Array[Decl] = []
  for r in raw {
    let (d, attrs) = r
    match d {
      DFn(fd) => {
        let (name, self_ty) = match fd.name.find("::") {
          Some(k) => {
            let t = fd.name.unsafe_substring(start=0, end=k)
            let qt = if local.contains(t) { prefix + t } else { t }
            (
              qt + fd.name.unsafe_substring(start=k, end=fd.name.length()),
              Some(qt),
            )
          }
          None => (prefix + fd.name, None)
        }
        let f = qualify(self_ty)
        let qb = (b : Binder) => { ..b, ty: b.ty.map(t => map_names(t, f)) }
        let fd2 = {
          ..fd,
          name,
          impl_params: fd.impl_params.map(qb),
          params: fd.params.map(ps => ps.map(qb)),
          ret: fd.ret.map(t => map_names(t, f)),
          raises: fd.raises.map(t => map_names(t, f)),
        }
        decls.push(DFn(fd2))
        // `#as_free_fn`: the method can also be called as `@pkg.name`
        if self_ty is Some(_) {
          for a in attrs {
            if a.has_prefix("#as_free_fn") && !a.contains("deprecated") {
              let m = fd.name.unsafe_substring(
                start=fd.name.find("::").unwrap() + 2,
                end=fd.name.length(),
              )
              let free = if a.has_prefix("#as_free_fn(") {
                let inner = a.unsafe_substring(start=12, end=a.length() - 1)
                inner.split(",").to_array()[0]
                .to_string()
                .trim(chars=" ")
                .to_string()
              } else {
                m
              }
              decls.push(DFn({ ..fd2, name: prefix + free }))
            }
          }
        }
      }
      DDef(p, n, bs, ty, body) =>
        decls.push(DDef(p, prefix + n, bs, ty, map_names(body, qualify(None))))
      DOpaque(p, n, k) => decls.push(DOpaque(p, prefix + n, k))
      DEnum(ed) => {
        let f = qualify(None)
        let qb = (b : Binder) => { ..b, ty: b.ty.map(t => map_names(t, f)) }
        decls.push(
          DEnum({
            ..ed,
            name: prefix + ed.name,
            cons: ed.cons.map(c => {
              ..c,
              impl_params: c.impl_params.map(qb),
              params: c.params.map(qb),
              ret: c.ret.map(t => map_names(t, f)),
            }),
          }),
        )
      }
      DStruct(sd) => {
        let f = qualify(None)
        decls.push(
          DStruct({
            ..sd,
            name: prefix + sd.name,
            fields: sd.fields.map(x => (x.0, x.1, map_names(x.2, f))),
          }),
        )
      }
      DTrait(td) => {
        let f = qualify(None)
        let qb = (b : Binder) => { ..b, ty: b.ty.map(t => map_names(t, f)) }
        decls.push(
          DTrait({
            ..td,
            name: prefix + td.name,
            supers: td.supers.map(s => if local.contains(s) {
              prefix + s
            } else {
              s
            }),
            methods: td.methods.map(m => {
              ..m,
              impl_params: m.impl_params.map(qb),
              params: m.params.map(qb),
              ret: map_names(m.ret, f),
              raises: m.raises.map(t => map_names(t, f)),
            }),
          }),
        )
      }
      DImpl(id) =>
        decls.push(DImpl({ ..id, for_ty: map_names(id.for_ty, qualify(None)) }))
    }
  }
  { decls, skipped }
}

///|
fn is_type_name(n : String) -> Bool {
  match n.get_char(0) {
    Some(c) => c >= 'A' && c <= 'Z'
    None => false
  }
}

///|
/// Parse one interface item.
fn mbti_item(p : Parser, pkg_path : String) -> Array[Decl] raise ParseError {
  let pos = p.pos()
  p.skip_visibility()
  let ext = (name : String) => FnBody::BodyExtern(
    "@mbt:" + pkg_path + "." + name,
  )
  let out : Array[Decl] = match p.peek().tok {
    TSym("fn") => {
      ignore(p.advance())
      let impl_bs = p.impl_binders()
      let mut name = p.ident()
      while p.accept("::") {
        name = name + "::" + p.ident()
      }
      let params = p.params(false)
      for b in params {
        // `loc~ : SourceLoc` is filled in by the MoonBit compiler
        if b.ty is Some(EVar(_, "SourceLoc" | "ArgsLoc")) {
          p.fail("autofill argument")
        }
      }
      let ret = if p.accept("->") { p.expr() } else { EVar(pos, "Unit") }
      let raises = p.raises_opt()
      [
        DFn({
          pos,
          name,
          impl_params: impl_bs,
          params: Some(params),
          ret: Some(ret),
          raises,
          body: ext(name),
          is_lemma: false,
        }),
      ]
    }
    TSym("let") | TIdent("const") => {
      ignore(p.advance())
      let name = p.ident()
      p.expect(":")
      let ty = p.expr()
      // ignore the value of a constant
      p.i = p.toks.length() - 1
      [
        DFn({
          pos,
          name,
          impl_params: [],
          params: None,
          ret: Some(ty),
          raises: None,
          body: ext(name),
          is_lemma: false,
        }),
      ]
    }
    TIdent("type") => {
      ignore(p.advance())
      let name = p.ident()
      let bs = p.impl_binders()
      if p.accept("=") {
        [DDef(pos, name, bs, Some(EType(pos)), p.expr())]
      } else {
        [DOpaque(pos, name, bs.length())]
      }
    }
    TSym("struct" | "enum" | "suberror" | "trait") => {
      p.i = 0
      [p.decl()]
    }
    TSym("impl") => {
      ignore(p.advance())
      let bs = p.impl_binders()
      let tr = p.ident()
      p.expect("for")
      let ty = p.expr()
      if bs.length() > 0 {
        p.fail("generic impl")
      }
      impl_decls(pos, tr, ty)
    }
    _ => p.fail("unsupported interface item")
  }
  if p.peek().tok != TEOF {
    p.fail("unexpected tokens")
  }
  out
}

///|
/// `impl Show for T` and friends: declare the external method and an
/// instance of the corresponding prelude trait that calls it. Other traits
/// are not imported.
fn impl_decls(
  pos : Pos,
  tr : String,
  ty : Expr,
) -> Array[Decl] raise ParseError {
  let head = match ty {
    EVar(_, n) => n
    _ => raise ParseError(pos, "impl for a non-trivial type")
  }
  let self_b = (n : String) => (
    { pos, name: n, ty: Some(ty), kind: Positional } : Binder)
  let var = (n : String) => EVar(pos, n)
  let (meth, params, ret, body) = match tr {
    "Show" =>
      (
        "to_string",
        [self_b("self")],
        var("String"),
        EMethod(pos, var("self"), "to_string", None, []),
      )
    "Eq" =>
      (
        "op_equal",
        [self_b("self"), self_b("other")],
        var("Bool"),
        EBin(pos, "==", var("self"), var("other")),
      )
    "Compare" =>
      (
        "compare",
        [self_b("self"), self_b("other")],
        var("Int"),
        EMethod(pos, var("self"), "compare", None, [var("other")]),
      )
    _ => raise ParseError(pos, "trait not imported")
  }
  [
    DFn({
      pos,
      name: head + "::" + meth,
      impl_params: [],
      params: Some(params),
      ret: Some(ret),
      raises: None,
      body: BodyExtern("@mbt:" + head + "::" + meth),
      is_lemma: false,
    }),
    DImpl({
      pos,
      impl_params: [],
      trait_name: tr,
      for_ty: ty,
      meth,
      params: params.map(b => { ..b, ty: None }),
      body: EBlock(pos, [SExpr(pos, body)]),
    }),
  ]
}
