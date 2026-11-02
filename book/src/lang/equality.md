# 命题相等

`a === b` 是 Prelude 中的 `Id[_](a)(b)`：

```text
enum Id[T](x : T) : (y : T) -> Prop {
  Refl : Id[T](x)(x)
}
```

`Refl` 是唯一的构造子，它证明 `x === x`。因为类型检查时会计算，两边规范化后相同的等式都可以
直接用 `Refl` 证明：

```moonbit
lemma two_plus_two : (2 : Nat) + 2 === 4 = Refl

lemma plus_zero_left(n : Nat) -> (0 : Nat) + n === n {
  Refl
}
```

`0 + n` 按 `Nat::op_add` 的定义计算为 `n`；`n + 0` 则不能直接计算（`n` 是变量），需要归纳，
见 [lemma](lemma.md)。

## 等式引理

| 引理 | 类型 |
| --- | --- |
| `Id::sym(p)` | `x === y` 推出 `y === x` |
| `Id::trans(p, q)` | `x === y`、`y === z` 推出 `x === z` |
| `Id::cong(f, p)` | `x === y` 推出 `f(x) === f(y)` |
| `Id::subst(p, motive, px)` | `x === y` 与 `motive(x)` 推出 `motive(y)`；`motive` 可以返回 `Type` |

`===` 是子单例，所以可以匹配 `Refl` 来改写类型，即使结果在 `Type` 中：

```moonbit
fn[a : Nat, b : Nat] cast(e : a === b, xs : Array[Int]) -> Array[Int] {
  match e {
    Refl => xs
  }
}
```

`==` 与 `===` 不同：`==` 是 `Bool` 值的比较，可以在运行时计算；`===` 是命题。

## 可判定相等

`a == b` 的结果是 `true` 并不能在逻辑中推出 `a === b`。需要从比较结果得到证明时（例如带证书的缓存、
哈希表），使用 `deq`，它的结果是 `Dec[a === b]`：

```text
enum Dec[P : Prop] {
  Yes(P)      // 附带证明
  No
}
```

```moonbit
enum Color {
  Red
  Rgb(Int, Int, Int)
} derive(DecEq)

// 按键查找：找到时附带“键相等”的证明
fn[K : DecEq, V] find(k : K, xs : List[(K, V)]) -> Option[V] {
  match xs {
    Nil => None
    Cons((k2, v), rest) =>
      match DecEq::deq(k, k2) {
        Yes(_) => Some(v)
        No => find(k, rest)
      }
  }
}

lemma three : Int::deq(3, 3) === Yes(Refl) = Refl

fn main {
  println(find(2, Cons((1, "one"), Cons((2, "two"), Nil))))
  println(DecEq::deq(Rgb(1, 2, 3), Rgb(1, 2, 3)) is Yes(_))
}
```

- `Int`、`Int64`、`UInt`、`UInt64`、`Byte`、`Char`、`String`、`BigInt` 有 `T::deq(a, b)`。它们的 `==`
  就是结构相等，所以比较成功就证明了相等：这由公理 `T::eq_sound : (a == b) === true -> a === b`
  保证，公理在检查时不计算，编译时被擦除。`Double` 没有：`0.0 == -0.0`，但它们是不同的值。
- `Bool`、`Unit`、`Nat` 的 `deq` 是普通的定义（`Nat` 的在运行时直接比较整数）。
- trait `DecEq : Eq` 的方法是 `deq(a : Self, b : Self) -> Dec[a === b]`。上面这些类型，以及元素满足
  它的 `Option`、`List`、二元组、三元组都有实例。
- `derive(DecEq)` 用于 enum 和 struct：比较构造子，逐个字段 `deq`，把各字段的证明匹配为 `Refl` 后
  得到整个值的 `Refl`。它同时 derive `Eq`（`DecEq` 需要 `Eq`）。
- `reflect(b)` 的类型是 `Reflect(b)`，即 `IsTrue(b === true)` 或 `IsFalse(b === false)`，用来在分支中
  取得一个布尔表达式的值的证明。

## 指针相等

`physical_equal(a, b)` 是 MoonBit 的 `physical_equal`：是否是同一个对象（结果为 `false` 时两个值仍可能
相等）。`ptr_deq(a, b)` 在是同一个对象时给出 `Yes(证明)`，可以作为结构比较之前的快速路径。两者在检查
时都不计算，所以检查时不能借它们得到证明。
