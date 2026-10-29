///|
/// Core terms and semantic values.
pub(all) enum Icit {
  Expl
  Impl
  /// An instance argument, filled in by instance search.
  Inst
} derive(Eq, Show)

///|
pub type Lit = @parser.Lit

///|
pub type Pos = @parser.Pos

///|
/// Core patterns. Every node of a pattern occupies one variable slot (the
/// value it matches); a constructor pattern is followed by the slots of its
/// arguments (the constructor's own arguments, without the datatype
/// parameters).
pub(all) enum CPat {
  CPVar(String)
  CPWild
  CPCon(String, Array[CPat])
  CPLit(Lit)
} derive(Show)

///|
pub(all) struct Clause {
  pats : Array[CPat]
  body : Tm
} derive(Show)

///|
pub(all) enum Tm {
  Var(Int)
  Global(String)
  Meta(Int)
  InsertedMeta(Int, Array[Bool])
  /// Name, icitness, whether this explicit binder starts a new argument group.
  Lam(String, Icit, Bool, Tm)
  App(Tm, Tm, Icit)
  Pi(String, Icit, Bool, Tm, Tm)
  Let(String, Tm, Tm, Tm)
  U
  PropU
  Lit(Lit)
  Match(Array[Tm], Array[Clause])
  /// `T raise E` in the codomain of a function type.
  Raises(Tm, Tm)
  LetMut(String, Tm, Tm, Tm)
  Assign(Int, Tm)
  /// Condition, body, step (run after the body and on `continue`).
  While(Tm, Tm, Tm)
  Break
  Continue
  Return(Tm)
  Raise(Tm)
  Try(Tm, Array[Clause])
  ArrayLit(Array[Tm])
  Seq(Tm, Tm)
} derive(Show)

///|
pub type Env = Array[Val]

///|
pub type Spine = Array[(Val, Icit)]

///|
pub(all) struct Closure {
  env : Env
  body : Tm
}

///|
pub(all) enum Val {
  VRigid(Int, Spine)
  VFlex(Int, Spine)
  /// A function application that is kept folded (see `force`).
  VGlobal(String, Spine)
  VData(String, Spine)
  VCon(String, Spine)
  VPrim(String, Spine)
  VLam(String, Icit, Bool, Closure)
  VPi(String, Icit, Bool, Val, Closure)
  VU
  VProp
  VLit(Lit)
  VRaises(Val, Val)
  /// A match blocked on its scrutinees, applied to a spine.
  VMatch(Env, Array[Val], Array[Clause], Spine)
  /// An imperative construct; never reduces during type checking.
  VStuck(Env, Tm, Spine)
  /// An array literal (arrays are mutable, so nothing reduces on it).
  VArrLit(Array[Val])
}

///|
pub fn v_var(l : Int) -> Val {
  VRigid(l, [])
}

///|
pub fn env_push(env : Env, v : Val) -> Env {
  let e = env.copy()
  e.push(v)
  e
}

///|
/// Number of variable slots bound by a pattern.
pub fn pat_slots(p : CPat) -> Int {
  match p {
    CPCon(_, ps) => {
      let mut n = 1
      for q in ps {
        n = n + pat_slots(q)
      }
      n
    }
    _ => 1
  }
}

///|
pub fn pats_slots(ps : Array[CPat]) -> Int {
  let mut n = 0
  for p in ps {
    n = n + pat_slots(p)
  }
  n
}

///|
pub fn apps(t : Tm, args : Array[(Tm, Icit)]) -> Tm {
  let mut r = t
  for a in args {
    r = App(r, a.0, a.1)
  }
  r
}

// ---------------------------------------------------------------------------
// Global definitions

///|
pub(all) struct DataInfo {
  name : String
  /// Number of parameter binders (all leading binders of the type that are
  /// not indices).
  nparams : Int
  nindices : Int
  cons : Array[String]
  mut is_prop : Bool
  /// Field names, for structs and traits.
  fields : Array[String]?
  is_trait : Bool
  is_error : Bool
  /// Built-in types (`Int`, `Array`, ...) have no constructors but are not
  /// empty.
  builtin : Bool
}

///|
pub(all) struct ConInfo {
  name : String
  data : String
  nparams : Int
  /// Own arguments (implicit and explicit).
  nargs : Int
  nimpl : Int
}

///|
pub(all) enum GKind {
  /// Body (None while it is being elaborated), opaque, number of leading
  /// lambdas.
  GFunc(Tm?, Bool, Int)
  GData(DataInfo)
  GCon(ConInfo)
  /// Primitive name, number of arguments.
  GPrim(String, Int)
}

///|
pub(all) struct GEntry {
  name : String
  ty : Tm
  vty : Val
  mut kind : GKind
}

///|
pub let globals : Map[String, GEntry] = {}

///|
pub fn lookup_global(name : String) -> GEntry? {
  globals.get(name)
}

///|
pub fn data_info(name : String) -> DataInfo? {
  match globals.get(name) {
    Some({ kind: GData(d), .. }) => Some(d)
    _ => None
  }
}

///|
pub fn con_info(name : String) -> ConInfo? {
  match globals.get(name) {
    Some({ kind: GCon(c), .. }) => Some(c)
    _ => None
  }
}

// ---------------------------------------------------------------------------
// Metavariables

///|
pub(all) struct MetaEntry {
  mut sol : Val?
}

///|
pub let metas : Array[MetaEntry] = []

///|
pub fn new_meta() -> Int {
  metas.push({ sol: None })
  metas.length() - 1
}

///|
pub fn meta_sol(m : Int) -> Val? {
  metas[m].sol
}

///|
pub fn snapshot_metas() -> Array[Val?] {
  metas.map(e => e.sol)
}

///|
pub fn restore_metas(s : Array[Val?]) -> Unit {
  for i = 0; i < metas.length(); i = i + 1 {
    metas[i].sol = if i < s.length() { s[i] } else { None }
  }
}

///|
pub fn reset_state() -> Unit {
  globals.clear()
  mbt_types.clear()
  mbt_fns.clear()
  metas.clear()
}

///|
pub fn[T] concat(a : Array[T], b : Array[T]) -> Array[T] {
  let r = a.copy()
  for x in b {
    r.push(x)
  }
  r
}
