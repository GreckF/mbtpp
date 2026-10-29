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

其余部分（类型层计算、GADT 细化、非 `#mbt` 的 trait 等）使用运行时的统一值表示 `Value`
（`VInt`、`VCon(名字, 字段)`、`VFun` …），由生成的 `runtime.mbt` 支持。两种代码之间在边界上
转换。

## 擦除

- 类型参数总是擦除。
- 其他隐式参数和构造子的隐式字段只用于类型时擦除。
- 证明不擦除：它们和普通值一样被计算。

## 性能

一个 `fib` 程序编译后约快 40 倍（解释器 7.85 秒，编译后 0.18 秒）。
