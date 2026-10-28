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
