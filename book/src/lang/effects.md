# 代数效应

效应是一组可以在函数中**执行**（`perform`）、在 `try` 中**处理**的操作。处理器可以用 `resume`
把结果交还给执行操作的地方，让它继续运行。

```moonbit
effect Yield[T] {
  Yield(T) -> Unit
}

fn[T] iter_array(xs : Array[T]) -> Unit!Yield[T] {
  for x in xs {
    perform Yield(x)
  }
}

fn main {
  try {
    iter_array([1, 2, 3])
  } catch {
    Yield(x) => {
      println(x)
      resume()
    }
  }
}
```

- `effect E[T] { Op(A) -> R }` 声明一个效应，`{ … }` 中是它的操作。`perform Op(x)` 的结果类型是
  `R`，也就是 `resume` 的参数类型；`R` 是 `Unit` 时写 `resume()`。
- 函数可能执行的效应写在返回类型后的 `!` 之后，多个效应用 `+` 连接，例如 `-> T!E1 + E2`。这个
  列表称为函数的**效应行**。调用一个有效应的函数，要么在处理这些效应的 `try` 中，要么所在函数的
  效应行也包含这些效应。
- `try` 的分支可以同时处理错误和效应操作，只有效应分支中有 `resume`。
- `resume` 之后，`try` 体中后面执行的操作仍由同一个 `try` 处理：上例中三次 `Yield` 都进入同一个
  分支（这样的处理器称为“深”的）。
- 处理器按词法作用域确定：lambda 中执行的操作，由创建这个 lambda 的地方外围的 `try` 处理，而不是
  调用它的地方。所以执行效应的 lambda 要在处理器之内，或在效应行包含该效应的函数之内创建。

## 两种操作

默认的操作是**尾恢复**的：处理分支的每条路径都以 `resume(…)` 结束。这样的操作编译为普通的函数
调用，没有额外开销。需要在别处恢复、恢复多次或不恢复时，用 `ctl` 声明操作：

```moonbit
effect Choose {
  ctl Choose() -> Bool
}

fn count_trues() -> Int!Choose {
  let mut n = 0
  if perform Choose() { n = n + 1 }
  if perform Choose() { n = n + 1 }
  n
}

fn main {
  // 恢复两次：所有路径
  println(try { Cons(count_trues(), Nil) } catch {
    Choose() => resume(true).append(resume(false))
  })
  // 不恢复：中止
  println(try { count_trues() } catch { Choose() => -1 })
}
```

- `ctl` 分支中，`resume(v)` 运行 `try` 体中剩下的部分（仍由这个处理器处理），返回 `try` 的结果；
  它可以被调用任意次。上例中每个 `Choose` 恢复两次，`try` 体共运行完 4 次，第一个 `println` 输出
  四种选择下的结果 `Cons(2, Cons(1, Cons(1, Cons(0, Nil))))`；第二个 `try` 不恢复，输出 `-1`。
- 每次恢复时，`let mut` 变量从执行操作那一刻的值继续：上例中第二次 `Choose` 的两次恢复都从同一个
  `n` 开始，互不影响。`try` 外面的变量、数组和 `mut` 字段则是共享的，一次恢复中的修改在下一次恢复
  中可见。
- 用到 `ctl` 操作的代码会被翻译为返回“计算”的代码，使用[统一表示](../interop/compile.md#统一表示)
  编译，比直接的代码慢；只用尾恢复操作的代码不受影响。

## 效应多态

一个接受回调的函数，往往应该具有回调的效应：回调执行 `Yield`，它就执行 `Yield`；回调是纯的，
它也是纯的。这用**效应变量**表示：

```moonbit
fn[T, e] each(xs : List[T], f : (T) -> Unit!e) -> Unit!e {
  match xs {
    Nil => ()
    Cons(x, rest) => { f(x); each(rest, f) }
  }
}
```

- 效应行中的小写名字（这里的 `e`）是效应变量，和类型参数一样写在 `fn[…]` 中。调用时它由参数
  推断：`each(xs, x => perform Yield(x))` 有效应 `Yield[T]`，`each(xs, g)`（`g` 是纯函数）没有
  效应。
- 效应变量**可以省略**。函数类型的参数如果在函数体中只被调用、或直接作为参数传给别的函数，省略
  `!e` 时检查器自动加上，推导出的效应变量显示在函数的类型中。上面的 `each` 不写 `e` 也是同样的
  类型，Prelude 中的 `List::map` 等函数也因此是效应多态的。
- 参数被存储、被返回，或被返回的闭包捕获时（称为**逃逸**），不会自动加上效应变量，省略表示回调
  必须是纯的。例如组合两个函数：

  ```moonbit
  // f 和 g 被返回的闭包捕获：需要效应时要写出 e
  fn[A, B, C, e] compose(f : (A) -> B!e, g : (B) -> C!e) -> (A) -> C!e {
    x => g(f(x))
  }
  ```

  不写 `!e` 时，`compose` 只接受纯函数，传入执行效应的 lambda 会报错。
- `!pure` 显式地要求纯，并关闭自动推导：`fn[T] apply(f : (T) -> T!pure, x : T) -> T` 只接受纯的
  回调。

## 错误与 async 也是效应

`raise E` 和 `async` 是效应行的另一种写法：`-> T raise E` 就是 `-> T!Raise[E]`，`async fn` 的
返回类型有效应 `Async`。所以效应变量也包括它们：Prelude 的 `List::map` 等函数，回调会抛出错误时
它也会抛出，回调是 async 时它也是 async：

```moonbit
suberror TooBig {
  TooBig(Int)
}

fn check_small(x : Int) -> Int!Raise[TooBig] {
  if x > 2 { raise TooBig(x) } else { x }
}

fn main {
  let r = try {
    Cons(1, Cons(5, Nil)).map(x => check_small(x))
  } catch {
    TooBig(n) => { println("too big: \{n}"); Nil }
  }
  println(r)
}
```

编译时它们保持专用的翻译：错误仍编译为 MoonBit 的错误，async 仍编译为 MoonBit 原生的 async。
一个效应多态的函数被传入 async 回调时，编译器会生成它的原生 async 版本。

## 检查时的计算

在函数内部被完整处理的效应不会出现在函数的类型中，这个函数是纯的，类型检查时会像其他函数一样
被计算（见[类型层计算](type-level.md)），处理器修改 `let mut` 也可以：

```moonbit
effect Emit {
  Emit(Int) -> Unit
}

fn emit_all(xs : List[Int]) -> Unit!Emit {
  match xs {
    Nil => ()
    Cons(x, rest) => { perform Emit(x); emit_all(rest) }
  }
}

fn sum(xs : List[Int]) -> Int {
  let mut s = 0
  try { emit_all(xs) } catch { Emit(x) => { s = s + x; resume() } }
  s
}

lemma sum3() -> sum(Cons(1, Cons(2, Cons(3, Nil)))) === 6 { Refl }

fn main {
  println(sum(Cons(4, Cons(5, Nil))))
}
```

`sum` 修改了 `let mut`，所以和其他使用可变状态的函数一样，在检查时被执行，参数是具体的值时才能
算出结果（见[可变状态与循环](mutation.md#与类型检查的关系)）。处理器不用 `let mut` 时，处理只是把
分支作为函数传进去，参数是变量也能展开，所以可以对它做一般的证明：

```moonbit
effect Ask {
  Ask() -> Int
}

fn add_asked(x : Int) -> Int!Ask {
  x + perform Ask()
}

fn add_one(x : Int) -> Int {
  try { add_asked(x) } catch { Ask() => resume(1) }
}

// x 是变量，调用仍然展开
lemma add_one_x(x : Int) -> add_one(x) === x + 1 { Refl }
```

`ctl` 操作的处理也会在检查时计算（包括恢复多次和 `let mut` 的恢复语义），参数是具体的值时可以
算出结果：

```moonbit
effect Choose {
  ctl Choose() -> Bool
}

fn count_trues() -> Int!Choose {
  let mut n = 0
  if perform Choose() { n = n + 1 }
  if perform Choose() { n = n + 1 }
  n
}

fn all_counts() -> List[Int] {
  try { Cons(count_trues(), Nil) } catch {
    Choose() => resume(true).append(resume(false))
  }
}

lemma all_counts_ok() -> all_counts() === Cons(2, Cons(1, Cons(1, Cons(0, Nil)))) { Refl }
```

关于有效应的函数的一般证明，常常要对定义中的条件分情况讨论：在证明中 `match x <= y`，目标里
出现的 `x <= y` 会被替换为 `true` 或 `false`（见[依赖匹配与细化](dependent-match.md#匹配目标中的表达式)）。
仓库中的 `examples/effects_dt.mbtpp` 有更完整的例子：结果类型由键决定的配置效应、格式决定参数
类型的 `printf`、对任意输入证明“丢弃日志的处理器不改变排序结果”，以及在检查时计算的搜索。

## 限制

- 尾恢复操作的分支中不能执行 `ctl` 操作。
- 一个 `try` 不能同时处理错误和 `ctl` 操作；`try … catch`（捕获错误的）和 `defer` 不能包住执行
  `ctl` 操作的代码。
- 返回命题的函数（如 `lemma`）不能有效应。
- async 函数不能再声明其他效应。
- 效应不能跨包使用。
