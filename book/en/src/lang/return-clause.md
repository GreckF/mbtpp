# The return Clause

```text
match e as x in D[_](i) return P(i, x) { … }
```

A Rocq-style match: you give the motive `P` explicitly, i.e. how the result type of each arm depends
on the scrutinee `x` and its index `i`.

```moonbit
enum Vector[T] : Nat -> Type {
  Nil : Vector[T](0)
  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
}

fn[T, n : Nat] Vector::length_eq(self : Vector[T](n)) -> Nat {
  match self as v in Vector[_](m) return Nat {
    Nil => Z
    Cons(_, xs) => S(xs.length_eq())
  }
}

fn main {
  let v : Vector[Int](2) = Cons(7, Cons(8, Nil))
  println(v.length_eq().to_int())
}
```

- `as x` names the scrutinee, `in D[_](i)` names the indices in its type, and `return P` is the
  motive; each of the three parts can be omitted (as in `match n as m return NAry(m)` in
  [Type-Level Computation](type-level.md)).
- With `return`, Rocq semantics apply and the context is not refined; without `return`, the match
  works as described in [Dependent Matching and Refinement](dependent-match.md).
