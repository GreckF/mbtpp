# Propositional Equality

`a === b` is `Id[_](a)(b)` from the Prelude:

```text
enum Id[T](x : T) : (y : T) -> Prop {
  Refl : Id[T](x)(x)
}
```

`Refl` is the only constructor, and it proves `x === x`. Because type checking computes, any equality
whose two sides normalize to the same term can be proved directly with `Refl`:

```moonbit
lemma two_plus_two : (2 : Nat) + 2 === 4 = Refl

lemma plus_zero_left(n : Nat) -> (0 : Nat) + n === n {
  Refl
}
```

`0 + n` computes to `n` by the definition of `Nat::op_add`; `n + 0` cannot be computed directly
(`n` is a variable) and needs induction; see [lemma](lemma.md).

## Equality lemmas

| Lemma | Type |
| --- | --- |
| `Id::sym(p)` | from `x === y` derive `y === x` |
| `Id::trans(p, q)` | from `x === y` and `y === z` derive `x === z` |
| `Id::cong(f, p)` | from `x === y` derive `f(x) === f(y)` |
| `Id::subst(p, motive, px)` | from `x === y` and `motive(x)` derive `motive(y)`; `motive` returns `Type` |
| `Id::subst_prop(p, motive, px)` | the same, with a `motive` returning `Prop` (rewriting a proposition, e.g. `NatLe(a, b)` to `NatLe(a, c)`) |

`===` is a subsingleton, so you can match on `Refl` to rewrite types, even when the result is in `Type`:

```moonbit
fn[a : Nat, b : Nat] cast(e : a === b, xs : Array[Int]) -> Array[Int] {
  match e {
    Refl => xs
  }
}
```

`==` is not the same as `===`: `==` compares values, producing a `Bool` that can be computed at run
time; `===` is a proposition.

## Decidable equality

`a == b` being `true` does not give `a === b` in the logic. When a comparison should give a proof
(certified caches, hash tables), use `deq`, whose result is a `Dec[a === b]`, as Lean's `Decidable`:

```text
enum False : Prop {}               // the proposition without proofs
fn Not(P : Prop) -> Prop { (P) -> False }
fn[T] absurd(f : False) -> T       // anything from a contradiction

enum Dec[P : Prop] {
  Yes(P)                           // a proof of the equality
  No(Not(P))                       // a proof that it does not hold
}
```

```moonbit
enum Color {
  Red
  Rgb(Int, Int, Int)
} derive(DecEq)

// a lookup by key: when found, with a proof that the keys are equal
fn[K : DecEq, V] find(k : K, xs : List[(K, V)]) -> Option[V] {
  match xs {
    Nil => None
    Cons((k2, v), rest) =>
      match DecEq::deq(k, k2) {
        Yes(_) => Some(v)
        No(_) => find(k, rest)
      }
  }
}

lemma three : Int::deq(3, 3) === Yes(Refl) = Refl

fn main {
  println(find(2, Cons((1, "one"), Cons((2, "two"), Nil))))
  println(DecEq::deq(Rgb(1, 2, 3), Rgb(1, 2, 3)) is Yes(_))
}
```

- `Int`, `Int64`, `UInt`, `UInt64`, `Byte`, `Char`, `String` and `BigInt` have `T::deq(a, b)`. Their
  `==` is structural equality, so a comparison proves the equality or that it does not hold: the
  axioms `T::eq_sound : (a == b) === true -> a === b` and `T::ne_sound : (a == b) === false ->
  Not(a === b)` say so; they are not computed during checking and are erased when compiling. `Double` has none: `0.0 == -0.0`, but they are different values.
- The `deq` of `Bool`, `Unit` and `Nat` are ordinary definitions (`Nat`'s compares integers at run
  time).
- The trait `DecEq : Eq` has the method `deq(a : Self, b : Self) -> Dec[a === b]`. The types above
  have instances, and so do `Option`, `List`, pairs and triples of such types.
- `derive(DecEq)` works on enums and structs: it compares the constructors, `deq`s the fields one by
  one, and matches their proofs with `Refl` to get the `Refl` of the whole value; otherwise the
  refutation of a field (or different constructors) refutes the whole. It also derives `Eq` (which
  `DecEq` needs).
- `reflect(b)` has the type `Reflect(b)`, which is `IsTrue(b === true)` or `IsFalse(b === false)`:
  it gives the value of a Boolean expression together with a proof, in the arms of a match.

With the refutation in `No`, functions defined with `deq` have properties provable on variables: the
`No` arm of `deq(p, p)` is ruled out with `absurd`.

```moonbit
fn upd(rho : (String) -> Nat, p : String, m : Nat) -> (String) -> Nat {
  n => match String::deq(n, p) {
    Yes(_) => m
    No(_) => rho(n)
  }
}

lemma upd_same(rho : (String) -> Nat, p : String, m : Nat) -> upd(rho, p, m)(p) === m {
  match String::deq(p, p) {
    Yes(_) => Refl
    No(nope) => absurd(nope(Refl))
  }
}

lemma upd_other(rho : (String) -> Nat, p : String, q : String, m : Nat, ne : Not(q === p)) ->
  upd(rho, p, m)(q) === rho(q) {
  match String::deq(q, p) {
    Yes(e) => absurd(ne(e))
    No(_) => Refl
  }
}
```

## Pointer equality

`physical_equal(a, b)` is MoonBit's `physical_equal`: whether the values are the same object (when
it is `false`, they may still be equal). `ptr_deq(a, b)` is a `Known[a === b]`: `Proved(proof)` for
the same object, `Unknown` otherwise (different objects may still be equal); a fast path before a
structural comparison. Neither is computed during checking, so they give no
proofs there.
