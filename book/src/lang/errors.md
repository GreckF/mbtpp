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

使用 `raise`、`try` 的函数和使用可变状态的函数一样，在类型检查时被执行，执行不完则保持不展开（见
[可变状态与循环](mutation.md)）。

## 不写 `try` 的 `catch` 与 `noraise`

```moonbit
suberror Oops {
  Oops(Int)
}

fn risky(n : Int) -> Int raise Oops {
  if n < 0 {
    raise Oops(n)
  } else {
    n * 2
  }
}

fn safe(n : Int) -> Int {
  risky(n) catch {
    Oops(k) => k
  }
}

fn describe(n : Int) -> String {
  try risky(n) catch {
    Oops(k) if k < -5 => "very bad"
    _ => "bad"
  } noraise {
    v => "ok \{v}"
  }
}

fn main {
  println(safe(-3))
  println(describe(4))
  println(describe(-9))
}
```

- `e catch { … }` 等同于 `try e catch { … }`，`catch` 要和 `e` 写在同一行。
- `noraise { 模式 => … }` 处理没有出错时的结果。`catch` 和 `noraise` 分支中抛出的错误不会被同一个
  `try` 捕获。
- `catch` 的分支可以使用或模式、`as` 和守卫。
