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
