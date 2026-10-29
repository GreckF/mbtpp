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
