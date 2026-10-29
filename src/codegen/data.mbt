///|
/// Native data. The uniform representation `Value` is generated for each
/// program: besides the fixed variants of the runtime (`VInt`, `VFun`, ...)
/// it has one variant per constructor used, with one `Value` field per
/// field that is not erased: `Exp::Add` of `Exp : [T] -> Type` becomes
/// `K_Exp_Add(Value, Value)`, its index gone. Constructing and matching are
/// native MoonBit; the runtime inspects constructors generically through
/// `con_name` and `con_fields`.

///|
/// The variant of constructor `c` (registered on first use), and its arity.
fn Gen::ctor(self : Gen, c : String) -> (String, Int32) {
  match self.ctors.get(c) {
    Some(x) => return x
    None => ()
  }
  let buf = StringBuilder::new()
  buf.write_string("K_")
  let mut prev_us = true
  for ch in c {
    if is_ident_char(ch) && ch != '_' {
      buf.write_char(ch)
      prev_us = false
    } else if !prev_us {
      buf.write_char('_')
      prev_us = true
    }
  }
  let mut id = buf.to_string()
  while id.has_suffix("_") {
    id = id.unsafe_substring(start=0, end=id.length() - 1)
  }
  // distinct names for distinct constructors
  let base = id
  let mut k = 1
  while self.ctors.values().any(x => x.0 == id) {
    k = k + 1
    id = base + "_" + k.to_string()
  }
  let arity = match @tt.con_info(c) {
    Some(ci) => {
      let mut n = 0
      for j = 0; j < ci.nargs; j = j + 1 {
        if !self.er.con_erased(c, j) {
          n = n + 1
        }
      }
      n
    }
    None => 0
  }
  self.ctors.set(c, (id, arity))
  self.ctor_order.push(c)
  (id, arity)
}

///|
/// A value (or pattern) of constructor `c` with its kept fields.
fn Gen::con_code(self : Gen, c : String, args : Array[String]) -> String {
  let (id, _) = self.ctor(c)
  if args.length() == 0 {
    id
  } else {
    id + "(" + args.join(", ") + ")"
  }
}

///|
/// The `Value` enum of the program, and the generic access to its
/// constructors.
fn Gen::value_decl(self : Gen) -> String {
  let decl = StringBuilder::new()
  let names = StringBuilder::new()
  let fields = StringBuilder::new()
  decl.write_string(
    (
      #|// ---- values -----------------------------------------------------------
      #|
      #|enum Value {
      #|  VInt(Int)
      #|  VDouble(Double)
      #|  VStr(String)
      #|  VChar(Char)
      #|  VBool(Bool)
      #|  VUnit
      #|  VFun((Value) -> Value raise)
      #|  VArr(Array[Value])
      #|  VType
      #|  VForeign(Foreign)
      #|  /// A constructor that is not of the program (e.g. a MoonBit error).
      #|  VDyn(String, Array[Value])
      #|
    ),
  )
  names.write_string(
    "\n///|\n/// The constructor of a value, if it is one.\nfn con_name(v : Value) -> String? {\n  match v {\n    VDyn(c, _) => Some(c)\n",
  )
  fields.write_string(
    "\n///|\n/// The fields of a constructor value.\nfn con_fields(v : Value) -> Array[Value] {\n  match v {\n    VDyn(_, xs) => xs\n",
  )
  for c in self.ctor_order {
    let (id, n) = self.ctors.get(c).unwrap()
    let xs : Array[String] = []
    for k = 0; k < n; k = k + 1 {
      xs.push("a" + k.to_string())
    }
    decl.write_string(
      "  /// " +
      c +
      "\n  " +
      id +
      (if n == 0 { "" } else { "(" + xs.map(_ => "Value").join(", ") + ")" }) +
      "\n",
    )
    let pat = if n == 0 { id } else { id + "(" + xs.join(", ") + ")" }
    names.write_string("    " + pat + " => Some(" + c.escape() + ")\n")
    if n > 0 {
      fields.write_string("    " + pat + " => [" + xs.join(", ") + "]\n")
    }
  }
  decl.write_string("}\n")
  names.write_string("    _ => None\n  }\n}\n")
  fields.write_string("    _ => []\n  }\n}\n")
  decl.to_string() + names.to_string() + fields.to_string() + "\n"
}
