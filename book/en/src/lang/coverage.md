# Coverage Checking and Impossible Branches

Every `match` must cover all cases; otherwise it is an error:

```text
t.mbtpp:2:3: error: match is not exhaustive; missing case(s):
  S(_)
```

## Impossible branches

When a constructor's indices fail to unify with the scrutinee's type, that branch cannot occur and
can be omitted:

```moonbit
enum Fin : (Nat) -> Type {
  FZ[n : Nat] : Fin(S(n))
  FS[n : Nat](Fin(n)) : Fin(S(n))
}

enum Vector[T] : Nat -> Type {
  Nil : Vector[T](0)
  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
}

// No Nil arm needed: Fin(0) is empty, so Nil can never occur together with a Fin(n)
fn[T, n : Nat] Vector::get(self : Vector[T](n), i : Fin(n)) -> T {
  match (self, i) {
    (Cons(x, _), FZ) => x
    (Cons(_, xs), FS(j)) => xs.get(j)
  }
}

fn main {
  let v : Vector[String](3) = Cons("a", Cons("b", Cons("c", Nil)))
  println(v.get(FS(FS(FZ))))
}
```

You can also write just the pattern without `=>`; the checker then confirms that it really is
impossible (if it is not, it reports "this pattern is not impossible"):

```moonbit
enum V3[T] : Nat -> Type {
  N3 : V3[T](0)
  C3[n : Nat](T, V3[T](n)) : V3[T](S(n))
}

fn[T, n : Nat] V3::head(self : V3[T](S(n))) -> T {
  match self {
    N3
    C3(x, _) => x
  }
}
```

## Empty types

A type that no constructor can match is empty, and a match on it may have no arms. The checker also
recognizes empty types in nested positions; for example, a constructor with a field of type `Fin(0)`
need not be listed. Built-in types (`Int`, `Array`, etc.) are not empty.
