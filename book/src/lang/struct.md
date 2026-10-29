# struct 与依赖字段

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

- **构造**：`{ x: 1, y: 2 }`，类型由期望类型决定。
- **字段访问**：`p.x`。
- **参数**：`struct Name[T, n : Nat] { … }`。
- 不支持结构体模式（`{ x: a, y: b } => …`），用字段访问。

## 依赖字段

后面的字段可以依赖前面的字段，例如一个带长度证明的数组：

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

`xs.size()` 返回 `Nat`，所以可以出现在类型中；`xs.length()` 返回 `Int`。
