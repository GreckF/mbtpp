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

## 错误作为逻辑中的值

类型检查时，会抛出错误的调用计算为值 `raise e`。它可以写进类型，可以比较，也可以被 `try` 捕获，
因此可以证明一个函数在什么情况下抛出、什么情况下不抛出：

```moonbit
suberror Empty

fn head(xs : List[Int]) -> Int raise Empty {
  match xs {
    Nil => raise Empty
    Cons(x, _) => x
  }
}

fn const0(x : Int) -> Int { 0 }

lemma head_nil() -> head(Nil) === raise Empty { Refl }

lemma head_ok(x : Int, xs : List[Int]) ->
  (try { head(Cons(x, xs)); true } catch { _ => false }) === true { Refl }

// 和运行时一样，参数的错误先发生
lemma strict() -> const0(head(Nil)) === raise Empty { Refl }

enum Void {}

// 错误不是值：这个等式不可能成立
lemma not_zero(p : head(Nil) === 0) -> Void { match p {} }

fn main {
  println(try { const0(head(Nil)) } catch { Empty => -1 })
}
```

规则与运行时的按值求值一致：

- 对 `raise e` 做 `match`、把它作为显式参数传给函数或构造子、`let x = raise e`，结果都是 `raise e`。
  函数体在调用之前不运行，所以 `(x) => raise e` 是一个值。隐式参数在运行时被擦除，不传播错误。
- 函数只在参数已知不抛出时展开。`const0(head(xs))` 中 `xs` 是变量，无法确定 `head(xs)` 是否
  抛出，所以这个调用不展开，`const0(head(xs)) === 0` 不能用 `Refl` 证明。变量总是代表值，
  `const0(x) === 0` 可以。
- `raise e` 与任何构造子和字面量都不同；`raise e1` 与 `raise e2` 相等当且仅当 `e1` 与 `e2` 相等。
- 会抛出的调用和 `raise e` 只能写在类型中，例如引理的结论 `head(Nil) === raise Empty`。证明本身
  是纯的项，不能调用会抛出的函数，所以证明中造不出错误，逻辑不会因此不一致。
- 引理的参数（包括隐式参数）代表值：调用引理时，隐式参数不会被合一推断为可能抛出的项，否则就能把
  关于值的引理用在错误上。构造子、类型，以及 `Id::sym`、`Id::trans`、`Id::cong`、`Id::subst` 的
  隐式参数没有这个限制，它们对任何项都成立。
- 返回证明（`Prop` 中的类型）的函数不能声明 `raise`：证明在运行时被擦除，错误会随之丢失。
- `raise` 的参数是整个表达式：`raise Empty === x` 是 `raise (Empty === x)`，需要写成
  `(raise Empty) === x`。
