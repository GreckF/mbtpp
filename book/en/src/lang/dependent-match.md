# Dependent Matching and Refinement

When you match on a variable, the constructor's indices are unified with the indices in the
variable's type, and the result refines the whole context and the goal type (Agda style):

```moonbit
enum Vec2[T] : Nat -> Type {
  VNil : Vec2[T](0)
  VCons[n : Nat](T, Vec2[T](n)) : Vec2[T](S(n))
}

fn[T, n : Nat] Vec2::zip_with(self : Vec2[T](n), other : Vec2[T](n), f : (T, T) -> T) -> Vec2[T](n) {
  match (self, other) {
    (VNil, VNil) => VNil
    (VCons(x, xs), VCons(y, ys)) => VCons(f(x, y), xs.zip_with(ys, f))
  }
}

fn main {
  let v : Vec2[Int](2) = VCons(1, VCons(2, VNil))
  match v.zip_with(v, (a, b) => a + b) {
    VCons(x, _) => println(x)
  }
}
```

- When `self` matches `VNil`, unification yields `n = 0`. So `other : Vec2[T](0)` can only be `VNil`,
  and combinations like `(VNil, VCons(…))` need not be written.
- In each arm the goal type `Vec2[T](n)` is refined too: the `VNil` arm returns `Vec2[T](0)`, and the
  `VCons` arm returns `Vec2[T](S(n'))`.
- Matching on implicit parameters refines as well. In `fn[T, n : Nat] first_or(v : Vector[T](n), d : T)`,
  for example, `match n { … }` gives `v : Vector[T](S(_))` in the `S(_)` arm, so a `match` on `v`
  there only needs the `Cons` arm.

## Matching on the result of a function call

When the scrutinee is not a variable (e.g. a function call), the index relationships in its result
type are still used to refine the goal type. The fragment below comes from the type safety proof of
the simply typed λ-calculus: `progress(t1)` has the type `Progress(t1)`, and its result says that
the term `t1` can take a step (`PrStep`) or is a value (`PrDone`). In the `PrDone(_, VLam(b))` arm,
the index of the constructor is unified with `t1`, so the checker knows that `t1` is `Lam(b)`, and
`StApp(b, t2)` is a step of `App(t1, t2)`:

```text
match progress(t1) {
  PrStep(_, u1, st1) => PrStep(_, _, StApp1(t1, u1, t2, st1))
  PrDone(_, VLam(b)) => PrStep(_, _, StApp(b, t2))
}
```

See `examples/stlc.mbtpp` in the repository for the full example.

## Matching on an expression of the goal

In a proof (when the goal is a proposition), an expression being matched that occurs in the goal is
first abstracted into a new variable, which is then matched dependently: in each arm, the expression
is replaced by the pattern of the arm in the goal (as Agda's `with` does). The expression may occur
in the definitions of the functions the goal mentions: the checker unfolds a few levels to find it.

```moonbit
fn insert(x : Int, xs : List[Int]) -> List[Int] {
  match xs {
    Nil => Cons(x, Nil)
    Cons(y, rest) => if x <= y { Cons(x, xs) } else { Cons(y, insert(x, rest)) }
  }
}

fn length(xs : List[Int]) -> Nat {
  match xs {
    Nil => Z
    Cons(_, r) => S(length(r))
  }
}

lemma insert_length(x : Int, xs : List[Int]) -> length(insert(x, xs)) === S(length(xs)) {
  match xs {
    Nil => Refl
    Cons(y, rest) =>
      // the definition of insert in the goal has `x <= y`: it is true in
      // the true arm
      match x <= y {
        true => Refl
        false => Id::cong(S, insert_length(x, rest))
      }
  }
}
```

- This is done only when the goal is a proposition; a `match` in an ordinary function is not
  affected.
- Literal patterns (`true`, `0`, `"a"`) refine the matched variable too: in the arm, the variable is
  that literal.

## Eliminating Prop

When matching on data in `Prop` (proofs), the result must also be in `Prop`: proofs are erased by
compilation, so the program cannot choose an arm by them at run time. The exception is a
**subsingleton**: a proposition with at most one constructor, whose fields are all proofs, such as
propositional equality `===`. Matching on it chooses nothing at run time, so the result can have any
type (see [Propositions and proofs](proofs.md)).
