# 快速开始

安装 `moonpp`（见[安装](moonpp/install.md)）后：

```bash
moonpp new hello
cd hello
moonpp run                # 用解释器运行 src/main
moonpp check              # 类型检查
moonpp run --compiled     # 编译到 MoonBit 再运行
moonpp build              # 编译成 MoonBit 项目 mbtpp_out/main
```

`moonpp new` 生成的 `src/main/main.mbtpp` 类似这样：

```moonbit
enum Vector[T] : Nat -> Type {
  Nil : Vector[T](0)
  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
}

// 只接受非空向量：不需要 Nil 的分支
fn[T, n : Nat] Vector::head(self : Vector[T](S(n))) -> T {
  match self {
    Cons(x, _) => x
  }
}

fn main {
  let v : Vector[String](2) = Cons("Hello", Cons("MoonBit++", Nil))
  println(v.head())
}
```

- `Vector[T](n)` 是长度为 `n` 的向量：`T` 是参数，`n` 是索引（见
  [enum 与索引类型](lang/enum.md)）。
- `head` 只接受类型为 `Vector[T](S(n))` 的向量，所以 `Nil` 不可能出现，`match` 不需要它的分支
  （见[覆盖检查与不可能分支](lang/coverage.md)）。
- `v.head()` 调用方法 `Vector::head`。

不安装也可以在 [Playground](https://greckf.github.io/mbtpp/) 中试用。
