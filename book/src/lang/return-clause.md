# return 子句

```text
match e as x in D[_](i) return P(i, x) { … }
```

Rocq 风格的匹配：显式给出动机 `P`，即每个分支的结果类型如何依赖于被匹配的值 `x` 和它的索引
`i`。

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

- `as x` 给被匹配的值命名，`in D[_](i)` 给它的类型中的索引命名，`return P` 是动机；三部分都
  可以省略（如[类型层计算](type-level.md)中的 `match n as m return NAry(m)`）。
- 有 `return` 时按 Rocq 的语义，不细化上下文；没有 `return` 时按
  [依赖匹配与细化](dependent-match.md)。
