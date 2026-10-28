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
  for n in ["Int", "String", "Char", "Bool", "Unit"] {
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
/// Type check a program (after the prelude).
pub fn check_program(
  file : String,
  src : String,
  prelude? : Bool = true,
) -> Unit raise CheckError {
  setup()
  if prelude {
    check_src("<prelude>", prelude_src)
  }
  check_src(file, src)
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
