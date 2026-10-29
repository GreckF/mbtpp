///|
/// The signatures of the functions generated for a program (the lines
/// starting with `fn`, without the numbering of the identifiers), and the
/// native enums.
fn signatures(src : String) -> String {
  @tt.check_program("t.mbtpp", src) catch {
    @tt.CheckError(msg) => return msg
  }
  let code = @codegen.generate([]) catch {
    @codegen.CodegenError(msg) => return msg
  }
  let out : Array[String] = []
  for line in code.split("\n") {
    let l = line.to_string()
    if (
        l.has_prefix("fn") &&
        !l.contains("_v()") &&
        !l.contains("_to_value") &&
        !l.contains("_of_value") &&
        !l.contains("fn con_name") &&
        !l.contains("fn con_fields") &&
        !l.has_prefix("fn init")
      ) ||
      l.has_prefix("enum E_") {
      // drop the counters: f12_fib -> f_fib, x_34 -> x
      let buf = StringBuilder::new()
      let cs : Array[Char] = l.iter().collect()
      let mut i = 0
      while i < cs.length() {
        let c = cs[i]
        if (c == '_' || (c == 'f' && (i == 0 || !is_word(cs[i - 1])))) &&
          i + 1 < cs.length() &&
          cs[i + 1] >= '0' &&
          cs[i + 1] <= '9' &&
          (c == 'f' || (i > 0 && is_word(cs[i - 1]))) {
          buf.write_char(if c == 'f' { 'f' } else { ' ' })
          i = i + 1
          while i < cs.length() && cs[i] >= '0' && cs[i] <= '9' {
            i = i + 1
          }
          if c == '_' {
            // `x_34` -> `x`
            let s = buf.to_string()
            buf.reset()
            buf.write_string(s.unsafe_substring(start=0, end=s.length() - 1))
          }
        } else {
          buf.write_char(c)
          i = i + 1
        }
      }
      out.push(buf.to_string())
    }
  }
  out.join("\n")
}

///|
fn is_word(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
}

///|
test "codegen: native functions over scalars" {
  inspect(
    signatures(
      (
        #|fn fib(n : Int) -> Int { if n < 2 { n } else { fib(n - 1) + fib(n - 2) } }
        #|fn main { println(fib(10)) }
      ),
    ),
    content=(
      #|fn f_fib_t(n : Int) -> Int raise {
      #|fn f_fib(a0 : Value) -> Value raise {
      #|fn main {
      #|fn[T0 : Show] f_println_t(x : T0) -> Unit raise {
      #|fn f_println(v_inst_t : Value, x : Value) -> Value raise {
      #|fn f_show_to_string(inst : Value) -> Value raise {
    ),
  )
}

///|
test "codegen: indexed datatypes become generic enums; indices are erased" {
  inspect(
    signatures(
      (
        #|enum Vector[T] : Nat -> Type {
        #|  Nil : Vector[T](0)
        #|  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
        #|}
        #|fn[T, n : Nat, m : Nat] Vector::append(self : Vector[T](n), ys : Vector[T](m)) -> Vector[T](n + m) {
        #|  match self {
        #|    Nil => ys
        #|    Cons(x, xs) => Cons(x, xs.append(ys))
        #|  }
        #|}
        #|fn[T, U, n : Nat] Vector::map(self : Vector[T](n), f : (T) -> U) -> Vector[U](n) {
        #|  match self {
        #|    Nil => Nil
        #|    Cons(x, xs) => Cons(f(x), xs.map(f))
        #|  }
        #|}
        #|fn main {
        #|  let v : Vector[Int](1) = Cons(1, Nil)
        #|  let w = v.append(v).map(x => x + 1)
        #|}
      ),
    ),
    content=(
      #|enum E_Vector[T0] {
      #|fn[T0, T1] f_vector_map_t(self : E_Vector[T0], f : (T0) -> T1 raise) -> E_Vector[T1] raise {
      #|fn f_vector_map(a3 : Value, a4 : Value) -> Value raise {
      #|fn[T0] f_vector_append_t(self : E_Vector[T0], ys : E_Vector[T0]) -> E_Vector[T0] raise {
      #|fn f_vector_append(a3 : Value, a4 : Value) -> Value raise {
      #|fn main {
    ),
  )
}

///|
test "codegen: an implicit field used at runtime is kept" {
  inspect(
    signatures(
      (
        #|enum Vector[T] : Nat -> Type {
        #|  Nil : Vector[T](0)
        #|  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
        #|}
        #|fn[T, n : Nat] len(v : Vector[T](n)) -> Nat {
        #|  match v {
        #|    Nil => Z
        #|    Cons[m](_, _) => S(m)
        #|  }
        #|}
        #|fn main { println(len(Vector::Cons(1, Nil))) }
      ),
    ),
    content=(
      #|enum E_Vector[T0] {
      #|fn[T0] f_len_t(v : E_Vector[T0]) -> E_Nat raise {
      #|fn f_len(a2 : Value) -> Value raise {
      #|fn main {
      #|fn[T0 : Show] f_println_t(x : T0) -> Unit raise {
      #|fn f_println(v_inst_t : Value, x : Value) -> Value raise {
      #|fn f_show_to_string(inst : Value) -> Value raise {
      #|enum E_Nat {
      #|fn f_nat_to_string_t(self : E_Nat) -> String raise {
      #|fn f_nat_to_string(a0 : Value) -> Value raise {
      #|fn f_nat_to_int_t(self : E_Nat) -> Int raise {
      #|fn f_nat_to_int(a0 : Value) -> Value raise {
    ),
  )
}

///|
test "codegen: dependent results stay uniform" {
  inspect(
    signatures(
      (
        #|fn NAry(n : Nat) -> Type {
        #|  match n {
        #|    Z => Int
        #|    S(k) => (Int) -> NAry(k)
        #|  }
        #|}
        #|fn sum_n(n : Nat, acc : Int) -> NAry(n) {
        #|  match n as m return NAry(m) {
        #|    Z => acc
        #|    S(k) => x => sum_n(k, acc + x)
        #|  }
        #|}
        #|fn main { println(sum_n(2, 0)(1)(2)) }
      ),
    ),
    content=(
      #|fn f_sum_n(n : Value, acc : Value) -> Value raise {
      #|fn main {
      #|fn[T0 : Show] f_println_t(x : T0) -> Unit raise {
      #|fn f_println(v_inst_t : Value, x : Value) -> Value raise {
      #|fn f_show_to_string(inst : Value) -> Value raise {
    ),
  )
}

///|
/// The MoonBit declarations generated for `#mbt` types and traits.
fn mbt_decls(src : String) -> String {
  @tt.check_program("t.mbtpp", src) catch {
    @tt.CheckError(msg) => return msg
  }
  let code = @codegen.generate([]) catch {
    @codegen.CodegenError(msg) => return msg
  }
  let out : Array[String] = []
  let mut inside = false
  for line in code.split("\n") {
    let l = line.to_string()
    if l.has_prefix("enum Tree") ||
      l.has_prefix("struct ") ||
      l.has_prefix("trait ") ||
      l.has_prefix("impl") {
      inside = !l.has_prefix("impl")
      out.push(l)
    } else if inside {
      out.push(l)
      if l == "}" {
        inside = false
      }
    }
  }
  out.join("\n")
}

///|
test "codegen: #mbt types and traits" {
  inspect(
    mbt_decls(
      (
        #|#mbt
        #|enum Tree[T] { Leaf; Node(Tree[T], T, Tree[T]) }
        #|#mbt
        #|struct P { x : Int; y : Int }
        #|#mbt
        #|trait Size { size(Self) -> Int }
        #|impl Size for P with size(self) { self.x + self.y }
        #|impl[T : Size] Size for Tree[T] with size(self) {
        #|  match self {
        #|    Leaf => 0
        #|    Node(l, x, r) => l.size() + x.size() + r.size()
        #|  }
        #|}
        #|fn[T : Size] total(t : Tree[T]) -> Int { t.size() }
        #|fn sizes(t : Tree[P]) -> Int { total(t) }
        #|fn main { println(sizes(Node(Leaf, { x: 1, y: 2 }, Leaf))) }
      ),
    ),
    content=(
      #|impl Size for P with size(a0) {
      #|impl[T0 : Size] Size for Tree[T0] with size(a0) {
    ),
  )
}

///|
test "codegen: #mbt functions must be native" {
  inspect(
    signatures(
      (
        #|trait Sz { size(Self) -> Int }
        #|impl Sz for Int with size(self) { self }
        #|#mbt
        #|fn f(x : Int) -> Int { x.size() }
        #|fn main { println(f(1)) }
      ),
    ),
    content=(
      #|#mbt fn f cannot be compiled to MoonBit: its body is not in the native fragment: in `Sz::size(x)`, Sz::size is a method of the trait Sz, which is not #mbt
    ),
  )
  inspect(
    signatures(
      (
        #|#mbt
        #|fn twice(x : Int) -> Int { x + x }
        #|fn main { println(1) }
      ),
    ),
    content=(
      #|fn f_twice_t(x : Int) -> Int raise {
      #|fn f_twice(a0 : Value) -> Value raise {
      #|fn main {
      #|fn[T0 : Show] f_println_t(x : T0) -> Unit raise {
      #|fn f_println(v_inst_t : Value, x : Value) -> Value raise {
      #|fn f_show_to_string(inst : Value) -> Value raise {
    ),
  )
}

///|
/// The constructor variants of `Value` and the patterns matching them.
fn data_lines(src : String) -> String {
  @tt.check_program("t.mbtpp", src) catch {
    @tt.CheckError(msg) => return msg
  }
  let code = @codegen.generate([]) catch {
    @codegen.CodegenError(msg) => return msg
  }
  code
  .split("\n")
  .map(l => l.to_string().trim(chars=" ").to_string())
  .filter(l => l.has_prefix("K_Exp"))
  .map(l => {
    // drop the counters of local names: n_176 -> n
    let buf = StringBuilder::new()
    let cs : Array[Char] = l.iter().collect()
    let mut i = 0
    while i < cs.length() {
      if cs[i] == '_' &&
        i + 1 < cs.length() &&
        cs[i + 1] >= '0' &&
        cs[i + 1] <= '9' &&
        i > 0 &&
        cs[i - 1] >= 'a' &&
        cs[i - 1] <= 'z' {
        i = i + 1
        while i < cs.length() && cs[i] >= '0' && cs[i] <= '9' {
          i = i + 1
        }
      } else {
        buf.write_char(cs[i])
        i = i + 1
      }
    }
    buf.to_string()
  })
  .to_array()
  .join("\n")
}

///|
test "codegen: data are native variants of Value, without indices" {
  inspect(
    data_lines(
      (
        #|enum Exp : [T] -> Type {
        #|  IntLit(Int) : Exp[Int]
        #|  BoolLit(Bool) : Exp[Bool]
        #|  Add(Exp[Int], Exp[Int]) : Exp[Int]
        #|  If[T](Exp[Bool], Exp[T], Exp[T]) : Exp[T]
        #|}
        #|fn[T] Exp::eval(self : Exp[T]) -> T {
        #|  match self {
        #|    IntLit(n) => n
        #|    BoolLit(b) => b
        #|    Add(l, r) => l.eval() + r.eval()
        #|    If[_](c, t, f) => if c.eval() { t.eval() } else { f.eval() }
        #|  }
        #|}
        #|fn main { println(If(BoolLit(true), IntLit(1), IntLit(2)).eval()) }
      ),
    ),
    content=(
      #|K_Exp_IntLit(Value)
      #|K_Exp_BoolLit(Value)
      #|K_Exp_Add(Value, Value)
      #|K_Exp_If(Value, Value, Value)
      #|K_Exp_IntLit(a0) => Some(("Exp::IntLit", [a0]))
      #|K_Exp_BoolLit(a0) => Some(("Exp::BoolLit", [a0]))
      #|K_Exp_Add(a0, a1) => Some(("Exp::Add", [a0, a1]))
      #|K_Exp_If(a0, a1, a2) => Some(("Exp::If", [a0, a1, a2]))
      #|K_Exp_IntLit(a0) => E_Exp::IntLit(as_int(a0))
      #|K_Exp_BoolLit(a0) => E_Exp::BoolLit(as_bool(a0))
      #|K_Exp_Add(a0, a1) => E_Exp::Add(exp_of_value(a0), exp_of_value(a1))
      #|K_Exp_If(a1, a2, a3) => E_Exp::If(exp_of_value(a1), exp_of_value(a2), exp_of_value(a3))
    ),
  )
}
