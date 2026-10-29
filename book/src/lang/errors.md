# 错误处理

```moonbit
suberror DivError {
  DivError(String)
}

fn div(a : Int, b : Int) -> Int raise DivError {
  if b == 0 {
    raise DivError("division by zero")
  }
  a / b
}

fn main {
  let r = try div(10, 0) catch {
    DivError(msg) => {
      println("caught: " + msg)
      0
    }
  }
  println(r)
  println(try? div(10, 2))      // Ok(5)
}
```

- **错误类型**：`suberror Name { C(…) }`，或单个构造子的简写 `suberror Name(String)`。
- **声明**：函数类型 `-> T raise E`；`raise` 不写类型时为 `Error`（任何错误）。
- **抛出**：`raise e`。
- **捕获**：`try e catch { 模式 => … }`，分支按错误的构造子匹配，没有匹配的错误继续向外抛出。
- **`try? e`**：得到 `Result[T, Error]`，不抛出。
- Prelude 中的 `fail(msg)` 抛出 `Failure(msg)`。

`raise`、`try` 与可变状态一样，使函数在类型检查时不展开（见
[可变状态与循环](mutation.md)）。
