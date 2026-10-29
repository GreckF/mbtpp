# Tactics

`proof { … }` builds a proof step by step with tactics, one per line:

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

lemma plus_comm : forall n m : Nat, n + m === m + n = proof {
  intros n m
  destruct n
  rewrite plus_zero(m)
  rfl
  rewrite plus_succ(m, n_0)
  rewrite plus_comm(n_0, m)
  rfl
}
```

| Tactic | Effect |
| --- | --- |
| `intros x y` | Introduce hypotheses (also `intro`; `_` discards one) |
| `exact e` | Close the current goal with the expression `e` |
| `rfl` | Close the goal with `Refl` (both sides normalize to the same term) |
| `destruct x` | Case split on `x`, one new goal per constructor; fields are named `x_0`, `x_1`, … (also `cases`) |
| `rewrite e`, `rewrite <- e` | Rewrite the goal with the equality `e`, left to right or right to left (also `rw`) |
| `apply f` | Reduce the goal to the arguments of the function `f` |
| `assume h : P` | Use `P` as hypothesis `h` now and prove `P` later (also `have`) |

More examples:

```moonbit
enum And[A : Prop, B : Prop] : Prop {
  Conj(A, B)
}

lemma and_comm[A : Prop, B : Prop] : (And[A, B]) -> And[B, A] = proof {
  intros p
  destruct p
  exact Conj(p_1, p_0)
}

lemma modus_ponens[A : Prop, B : Prop] : (A, (A) -> B) -> B = proof {
  intros a f
  apply f
  exact a
}

lemma zero_ne_one : (0 : Nat) === 1 -> Int = proof {
  intros h
  destruct h
}
```

- Tactics are just another way to build proof terms; the result is the same as a hand-written term.
- `destruct` on an impossible equality (such as `0 === 1`) leaves no goals.
- There are no automation tactics such as `simp`, `omega`, or `auto`.
