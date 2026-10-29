# lemma

A `lemma` is the same as a `fn`, except that its result is usually a proposition. There are two forms:

- `lemma name[implicits](params) -> proposition { proof }`
- `lemma name[implicits] : proposition = proof expression`

Induction is done with pattern matching and recursion:

```moonbit
lemma plus_zero(n : Nat) -> n + 0 === n {
  match n {
    Z => Refl
    S(k) => Id::cong(S, plus_zero(k))
  }
}

lemma plus_succ(n : Nat, m : Nat) -> n + S(m) === S(n + m) {
  match n {
    Z => Refl
    S(k) => Id::cong(S, plus_succ(k, m))
  }
}

lemma append_nil[T](xs : List[T]) -> xs.append(Nil) === xs {
  match xs {
    Nil => Refl
    Cons(x, rest) => Id::cong(r => List::Cons(x, r), append_nil(rest))
  }
}
```

- In the `Z` arm, both sides of the goal `0 + 0 === 0` compute to the same term, so `Refl` works.
- In the `S(k)` arm, the goal is `S(k) + 0 === S(k)`, which computes to `S(k + 0) === S(k)`; it
  follows from the recursively obtained `k + 0 === k` via `Id::cong(S, …)`.
- The recursive call is the induction hypothesis. The checker does not verify that the recursion
  terminates.

For longer proofs, see `examples/proofs.mbtpp` in the repository (associativity of vector append,
properties of `reverse`) and `examples/stlc.mbtpp` (substitution lemmas, progress, and canonicity for
the simply typed λ-calculus, plus an evaluator extracted from the canonicity proof).
