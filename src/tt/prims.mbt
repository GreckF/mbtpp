///|
/// Pure primitives on literals, shared by the type checker and the
/// interpreter. Returns `None` for unknown or impure primitives and for
/// invalid arguments (e.g. division by zero).
pub fn prim_pure(name : String, args : Array[Lit]) -> Lit? {
  match (name, args) {
    ("%int_add", [LInt(a), LInt(b)]) => Some(LInt(a + b))
    ("%int_sub", [LInt(a), LInt(b)]) => Some(LInt(a - b))
    ("%int_mul", [LInt(a), LInt(b)]) => Some(LInt(a * b))
    ("%int_div", [LInt(a), LInt(b)]) =>
      if b == 0 {
        None
      } else {
        Some(LInt(a / b))
      }
    ("%int_mod", [LInt(a), LInt(b)]) =>
      if b == 0 {
        None
      } else {
        Some(LInt(a % b))
      }
    ("%int_neg", [LInt(a)]) => Some(LInt(-a))
    ("%int_eq", [LInt(a), LInt(b)]) => Some(LBool(a == b))
    ("%int_lt", [LInt(a), LInt(b)]) => Some(LBool(a < b))
    ("%int_le", [LInt(a), LInt(b)]) => Some(LBool(a <= b))
    ("%int_gt", [LInt(a), LInt(b)]) => Some(LBool(a > b))
    ("%int_ge", [LInt(a), LInt(b)]) => Some(LBool(a >= b))
    ("%int_compare", [LInt(a), LInt(b)]) => Some(LInt(a.compare(b)))
    ("%int_to_string", [LInt(a)]) => Some(LStr(a.to_string()))
    ("%int_to_char", [LInt(a)]) =>
      match a.to_char() {
        Some(c) => Some(LChar(c))
        None => None
      }
    ("%str_add", [LStr(a), LStr(b)]) => Some(LStr(a + b))
    ("%str_eq", [LStr(a), LStr(b)]) => Some(LBool(a == b))
    ("%str_compare", [LStr(a), LStr(b)]) => Some(LInt(a.compare(b)))
    ("%str_length", [LStr(a)]) => Some(LInt(a.length()))
    ("%str_get", [LStr(a), LInt(i)]) =>
      match a.get_char(i) {
        Some(c) => Some(LChar(c))
        None => None
      }
    ("%str_substring", [LStr(a), LInt(i), LInt(j)]) =>
      if i >= 0 && i <= j && j <= a.length() {
        Some(LStr(a.unsafe_substring(start=i, end=j)))
      } else {
        None
      }
    ("%bool_eq", [LBool(a), LBool(b)]) => Some(LBool(a == b))
    ("%bool_not", [LBool(a)]) => Some(LBool(!a))
    ("%bool_to_string", [LBool(a)]) => Some(LStr(a.to_string()))
    ("%char_eq", [LChar(a), LChar(b)]) => Some(LBool(a == b))
    ("%char_compare", [LChar(a), LChar(b)]) => Some(LInt(a.compare(b)))
    ("%char_to_int", [LChar(a)]) => Some(LInt(a.to_int()))
    ("%char_to_string", [LChar(a)]) => Some(LStr(a.to_string()))
    ("%unit_to_string", [LUnit]) => Some(LStr("()"))
    _ => None
  }
}
