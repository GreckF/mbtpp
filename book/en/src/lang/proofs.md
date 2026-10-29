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
> recursive proofs are accepted as they are, so false propositions can be "proved".
>
> Propositions are proof irrelevant: two proofs of a proposition are equal, and a proof is
> eliminated only into a proposition, or into any type when the proposition is a subsingleton (at
> most one constructor, whose fields are proofs, like `===`). So no value depends on a proof, and
> all proofs are erased at compile time (see [Compiling to MoonBit](../interop/compile.md)). A cast
> with a false proof (`Id::subst`) does not hang in a compiled program on the infinite recursion;
> it fails at run time where the types do not match.
