# trait

```moonbit
trait Shape {
  area(Self) -> Int
  name(Self) -> String
}

trait Solid : Shape {                          // 父 trait
  volume(Self, Int) -> Int
}

struct Square {
  side : Int
}

impl Shape for Square with area(self) { self.side * self.side }
impl Shape for Square with name(self) { "square" }
impl Solid for Square with volume(self, depth) { self.area() * depth }

fn[S : Shape] describe(s : S) -> String {
  "\{s.name()} with area \{s.area()}"
}

fn[S : Solid] describe_solid(s : S) -> String {
  describe(s) + ", volume \{s.volume(2)}"     // 父 trait 的方法可用
}

fn main {
  let sq : Square = { side: 2 }
  println(describe_solid(sq))
}
```

- **声明**：`trait Name : Super1 + Super2 { 方法(参数类型) -> 结果 }`，方法的第一个参数通常是
  `Self`。泛型方法写 `fn[T] m(…)`。
- **实现**：`impl Tr for T with m(参数) { … }`，每个方法一条。泛型实例：
  `impl[T : Show] Show for Array[T] with to_string(self) { … }`。
- **约束**：`fn[T : Tr]`，多个约束 `[T : Eq + Show]`。
- **调用**：`x.m()` 或 `Tr::m(x)`。
- **实例搜索**：约束对应的实例由检查器自动填充：先找局部约束（以及它们的父 trait），再找全局
  实例（包括泛型实例）。

Prelude 中的 trait：`Show`（`to_string`）、`Eq`（`op_equal`）、`Compare : Eq`（`compare`）、
`Add`（`op_add`）、`Monad`（见[高阶 trait 与 monad](monad.md)）。`println` 需要 `Show`。
