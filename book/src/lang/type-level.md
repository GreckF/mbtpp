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

类型检查时，纯函数直接展开；使用了可变状态、循环或异常的函数会被执行，执行不完则保持不展开（见
[可变状态与循环](mutation.md)）。

## 检查时限

类型检查没有终止检查，计算可能永远不结束。所以每个定义的检查都有时间上限，默认 30 秒；超过时，
这个定义报错，并指出当时正在计算的函数：

```text
t.mbtpp:3:1: error: checking f took more than 30 s (while evaluating T); a definition that does
not terminate? Raise the limit with #timelimit(seconds) or #timelimit(none)
```

在定义前加 `#timelimit` 可以修改它的时限：

```moonbit
fn sum_to(n : Int) -> Int {
  let mut acc = 0
  for i = 1; i <= n; i = i + 1 {
    acc = acc + i
  }
  acc
}

#timelimit(120)
lemma big : sum_to(1000) === 500500 = Refl

#timelimit(none)
lemma bigger : sum_to(2000) === 2001000 = Refl
```

- 单位是秒；`#timelimit(none)` 表示不限时。可以和 `#mbt` 一起写。
- 时限针对单个定义，而不是整个检查过程。签名和函数体分开计时。检查过程中顺带检查的其他定义
  （例如它用到、但写在后面的函数）按各自的时限计时，所花的时间不算在这个定义上。
- 时限只管类型检查，不管 `moonpp run` 运行程序。
- Playground 对整个检查或运行另有 60 秒的上限，VS Code 插件对一次检查默认 120 秒
  （设置 `mbtpp.checkTimeout`）。
