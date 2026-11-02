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
| `Id::subst(p, motive, px)` | from `x === y` and `motive(x)` derive `motive(y)`; `motive` may return `Type` |

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
(certified caches, hash tables), use `deq`, whose result is a `Dec[a === b]`:

```text
enum Dec[P : Prop] {
  Yes(P)      // with a proof
  No
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
        No => find(k, rest)
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
  `==` is structural equality, so a comparison that succeeds proves the equality: the axiom
  `T::eq_sound : (a == b) === true -> a === b` says so; it is not computed during checking and is
  erased when compiling. `Double` has none: `0.0 == -0.0`, but they are different values.
- The `deq` of `Bool`, `Unit` and `Nat` are ordinary definitions (`Nat`'s compares integers at run
  time).
- The trait `DecEq : Eq` has the method `deq(a : Self, b : Self) -> Dec[a === b]`. The types above
  have instances, and so do `Option`, `List`, pairs and triples of such types.
- `derive(DecEq)` works on enums and structs: it compares the constructors, `deq`s the fields one by
  one, and matches their proofs with `Refl` to get the `Refl` of the whole value. It also derives
  `Eq` (which `DecEq` needs).
- `reflect(b)` has the type `Reflect(b)`, which is `IsTrue(b === true)` or `IsFalse(b === false)`:
  it gives the value of a Boolean expression together with a proof, in the arms of a match.

## Pointer equality

`physical_equal(a, b)` is MoonBit's `physical_equal`: whether the values are the same object (when
it is `false`, they may still be equal). `ptr_deq(a, b)` gives `Yes(proof)` for the same object, a
fast path before a structural comparison. Neither is computed during checking, so they give no
proofs there.
