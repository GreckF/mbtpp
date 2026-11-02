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
| `Id::subst(p, motive, px)` | `x === y` 与 `motive(x)` 推出 `motive(y)`；`motive` 返回 `Type` |
| `Id::subst_prop(p, motive, px)` | 同上，`motive` 返回 `Prop`（改写命题，例如 `NatLe(a, b)` 到 `NatLe(a, c)`） |

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
哈希表），使用 `deq`，它的结果是 `Dec[a === b]`，与 Lean 的 `Decidable` 相同：

```text
enum False : Prop {}               // 没有证明的命题
fn Not(P : Prop) -> Prop { (P) -> False }
fn[T] absurd(f : False) -> T       // 由矛盾得到任何值

enum Dec[P : Prop] {
  Yes(P)                           // 相等的证明
  No(Not(P))                       // 不相等的证明
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
        No(_) => find(k, rest)
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
  就是结构相等，所以比较的结果证明了相等或不相等：这由公理 `T::eq_sound : (a == b) === true ->
  a === b` 与 `T::ne_sound : (a == b) === false -> Not(a === b)` 保证，公理在检查时不计算，编译时被
  擦除。`Double` 没有：`0.0 == -0.0`，但它们是不同的值。
- `Bool`、`Unit`、`Nat` 的 `deq` 是普通的定义（`Nat` 的在运行时直接比较整数）。
- trait `DecEq : Eq` 的方法是 `deq(a : Self, b : Self) -> Dec[a === b]`。上面这些类型，以及元素满足
  它的 `Option`、`List`、二元组、三元组都有实例。
- `derive(DecEq)` 用于 enum 和 struct：比较构造子，逐个字段 `deq`，把各字段的证明匹配为 `Refl` 后
  得到整个值的 `Refl`；不相等时由字段的反驳（或构造子不同）得到整个值的反驳。它同时 derive `Eq`
  （`DecEq` 需要 `Eq`）。
- `reflect(b)` 的类型是 `Reflect(b)`，即 `IsTrue(b === true)` 或 `IsFalse(b === false)`，用来在分支中
  取得一个布尔表达式的值的证明。

有了 `No` 的反驳，用 `deq` 定义的函数也能对变量证明性质：`deq(p, p)` 的 `No` 分支用 `absurd` 排除。

```moonbit
fn upd(rho : (String) -> Nat, p : String, m : Nat) -> (String) -> Nat {
  n => match String::deq(n, p) {
    Yes(_) => m
    No(_) => rho(n)
  }
}

lemma upd_same(rho : (String) -> Nat, p : String, m : Nat) -> upd(rho, p, m)(p) === m {
  match String::deq(p, p) {
    Yes(_) => Refl
    No(nope) => absurd(nope(Refl))
  }
}

lemma upd_other(rho : (String) -> Nat, p : String, q : String, m : Nat, ne : Not(q === p)) ->
  upd(rho, p, m)(q) === rho(q) {
  match String::deq(q, p) {
    Yes(e) => absurd(ne(e))
    No(_) => Refl
  }
}
```

## 指针相等

`physical_equal(a, b)` 是 MoonBit 的 `physical_equal`：是否是同一个对象（结果为 `false` 时两个值仍可能
相等）。`ptr_deq(a, b)` 的结果是 `Known[a === b]`：是同一个对象时为 `Proved(证明)`，否则为 `Unknown`
（不是同一个对象并不说明不相等），可以作为结构比较之前的快速路径。两者在检查时都不计算，所以检查时
不能借它们得到证明。
