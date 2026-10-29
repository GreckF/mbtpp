# 类型层计算

类型是值，所以可以用普通函数计算类型，类型检查时会规范化（计算）它们：

```moonbit
// 接受 n 个 Int 参数、返回 Int 的函数类型
fn NAry(n : Nat) -> Type {
  match n {
    Z => Int
    S(k) => (Int) -> NAry(k)
  }
}

fn sum_n(n : Nat, acc : Int) -> NAry(n) {
  match n as m return NAry(m) {
    Z => acc
    S(k) => x => sum_n(k, acc + x)
  }
}

fn main {
  println(sum_n(3, 0)(1)(2)(3))   // 6
}
```

`sum_n(3, 0)` 的类型 `NAry(3)` 在类型检查时被计算成 `(Int) -> (Int) -> (Int) -> Int`。
这里用 [return 子句](return-clause.md) 给出了匹配的动机。

类型检查时会展开的只有纯函数：使用了可变状态、循环或异常的函数不展开（见
[可变状态与循环](mutation.md)）。
