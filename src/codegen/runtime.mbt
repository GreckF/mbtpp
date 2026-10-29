///|
/// The runtime support of compiled MoonBit++ programs, emitted at the top of
/// every generated `main.mbt`. Values are represented uniformly by `Value`
/// (like the interpreter's `RVal`).
let runtime_src : String =
  #|// ---- MoonBit++ runtime -------------------------------------------------
  #|
  #|/// Values. Each generated file adds the constructors of its datatypes
  #|/// (`extenum Value += { K_Exp_Add(Value, Value) }`) and registers a
  #|/// decoder for them in `con_decoders`.
  #|extenum Value {
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
  #|}
  #|
  #|/// Values of foreign MoonBit types (extended by mbtpp_imports.mbt).
  #|extenum Foreign {
  #|  FNone
  #|}
  #|
  #|/// The name and fields of a constructor value, by generated file.
  #|let con_decoders : Array[(Value) -> (String, Array[Value])?] = []
  #|
  #|fn con_decode(v : Value) -> (String, Array[Value])? {
  #|  match v {
  #|    VDyn(c, xs) => return Some((c, xs))
  #|    _ => ()
  #|  }
  #|  for d in con_decoders {
  #|    match d(v) {
  #|      Some(x) => return Some(x)
  #|      None => ()
  #|    }
  #|  }
  #|  None
  #|}
  #|
  #|/// The constructor of a value, if it is one.
  #|fn con_name(v : Value) -> String? {
  #|  con_decode(v).map(x => x.0)
  #|}
  #|
  #|/// The fields of a constructor value.
  #|fn con_fields(v : Value) -> Array[Value] {
  #|  match con_decode(v) {
  #|    Some((_, xs)) => xs
  #|    None => []
  #|  }
  #|}
  #|
  #|suberror Ctl {
  #|  CRaise(Value)
  #|  CReturn(Value)
  #|  CBreak
  #|  CContinue
  #|  CAbort(String)
  #|}
  #|
  #|enum Pat {
  #|  PAny
  #|  PCon(String, Array[Pat])
  #|  PLit(Value)
  #|}
  #|
  #|fn[T] rt_fail(msg : String) -> T raise {
  #|  raise CAbort(msg)
  #|}
  #|
  #|fn rt_break() -> Value raise {
  #|  raise CBreak
  #|}
  #|
  #|fn rt_continue() -> Value raise {
  #|  raise CContinue
  #|}
  #|
  #|fn rt_return(v : Value) -> Value raise {
  #|  raise CReturn(v)
  #|}
  #|
  #|fn rt_raise(v : Value) -> Value raise {
  #|  raise CRaise(v)
  #|}
  #|
  #|fn int_div(a : Int, b : Int) -> Int raise {
  #|  if b == 0 {
  #|    rt_fail("division by zero")
  #|  } else {
  #|    a / b
  #|  }
  #|}
  #|
  #|fn int_mod(a : Int, b : Int) -> Int raise {
  #|  if b == 0 {
  #|    rt_fail("division by zero")
  #|  } else {
  #|    a % b
  #|  }
  #|}
  #|
  #|fn apply(f : Value, a : Value) -> Value raise {
  #|  match f {
  #|    VFun(g) => g(a)
  #|    VType => VType
  #|    _ => rt_fail("cannot apply " + show_value(f))
  #|  }
  #|}
  #|
  #|fn truthy(v : Value) -> Bool raise {
  #|  match v {
  #|    VBool(b) => b
  #|    _ => rt_fail("expected a boolean")
  #|  }
  #|}
  #|
  #|fn value_eq(a : Value, b : Value) -> Bool {
  #|  match (a, b) {
  #|    (VInt(x), VInt(y)) => x == y
  #|    (VDouble(x), VDouble(y)) => x == y
  #|    (VStr(x), VStr(y)) => x == y
  #|    (VChar(x), VChar(y)) => x == y
  #|    (VBool(x), VBool(y)) => x == y
  #|    (VUnit, VUnit) => true
  #|    (VArr(xs), VArr(ys)) => {
  #|      if xs.length() != ys.length() {
  #|        return false
  #|      }
  #|      for k = 0; k < xs.length(); k = k + 1 {
  #|        if !value_eq(xs[k], ys[k]) {
  #|          return false
  #|        }
  #|      }
  #|      true
  #|    }
  #|    _ =>
  #|      match (con_name(a), con_name(b)) {
  #|        (Some(c), Some(d)) if c == d => {
  #|          let xs = con_fields(a)
  #|          let ys = con_fields(b)
  #|          if xs.length() != ys.length() {
  #|            return false
  #|          }
  #|          for k = 0; k < xs.length(); k = k + 1 {
  #|            if !value_eq(xs[k], ys[k]) {
  #|              return false
  #|            }
  #|          }
  #|          true
  #|        }
  #|        _ => false
  #|      }
  #|  }
  #|}
  #|
  #|fn match_pat(p : Pat, v : Value, out : Array[Value]) -> Bool {
  #|  out.push(v)
  #|  match p {
  #|    PAny => true
  #|    PCon(c, ps) =>
  #|      match con_name(v) {
  #|        Some(c2) if c2 == c && con_fields(v).length() == ps.length() => {
  #|          let args = con_fields(v)
  #|          for k = 0; k < ps.length(); k = k + 1 {
  #|            if !match_pat(ps[k], args[k], out) {
  #|              return false
  #|            }
  #|          }
  #|          true
  #|        }
  #|        _ => false
  #|      }
  #|    PLit(l) => value_eq(l, v)
  #|  }
  #|}
  #|
  #|fn match_pats(ps : Array[Pat], vs : Array[Value], out : Array[Value]) -> Bool {
  #|  out.clear()
  #|  for k = 0; k < ps.length(); k = k + 1 {
  #|    if !match_pat(ps[k], vs[k], out) {
  #|      return false
  #|    }
  #|  }
  #|  true
  #|}
  #|
  #|fn short_name(c : String) -> String {
  #|  match c.rev_find("::") {
  #|    Some(i) => c.unsafe_substring(start=i + 2, end=c.length())
  #|    None => c
  #|  }
  #|}
  #|
  #|fn value_id(v : Value) -> Value {
  #|  v
  #|}
  #|
  #|fn value_id_raise(v : Value) -> Value raise {
  #|  v
  #|}
  #|
  #|fn show_value(v : Value) -> String {
  #|  match v {
  #|    VInt(n) => n.to_string()
  #|    VDouble(d) => d.to_string()
  #|    VStr(s) => s.escape()
  #|    VChar(c) => c.to_string().escape()
  #|    VBool(b) => b.to_string()
  #|    VUnit => "()"
  #|    VArr(xs) => "[" + xs.map(show_value).join(", ") + "]"
  #|    VFun(_) => "<function>"
  #|    VType => "<type>"
  #|    VForeign(_) => "<foreign>"
  #|    _ =>
  #|      match (con_name(v), con_fields(v)) {
  #|        (Some(c), []) => short_name(c)
  #|        (Some(c), args) =>
  #|          short_name(c) + "(" + args.map(show_value).join(", ") + ")"
  #|        (None, _) => "<value>"
  #|      }
  #|  }
  #|}
  #|
  #|impl Show for Value with output(self, logger) {
  #|  logger.write_string(show_value(self))
  #|}
  #|
  #|impl Eq for Value with equal(self, other) {
  #|  value_eq(self, other)
  #|}
  #|
  #|impl Compare for Value with compare(self, other) {
  #|  match (self, other) {
  #|    (VInt(x), VInt(y)) => x.compare(y)
  #|    (VDouble(x), VDouble(y)) => x.compare(y)
  #|    (VStr(x), VStr(y)) => x.compare(y)
  #|    (VChar(x), VChar(y)) => x.compare(y)
  #|    (VBool(x), VBool(y)) => x.compare(y)
  #|    _ => show_value(self).compare(show_value(other))
  #|  }
  #|}
  #|
  #|impl Hash for Value with hash_combine(self, hasher) {
  #|  hasher.combine_string(show_value(self))
  #|}
  #|
  #|let out_buf : StringBuilder = StringBuilder::new()
  #|
  #|fn rt_write(s : String) -> Unit {
  #|  for c in s {
  #|    if c == '\n' {
  #|      println(out_buf.to_string())
  #|      out_buf.reset()
  #|    } else {
  #|      out_buf.write_char(c)
  #|    }
  #|  }
  #|}
  #|
  #|fn rt_flush() -> Unit {
  #|  if out_buf.to_string() != "" {
  #|    println(out_buf.to_string())
  #|    out_buf.reset()
  #|  }
  #|}
  #|
  #|fn as_int(v : Value) -> Int raise {
  #|  match v {
  #|    VInt(n) => n
  #|    _ => rt_fail("expected an Int, got " + show_value(v))
  #|  }
  #|}
  #|
  #|fn as_double(v : Value) -> Double raise {
  #|  match v {
  #|    VDouble(d) => d
  #|    _ => rt_fail("expected a Double, got " + show_value(v))
  #|  }
  #|}
  #|
  #|fn as_str(v : Value) -> String raise {
  #|  match v {
  #|    VStr(s) => s
  #|    _ => rt_fail("expected a String, got " + show_value(v))
  #|  }
  #|}
  #|
  #|fn as_char(v : Value) -> Char raise {
  #|  match v {
  #|    VChar(c) => c
  #|    _ => rt_fail("expected a Char, got " + show_value(v))
  #|  }
  #|}
  #|
  #|fn as_bool(v : Value) -> Bool raise {
  #|  match v {
  #|    VBool(b) => b
  #|    _ => rt_fail("expected a Bool, got " + show_value(v))
  #|  }
  #|}
  #|
  #|fn as_arr(v : Value) -> Array[Value] raise {
  #|  match v {
  #|    VArr(xs) => xs
  #|    _ => rt_fail("expected an Array, got " + show_value(v))
  #|  }
  #|}
  #|
  #|fn as_unit(v : Value) -> Unit raise {
  #|  match v {
  #|    VUnit => ()
  #|    _ => rt_fail("expected (), got " + show_value(v))
  #|  }
  #|}
  #|
  #|fn prim(name : String, args : Array[Value]) -> Value raise {
  #|  match (name, args) {
  #|    ("%int_add", [VInt(a), VInt(b)]) => VInt(a + b)
  #|    ("%int_sub", [VInt(a), VInt(b)]) => VInt(a - b)
  #|    ("%int_mul", [VInt(a), VInt(b)]) => VInt(a * b)
  #|    ("%int_land", [VInt(a), VInt(b)]) => VInt(a & b)
  #|    ("%int_lor", [VInt(a), VInt(b)]) => VInt(a | b)
  #|    ("%int_lxor", [VInt(a), VInt(b)]) => VInt(a ^ b)
  #|    ("%int_shl", [VInt(a), VInt(b)]) => VInt(a << b)
  #|    ("%int_shr", [VInt(a), VInt(b)]) => VInt(a >> b)
  #|    ("%int_div", [VInt(_), VInt(0)]) | ("%int_mod", [VInt(_), VInt(0)]) =>
  #|      rt_fail("division by zero")
  #|    ("%int_div", [VInt(a), VInt(b)]) => VInt(a / b)
  #|    ("%int_mod", [VInt(a), VInt(b)]) => VInt(a % b)
  #|    ("%int_neg", [VInt(a)]) => VInt(-a)
  #|    ("%int_eq", [VInt(a), VInt(b)]) => VBool(a == b)
  #|    ("%int_lt", [VInt(a), VInt(b)]) => VBool(a < b)
  #|    ("%int_le", [VInt(a), VInt(b)]) => VBool(a <= b)
  #|    ("%int_gt", [VInt(a), VInt(b)]) => VBool(a > b)
  #|    ("%int_ge", [VInt(a), VInt(b)]) => VBool(a >= b)
  #|    ("%int_compare", [VInt(a), VInt(b)]) => VInt(a.compare(b))
  #|    ("%int_to_string", [VInt(a)]) => VStr(a.to_string())
  #|    ("%int_to_char", [VInt(a)]) =>
  #|      match a.to_char() {
  #|        Some(c) => VChar(c)
  #|        None => rt_fail("invalid character code")
  #|      }
  #|    ("%int_to_double", [VInt(a)]) => VDouble(a.to_double())
  #|    ("%str_add", [VStr(a), VStr(b)]) => VStr(a + b)
  #|    ("%str_eq", [VStr(a), VStr(b)]) => VBool(a == b)
  #|    ("%str_compare", [VStr(a), VStr(b)]) => VInt(a.compare(b))
  #|    ("%str_length", [VStr(a)]) => VInt(a.length())
  #|    ("%str_get", [VStr(a), VInt(i)]) =>
  #|      match a.get_char(i) {
  #|        Some(c) => VChar(c)
  #|        None => rt_fail("index out of bounds")
  #|      }
  #|    ("%str_substring", [VStr(a), VInt(i), VInt(j)]) =>
  #|      if i >= 0 && i <= j && j <= a.length() {
  #|        VStr(a.unsafe_substring(start=i, end=j))
  #|      } else {
  #|        rt_fail("index out of bounds")
  #|      }
  #|    ("%bool_eq", [VBool(a), VBool(b)]) => VBool(a == b)
  #|    ("%bool_not", [VBool(a)]) => VBool(!a)
  #|    ("%bool_to_string", [VBool(a)]) => VStr(a.to_string())
  #|    ("%char_eq", [VChar(a), VChar(b)]) => VBool(a == b)
  #|    ("%char_compare", [VChar(a), VChar(b)]) => VInt(a.compare(b))
  #|    ("%char_to_int", [VChar(a)]) => VInt(a.to_int())
  #|    ("%char_to_string", [VChar(a)]) => VStr(a.to_string())
  #|    ("%unit_to_string", [VUnit]) => VStr("()")
  #|    ("%double_add", [VDouble(a), VDouble(b)]) => VDouble(a + b)
  #|    ("%double_sub", [VDouble(a), VDouble(b)]) => VDouble(a - b)
  #|    ("%double_mul", [VDouble(a), VDouble(b)]) => VDouble(a * b)
  #|    ("%double_div", [VDouble(a), VDouble(b)]) => VDouble(a / b)
  #|    ("%double_neg", [VDouble(a)]) => VDouble(-a)
  #|    ("%double_eq", [VDouble(a), VDouble(b)]) => VBool(a == b)
  #|    ("%double_lt", [VDouble(a), VDouble(b)]) => VBool(a < b)
  #|    ("%double_le", [VDouble(a), VDouble(b)]) => VBool(a <= b)
  #|    ("%double_gt", [VDouble(a), VDouble(b)]) => VBool(a > b)
  #|    ("%double_ge", [VDouble(a), VDouble(b)]) => VBool(a >= b)
  #|    ("%double_compare", [VDouble(a), VDouble(b)]) => VInt(a.compare(b))
  #|    ("%double_to_string", [VDouble(a)]) => VStr(a.to_string())
  #|    ("%double_to_int", [VDouble(a)]) => VInt(a.to_int())
  #|    ("%print", [VStr(s)]) => {
  #|      rt_write(s)
  #|      VUnit
  #|    }
  #|    ("%panic", _) => rt_fail("panic")
  #|    ("%abort", [VStr(s)]) => rt_fail(s)
  #|    ("%error_to_string", [e]) => VStr(show_value(e))
  #|    ("%array_make", [VInt(n), x]) => VArr(Array::make(n, x))
  #|    ("%array_new", _) => VArr([])
  #|    ("%array_length", [VArr(xs)]) => VInt(xs.length())
  #|    ("%array_get", [VArr(xs), VInt(i)]) =>
  #|      if i >= 0 && i < xs.length() {
  #|        xs[i]
  #|      } else {
  #|        rt_fail("index out of bounds: " + i.to_string())
  #|      }
  #|    ("%array_set", [VArr(xs), VInt(i), x]) =>
  #|      if i >= 0 && i < xs.length() {
  #|        xs[i] = x
  #|        VUnit
  #|      } else {
  #|        rt_fail("index out of bounds: " + i.to_string())
  #|      }
  #|    ("%array_push", [VArr(xs), x]) => {
  #|      xs.push(x)
  #|      VUnit
  #|    }
  #|    _ => rt_fail("primitive " + name + " failed")
  #|  }
  #|}
  #|
  #|/// A foreign MoonBit error, as a MoonBit++ value.
  #|fn foreign_error(e : Error) -> Value {
  #|  VDyn("MoonBitError", [VStr(e.to_string())])
  #|}
  #|
  #|fn run_main(f : () -> Value raise) -> Unit {
  #|  try {
  #|    ignore(f())
  #|  } catch {
  #|    e => report_error(e)
  #|  }
  #|  rt_flush()
  #|}
  #|
  #|/// Report an error that escaped `main`.
  #|fn report_error(e : Error) -> Unit {
  #|  match e {
  #|    CReturn(_) => ()
  #|    CRaise(e) => {
  #|      rt_flush()
  #|      println("uncaught error: " + show_value(e))
  #|    }
  #|    CAbort(m) => {
  #|      rt_flush()
  #|      println("runtime error: " + m)
  #|    }
  #|    e => {
  #|      rt_flush()
  #|      println("runtime error: " + e.to_string())
  #|    }
  #|  }
  #|  rt_flush()
  #|}
  #|
