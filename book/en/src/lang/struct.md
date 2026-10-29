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

## Mutable fields, updates, patterns and tuple structs

```moonbit
struct Counter {
  name : String
  mut count : Int
}

struct Pair(Int, Int)

struct Point {
  x : Int
  y : Int
} derive(Show)

fn main {
  let c = { name: "clicks", count: 0 }
  c.count += 1
  let copy = { ..c, name: "copy" }
  copy.count = 10
  println("\{c.count} \{copy.count}")
  match Pair(1, 2) {
    Pair(a, b) => println(a + b)
  }
  let p = { x: 3, y: 4 }
  match p {
    { x, .. } => println(x)
  }
  println({ ..p, y: 10 })
}
```

- **`mut` fields**: `p.x = v` and `p.x += 1` change them, and every reference to the same struct
  sees the change.
- **Updates**: `{ ..p, x: e }` is a new struct whose other fields come from `p` (`mut` fields get
  a copy of their current value).
- **Patterns**: `{ x, y }`, `{ x: p, .. }`; omitting fields requires `..`. In a pattern, a `mut`
  field can only be `_`.
- **Tuple structs**: the fields of `struct P(Int, Int)` are `0` and `1`; `P(a, b)` builds one and
  is its pattern. `type Meters Int` is a tuple struct with one field.
- `mut` fields take no part in type-level computation; the `mut` fields of structs imported from
  MoonBit can only be read.
