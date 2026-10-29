# 高阶 trait 与 monad

`Self` 可以是类型构造子。Prelude 中的 `Monad`：

```text
trait Monad(Self : [T] -> Type) {
  fn[T] pure(T) -> Self[T]
  fn[T, U] bind(Self[T], (T) -> Self[U]) -> Self[U]
}
```

`Option` 和 `List` 有 `Monad` 实例。

## monad 块

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

- `let x <- m` 绑定 `m` 的结果，之后的语句在 `bind` 的回调中。
- 表达式中的 `<- m` 就地绑定，按从左到右的顺序。
- `monad { … }` 的类型由期望类型或其中的表达式推断出用哪个 `Monad` 实例。
