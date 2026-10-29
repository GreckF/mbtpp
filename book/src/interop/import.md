# 导入 MoonBit 包

在包的 `moon.pkg` 中导入后，用 `@包.名字` 引用：

```text
import {
  "moonbitlang/core/math",
  "moonbitlang/core/string" @str,
}
```

```text
fn distance(x : Double, y : Double) -> Double {
  @math.hypot(x, y)
}

fn parse_hex(s : String) -> Int raise {
  @str.parse_int(s, base=16)
}

fn main {
  println(distance(3.0, 4.0))
  println(try? parse_hex("ff"))
}
```

（完整的例子见仓库中的 `examples/import`。）

## 工作方式

`moonpp` 读取包的 `.mbti` 接口文件，把其中的项翻译成 MoonBit++ 声明：

- 函数成为外部常量：类型检查时只有类型，不会展开。
- 类型、trait 翻译成对应的 MoonBit++ 声明（见[类型对应与不导入的项](types.md)）。

**解释器不能运行导入的函数**，运行到它们时报错
“cannot run the imported MoonBit function … in the interpreter”。需要真正调用时，运行编译后的
程序：`moonpp run --compiled`（见[调用 MoonBit 函数](ffi.md)）。

## 名字

| 项 | 写法 |
| --- | --- |
| 函数 | `@pkg.f` |
| 类型 | `@pkg.T` |
| 构造子 | `@pkg.T::C` 或 `@pkg.C`；按期望类型也可以只写 `C` |
| 方法 | `x.m()`；`#as_free_fn` 的方法也可以写 `@pkg.m` |
| trait | `@pkg.Tr`：用于约束、`impl @pkg.Tr for T`、`trait A : @pkg.Tr` |

带标签参数、可选参数、`raise` 与 MoonBit 中相同。
