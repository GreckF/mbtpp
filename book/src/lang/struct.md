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

## 可变字段、更新、模式与元组结构体

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

- **`mut` 字段**：`p.x = v`、`p.x += 1` 修改它，所有引用同一个结构体的地方都看得到。
- **更新**：`{ ..p, x: e }` 是一个新结构体，其余字段取自 `p`（`mut` 字段复制当前的值）。
- **模式**：`{ x, y }`、`{ x: p, .. }`；省略字段时要写 `..`。`mut` 字段在模式中只能是 `_`。
- **元组结构体**：`struct P(Int, Int)` 的字段是 `0`、`1`，`P(a, b)` 构造，也是它的模式。
  `type Meters Int` 是只有一个字段的元组结构体。
- `mut` 字段在类型检查时不参与计算；从 MoonBit 导入的结构体的 `mut` 字段只能读。
