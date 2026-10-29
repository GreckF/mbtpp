# Methods and Operators

## Methods

`fn Type::m(self : Type, …)` defines a method on type `Type`. `x.m(a)` calls `T::m(x, a)`, where `T` is the head of `x`'s
type; you can also write `Type::m(x, a)`.

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

`x.m()` looks for the type's own methods first, then trait methods (see [trait](traits.md)).

## Operators

Operators resolve to methods, so defining the corresponding methods on your own type lets you use them:

| Operator | Method |
| --- | --- |
| `a + b`, `a - b`, `a * b`, `a / b`, `a % b` | `op_add`, `op_sub`, `op_mul`, `op_div`, `op_mod` |
| `-a` | `op_neg` |
| `a & b`, `a \| b`, `a ^ b` | `op_land`, `op_lor`, `op_lxor` |
| `a << n`, `a >> n` | `op_shl`, `op_shr` |
| `a == b`, `a != b` | `op_equal` |
| `a < b`, `a <= b`, `a > b`, `a >= b` | `op_lt`, `op_le`, `op_gt`, `op_ge` |

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

`!`, `&&`, and `||` work only on `Bool`.
