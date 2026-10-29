# 覆盖检查与不可能分支

每个 `match` 都要覆盖所有情况，否则报错：

```text
t.mbtpp:2:3: error: match is not exhaustive; missing case(s):
  S(_)
```

## 不可能的分支

构造子的索引与被匹配的类型合一失败时，这个分支不可能出现，可以省略：

```moonbit
enum Fin : (Nat) -> Type {
  FZ[n : Nat] : Fin(S(n))
  FS[n : Nat](Fin(n)) : Fin(S(n))
}

enum Vector[T] : Nat -> Type {
  Nil : Vector[T](0)
  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
}

// 不需要 Nil 的分支：Fin(0) 是空类型，Nil 不可能与 Fin(n) 同时出现
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

也可以只写模式、不写 `=>`，此时检查器会确认它确实不可能（写错了会报“this pattern is not
impossible”）：

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

## 空类型

没有构造子能匹配的类型是空类型，对它的匹配可以没有分支。检查器会在嵌套的位置识别空类型，
例如字段类型为 `Fin(0)` 的构造子不必列出。内置类型（`Int`、`Array` 等）不是空类型。
