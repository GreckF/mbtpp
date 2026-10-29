# Trait Objects

`&Tr` is "a value of some type that implements `Tr`", as with MoonBit's trait objects:

```moonbit
trait Shape {
  area(Self) -> Double
}

struct Circle {
  r : Double
}

struct Square {
  side : Double
}

impl Shape for Circle with area(self) { 3.0 * self.r * self.r }
impl Shape for Square with area(self) { self.side * self.side }

fn total(shapes : Array[&Shape]) -> Double {
  let mut s = 0.0
  for x in shapes {
    s = s + x.area()
  }
  s
}

fn main {
  let c : Circle = { r: 1.0 }
  let q : Square = { side: 2.0 }
  println(total([c, q]))               // 7
  let things : Array[&Show] = [1, "two", Some(3)]
  for t in things {
    println(t)
  }
}
```

- **Packing**: where an `&Tr` is expected (a type annotation, a parameter, an array element), a
  value whose type has an instance of `Tr` is packed automatically.
- **Calls**: `x.m(...)` calls the method of the packed instance; `&Tr` itself has an instance of
  `Tr` (and of its supertraits), so an `&Show` works with `println` and with functions bounded by
  `Show`.
- **Object safety**: as in MoonBit, `Self` must be a type, and every method (supertraits'
  included) mentions `Self` only in its first parameter and is not generic. `&Eq` is not allowed
  (`op_equal(Self, Self)`), nor is `&Monad`.
- **Representation**: `&Tr` is the dependent struct `{ ty : Type; inst : Tr(ty); val : ty }`,
  generated on first use.

## Interoperating with MoonBit

A MoonBit++ `&Tr` can be passed for an `&Tr` parameter of an imported function (such as
`inspect(&Show, content?)` of `moonbitlang/core/prelude`) when `Tr` is a MoonBit trait (a Prelude
trait that is MoonBit's, or an imported trait): in the compiled program it is wrapped in a MoonBit
value whose impl calls the MoonBit++ instance. For example, a type with its own `Show` can be
compared by MoonBit's `inspect`.

Imported functions that return an `&Tr` cannot be compiled yet.
