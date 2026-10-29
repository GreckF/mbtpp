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

### 约束与隐式参数

`[T : Add]` 和 `[n : Nat]` 写法相同，由冒号右边的名字区分：

- 右边是 trait（或用 `+` 连接的几个 trait）时，这是**约束**：`T` 是一个类型（种类由 trait 的
  `Self` 决定：`Add` 的是 `Type`，`Monad` 的是 `[T] -> Type`），每个 trait 另有一个由检查器
  自动填充的实例参数。读作“实现了 `Add` 的类型 `T`”。
- 右边是类型时，这是普通的**隐式参数**：`n` 是 `Nat` 的一个值，例如
  `fn[T, n : Nat] Vector::head(…)`。

trait 和类型在同一个命名空间中，不能同名，所以不会有歧义。注意：

- 这条规则只用于 `[...]`。显式参数 `(x : Add)` 按类型检查，会报错：没有 MoonBit 的 trait
  对象 `&Add`。
- 局部名字优先：如果外层有与 trait 同名的参数，冒号右边指的是那个参数。
- 多个约束的种类要相同（`T` 的种类取自第一个 trait），`[M : Monad + Show]` 会报错。
- **实例搜索**：约束对应的实例由检查器自动填充：先找局部约束（以及它们的父 trait），再找全局
  实例（包括泛型实例）。

Prelude 中的 trait：`Show`（`to_string`）、`Eq`（`op_equal`）、`Compare : Eq`（`compare`）、
`Add`（`op_add`）、`Monad`（见[高阶 trait 与 monad](monad.md)）。`println` 需要 `Show`。
