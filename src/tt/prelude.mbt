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
  #|enum Option[T] {
  #|  None
  #|  Some(T)
  #|}
  #|
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
  #|// ---- traits -----------------------------------------------------------
  #|
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
  #|
  #|trait Compare : Eq {
  #|  compare(Self, Self) -> Int
  #|}
  #|
  #|impl Compare for Int with compare(a, b) { a.compare(b) }
  #|impl Compare for String with compare(a, b) { a.compare(b) }
  #|impl Compare for Char with compare(a, b) { a.compare(b) }
  #|impl Compare for Double with compare(a, b) { a.compare(b) }
  #|
  #|trait Add {
  #|  op_add(Self, Self) -> Self
  #|}
  #|
  #|impl Add for Int with op_add(a, b) { a + b }
  #|impl Add for String with op_add(a, b) { a + b }
  #|impl Add for Nat with op_add(a, b) { a + b }
  #|impl Add for Double with op_add(a, b) { a + b }
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
  #|fn[T] fail(msg : String) -> T raise Failure {
  #|  raise Failure(msg)
  #|}
  #|
