///|
/// Programs that must be rejected, and a few small positive checks.
fn check(src : String) -> String {
  check_source("t.mbtpp", src)
}

///|
test "non-exhaustive match" {
  inspect(
    check(
      (
        #|fn f(n : Nat) -> Int {
        #|  match n {
        #|    Z => 0
        #|  }
        #|}
      ),
    ),
    content=(
      #|t.mbtpp:2:3: error: match is not exhaustive; missing case(s):
      #|  S(_)
    ),
  )
}

///|
test "impossible case that is possible" {
  inspect(
    check(
      (
        #|fn f(n : Nat) -> Int {
        #|  match n {
        #|    Z
        #|    S(_) => 1
        #|  }
        #|}
      ),
    ),
    content="t.mbtpp:3:5: error: this pattern is not impossible",
  )
}

///|
test "type mismatch" {
  inspect(
    check("fn f(x : Int) -> String { x }"),
    content=(
      #|t.mbtpp:1:27: error: type mismatch
      #|  expected: String
      #|  actual:   Int
    ),
  )
}

///|
test "uncurried: too few arguments" {
  inspect(
    check(
      (
        #|fn add(a : Int, b : Int) -> Int { a + b }
        #|fn main { println(add(1)(2)) }
      ),
    ),
    content="t.mbtpp:2:22: error: expected 2 argument(s), got 1",
  )
}

///|
test "uncurried: curried function called with two arguments" {
  inspect(
    check(
      (
        #|fn add(a : Int) -> (Int) -> Int { b => a + b }
        #|fn main { println(add(1, 2)) }
      ),
    ),
    content="t.mbtpp:2:22: error: expected 1 argument(s), got 2",
  )
}

///|
test "uncurried: groups are different types" {
  inspect(
    check(
      (
        #|fn f(g : (Int, Int) -> Int) -> Int { g(1, 2) }
        #|fn h(a : Int) -> (Int) -> Int { b => a }
        #|fn main { println(f(h)) }
      ),
    ),
    content=(
      #|t.mbtpp:3:21: error: type mismatch
      #|  expected: (Int, Int) -> Int
      #|  actual:   (a : Int) -> (Int) -> Int
    ),
  )
}

///|
test "prop elimination into Type" {
  inspect(
    check(
      (
        #|enum Or[A : Prop, B : Prop] : Prop {
        #|  Inl(A)
        #|  Inr(B)
        #|}
        #|fn[A : Prop, B : Prop] which(p : Or[A, B]) -> Bool {
        #|  match p {
        #|    Inl(_) => true
        #|    Inr(_) => false
        #|  }
        #|}
      ),
    ),
    content="t.mbtpp:6:3: error: cannot eliminate a proof of Or into a type that is not a proposition",
  )
}

///|
test "prop elimination into Prop is fine" {
  inspect(
    check(
      (
        #|enum Or[A : Prop, B : Prop] : Prop {
        #|  Inl(A)
        #|  Inr(B)
        #|}
        #|fn[A : Prop, B : Prop] swap(p : Or[A, B]) -> Or[B, A] {
        #|  match p {
        #|    Inl(a) => Inr(a)
        #|    Inr(b) => Inl(b)
        #|  }
        #|}
      ),
    ),
    content="ok",
  )
}

///|
test "proof irrelevance" {
  inspect(
    check(
      (
        #|fn[P : Prop] irrelevant(p : P, q : P) -> p === q { Refl }
      ),
    ),
    content="ok",
  )
}

///|
test "raise outside a raising function" {
  inspect(
    check("fn f() -> Int { raise Failure(\"x\") }"),
    content="t.mbtpp:1:17: error: `raise` outside of a function declared with `raise`",
  )
}

///|
test "calling a raising function" {
  inspect(
    check(
      (
        #|fn f() -> Int raise Failure { fail("x") }
        #|fn g() -> Int { f() }
      ),
    ),
    content="t.mbtpp:2:18: error: this call may raise an error; use it inside `try` or in a function declared with `raise`",
  )
}

///|
test "assignment to an immutable variable" {
  inspect(
    check("fn f() -> Unit { let x = 1; x = 2 }"),
    content="t.mbtpp:1:29: error: x is not a mutable variable",
  )
}

///|
test "missing instance" {
  inspect(
    check(
      (
        #|enum Color { Red }
        #|fn main { println(Red) }
      ),
    ),
    content="t.mbtpp:2:18: error: no instance of Show(Color)",
  )
}

///|
test "wrong index" {
  inspect(
    check(
      (
        #|enum Vector[T] : Nat -> Type {
        #|  Nil : Vector[T](0)
        #|  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
        #|}
        #|fn bad() -> Vector[Int](2) { Cons(1, Nil) }
      ),
    ),
    content=(
      #|t.mbtpp:5:34: error: type mismatch
      #|  expected: Vector[Int](2)
      #|  actual:   Vector[Int](1)
    ),
  )
}

///|
test "type-level computation" {
  inspect(
    check(
      (
        #|fn two() -> Nat { 1 + 1 }
        #|lemma two_eq : two(()) === 2 = Refl
        #|lemma plus_comm_ex : plus(2, 3) === plus(3, 2) = Refl
      ),
    ),
    content="ok",
  )
}

///|
test "functions with mutation do not reduce in types" {
  inspect(
    check(
      (
        #|fn one() -> Int { let mut x = 0; x = x + 1; x }
        #|lemma bad : one(()) === 1 = Refl
      ),
    ),
    content=(
      #|t.mbtpp:2:29: error: type mismatch
      #|  expected: one(()) === 1
      #|  actual:   ?86 === ?86
    ),
  )
}

///|
test "implicit binder defaults to Type" {
  inspect(
    check("fn[T] id(x : T) -> T { x }\nlemma t : id(3) === 3 = Refl"),
    content="ok",
  )
}

///|
test "unsolved goals" {
  inspect(
    check("lemma l : forall n : Nat, plus(n, 0) === n = proof { intros n }"),
    content=(
      #|t.mbtpp:1:54: error: unsolved goal(s); the first is
      #|  plus(n, 0) === n
      #|in context n
    ),
  )
}

///|
let stlc_prelude : String =
  #|enum Vector[T] : Nat -> Type {
  #|  Nil : Vector[T](0)
  #|  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
  #|}
  #|enum Fin : (Nat) -> Type {
  #|  FZ[n : Nat] : Fin(S(n))
  #|  FS[n : Nat](Fin(n)) : Fin(S(n))
  #|}
  #|enum Ty {
  #|  TInt
  #|  TArr(Ty, Ty)
  #|}
  #|enum Ctx {
  #|  Empty
  #|  Ext(Ctx, Ty)
  #|}
  #|enum Elem : (Ctx, Ty) -> Type {
  #|  Here[g : Ctx, t : Ty] : Elem(Ext(g, t), t)
  #|  There[g : Ctx, t : Ty, s : Ty](Elem(g, t)) : Elem(Ext(g, s), t)
  #|}
  #|enum Term : (Ctx, Ty) -> Type {
  #|  Var[g : Ctx, t : Ty](Elem(g, t)) : Term(g, t)
  #|  Lit[g : Ctx](Int) : Term(g, TInt)
  #|  App[g : Ctx, a : Ty, b : Ty](Term(g, TArr(a, b)), Term(g, a)) : Term(g, b)
  #|}
  #|

///|
test "regression: a variable of a built-in type is not empty" {
  inspect(
    check(
      (
        #|fn f(x : Int, n : Nat) -> Int {
        #|  match n {
        #|    Z => 0
        #|  }
        #|}
      ),
    ),
    content=(
      #|t.mbtpp:2:3: error: match is not exhaustive; missing case(s):
      #|  S(_)
    ),
  )
}

///|
test "empty index type makes a case impossible" {
  inspect(
    check(
      stlc_prelude +
      (
        #|fn[T, n : Nat] get(v : Vector[T](n), i : Fin(n)) -> T {
        #|  match (v, i) {
        #|    (Nil, _)
        #|    (Cons(x, _), FZ) => x
        #|    (Cons(_, xs), FS(j)) => get(xs, j)
        #|  }
        #|}
      ),
    ),
    content="ok",
  )
}

///|
test "indexing an empty vector" {
  inspect(
    check(
      stlc_prelude +
      (
        #|fn[T, n : Nat] get(v : Vector[T](n), i : Fin(n)) -> T {
        #|  match (v, i) {
        #|    (Cons(x, _), FZ) => x
        #|    (Cons(_, xs), FS(j)) => get(xs, j)
        #|  }
        #|}
        #|fn bad() -> Int { get(Vector::Nil, FZ) }
      ),
    ),
    content=(
      #|t.mbtpp:32:36: error: type mismatch
      #|  expected: Fin(0)
      #|  actual:   Fin(S(?92(_)))
    ),
  )
}

///|
test "ill-typed object term" {
  inspect(
    check(
      stlc_prelude + "fn bad() -> Term(Empty, TInt) { App(Lit(1), Lit(2)) }",
    ),
    content=(
      #|t.mbtpp:26:40: error: type mismatch
      #|  expected: Term(?86(_), TArr(?87(_), ?88(_)))
      #|  actual:   Term(?89(_), TInt)
    ),
  )
}

///|
test "unbound object variable" {
  inspect(
    check(stlc_prelude + "fn bad() -> Term(Empty, TInt) { Var(Here) }"),
    content=(
      #|t.mbtpp:26:36: error: type mismatch
      #|  expected: Term(Empty, TInt)
      #|  actual:   Term(Ext(?88(_), ?89(_)), ?89(_))
    ),
  )
}

///|
test "no termination check: a looping proof is accepted (by design)" {
  inspect(check("lemma bad(n : Nat) -> n === S(n) { bad(n) }"), content="ok")
}

///|
let labelled_prelude : String =
  #|fn f(x : Int, a~ : Int, b~ : Int = 1, c? : Int) -> Int { x + a + b }
  #|

///|
test "tagged: missing labelled argument" {
  inspect(
    check(labelled_prelude + "fn main { println(f(1)) }"),
    content="t.mbtpp:2:20: error: missing labelled argument a~",
  )
}

///|
test "tagged: unknown label" {
  inspect(
    check(labelled_prelude + "fn main { println(f(1, a=2, d=3)) }"),
    content="t.mbtpp:2:29: error: no labelled parameter d",
  )
}

///|
test "tagged: argument given twice" {
  inspect(
    check(labelled_prelude + "fn main { println(f(1, a=2, a=3)) }"),
    content="t.mbtpp:2:29: error: argument a is given twice",
  )
}

///|
test "tagged: `?=` on a parameter that is not optional" {
  inspect(
    check(labelled_prelude + "fn main { println(f(1, a?=Some(2))) }"),
    content="t.mbtpp:2:24: error: `a?=` is only for parameters declared `a?`",
  )
}

///|
test "tagged: too many positional arguments" {
  inspect(
    check(labelled_prelude + "fn main { println(f(1, 2, a=3)) }"),
    content="t.mbtpp:2:20: error: too many positional arguments",
  )
}

///|
test "tagged: wrong type for an optional argument" {
  inspect(
    check(labelled_prelude + "fn main { println(f(1, a=2, c=\"x\")) }"),
    content=(
      #|t.mbtpp:2:29: error: type mismatch
      #|  expected: Option[Int]
      #|  actual:   Option[String]
    ),
  )
}

///|
test "tagged: lambdas cannot have labelled parameters" {
  inspect(
    check("fn main { let g = fn(x~ : Int) { x }; println(g(x=1)) }"),
    content="t.mbtpp:1:22: error: only top-level functions can have labelled parameters",
  )
}

///|
test "tagged: all accepted call forms" {
  inspect(
    check(
      labelled_prelude +
      (
        #|fn main {
        #|  let a = 2
        #|  let c : Int? = None
        #|  println(f(1, a~))
        #|  println(f(b=5, a=1, 0))
        #|  println(f(1, a=2, c=3))
        #|  println(f(1, a=2, c?))
        #|  println(f(1, a=2, c?=Some(4)))
        #|}
      ),
    ),
    content="ok",
  )
}

///|
test "mbt: translatable declarations" {
  inspect(
    check(
      (
        #|#mbt
        #|enum Tree[T] {
        #|  Leaf
        #|  Node(Tree[T], T, Tree[T])
        #|}
        #|#mbt
        #|struct Point { x : Double; y : Double }
        #|#mbt
        #|trait Size { size(Self) -> Int; zero() -> Self }
        #|impl[T : Size] Size for Tree[T] with size(self) {
        #|  match self {
        #|    Leaf => 0
        #|    Node(l, x, r) => l.size() + x.size() + r.size()
        #|  }
        #|}
        #|impl[T : Size] Size for Tree[T] with zero() { Leaf }
        #|impl Size for Int with size(self) { self }
        #|impl Size for Int with zero() { 0 }
        #|fn main { println(Node(Leaf, 3, Leaf).size()) }
      ),
    ),
    content="ok",
  )
}

///|
test "mbt: indexed types are rejected" {
  inspect(
    check(
      (
        #|#mbt
        #|enum Vec[T] : (n : Nat) -> Type {
        #|  VNil : Vec[T](Z)
        #|}
      ),
    ),
    content="t.mbtpp:1:1: error: #mbt Vec: indexed types have no MoonBit type",
  )
}

///|
test "mbt: fields need MoonBit types" {
  inspect(
    check("#mbt\nstruct P { n : Nat }"),
    content="t.mbtpp:1:1: error: #mbt P: the field n of P::mk has type Nat, which has no MoonBit type",
  )
  inspect(
    check("#mbt\nenum E { A(Int); b }"),
    content="t.mbtpp:1:1: error: #mbt E: constructor E::b must start with an upper case letter",
  )
  inspect(
    check("#mbt\nenum Value { A }"),
    content=(
      #|t.mbtpp:1:1: error: #mbt Value: Value cannot be the name of a generated MoonBit type (use #mbt("name") for an existing one)
    ),
  )
}

///|
test "mbt: traits" {
  inspect(
    check("#mbt\ntrait T { fn[A] m(Self, A) -> Int }"),
    content="t.mbtpp:1:1: error: #mbt T: the method m is generic",
  )
  inspect(
    check("trait S { s(Self) -> Int }\n#mbt\ntrait T : S { m(Self) -> Int }"),
    content="t.mbtpp:2:1: error: #mbt T: the supertrait S is not #mbt",
  )
  inspect(
    check(
      (
        #|#mbt
        #|trait T { m(Self) -> Int }
        #|impl T for Nat with m(self) { 0 }
      ),
    ),
    content="t.mbtpp:3:1: error: impl of #mbt trait T: the type Nat has no MoonBit type",
  )
  inspect(
    check(
      (
        #|#mbt("Hash")
        #|trait H { m(Self) -> Int }
        #|impl H for Int with m(self) { 0 }
      ),
    ),
    content="t.mbtpp:3:1: error: impl of #mbt trait H: MoonBit does not allow implementing the existing trait Hash for a type that is not generated by this program",
  )
}

///|
test "mbt: functions" {
  inspect(
    check("#mbt\nfn f(n : Nat) -> Int { 0 }"),
    content="t.mbtpp:1:1: error: #mbt fn f: the parameter n has type Nat, which has no MoonBit type",
  )
  inspect(
    check("#mbt\nfn[T : Show] f(x : T) -> String { x.to_string() }"),
    content="t.mbtpp:1:1: error: #mbt fn f: the bound Show(T) is not a #mbt trait bound of a type parameter",
  )
  inspect(
    check("#mbt\nfn Nat::twice(self : Nat) -> Nat { self + self }"),
    content="t.mbtpp:1:1: error: #mbt fn Nat::twice: a method must belong to a type generated by this program (a #mbt type without a name)",
  )
  inspect(
    check("#mbt\nfn f(x~ : Int = 1) -> Int { x }"),
    content="t.mbtpp:1:1: error: #mbt fn f: default arguments are not supported",
  )
  inspect(
    check("#mbt\nfn f(xs : Array[Int]) -> Int { 0 }"),
    content="t.mbtpp:1:1: error: #mbt fn f: the parameter xs has type Array[Int], which does not translate to MoonBit (arrays are not supported yet)",
  )
}

///|
fn check_files(files : Array[(String, String)]) -> String {
  @tt.check_package(files) catch {
    @tt.CheckError(msg) => return msg
  }
  "ok"
}

///|
test "file order: a hint when a later file's function is needed" {
  let shapes = (
    "shapes.mbtpp", "enum Shape { Sq(Int) }\nfn Shape::area(self : Shape) -> Int { match self { Sq(n) => n * n } }",
  )
  let facts = ("facts.mbtpp", "lemma area3 : Sq(3).area() === 9 = Refl")
  inspect(
    check_files([facts, shapes]),
    content=(
      #|facts.mbtpp:1:36: error: type mismatch
      #|  expected: Shape::area(Sq(3)) === 9
      #|  actual:   ?86 === ?86
      #|hint: Shape::area is defined in shapes.mbtpp, which is checked after facts.mbtpp, so its definition could not be used here; the error may come from that. Files are checked in dictionary order; to check shapes.mbtpp first, list it in the package's moon.pkg: options("mbtpp-order": [ "shapes.mbtpp", ... ])
    ),
  )
  inspect(check_files([shapes, facts]), content="ok")
}
