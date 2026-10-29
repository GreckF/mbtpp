# struct and Dependent Fields

```moonbit
struct Point {
  x : Int
  y : Int
}

fn main {
  let p : Point = { x: 1, y: 2 }
  println(p.x + p.y)
}
```

- **Construction**: `{ x: 1, y: 2 }`; the type is determined by the expected type.
- **Field access**: `p.x`.
- **Parameters**: `struct Name[T, n : Nat] { … }`.
- Struct patterns (`{ x: a, y: b } => …`) are not supported; use field access.

## Dependent fields

Later fields can depend on earlier ones, e.g. an array that carries a proof of its length:

```moonbit
struct Vec[T, n : Nat] {
  to_array : Array[T]
  length_to_array : to_array.size() === n
}

fn[T] Vec::from_array(xs : Array[T]) -> Vec[T, xs.size()] {
  { to_array: xs, length_to_array: Refl }
}

fn[T, n : Nat] Vec::get(self : Vec[T, n], i : Int) -> T {
  self.to_array[i]
}

fn main {
  let v = Vec::from_array([1, 2, 3])
  println(v.get(1))
}
```

`xs.size()` returns a `Nat`, so it can appear in types; `xs.length()` returns an `Int`.
