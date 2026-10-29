# Propositions and Proofs

Propositions are types in `Prop`, and proofs are their values. The type checker computes (normalizes)
expressions while checking proofs, so many equalities follow directly by computation.

- [Propositional Equality](equality.md): `===`, `Refl`, and the equality lemmas in the Prelude.
- [lemma](lemma.md): declaring theorems.
- [Tactics](tactics.md): building proofs step by step with `proof { … }`.

User-defined propositions are enums whose universe is `Prop`:

```moonbit
enum And[A : Prop, B : Prop] : Prop {
  Conj(A, B)
}

lemma and_comm[A : Prop, B : Prop](p : And[A, B]) -> And[B, A] {
  match p {
    Conj(a, b) => Conj(b, a)
  }
}
```

> There is no termination checking and no strict positivity checking: recursive functions and
> recursive proofs are accepted as they are, so false propositions can be "proved". Proofs are also
> not erased at compile time.
