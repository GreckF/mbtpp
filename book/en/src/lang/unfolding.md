# Controlled Unfolding

During type checking, functions are unfolded (computed) by default, which is why `2 + 2 === 4` can be
proved by `Refl`. But proofs that depend on the definition of a function have a cost: changing the
definition (making addition recurse on its second argument, say) breaks every proof that depends on
it, and unfolding or running large definitions slows checking down, possibly beyond the
[time limit](type-level.md#time-limits).

`#opaque` makes a function not unfold during type checking, except where unfolding is asked for:

```moonbit
#opaque
fn add(m : Nat, n : Nat) -> Nat {
  match m {
    Z => n
    S(k) => S(add(k, n))
  }
}

// only these two lemmas depend on the definition of add
#unfold(add)
lemma add_z(n : Nat) -> add(Z, n) === n { Refl }

#unfold(add)
lemma add_s(m : Nat, n : Nat) -> add(S(m), n) === S(add(m, n)) { Refl }

// the other proofs only use the lemmas above
lemma add_n_z(n : Nat) -> add(n, Z) === n {
  match n {
    Z => add_z(Z)
    S(k) => Id::trans(add_s(k, Z), Id::cong(S, add_n_z(k)))
  }
}

fn main {
  println(add(3, 4).to_int())
}
```

`add` is still an ordinary function, and running and compiling it is not affected; only, during type
checking, `add(Z, n)` is not computed to `n`, and stays as it is, like a call of an unknown function.
When the definition of `add` changes, only `add_z` and `add_s` need new proofs.

## Three ways to unfold

| Notation | Scope |
| --- | --- |
| `#unfold(f, g)` before a declaration | the definition of the declaration |
| `unfold(f, g) { e }` | the expression `e`, which may be in a type |
| the tactic `unfold f, g` in `proof { … }` | the rest of the proof |

```moonbit
#opaque
fn add(m : Nat, n : Nat) -> Nat {
  match m {
    Z => n
    S(k) => S(add(k, n))
  }
}

lemma two_plus_two() -> add(2, 2) === 4 {
  unfold(add) { Refl }
}

lemma two_plus_two_t : add(2, 2) === 4 = proof {
  unfold add
  rfl
}
```

- `#unfold` applies to the definition, not to the type of the declaration; to unfold in the type,
  write `unfold(f) { … }` in the type.
- An `unfold` block or tactic in a declaration makes the declaration unfold these functions, as
  `#unfold` does (see transitivity below).
- An opaque function can be unfolded in its own definition, in recursive calls for instance.
- When something cannot be unfolded, the error has a hint:

  ```text
  t.mbtpp:8:35: error: type mismatch
    expected: add(1, 1) === 2
    ...
  hint: add is opaque here; if the definition is needed, add #unfold(add) to the declaration, or use unfold(add) { … }
  ```

## Transitivity

Unfolding a function also unfolds the functions it unfolds. The type of `app` below uses `add`, and
its definition is well typed only if `add` computes, so it has `#unfold(add)`; a proof that unfolds
`app` can therefore compute `add` too:

```moonbit
#opaque
fn add(m : Nat, n : Nat) -> Nat {
  match m {
    Z => n
    S(k) => S(add(k, n))
  }
}

enum Vec[T] : Nat -> Type {
  VNil : Vec[T](0)
  VCons[n : Nat](T, Vec[T](n)) : Vec[T](S(n))
}

#opaque
#unfold(add)
fn[T, m : Nat, n : Nat] app(u : Vec[T](m), v : Vec[T](n)) -> Vec[T](add(m, n)) {
  match u {
    VNil => v
    VCons(x, r) => VCons(x, app(r, v))
  }
}

// app(VNil, v) has the type Vec[T](add(0, n)), and v the type Vec[T](n):
// stating the equation unfolds add in the type; the proof unfolds app, and
// thus add
#unfold(app)
lemma app_nil[T, n : Nat](v : Vec[T](n)) -> app(VNil, v) === unfold(add) { v } {
  Refl
}
```

A function without `#opaque` but with `#unfold(f)` is unfolded only where `f` can be: its definition
relies on `f` computing, and unfolding it where `f` does not would be of no use.

## Not run

Functions with mutable state are run during type checking (see
[Mutable State and Loops](mutation.md#interaction-with-type-checking)). Opaque functions are not run
outside the scope of an unfolding either, which avoids needless computation during checking:

```moonbit
#opaque
fn sum_to(n : Int) -> Int {
  let mut acc = 0
  for i = 1; i <= n; i = i + 1 {
    acc = acc + i
  }
  acc
}

#unfold(sum_to)
lemma sum_10() -> sum_to(10) === 55 { Refl }
```

## `#opaque(sealed)`

A function marked `#opaque(sealed)` can never be unfolded (except in its own definition): naming it
in `#unfold` or `unfold` is an error. This ensures that other code uses the function only through
the lemmas stated about it.

## Notes

- `#opaque` and `#unfold` can be written on `fn` and `lemma` (methods included), together with
  `#mbt` and `#timelimit`. Functions without them (including the functions of the Prelude and the
  instances of traits) unfold as usual.
- Opacity only affects type checking: the interpreter, the compiler and erasure are not affected.
- Errors in arguments propagate as usual: `f(raise e)` is `raise e`, whether `f` unfolds or not (see
  [Errors as values of the logic](errors.md#errors-as-values-of-the-logic)).
- The mechanism comes from *Controlling Unfolding in Type Theory* by Gratzer et al.; unlike in the
  paper, MoonBit++ functions are transparent by default. The design notes are in
  `doc/mbtpp/unfolding.md` in the repository.
