# 表达式与语句

表达式和语句与 MoonBit 一致：

```moonbit
fn demo(xs : Array[Int]) -> Int {
  let a = 1                       // 不可变绑定
  let mut total = a               // 可变绑定
  total = total + 2               // 赋值
  for x in xs {
    total = total + x
  }
  let f = (x : Int) => x * 2      // lambda；也可写 x => e、(x, y) => e
  let g = fn(x : Int) { x + 1 }   // 匿名函数
  let s = if total > 10 { "big" } else { "small" }
  println(s)
  total |> f |> g                 // 管道
}

fn main {
  println(demo([1, 2, 3]))
}
```

- **块**：`{ s1; s2; e }` 的值是最后一个表达式。
- **`let`**：`let x = e`、`let x : T = e`；模式绑定 `let (a, b) = pair`（做覆盖检查）。
- **`if`**：`if c { a } else { b }` 是表达式；没有 `else` 时值为 `()`。
- **lambda**：`x => e`、`(x, y) => e`、`(x : Int) => e`、`fn(x : Int) { … }`。
- **管道**：`e |> f` 即 `f(e)`，`e |> f(a)` 即 `f(e, a)`。
- **类型注解**：`(e : T)`。
- **洞**：`_` 由合一推断，可以出现在表达式和类型中，例如 `Cons(_, xs)`、`f[_, Int](x)`。
- **局部函数**：块内可以写 `fn name(x : T) -> R { … }`，可以递归；递归的局部函数不能使用外层的
  `let mut` 变量。
- **级联调用**：`xs..push(1)..push(2)` 依次调用 `xs` 的方法，值是 `xs`。
- **数组**：`xs[i]` 取元素，`xs[i] = v` 赋值。

三种等号：`=` 定义，`==` 布尔相等（结果是 `Bool`），`===` 命题相等（结果是 `Prop`，见
[命题相等](equality.md)）。

循环、`return`、`break`、`continue` 见[可变状态与循环](mutation.md)，`raise`、`try` 见
[错误处理](errors.md)。
