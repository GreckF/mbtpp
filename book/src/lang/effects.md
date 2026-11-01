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

- `effect E[T] { Op(A) -> R }` 声明一个效应。`perform Op(x)` 的结果类型是 `R`，也就是 `resume`
  的参数类型；`R` 是 `Unit` 时写 `resume()`。
- 函数的效应写在返回类型后：`-> T!E1 + E2 raise Err`。调用一个有效应的函数，要么在处理这些效应的
  `try` 中，要么所在函数自己也声明这些效应。
- `try` 的分支可以同时处理错误和效应操作，只有效应分支中有 `resume`。
- 处理器是深的：`resume` 之后，后面的操作仍由同一个 `try` 处理。
- 处理器是词法的：lambda 在创建时捕获作用域中的处理器，所以执行效应的 lambda 要在处理器之内，或在
  声明了该效应的函数之内创建。

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
  它可以被调用任意次。
- `let mut` 变量在每次恢复时都从执行操作时的值继续（上例的结果是 `[2, 1, 1, 0]`）；`try` 外面的
  变量、数组和 `mut` 字段是共享的。
- 用到 `ctl` 效应的代码会被翻译为返回"计算"的代码，使用统一表示编译，比直接的代码慢；只用尾恢复
  操作的代码不受影响。

## 效应多态

```moonbit
fn[T, e] each(xs : List[T], f : (T) -> Unit!e) -> Unit!e {
  match xs {
    Nil => ()
    Cons(x, rest) => { f(x); each(rest, f) }
  }
}
```

- 行中的小写名字是效应变量，写在隐式参数中。调用时它由参数推断：`each(xs, x => perform Yield(x))`
  有效应 `Yield[T]`，`each(xs, g)`（`g` 是纯函数）没有效应。
- **可以省略**：函数类型的参数如果在函数体中只被调用、或直接作为参数传出（不被存储、返回，或被返回
  的闭包捕获），省略 `!e` 时检查器自动加上，并显示在函数的类型中。Prelude 中的 `List::map` 等函数
  因此是效应多态的。参数会逃逸时（比如 `compose`），省略表示纯，需要效应时要写 `!e`。
- `!pure` 显式地要求纯，并关闭自动推导。

## 错误与 async 也是效应

`raise E` 和 `async` 是效应行的写法：`-> T raise E` 就是 `-> T!Raise[E]`，`async fn` 的返回类型
有效应 `Async`。效应变量因此也覆盖它们，Prelude 的 `List::map` 等函数会跟随回调抛出错误或成为
async：

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

翻译保持专用：错误仍编译为 MoonBit 的错误，async 仍编译为 MoonBit 原生的 async。一个效应多态的
函数被传入 async 回调时，会生成它的原生 async 版本。

## 检查时的计算

被完整处理的计算是纯的，类型检查时会计算，处理器修改 `let mut` 也可以：

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

没有状态的处理器只是传入闭包，参数是变量时也能展开，可以对它做归纳。

## 限制

- 尾恢复操作的分支不能执行 `ctl` 操作。
- 一个 `try` 不能同时处理错误和 `ctl` 操作；`try … catch`（错误）和 `defer` 不能包住执行 `ctl`
  操作的代码。
- 证明（返回 `Prop` 中类型的函数）不能有效应。
- 效应不能和 `async` 组合，也不能跨包使用。
