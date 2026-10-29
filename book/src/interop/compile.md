# 编译到 MoonBit

编译器把类型检查后的程序翻译成 MoonBit。`moonpp build` 和 `moonpp run --compiled` 使用它；
[Playground](https://greckf.github.io/mbtpp/) 中的“编译到 MoonBit”可以直接查看结果。

两种翻译混合使用：

## 原生翻译

参数和结果都是原生类型、函数体也在一阶片段中的函数，翻译成普通的（可以是泛型的）MoonBit
函数。原生类型是：

- `Int`、`Double`、`Bool`、`Char`、`String`、`Unit`；
- 类型参数和函数类型；
- 参数都是类型、字段都是原生类型的数据类型。

索引和被擦除的字段消失，例如：

```text
enum Vector[T] : Nat -> Type { Nil : …; Cons[n : Nat](T, Vector[T](n)) : … }
// 编译为
enum E_Vector[T0] { Nil; Cons(T0, E_Vector[T0]) }
```

`#mbt` 类型使用自己的名字而不是 `E_…`（见 [#mbt 类型与 trait](mbt-types.md)）。

## 统一表示

其余部分（类型层计算、GADT 细化、非 `#mbt` 的 trait 等）使用统一值表示 `Value`。它是运行时
中的一个可扩展 enum（MoonBit 的 `extenum`），固定变体是 `VInt`、`VFun` 等；每个生成的文件用
`extenum Value += { … }` 加入自己的数据类型中用到的构造子，索引和被擦除的字段不出现，字段是
`Value`。例如 `basic.mbtpp` 的 GADT：

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
- 其他隐式参数和构造子的隐式字段只用于类型时擦除。
- 证明不擦除：它们和普通值一样被计算。

## 性能

一个 `fib` 程序编译后约快 40 倍（解释器 7.85 秒，编译后 0.18 秒）。构造子成为 `Value` 的原生
变体之前，统一表示中的数据是 `VCon(构造子名, 字段数组)`，匹配要比较字符串；改为原生变体后，
对一棵 2^18 个叶子的 `Exp` 树求值 20 次，从 2.65 秒降到 1.26 秒。
