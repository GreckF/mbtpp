# 带标签参数

与 MoonBit 相同：

```moonbit
fn greet(name~ : String, greeting~ : String = "Hello", title? : String) -> String {
  match title {
    Some(t) => greeting + ", " + t + " " + name
    None => greeting + ", " + name
  }
}

fn main {
  println(greet(name="Alice"))
  println(greet(greeting="Hi", name="Bob", title="Dr."))
  let name = "Carol"
  println(greet(name~))            // name~ 即 name=name
  let t : String? = None
  println(greet(name~, title?=t))  // title?= 直接传 Option
}
```

| 声明 | 调用 | 说明 |
| --- | --- | --- |
| `x~ : T` | `f(x=e)`、`f(x~)` | 必须传 |
| `x~ : T = d` | 可以省略 | 默认值 `d` 可以引用前面的参数，每次调用时求值 |
| `x? : T` | `f(x=e)`、`f(x?=opt)`、省略 | 函数体内的类型是 `T?`，省略时为 `None` |

- 带标签参数可以按任意顺序传，也可以和位置参数交错。
- 只有顶层函数（包括方法）能有带标签参数，lambda 和局部函数不能。
- 作为值使用时，函数类型只按声明顺序列出参数，不含标签。
