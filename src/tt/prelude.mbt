///|
/// The MoonBit++ prelude. `Int`, `String`, `Char`, `Bool`, `Unit`,
/// `Array` and `Error` are built in.
pub let prelude_src : String =
  #|enum Nat {
  #|  Z
  #|  S(Nat)
  #|}
  #|
  #|enum Id[T](x : T) : (y : T) -> Prop {
  #|  Refl : Id[T](x)(x)
  #|}
  #|
  #|#mbt("Option")
  #|enum Option[T] {
  #|  None
  #|  Some(T)
  #|}
  #|
  #|#mbt("Result")
  #|enum Result[T, E] {
  #|  Ok(T)
  #|  Err(E)
  #|}
  #|
  #|enum List[T] {
  #|  Nil
  #|  Cons(T, List[T])
  #|}
  #|
  #|struct Tuple2[A, B] {
  #|  _0 : A
  #|  _1 : B
  #|}
  #|
  #|struct Tuple3[A, B, C] {
  #|  _0 : A
  #|  _1 : B
  #|  _2 : C
  #|}
  #|
  #|suberror Failure {
  #|  Failure(String)
  #|}
  #|
  #|// ---- primitives -------------------------------------------------------
  #|
  #|fn Int::op_add(self : Int, other : Int) -> Int = "%int_add"
  #|fn Int::op_sub(self : Int, other : Int) -> Int = "%int_sub"
  #|fn Int::op_mul(self : Int, other : Int) -> Int = "%int_mul"
  #|fn Int::op_div(self : Int, other : Int) -> Int = "%int_div"
  #|fn Int::op_mod(self : Int, other : Int) -> Int = "%int_mod"
  #|fn Int::op_neg(self : Int) -> Int = "%int_neg"
  #|fn Int::op_land(self : Int, other : Int) -> Int = "%int_land"
  #|fn Int::op_lor(self : Int, other : Int) -> Int = "%int_lor"
  #|fn Int::op_lxor(self : Int, other : Int) -> Int = "%int_lxor"
  #|fn Int::op_shl(self : Int, n : Int) -> Int = "%int_shl"
  #|fn Int::op_shr(self : Int, n : Int) -> Int = "%int_shr"
  #|fn Int::op_equal(self : Int, other : Int) -> Bool = "%int_eq"
  #|fn Int::op_lt(self : Int, other : Int) -> Bool = "%int_lt"
  #|fn Int::op_le(self : Int, other : Int) -> Bool = "%int_le"
  #|fn Int::op_gt(self : Int, other : Int) -> Bool = "%int_gt"
  #|fn Int::op_ge(self : Int, other : Int) -> Bool = "%int_ge"
  #|fn Int::compare(self : Int, other : Int) -> Int = "%int_compare"
  #|fn Int::to_string(self : Int) -> String = "%int_to_string"
  #|fn Int::unsafe_to_char(self : Int) -> Char = "%int_to_char"
  #|fn Int::to_double(self : Int) -> Double = "%int_to_double"
  #|
  #|fn Double::op_add(self : Double, other : Double) -> Double = "%double_add"
  #|fn Double::op_sub(self : Double, other : Double) -> Double = "%double_sub"
  #|fn Double::op_mul(self : Double, other : Double) -> Double = "%double_mul"
  #|fn Double::op_div(self : Double, other : Double) -> Double = "%double_div"
  #|fn Double::op_neg(self : Double) -> Double = "%double_neg"
  #|fn Double::op_equal(self : Double, other : Double) -> Bool = "%double_eq"
  #|fn Double::op_lt(self : Double, other : Double) -> Bool = "%double_lt"
  #|fn Double::op_le(self : Double, other : Double) -> Bool = "%double_le"
  #|fn Double::op_gt(self : Double, other : Double) -> Bool = "%double_gt"
  #|fn Double::op_ge(self : Double, other : Double) -> Bool = "%double_ge"
  #|fn Double::compare(self : Double, other : Double) -> Int = "%double_compare"
  #|fn Double::to_string(self : Double) -> String = "%double_to_string"
  #|fn Double::to_int(self : Double) -> Int = "%double_to_int"
  #|
  #|fn String::op_add(self : String, other : String) -> String = "%str_add"
  #|fn String::op_equal(self : String, other : String) -> Bool = "%str_eq"
  #|fn String::compare(self : String, other : String) -> Int = "%str_compare"
  #|fn String::length(self : String) -> Int = "%str_length"
  #|fn String::op_get(self : String, i : Int) -> Char = "%str_get"
  #|fn String::substring(self : String, start : Int, end : Int) -> String = "%str_substring"
  #|fn String::slice(self : String, start : Int, end : Int) -> String { self.substring(start, end) }
  #|fn String::to_string(self : String) -> String { self }
  #|
  #|fn Bool::op_equal(self : Bool, other : Bool) -> Bool = "%bool_eq"
  #|fn Bool::not(self : Bool) -> Bool = "%bool_not"
  #|fn Bool::to_string(self : Bool) -> String = "%bool_to_string"
  #|fn not(b : Bool) -> Bool = "%bool_not"
  #|
  #|fn Char::op_equal(self : Char, other : Char) -> Bool = "%char_eq"
  #|fn Char::compare(self : Char, other : Char) -> Int = "%char_compare"
  #|fn Char::to_int(self : Char) -> Int = "%char_to_int"
  #|fn Char::to_string(self : Char) -> String = "%char_to_string"
  #|
  #|fn Unit::to_string(self : Unit) -> String = "%unit_to_string"
  #|
  #|fn[T] Array::make(n : Int, x : T) -> Array[T] = "%array_make"
  #|fn[T] Array::new() -> Array[T] = "%array_new"
  #|fn[T] Array::length(self : Array[T]) -> Int = "%array_length"
  #|fn[T] Array::op_get(self : Array[T], i : Int) -> T = "%array_get"
  #|fn[T] Array::op_set(self : Array[T], i : Int, x : T) -> Unit = "%array_set"
  #|fn[T] Array::push(self : Array[T], x : T) -> Unit = "%array_push"
  #|
  #|// the elements from `start` to `end` (excluded), e.g. for `[x, ..rest]`
  #|fn[T] Array::slice(self : Array[T], start : Int, end : Int) -> Array[T] {
  #|  let out : Array[T] = Array::new()
  #|  for i = start; i < end; i = i + 1 {
  #|    out.push(self[i])
  #|  }
  #|  out
  #|}
  #|
  #|fn print_string(s : String) -> Unit = "%print"
  #|fn[T] panic() -> T = "%panic"
  #|fn[T] abort(msg : String) -> T = "%abort"
  #|
  #|// ---- Nat --------------------------------------------------------------
  #|
  #|fn int_to_nat(n : Int) -> Nat {
  #|  if n <= 0 { Z } else { S(int_to_nat(n - 1)) }
  #|}
  #|
  #|fn Nat::to_int(self : Nat) -> Int {
  #|  match self {
  #|    Z => 0
  #|    S(n) => n.to_int() + 1
  #|  }
  #|}
  #|
  #|fn Nat::op_add(self : Nat, other : Nat) -> Nat {
  #|  match self {
  #|    Z => other
  #|    S(n) => S(n + other)
  #|  }
  #|}
  #|
  #|fn Nat::op_mul(self : Nat, other : Nat) -> Nat {
  #|  match self {
  #|    Z => Z
  #|    S(n) => other + n * other
  #|  }
  #|}
  #|
  #|fn Nat::op_equal(self : Nat, other : Nat) -> Bool {
  #|  match (self, other) {
  #|    (Z, Z) => true
  #|    (S(a), S(b)) => a == b
  #|    _ => false
  #|  }
  #|}
  #|
  #|fn Nat::to_string(self : Nat) -> String {
  #|  self.to_int().to_string()
  #|}
  #|
  #|fn plus(n : Nat, m : Nat) -> Nat {
  #|  n + m
  #|}
  #|
  #|fn[T] Array::size(self : Array[T]) -> Nat {
  #|  int_to_nat(self.length())
  #|}
  #|
  #|// ---- propositional equality -----------------------------------------
  #|
  #|fn[T, x : T, y : T] Id::sym(p : x === y) -> y === x {
  #|  match p {
  #|    Refl => Refl
  #|  }
  #|}
  #|
  #|fn[T, x : T, y : T, z : T] Id::trans(p : x === y, q : y === z) -> x === z {
  #|  match q {
  #|    Refl => p
  #|  }
  #|}
  #|
  #|fn[T, U, x : T, y : T] Id::cong(f : (T) -> U, p : x === y) -> f(x) === f(y) {
  #|  match p {
  #|    Refl => Refl
  #|  }
  #|}
  #|
  #|fn[T, x : T, y : T] Id::subst(p : x === y, motive : (T) -> Type, px : motive(x)) -> motive(y) {
  #|  match p {
  #|    Refl => px
  #|  }
  #|}
  #|
  #|// ---- lists ------------------------------------------------------------
  #|
  #|fn[T] List::length(self : List[T]) -> Int {
  #|  match self {
  #|    Nil => 0
  #|    Cons(_, xs) => xs.length() + 1
  #|  }
  #|}
  #|
  #|fn[T] List::append(self : List[T], ys : List[T]) -> List[T] {
  #|  match self {
  #|    Nil => ys
  #|    Cons(x, xs) => Cons(x, xs.append(ys))
  #|  }
  #|}
  #|
  #|fn[T] List::reverse(self : List[T]) -> List[T] {
  #|  match self {
  #|    Nil => Nil
  #|    Cons(x, xs) => xs.reverse().append(Cons(x, Nil))
  #|  }
  #|}
  #|
  #|fn[T, U] List::map(self : List[T], f : (T) -> U) -> List[U] {
  #|  match self {
  #|    Nil => Nil
  #|    Cons(x, xs) => Cons(f(x), xs.map(f))
  #|  }
  #|}
  #|
  #|// ---- other numeric types ----------------------------------------------
  #|fn Int64::op_add(self : Int64, other : Int64) -> Int64 = "%int64_add"
  #|fn Int64::op_sub(self : Int64, other : Int64) -> Int64 = "%int64_sub"
  #|fn Int64::op_mul(self : Int64, other : Int64) -> Int64 = "%int64_mul"
  #|fn Int64::op_div(self : Int64, other : Int64) -> Int64 = "%int64_div"
  #|fn Int64::op_mod(self : Int64, other : Int64) -> Int64 = "%int64_mod"
  #|fn Int64::op_neg(self : Int64) -> Int64 = "%int64_neg"
  #|fn Int64::op_land(self : Int64, other : Int64) -> Int64 = "%int64_land"
  #|fn Int64::op_lor(self : Int64, other : Int64) -> Int64 = "%int64_lor"
  #|fn Int64::op_lxor(self : Int64, other : Int64) -> Int64 = "%int64_lxor"
  #|fn Int64::op_shl(self : Int64, n : Int) -> Int64 = "%int64_shl"
  #|fn Int64::op_shr(self : Int64, n : Int) -> Int64 = "%int64_shr"
  #|fn Int64::op_equal(self : Int64, other : Int64) -> Bool = "%int64_eq"
  #|fn Int64::op_lt(self : Int64, other : Int64) -> Bool = "%int64_lt"
  #|fn Int64::op_le(self : Int64, other : Int64) -> Bool = "%int64_le"
  #|fn Int64::op_gt(self : Int64, other : Int64) -> Bool = "%int64_gt"
  #|fn Int64::op_ge(self : Int64, other : Int64) -> Bool = "%int64_ge"
  #|fn Int64::compare(self : Int64, other : Int64) -> Int = "%int64_compare"
  #|fn Int64::to_string(self : Int64) -> String = "%int64_to_string"
  #|fn Int64::hash(self : Int64) -> Int = "%int64_hash"
  #|fn UInt::op_add(self : UInt, other : UInt) -> UInt = "%uint_add"
  #|fn UInt::op_sub(self : UInt, other : UInt) -> UInt = "%uint_sub"
  #|fn UInt::op_mul(self : UInt, other : UInt) -> UInt = "%uint_mul"
  #|fn UInt::op_div(self : UInt, other : UInt) -> UInt = "%uint_div"
  #|fn UInt::op_mod(self : UInt, other : UInt) -> UInt = "%uint_mod"
  #|fn UInt::op_land(self : UInt, other : UInt) -> UInt = "%uint_land"
  #|fn UInt::op_lor(self : UInt, other : UInt) -> UInt = "%uint_lor"
  #|fn UInt::op_lxor(self : UInt, other : UInt) -> UInt = "%uint_lxor"
  #|fn UInt::op_shl(self : UInt, n : Int) -> UInt = "%uint_shl"
  #|fn UInt::op_shr(self : UInt, n : Int) -> UInt = "%uint_shr"
  #|fn UInt::op_equal(self : UInt, other : UInt) -> Bool = "%uint_eq"
  #|fn UInt::op_lt(self : UInt, other : UInt) -> Bool = "%uint_lt"
  #|fn UInt::op_le(self : UInt, other : UInt) -> Bool = "%uint_le"
  #|fn UInt::op_gt(self : UInt, other : UInt) -> Bool = "%uint_gt"
  #|fn UInt::op_ge(self : UInt, other : UInt) -> Bool = "%uint_ge"
  #|fn UInt::compare(self : UInt, other : UInt) -> Int = "%uint_compare"
  #|fn UInt::to_string(self : UInt) -> String = "%uint_to_string"
  #|fn UInt::hash(self : UInt) -> Int = "%uint_hash"
  #|fn UInt64::op_add(self : UInt64, other : UInt64) -> UInt64 = "%uint64_add"
  #|fn UInt64::op_sub(self : UInt64, other : UInt64) -> UInt64 = "%uint64_sub"
  #|fn UInt64::op_mul(self : UInt64, other : UInt64) -> UInt64 = "%uint64_mul"
  #|fn UInt64::op_div(self : UInt64, other : UInt64) -> UInt64 = "%uint64_div"
  #|fn UInt64::op_mod(self : UInt64, other : UInt64) -> UInt64 = "%uint64_mod"
  #|fn UInt64::op_land(self : UInt64, other : UInt64) -> UInt64 = "%uint64_land"
  #|fn UInt64::op_lor(self : UInt64, other : UInt64) -> UInt64 = "%uint64_lor"
  #|fn UInt64::op_lxor(self : UInt64, other : UInt64) -> UInt64 = "%uint64_lxor"
  #|fn UInt64::op_shl(self : UInt64, n : Int) -> UInt64 = "%uint64_shl"
  #|fn UInt64::op_shr(self : UInt64, n : Int) -> UInt64 = "%uint64_shr"
  #|fn UInt64::op_equal(self : UInt64, other : UInt64) -> Bool = "%uint64_eq"
  #|fn UInt64::op_lt(self : UInt64, other : UInt64) -> Bool = "%uint64_lt"
  #|fn UInt64::op_le(self : UInt64, other : UInt64) -> Bool = "%uint64_le"
  #|fn UInt64::op_gt(self : UInt64, other : UInt64) -> Bool = "%uint64_gt"
  #|fn UInt64::op_ge(self : UInt64, other : UInt64) -> Bool = "%uint64_ge"
  #|fn UInt64::compare(self : UInt64, other : UInt64) -> Int = "%uint64_compare"
  #|fn UInt64::to_string(self : UInt64) -> String = "%uint64_to_string"
  #|fn UInt64::hash(self : UInt64) -> Int = "%uint64_hash"
  #|fn Byte::op_add(self : Byte, other : Byte) -> Byte = "%byte_add"
  #|fn Byte::op_sub(self : Byte, other : Byte) -> Byte = "%byte_sub"
  #|fn Byte::op_mul(self : Byte, other : Byte) -> Byte = "%byte_mul"
  #|fn Byte::op_div(self : Byte, other : Byte) -> Byte = "%byte_div"
  #|fn Byte::op_mod(self : Byte, other : Byte) -> Byte = "%byte_mod"
  #|fn Byte::op_land(self : Byte, other : Byte) -> Byte = "%byte_land"
  #|fn Byte::op_lor(self : Byte, other : Byte) -> Byte = "%byte_lor"
  #|fn Byte::op_lxor(self : Byte, other : Byte) -> Byte = "%byte_lxor"
  #|fn Byte::op_shl(self : Byte, n : Int) -> Byte = "%byte_shl"
  #|fn Byte::op_shr(self : Byte, n : Int) -> Byte = "%byte_shr"
  #|fn Byte::op_equal(self : Byte, other : Byte) -> Bool = "%byte_eq"
  #|fn Byte::op_lt(self : Byte, other : Byte) -> Bool = "%byte_lt"
  #|fn Byte::op_le(self : Byte, other : Byte) -> Bool = "%byte_le"
  #|fn Byte::op_gt(self : Byte, other : Byte) -> Bool = "%byte_gt"
  #|fn Byte::op_ge(self : Byte, other : Byte) -> Bool = "%byte_ge"
  #|fn Byte::compare(self : Byte, other : Byte) -> Int = "%byte_compare"
  #|fn Byte::to_string(self : Byte) -> String = "%byte_to_string"
  #|fn Byte::hash(self : Byte) -> Int = "%byte_hash"
  #|fn Float::op_add(self : Float, other : Float) -> Float = "%float_add"
  #|fn Float::op_sub(self : Float, other : Float) -> Float = "%float_sub"
  #|fn Float::op_mul(self : Float, other : Float) -> Float = "%float_mul"
  #|fn Float::op_div(self : Float, other : Float) -> Float = "%float_div"
  #|fn Float::op_neg(self : Float) -> Float = "%float_neg"
  #|fn Float::op_equal(self : Float, other : Float) -> Bool = "%float_eq"
  #|fn Float::op_lt(self : Float, other : Float) -> Bool = "%float_lt"
  #|fn Float::op_le(self : Float, other : Float) -> Bool = "%float_le"
  #|fn Float::op_gt(self : Float, other : Float) -> Bool = "%float_gt"
  #|fn Float::op_ge(self : Float, other : Float) -> Bool = "%float_ge"
  #|fn Float::compare(self : Float, other : Float) -> Int = "%float_compare"
  #|fn Float::to_string(self : Float) -> String = "%float_to_string"
  #|fn Float::hash(self : Float) -> Int = "%float_hash"
  #|fn Int64::to_int(self : Int64) -> Int = "%int64_to_int"
  #|fn Int64::to_double(self : Int64) -> Double = "%int64_to_double"
  #|fn Int::to_int64(self : Int) -> Int64 = "%int_to_int64"
  #|fn UInt::to_int(self : UInt) -> Int = "%uint_to_int"
  #|fn UInt::to_double(self : UInt) -> Double = "%uint_to_double"
  #|fn Int::to_uint(self : Int) -> UInt = "%int_to_uint"
  #|fn UInt64::to_int(self : UInt64) -> Int = "%uint64_to_int"
  #|fn UInt64::to_double(self : UInt64) -> Double = "%uint64_to_double"
  #|fn Int::to_uint64(self : Int) -> UInt64 = "%int_to_uint64"
  #|fn Byte::to_int(self : Byte) -> Int = "%byte_to_int"
  #|fn Byte::to_double(self : Byte) -> Double = "%byte_to_double"
  #|fn Int::to_byte(self : Int) -> Byte = "%int_to_byte"
  #|fn Float::to_int(self : Float) -> Int = "%float_to_int"
  #|fn Float::to_double(self : Float) -> Double = "%float_to_double"
  #|fn Int::to_float(self : Int) -> Float = "%int_to_float"
  #|fn Double::to_float(self : Double) -> Float = "%double_to_float"
  #|fn Int64::to_uint64(self : Int64) -> UInt64 = "%int64_to_uint64"
  #|fn UInt64::to_int64(self : UInt64) -> Int64 = "%uint64_to_int64"
  #|fn UInt::to_uint64(self : UInt) -> UInt64 = "%uint_to_uint64"
  #|fn UInt64::to_uint(self : UInt64) -> UInt = "%uint64_to_uint"
  #|fn UInt::to_int64(self : UInt) -> Int64 = "%uint_to_int64"
  #|fn Byte::to_int64(self : Byte) -> Int64 = "%byte_to_int64"
  #|fn Byte::to_uint(self : Byte) -> UInt = "%byte_to_uint"
  #|fn Byte::to_uint64(self : Byte) -> UInt64 = "%byte_to_uint64"
  #|fn Int64::to_byte(self : Int64) -> Byte = "%int64_to_byte"
  #|impl Show for Int64 with to_string(self) { self.to_string() }
  #|impl Eq for Int64 with op_equal(a, b) { a == b }
  #|impl Compare for Int64 with compare(a, b) { a.compare(b) }
  #|impl Hash for Int64 with hash(self) { self.hash() }
  #|impl Default for Int64 with default() { 0L }
  #|impl Add for Int64 with op_add(a, b) { a + b }
  #|impl Sub for Int64 with op_sub(a, b) { a - b }
  #|impl Mul for Int64 with op_mul(a, b) { a * b }
  #|impl Div for Int64 with op_div(a, b) { a / b }
  #|impl Mod for Int64 with op_mod(a, b) { a % b }
  #|impl Neg for Int64 with op_neg(a) { -a }
  #|impl BitAnd for Int64 with op_land(a, b) { a & b }
  #|impl BitOr for Int64 with op_lor(a, b) { a | b }
  #|impl BitXOr for Int64 with op_lxor(a, b) { a ^ b }
  #|impl Shl for Int64 with op_shl(a, n) { a << n }
  #|impl Shr for Int64 with op_shr(a, n) { a >> n }
  #|impl Show for UInt with to_string(self) { self.to_string() }
  #|impl Eq for UInt with op_equal(a, b) { a == b }
  #|impl Compare for UInt with compare(a, b) { a.compare(b) }
  #|impl Hash for UInt with hash(self) { self.hash() }
  #|impl Default for UInt with default() { 0U }
  #|impl Add for UInt with op_add(a, b) { a + b }
  #|impl Sub for UInt with op_sub(a, b) { a - b }
  #|impl Mul for UInt with op_mul(a, b) { a * b }
  #|impl Div for UInt with op_div(a, b) { a / b }
  #|impl Mod for UInt with op_mod(a, b) { a % b }
  #|impl BitAnd for UInt with op_land(a, b) { a & b }
  #|impl BitOr for UInt with op_lor(a, b) { a | b }
  #|impl BitXOr for UInt with op_lxor(a, b) { a ^ b }
  #|impl Shl for UInt with op_shl(a, n) { a << n }
  #|impl Shr for UInt with op_shr(a, n) { a >> n }
  #|impl Show for UInt64 with to_string(self) { self.to_string() }
  #|impl Eq for UInt64 with op_equal(a, b) { a == b }
  #|impl Compare for UInt64 with compare(a, b) { a.compare(b) }
  #|impl Hash for UInt64 with hash(self) { self.hash() }
  #|impl Default for UInt64 with default() { 0UL }
  #|impl Add for UInt64 with op_add(a, b) { a + b }
  #|impl Sub for UInt64 with op_sub(a, b) { a - b }
  #|impl Mul for UInt64 with op_mul(a, b) { a * b }
  #|impl Div for UInt64 with op_div(a, b) { a / b }
  #|impl Mod for UInt64 with op_mod(a, b) { a % b }
  #|impl BitAnd for UInt64 with op_land(a, b) { a & b }
  #|impl BitOr for UInt64 with op_lor(a, b) { a | b }
  #|impl BitXOr for UInt64 with op_lxor(a, b) { a ^ b }
  #|impl Shl for UInt64 with op_shl(a, n) { a << n }
  #|impl Shr for UInt64 with op_shr(a, n) { a >> n }
  #|impl Show for Byte with to_string(self) { self.to_string() }
  #|impl Eq for Byte with op_equal(a, b) { a == b }
  #|impl Compare for Byte with compare(a, b) { a.compare(b) }
  #|impl Hash for Byte with hash(self) { self.hash() }
  #|impl Default for Byte with default() { b'\x00' }
  #|impl Add for Byte with op_add(a, b) { a + b }
  #|impl Sub for Byte with op_sub(a, b) { a - b }
  #|impl Mul for Byte with op_mul(a, b) { a * b }
  #|impl Div for Byte with op_div(a, b) { a / b }
  #|impl Mod for Byte with op_mod(a, b) { a % b }
  #|impl BitAnd for Byte with op_land(a, b) { a & b }
  #|impl BitOr for Byte with op_lor(a, b) { a | b }
  #|impl BitXOr for Byte with op_lxor(a, b) { a ^ b }
  #|impl Shl for Byte with op_shl(a, n) { a << n }
  #|impl Shr for Byte with op_shr(a, n) { a >> n }
  #|impl Show for Float with to_string(self) { self.to_string() }
  #|impl Eq for Float with op_equal(a, b) { a == b }
  #|impl Compare for Float with compare(a, b) { a.compare(b) }
  #|impl Hash for Float with hash(self) { self.hash() }
  #|impl Default for Float with default() { 0.0F }
  #|impl Add for Float with op_add(a, b) { a + b }
  #|impl Sub for Float with op_sub(a, b) { a - b }
  #|impl Mul for Float with op_mul(a, b) { a * b }
  #|impl Div for Float with op_div(a, b) { a / b }
  #|impl Neg for Float with op_neg(a) { -a }
  #|
  #|// ---- Map ------------------------------------------------------------------
  #|
  #|// A map from keys to values, in insertion order: `{ "a": 1 }`, `m[k]`,
  #|// `m[k] = v`, `for k, v in m`. (It is not MoonBit's `Map`: imported MoonBit
  #|// functions taking or returning a `Map` cannot be called.)
  #|struct Map[K, V] {
  #|  mut map_keys : Array[K]
  #|  mut map_values : Array[V]
  #|}
  #|
  #|fn[K, V] Map::new() -> Map[K, V] {
  #|  { map_keys: [], map_values: [] }
  #|}
  #|
  #|fn[K : Eq, V] Map::index_of(self : Map[K, V], key : K) -> Int {
  #|  let ks = self.map_keys
  #|  for i = 0; i < ks.length(); i = i + 1 {
  #|    if ks[i] == key {
  #|      return i
  #|    }
  #|  }
  #|  -1
  #|}
  #|
  #|fn[K : Eq, V] Map::set(self : Map[K, V], key : K, value : V) -> Unit {
  #|  let i = self.index_of(key)
  #|  if i < 0 {
  #|    self.map_keys.push(key)
  #|    self.map_values.push(value)
  #|  } else {
  #|    self.map_values[i] = value
  #|  }
  #|}
  #|
  #|fn[K : Eq, V] Map::get(self : Map[K, V], key : K) -> V? {
  #|  let i = self.index_of(key)
  #|  if i < 0 { None } else { Some(self.map_values[i]) }
  #|}
  #|
  #|fn[K : Eq, V] Map::op_get(self : Map[K, V], key : K) -> V? {
  #|  self.get(key)
  #|}
  #|
  #|fn[K : Eq, V] Map::op_set(self : Map[K, V], key : K, value : V) -> Unit {
  #|  self.set(key, value)
  #|}
  #|
  #|fn[K : Eq, V] Map::contains(self : Map[K, V], key : K) -> Bool {
  #|  self.index_of(key) >= 0
  #|}
  #|
  #|fn[K : Eq, V] Map::remove(self : Map[K, V], key : K) -> Unit {
  #|  let i = self.index_of(key)
  #|  if i >= 0 {
  #|    let ks : Array[K] = Array::new()
  #|    let vs : Array[V] = Array::new()
  #|    for j = 0; j < self.map_keys.length(); j = j + 1 {
  #|      if j != i {
  #|        ks.push(self.map_keys[j])
  #|        vs.push(self.map_values[j])
  #|      }
  #|    }
  #|    self.map_keys = ks
  #|    self.map_values = vs
  #|  }
  #|}
  #|
  #|fn[K, V] Map::length(self : Map[K, V]) -> Int {
  #|  self.map_keys.length()
  #|}
  #|
  #|fn[K, V] Map::size(self : Map[K, V]) -> Int {
  #|  self.map_keys.length()
  #|}
  #|
  #|fn[K, V] Map::is_empty(self : Map[K, V]) -> Bool {
  #|  self.map_keys.length() == 0
  #|}
  #|
  #|fn[K, V] Map::keys(self : Map[K, V]) -> Array[K] {
  #|  self.map_keys.slice(0, self.map_keys.length())
  #|}
  #|
  #|fn[K, V] Map::values(self : Map[K, V]) -> Array[V] {
  #|  self.map_values.slice(0, self.map_values.length())
  #|}
  #|
  #|fn[K, V] Map::to_array(self : Map[K, V]) -> Array[(K, V)] {
  #|  let out : Array[(K, V)] = Array::new()
  #|  for i = 0; i < self.map_keys.length(); i = i + 1 {
  #|    out.push((self.map_keys[i], self.map_values[i]))
  #|  }
  #|  out
  #|}
  #|
  #|fn[K : Eq, V] Map::from_array(xs : Array[(K, V)]) -> Map[K, V] {
  #|  let m : Map[K, V] = Map::new()
  #|  for i = 0; i < xs.length(); i = i + 1 {
  #|    m.set(xs[i].0, xs[i].1)
  #|  }
  #|  m
  #|}
  #|
  #|impl[K : Show, V : Show] Show for Map[K, V] with to_string(self) {
  #|  let mut s = "{"
  #|  for i = 0; i < self.map_keys.length(); i = i + 1 {
  #|    if i > 0 { s = s + ", " }
  #|    s = s + self.map_keys[i].to_string() + ": " + self.map_values[i].to_string()
  #|  }
  #|  s + "}"
  #|}
  #|
  #|// ---- traits -----------------------------------------------------------
  #|
  #|#mbt("Show")
  #|trait Show {
  #|  to_string(Self) -> String
  #|}
  #|
  #|impl Show for Int with to_string(self) { self.to_string() }
  #|impl Show for String with to_string(self) { self }
  #|impl Show for Bool with to_string(self) { self.to_string() }
  #|impl Show for Char with to_string(self) { self.to_string() }
  #|impl Show for Unit with to_string(self) { self.to_string() }
  #|impl Show for Nat with to_string(self) { self.to_string() }
  #|impl Show for Double with to_string(self) { self.to_string() }
  #|
  #|impl[T : Show] Show for Array[T] with to_string(self) {
  #|  let mut s = "["
  #|  for i = 0; i < self.length(); i = i + 1 {
  #|    if i > 0 { s = s + ", " }
  #|    s = s + self[i].to_string()
  #|  }
  #|  s + "]"
  #|}
  #|
  #|impl[T : Show] Show for List[T] with to_string(self) {
  #|  match self {
  #|    Nil => "Nil"
  #|    Cons(x, xs) => "Cons(" + x.to_string() + ", " + xs.to_string() + ")"
  #|  }
  #|}
  #|
  #|impl[T : Show] Show for Option[T] with to_string(self) {
  #|  match self {
  #|    None => "None"
  #|    Some(x) => "Some(" + x.to_string() + ")"
  #|  }
  #|}
  #|
  #|#mbt("Eq")
  #|trait Eq {
  #|  op_equal(Self, Self) -> Bool
  #|}
  #|
  #|impl Eq for Int with op_equal(a, b) { a == b }
  #|impl Eq for String with op_equal(a, b) { a == b }
  #|impl Eq for Bool with op_equal(a, b) { a == b }
  #|impl Eq for Char with op_equal(a, b) { a == b }
  #|impl Eq for Nat with op_equal(a, b) { a == b }
  #|impl Eq for Double with op_equal(a, b) { a == b }
  #|impl Eq for Unit with op_equal(_, _) { true }
  #|
  #|impl[T : Eq] Eq for Option[T] with op_equal(a, b) {
  #|  match (a, b) {
  #|    (None, None) => true
  #|    (Some(x), Some(y)) => x == y
  #|    _ => false
  #|  }
  #|}
  #|
  #|impl[T : Eq] Eq for List[T] with op_equal(a, b) {
  #|  match (a, b) {
  #|    (Nil, Nil) => true
  #|    (Cons(x, xs), Cons(y, ys)) => x == y && xs == ys
  #|    _ => false
  #|  }
  #|}
  #|
  #|#mbt("Compare")
  #|trait Compare : Eq {
  #|  compare(Self, Self) -> Int
  #|}
  #|
  #|impl Compare for Int with compare(a, b) { a.compare(b) }
  #|impl Compare for String with compare(a, b) { a.compare(b) }
  #|impl Compare for Char with compare(a, b) { a.compare(b) }
  #|impl Compare for Double with compare(a, b) { a.compare(b) }
  #|impl Compare for Bool with compare(a, b) {
  #|  if a == b { 0 } else if a { 1 } else { -1 }
  #|}
  #|impl Compare for Nat with compare(a, b) { a.to_int().compare(b.to_int()) }
  #|impl Compare for Unit with compare(_, _) { 0 }
  #|
  #|impl[T : Compare] Compare for Option[T] with compare(a, b) {
  #|  match (a, b) {
  #|    (None, None) => 0
  #|    (None, Some(_)) => -1
  #|    (Some(_), None) => 1
  #|    (Some(x), Some(y)) => x.compare(y)
  #|  }
  #|}
  #|
  #|impl[T : Compare] Compare for List[T] with compare(a, b) {
  #|  match (a, b) {
  #|    (Nil, Nil) => 0
  #|    (Nil, Cons(_, _)) => -1
  #|    (Cons(_, _), Nil) => 1
  #|    (Cons(x, xs), Cons(y, ys)) => {
  #|      let c = x.compare(y)
  #|      if c == 0 { xs.compare(ys) } else { c }
  #|    }
  #|  }
  #|}
  #|
  #|#mbt("Add")
  #|trait Add {
  #|  op_add(Self, Self) -> Self
  #|}
  #|
  #|impl Add for Int with op_add(a, b) { a + b }
  #|impl Add for String with op_add(a, b) { a + b }
  #|impl Add for Nat with op_add(a, b) { a + b }
  #|impl Add for Double with op_add(a, b) { a + b }
  #|
  #|#mbt("Sub")
  #|trait Sub {
  #|  op_sub(Self, Self) -> Self
  #|}
  #|
  #|impl Sub for Int with op_sub(a, b) { a - b }
  #|impl Sub for Double with op_sub(a, b) { a - b }
  #|
  #|#mbt("Mul")
  #|trait Mul {
  #|  op_mul(Self, Self) -> Self
  #|}
  #|
  #|impl Mul for Int with op_mul(a, b) { a * b }
  #|impl Mul for Double with op_mul(a, b) { a * b }
  #|impl Mul for Nat with op_mul(a, b) { a * b }
  #|
  #|#mbt("Div")
  #|trait Div {
  #|  op_div(Self, Self) -> Self
  #|}
  #|
  #|impl Div for Int with op_div(a, b) { a / b }
  #|impl Div for Double with op_div(a, b) { a / b }
  #|
  #|#mbt("Mod")
  #|trait Mod {
  #|  op_mod(Self, Self) -> Self
  #|}
  #|
  #|impl Mod for Int with op_mod(a, b) { a % b }
  #|
  #|#mbt("Neg")
  #|trait Neg {
  #|  op_neg(Self) -> Self
  #|}
  #|
  #|impl Neg for Int with op_neg(a) { -a }
  #|impl Neg for Double with op_neg(a) { -a }
  #|
  #|#mbt("Default")
  #|trait Default {
  #|  default() -> Self
  #|}
  #|
  #|impl Default for Int with default() { 0 }
  #|impl Default for Double with default() { 0.0 }
  #|impl Default for String with default() { "" }
  #|impl Default for Bool with default() { false }
  #|impl Default for Unit with default() { () }
  #|impl[T] Default for Option[T] with default() { None }
  #|impl[T] Default for List[T] with default() { Nil }
  #|
  #|#mbt("BitAnd")
  #|trait BitAnd {
  #|  op_land(Self, Self) -> Self
  #|}
  #|
  #|impl BitAnd for Int with op_land(a, b) { a & b }
  #|
  #|#mbt("BitOr")
  #|trait BitOr {
  #|  op_lor(Self, Self) -> Self
  #|}
  #|
  #|impl BitOr for Int with op_lor(a, b) { a | b }
  #|
  #|#mbt("BitXOr")
  #|trait BitXOr {
  #|  op_lxor(Self, Self) -> Self
  #|}
  #|
  #|impl BitXOr for Int with op_lxor(a, b) { a ^ b }
  #|
  #|#mbt("Shl")
  #|trait Shl {
  #|  op_shl(Self, Int) -> Self
  #|}
  #|
  #|impl Shl for Int with op_shl(a, n) { a << n }
  #|
  #|#mbt("Shr")
  #|trait Shr {
  #|  op_shr(Self, Int) -> Self
  #|}
  #|
  #|impl Shr for Int with op_shr(a, n) { a >> n }
  #|
  #|// `hash` is MoonBit's `Hash::hash`; the impls of `#mbt` types are MoonBit
  #|// impls whose `hash_combine` combines this hash. The interpreter's hashes
  #|// differ from those of compiled programs.
  #|#mbt("Hash")
  #|trait Hash {
  #|  hash(Self) -> Int
  #|}
  #|
  #|impl Hash for Int with hash(self) { self }
  #|impl Hash for Bool with hash(self) { if self { 1 } else { 0 } }
  #|impl Hash for Char with hash(self) { self.to_int() }
  #|impl Hash for Unit with hash(_) { 0 }
  #|impl Hash for Nat with hash(self) { self.to_int() }
  #|impl Hash for String with hash(self) {
  #|  let mut h = 0
  #|  for i = 0; i < self.length(); i = i + 1 {
  #|    h = h * 31 + self[i].to_int()
  #|  }
  #|  h
  #|}
  #|impl Hash for Double with hash(self) { self.to_string().hash() }
  #|impl[T : Hash] Hash for Option[T] with hash(self) {
  #|  match self {
  #|    None => 0
  #|    Some(x) => x.hash() * 31 + 1
  #|  }
  #|}
  #|impl[T : Hash] Hash for List[T] with hash(self) {
  #|  match self {
  #|    Nil => 0
  #|    Cons(x, xs) => x.hash() * 31 + xs.hash()
  #|  }
  #|}
  #|
  #|// `Json` is MoonBit's: its values are made and used by MoonBit code
  #|// (compiled programs), e.g. `@json` functions or `derive(ToJson)` of `#mbt`
  #|// types.
  #|#mbt("ToJson")
  #|trait ToJson {
  #|  to_json(Self) -> Json
  #|}
  #|
  #|fn int_to_json(x : Int) -> Json = "@mbt:trait:ToJson::to_json"
  #|fn double_to_json(x : Double) -> Json = "@mbt:trait:ToJson::to_json"
  #|fn string_to_json(x : String) -> Json = "@mbt:trait:ToJson::to_json"
  #|fn bool_to_json(x : Bool) -> Json = "@mbt:trait:ToJson::to_json"
  #|fn char_to_json(x : Char) -> Json = "@mbt:trait:ToJson::to_json"
  #|fn unit_to_json(x : Unit) -> Json = "@mbt:trait:ToJson::to_json"
  #|fn json_to_string(x : Json) -> String = "@mbt:trait:Show::to_string"
  #|fn json_equal(x : Json, y : Json) -> Bool = "@mbt:trait:Eq::equal"
  #|fn Json::stringify(self : Json) -> String = "@mbt:Json::stringify"
  #|
  #|impl ToJson for Int with to_json(self) { int_to_json(self) }
  #|impl ToJson for Double with to_json(self) { double_to_json(self) }
  #|impl ToJson for String with to_json(self) { string_to_json(self) }
  #|impl ToJson for Bool with to_json(self) { bool_to_json(self) }
  #|impl ToJson for Char with to_json(self) { char_to_json(self) }
  #|impl ToJson for Unit with to_json(self) { unit_to_json(self) }
  #|impl ToJson for Json with to_json(self) { self }
  #|impl Show for Json with to_string(self) { json_to_string(self) }
  #|impl Eq for Json with op_equal(a, b) { json_equal(a, b) }
  #|
  #|trait Monad(Self : [T] -> Type) {
  #|  fn[T] pure(T) -> Self[T]
  #|  fn[T, U] bind(Self[T], (T) -> Self[U]) -> Self[U]
  #|}
  #|
  #|impl Monad for Option with pure(x) { Some(x) }
  #|impl Monad for Option with bind(m, f) {
  #|  match m {
  #|    None => None
  #|    Some(x) => f(x)
  #|  }
  #|}
  #|
  #|fn[T, U] List::flat_map(self : List[T], f : (T) -> List[U]) -> List[U] {
  #|  match self {
  #|    Nil => Nil
  #|    Cons(x, xs) => f(x).append(xs.flat_map(f))
  #|  }
  #|}
  #|
  #|impl Monad for List with pure(x) { Cons(x, Nil) }
  #|impl Monad for List with bind(m, f) { m.flat_map(f) }
  #|
  #|// ---- IO and errors ----------------------------------------------------
  #|
  #|fn Error::to_string(self : Error) -> String = "%error_to_string"
  #|impl Show for Error with to_string(self) { self.to_string() }
  #|
  #|impl[T : Show, E : Show] Show for Result[T, E] with to_string(self) {
  #|  match self {
  #|    Ok(x) => "Ok(" + x.to_string() + ")"
  #|    Err(e) => "Err(" + e.to_string() + ")"
  #|  }
  #|}
  #|
  #|fn[T : Show] println(x : T) -> Unit {
  #|  print_string(x.to_string() + "\n")
  #|}
  #|
  #|fn[T : Show] print(x : T) -> Unit {
  #|  print_string(x.to_string())
  #|}
  #|
  #|fn[T : Eq + Show] assert_eq(a : T, b : T) -> Unit raise Failure {
  #|  if !(a == b) {
  #|    raise Failure("`" + a.to_string() + " == " + b.to_string() + "`")
  #|  }
  #|}
  #|
  #|fn[T : Eq + Show] assert_not_eq(a : T, b : T) -> Unit raise Failure {
  #|  if a == b {
  #|    raise Failure("`" + a.to_string() + " != " + b.to_string() + "`")
  #|  }
  #|}
  #|
  #|fn assert_true(b : Bool) -> Unit raise Failure {
  #|  if !b {
  #|    raise Failure("`true` expected")
  #|  }
  #|}
  #|
  #|fn assert_false(b : Bool) -> Unit raise Failure {
  #|  if b {
  #|    raise Failure("`false` expected")
  #|  }
  #|}
  #|
  #|fn[T] fail(msg : String) -> T raise Failure {
  #|  raise Failure(msg)
  #|}
  #|
