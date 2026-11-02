# 编译到 MoonBit

编译器把类型检查后的程序翻译成 MoonBit。`moonpp build` 和 `moonpp run --compiled` 使用它；
[Playground](https://greckf.github.io/mbtpp/) 中的“编译到 MoonBit”可以直接查看结果。

两种翻译混合使用：能用 MoonBit 类型表达的代码翻译成普通的 MoonBit 代码（原生翻译），其余代码
使用动态的统一表示。两种代码之间在边界上转换。

## 原生翻译

能原生翻译的类型称为原生类型，只用原生类型的值、能原生翻译的表达式称为**原生片段**。参数和结果
都是原生类型、函数体也在原生片段中的函数，翻译成普通的（可以是泛型的）MoonBit 函数。原生类型是：

- `Int`、`Double`、`Bool`、`Char`、`String`、`Unit`；
- `Nat`，即 MoonBit 的 `BigInt`（见下面的 [Nat](#nat)）；
- 类型参数和函数类型；
- 数组 `Array[T]`（`T` 是原生类型），即 MoonBit 的数组；
- 字段都是原生类型的数据类型。

索引和被擦除的字段消失，例如：

```text
enum Vector[T] : Nat -> Type { Nil : …; Cons[n : Nat](T, Vector[T](n)) : … }
// 编译为
enum E_Vector[T0] { Nil; Cons(T0, E_Vector[T0]) }
```

不是类型的参数（值参数，如 `struct Scoped(n : Nat)` 的 `n`，以及命题参数）也像索引一样去掉，所以只在
类型或证明字段中用到它们的数据类型仍是原生的。擦除之后只有一个构造子、只保留一个字段（且字段不是
这个类型本身）的数据类型编译成 MoonBit 的元组 struct，不额外装箱：

```text
type Ex Int                          // struct E_Ex(Int)
struct Scoped(n : Nat) {             // struct E_Scoped(E_Expr)
  e : Expr
  ok : closed(e, n) === true
}
```

`#mbt` 类型使用自己的名字而不是 `E_…`（见 [#mbt 类型与 trait](mbt-types.md)）。

Prelude 中 `#mbt` trait（`Show`、`Eq`、`Compare`、`Hash`、`Default`、运算符等）的实例，在原生代码
需要时成为 `E_…` 的 MoonBit `impl`，包括 `derive` 的实例；`Option` 与 `Result` 使用 MoonBit 自己的
impl，它们的输出与比较和 Prelude 的实例相同。因此在 async 函数（只有原生代码）中也可以打印、比较
这些数据（以及数组和 `Map`）。

数组不会在原生代码与统一表示之间转换：两边的数组若是副本，修改就不能共享。参数或结果含数组的
函数有原生和统一表示两个版本，原生代码之间、统一表示代码之间各自直接传递数组。

类型是原生类型、定义在原生片段中的全局 `let` 也是原生的：它在第一次使用时计算一次，原生代码直接
引用它，所以读写它的函数仍有原生版本。统一表示中的代码看到的是它转换后的值；含数组（或其他不能
转换的部分）的全局 `let` 只有在没有统一表示代码使用它时才是原生的，以保证两边是同一个数组。

```text
struct Arena { kinds : Array[Int] }
let glob : Arena = { kinds: [1, 2, 3] }
fn kind_glob(e : Int) -> Int { glob.kinds[e] }   // fn f_kind_glob_t(e : Int) -> Int
```

不会抛出错误的原生函数编译成不带 `raise` 的 MoonBit 函数（在 JS 后端，调用 `raise` 函数要分配和检查
结果对象）。会抛出的只有 `raise`、调用会抛出的函数（包括函数值和 trait 方法）以及经过统一表示的调用；
原生代码中的运行时错误（数组越界、除以零、没有匹配的分支）不是错误值，它们输出与统一表示相同的信息
后终止程序。

参数或结果含数组（或其他不能转换的部分）的函数，统一表示的代码只能调用它的统一版本。所以入口要
留在原生片段中：`main`（以及全局 `let`）的定义在原生片段中时是原生的，可以使用 `return`；一旦
`main` 只能用统一表示，它调用的这类函数也都在统一表示中运行。

`moonpp build --verbose` 列出程序中没有原生版本的函数和全局 `let`（包括 `main`），以及原因，
原因会沿着类型和字段一直追到源头，例如：

```text
without a native version (they run in the uniform representation):
  bump: its body is not in the native fragment: in `glob`, the global let glob is not native
  glob: it holds arrays, and code in the uniform representation uses it
  sum_n: its signature has no native translation
```

## Nat

类型检查时，`Nat` 是一进制的 `Z`、`S(n)`，证明按定义计算。运行时（解释器和编译后的程序）中，`Nat`
是任意精度的整数，即 MoonBit 的 `BigInt`：

- `Z` 是 0，`S(e)` 是 `e + 1`；数字字面量直接是 `BigInt` 字面量（如 `10N`）。
- 模式 `S(…S(p))`（k 层）检查值是否 ≥ k（`p` 是 `Z` 时检查是否 = k），各层绑定的值是原值减去
  相应的层数。
- Prelude 中 `Nat` 的 `+`、`*`、`==`、`compare`、`to_int`、`to_string` 和 `int_to_nat` 是
  `BigInt` 的运算。

所以 `Nat` 的算术不再随数值线性增长，也不会因为深度递归而栈溢出：

```text
fn fact(n : Nat) -> Nat {
  match n {
    Z => 1
    S(k) => n * fact(k)
  }
}
// 原生翻译
fn f45_fact_t(n : BigInt) -> BigInt raise {
  match n {
    n0 if n0 == 0N => 1N
    n1 if n1 >= 1N => n * f45_fact_t(n1 - 1N)
    _ => rt_fail("no match")
  }
}
```

`fact(30)` 的结果是 `265252859812191058636308480000000`。自己按结构递归定义的函数（例如另写的加法）
仍然每层递归一次，只是每一层是 `BigInt` 的运算。`Nat` 不是 MoonBit 类型：`#mbt fn` 的参数和结果
不能是 `Nat`，因为 MoonBit 传入的 `BigInt` 可能是负数。

### 形状与 Nat 相同的类型

编译后，擦除之后形状与 `Nat` 相同的数据类型也用 `BigInt` 表示：两个构造子，一个没有保留的字段（零），
另一个只保留一个字段，类型是这个数据类型本身（后继）。最常见的是有限集 `Fin`：

```text
enum Fin : (Nat) -> Type {
  FZ[n : Nat] : Fin(S(n))
  FS[n : Nat](Fin(n)) : Fin(S(n))
}
```

`FZ`、`FS` 的隐式字段 `n` 只用于类型，被擦除，所以 `Fin(n)` 的值就是一个下标，`FS(FS(FZ))` 是
`2N`。按 `Fin` 取向量元素因此编译为按整数下标逐层递归：

```text
fn[T0] f46_vector_get_t(self : E_Vector[T0], i : BigInt) -> T0 raise {
  match (self, i) {
    (E_Vector::Cons(x, _), n0) if n0 == 0N => x
    (E_Vector::Cons(_, xs), n1) if n1 >= 1N => f46_vector_get_t(xs, n1 - 1N)
    _ => rt_fail("no match")
  }
}
```

- 自己定义的 `enum Peano { Zero; Succ(Peano) }` 也是这样。
- 隐式字段在运行时用到时（例如模式 `FS[m](_) => m.to_int()`），它不被擦除，类型仍是普通的
  enum。
- 命题、错误类型、`#mbt` 类型和导入的类型保持原来的表示。
- 这样的类型（`Nat` 除外）的实例不会成为 MoonBit 的 `impl`，因为它们在 MoonBit 中都是 `BigInt`；
  用到这些实例的代码使用统一表示。
- 解释器只对 `Nat` 这样做（解释器不做擦除）。

## 统一表示

其余部分（类型层计算、GADT 细化、非 `#mbt` 的 trait 等）使用统一值表示 `Value`。它是运行时
中的一个可扩展 enum（MoonBit 的 `extenum`），固定变体是 `VInt`、`VFun` 等；每个生成的文件用
`extenum Value += { … }` 加入自己的数据类型中用到的构造子，索引和被擦除的字段不出现，字段是
`Value`。例如仓库中 `examples/basic.mbtpp` 的 GADT（与 [enum 与索引类型](../lang/enum.md)中的
`Exp` 相同）：

```text
enum Exp : [T] -> Type {
  IntLit(Int) : Exp[Int]
  Add(Exp[Int], Exp[Int]) : Exp[Int]
  If[T](Exp[Bool], Exp[T], Exp[T]) : Exp[T]
  …
}
```

在 `basic.mbt` 中编译为

```text
extenum Value += {
  K_Exp_IntLit(Value)
  K_Exp_Add(Value, Value)
  K_Exp_If(Value, Value, Value)
  …
}
```

`eval` 中的 `match` 是原生的：

```text
fn f19_exp_eval(self : Value) -> Value raise {
  match self {
    K_Exp_IntLit(n) => n
    K_Exp_Add(lhs, rhs) => VInt(as_int(f19_exp_eval(lhs)) + as_int(f19_exp_eval(rhs)))
    …
  }
}
```

`eval` 的结果类型随索引变化（`IntLit` 分支返回 `Int`，`BoolLit` 分支返回 `Bool`），MoonBit
的类型系统表达不了，所以它的结果仍是 `Value`。运行时支持（`apply`、原语、动态模式匹配器）在
生成的 `mbtpp_runtime.mbt` 中；它通过各文件在 `fn init` 中注册的解码器得到构造子的名字和字段
（用于显示与相等比较）。两种代码之间在边界上转换。

因为 `Value` 可以从别的文件、别的包扩展，这种表示也适合将来分别编译多个 MoonBit++ 包。

## 擦除

- 类型参数总是擦除。
- 其他隐式参数和构造子的隐式字段只用于类型时擦除；在运行时用到的隐式参数是原生函数的普通参数。
- 证明总是擦除：类型是命题的参数和字段（无论是否隐式）、类型是命题的 `let`、lemma 的调用都不
  生成代码，lemma 本身也不生成；对证明的匹配直接执行第一个分支（对空命题的证明的匹配变成
  `abort`）。因此 `#mbt fn` 可以有证明参数，例如 `fn get(xs : Array[Int], i : Int, p : i < n)`，
  导出的 MoonBit 函数没有这个参数。

## 性能

一个 `fib` 程序编译后约快 40 倍（解释器 7.85 秒，编译后 0.18 秒）。构造子成为 `Value` 的原生
变体之前，统一表示中的数据是 `VCon(构造子名, 字段数组)`，匹配要比较字符串；改为原生变体后，
对一棵 2^18 个叶子的 `Exp` 树求值 20 次，从 2.65 秒降到 1.26 秒。

原生代码与统一表示之间按值递归转换（`expr_to_value`、`expr_of_value`）。如果数据是高度共享的
DAG（例如共享子项的表达式），转换会展开共享，大小可能变成指数级。处理这种数据的函数应当留在原生
片段中，避免让它们跨过边界：例如不要让它们经过类型层计算、GADT 细化等只能用统一表示的代码。
