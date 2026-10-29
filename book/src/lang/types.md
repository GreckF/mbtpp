# 类型

## 宇宙

- `Type : Type`：类型本身是值，类型的类型是 `Type`（因此不一致，见[介绍](../README.md)中的声明）。
- `Prop : Type`：命题的宇宙。`Prop` 中类型的值是证明；证明无关，任意两个同类型的证明视为相等。
  见[命题与证明](proofs.md)。

## 函数类型

| 写法 | 含义 |
| --- | --- |
| `(Int, Int) -> Int` | 接受两个参数的函数 |
| `(Int) -> (Int) -> Int` | 返回函数的函数 |
| `(n : Nat, v : Vector[Int](n)) -> Int` | 依赖函数类型：后面的类型可以引用前面的参数 |
| `forall x : A, P(x)` | 即 `(x : A) -> P(x)`；`forall x y : A, …` 绑定多个 |
| `[T](x : T) -> T` | 一组参数，隐式在前、显式在后 |
| `[T] -> Type` | 只有隐式参数的一组 |
| `(A) -> B raise E` | 可能抛出错误 `E` 的函数 |

```moonbit
fn types_demo() -> Int {
  let f : (Int, Int) -> Int = (a, b) => a + b       // 两个参数
  let g : (Int) -> (Int) -> Int = a => b => a + b   // 返回函数的函数
  f(1, 2) + g(1)(2)
}

fn main {
  println(types_demo())
}
```

## 应用与简写

- 类型也是函数，`Array[Int]`、`Vector[T](n)`、`Id[T](x)(y)` 都是普通的应用：`[...]` 给隐式
  参数，`(...)` 给显式参数。
- `T?` 即 `Option[T]`；`(A, B)` 是二元组类型。
- 返回 `Type` 的函数就是类型层的函数，见[类型层计算](type-level.md)。

## 常量与类型别名

- `const N : Int = 3`、`const N = 3` 定义常量（同 `let`）。
- `typealias Int as Score` 或 `typealias Pair[A] = (A, A)` 定义类型别名。
