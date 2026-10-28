///|
/// Entry points of the type checker.
fn builtin_data(name : String, ty : Tm, nparams : Int, is_error : Bool) -> Unit {
  register(
    name,
    ty,
    GData({
      name,
      nparams,
      nindices: 0,
      cons: [],
      is_prop: false,
      fields: None,
      is_trait: false,
      is_error,
      builtin: true,
    }),
  )
}

///|
/// Reset all state and install the built-in types.
pub fn setup() -> Unit {
  reset_state()
  reset_elab()
  for n in ["Int", "String", "Char", "Bool", "Unit", "Double"] {
    builtin_data(n, U, 0, false)
  }
  builtin_data("Error", U, 0, true)
  builtin_data("Array", Pi("T", Impl, false, U, U), 1, false)
}

///|
pub suberror CheckError {
  CheckError(String)
}

///|
fn format_pos(file : String, p : Pos) -> String {
  file + ":" + p.line.to_string() + ":" + p.col.to_string()
}

///|
fn check_src(file : String, src : String) -> Unit raise CheckError {
  let decls = @parser.parse_program(src) catch {
    @parser.ParseError(p, msg) =>
      raise CheckError(format_pos(file, p) + ": parse error: " + msg)
  }
  check_decls(decls) catch {
    ElabError(p, msg) =>
      raise CheckError(format_pos(file, p) + ": error: " + msg)
  }
}

///|
/// An imported MoonBit package: the alias it is referred to with
/// (`@alias.name`), its path, and the text of its `.mbti` interface.
pub(all) struct Import {
  alias : String
  path : String
  mbti : String
}

///|
/// Interface items that could not be imported by the last `check_program`.
pub let import_skipped : Array[String] = []

///|
/// Type check a program (after the prelude and the imported interfaces).
pub fn check_program(
  file : String,
  src : String,
  prelude? : Bool = true,
  imports? : Array[Import] = [],
) -> Unit raise CheckError {
  setup()
  if prelude {
    check_src("<prelude>", prelude_src)
  }
  import_skipped.clear()
  load_imports(imports)
  check_src(file, src)
}

///|
fn is_type_like(n : String) -> Bool {
  let base = match n.rev_find(".") {
    Some(k) if n.has_prefix("@") =>
      n.unsafe_substring(start=k + 1, end=n.length())
    _ => n
  }
  match base.get_char(0) {
    Some(c) => c >= 'A' && c <= 'Z' && !base.contains("::")
    None => false
  }
}

///|
fn load_imports(imports : Array[Import]) -> Unit raise CheckError {
  if imports.length() == 0 {
    return
  }
  let aliases : Map[String, String] = {}
  for im in imports {
    aliases.set(im.path, im.alias)
  }
  let decls : Array[@parser.Decl] = []
  // Views are taken to be the containers themselves (MoonBit converts a
  // string literal to a `StringView`, for example).
  let p0 : Pos = { line: 0, col: 0 }
  let view_aliases : Array[@parser.Decl] = [
    DDef(p0, "StringView", [], Some(EType(p0)), EVar(p0, "String")),
    DDef(
      p0,
      "ArrayView",
      [{ pos: p0, name: "T", ty: None, kind: Positional }],
      Some(EType(p0)),
      EApp(p0, EVar(p0, "Array"), Some([EVar(p0, "T")]), None),
    ),
  ]
  for d in view_aliases {
    match d {
      DDef(_, n, _, _, _) if !globals.contains(n) => decls.push(d)
      _ => ()
    }
  }
  for im in imports {
    let r = @parser.parse_mbti(im.mbti, im.alias, im.path, aliases)
    for d in r.decls {
      decls.push(d)
    }
    for s in r.skipped {
      import_skipped.push(s)
    }
  }
  // Types that the interfaces mention but nobody defines (e.g. `Int64`,
  // `Map`, or types of packages that are not imported) become opaque.
  let declared : Array[String] = []
  for d in decls {
    match d {
      DEnum(ed) => declared.push(ed.name)
      DStruct(sd) => declared.push(sd.name)
      DTrait(td) => declared.push(td.name)
      DOpaque(_, n, _) | DDef(_, n, _, _, _) => declared.push(n)
      _ => ()
    }
  }
  // unknown traits used as bounds become opaque traits
  let bounds : Array[String] = []
  for d in decls {
    for n in @parser.decl_bound_names(d) {
      if !declared.contains(n) && !globals.contains(n) && !bounds.contains(n) {
        bounds.push(n)
      }
    }
  }
  let trait_stubs : Array[@parser.Decl] = bounds.map(n => @parser.DTrait({
    pos: { line: 0, col: 0 },
    name: n,
    self_kind: None,
    supers: [],
    methods: [],
  }))
  for n in bounds {
    declared.push(n)
    st.opaque_traits.push(n)
  }
  let needed : Map[String, Int] = {}
  for d in decls {
    for n, k in @parser.decl_type_names(d) {
      if is_type_like(n) && !declared.contains(n) && !globals.contains(n) {
        let k0 = needed.get(n).unwrap_or(0)
        needed.set(n, if k > k0 { k } else { k0 })
      }
    }
  }
  let stubs : Array[@parser.Decl] = []
  for n, k in needed {
    stubs.push(DOpaque({ line: 0, col: 0 }, n, k))
  }
  check_decls(
    concat(concat(trait_stubs, stubs), decls),
    lenient=true,
    skipped=import_skipped,
  ) catch {
    ElabError(p, msg) =>
      raise CheckError("<import>:" + p.to_string() + ": error: " + msg)
  }
}

///|
/// Pretty-print the type of a global.
pub fn show_global_type(name : String) -> String? {
  match globals.get(name) {
    Some(g) => Some(show_tm([], g.ty))
    None => None
  }
}

///|
/// Body of a global function, if it has one.
pub fn global_body(name : String) -> Tm? {
  match globals.get(name) {
    Some({ kind: GFunc(b, _, _), .. }) => b
    _ => None
  }
}

///|
/// Normal form of a closed term, for tests.
pub fn normalize(t : Tm) -> String {
  show_tm([], nf([], t))
}
