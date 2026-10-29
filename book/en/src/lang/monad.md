# Higher-Kinded Traits and Monads

`Self` can be a type constructor. `Monad` in the Prelude:

```text
trait Monad(Self : [T] -> Type) {
  fn[T] pure(T) -> Self[T]
  fn[T, U] bind(Self[T], (T) -> Self[U]) -> Self[U]
}
```

`Option` and `List` have `Monad` instances.

## monad blocks

```moonbit
fn[M : Monad, T, U, V] lift2(f : (T, U) -> V, m : M[T], n : M[U]) -> M[V] {
  monad {
    let t <- m
    let u <- n
    Monad::pure(f(t, u))
  }
}

fn[M : Monad, T, U, V] lift2_inline(f : (T, U) -> V, m : M[T], n : M[U]) -> M[V] {
  monad {
    Monad::pure(f(<- m, <- n))
  }
}

fn main {
  println(lift2((a, b) => a + b, Some(1), Some(2)))
  println(lift2_inline((a, b) => a + b, Some(1), None))
  let xs : List[Int] = Cons(1, Cons(2, Nil))
  let ys : List[Int] = Cons(10, Cons(20, Nil))
  println(lift2_inline((a, b) => a * b, xs, ys))
}
```

- `let x <- m` binds the result of `m`; the statements after it go into the `bind` callback.
- `<- m` inside an expression binds in place, from left to right.
- The `Monad` instance a `monad { … }` block uses is inferred from the expected type or from the
  expressions inside it.
