# 方法与运算符

## 方法

`fn Type::m(self : Type, …)` 定义类型 `Type` 的方法。`x.m(a)` 调用 `T::m(x, a)`，`T` 是 `x` 的
类型的头部；也可以写 `Type::m(x, a)`。

```moonbit
enum Color {
  Red
  Green
}

fn Color::name(self : Color) -> String {
  match self {
    Red => "red"
    Green => "green"
  }
}

fn main {
  println(Red.name())
  println(Color::name(Green))
}
```

`x.m()` 先找类型自己的方法，再找 trait 方法（见 [trait](traits.md)）。

## 运算符

运算符解析为方法，所以给自己的类型定义对应的方法就能使用它们：

| 运算符 | 方法 |
| --- | --- |
| `a + b`、`a - b`、`a * b`、`a / b`、`a % b` | `op_add`、`op_sub`、`op_mul`、`op_div`、`op_mod` |
| `-a` | `op_neg` |
| `a & b`、`a \| b`、`a ^ b` | `op_land`、`op_lor`、`op_lxor` |
| `a << n`、`a >> n` | `op_shl`、`op_shr` |
| `a == b`、`a != b` | `op_equal` |
| `a < b`、`a <= b`、`a > b`、`a >= b` | `op_lt`、`op_le`、`op_gt`、`op_ge` |

```moonbit
struct Money {
  cents : Int
}

fn Money::op_add(self : Money, other : Money) -> Money {
  { cents: self.cents + other.cents }
}

fn Money::op_lt(self : Money, other : Money) -> Bool {
  self.cents < other.cents
}

fn main {
  let a : Money = { cents: 150 }
  let b : Money = { cents: 75 }
  println((a + b).cents)
  println(b < a)
}
```

`!`、`&&`、`||` 只用于 `Bool`。
