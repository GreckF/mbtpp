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

## 默认方法

trait 中写 `= _` 的方法有默认实现，用 `impl Tr with m(…) { … }`（不写 `for`）给出；实例没有
实现它时就用默认的。`impl Tr for T` 可以不写任何方法。

```moonbit
trait Describe {
  name(Self) -> String
  describe(Self) -> String = _
}

impl Describe with describe(self) {
  "<" + self.name() + ">"
}

struct Dog {
  age : Int
}

impl Describe for Dog with name(_) {
  "dog"
}

fn main {
  let d : Dog = { age: 3 }
  println(d.describe())
}
```

## Prelude 中的 trait

| trait | 方法 | MoonBit 中的 trait 与方法 |
| --- | --- | --- |
| `Show` | `to_string(Self) -> String` | `Show`（`to_string`） |
| `Eq` | `op_equal(Self, Self) -> Bool`（`==`） | `Eq`（`equal`） |
| `Compare : Eq` | `compare(Self, Self) -> Int` | `Compare`（`compare`） |
| `Add`、`Sub`、`Mul`、`Div`、`Mod` | `op_add` 等（`+ - * / %`） | `Add`（`add`）等 |
| `Neg` | `op_neg(Self) -> Self`（一元 `-`） | `Neg`（`neg`） |
| `Default` | `default() -> Self`，用 `Default::default()` 调用 | `Default`（`default`） |
| `BitAnd`、`BitOr`、`BitXOr` | `op_land` 等（`& \| ^`） | `BitAnd`（`land`）等 |
| `Shl`、`Shr` | `op_shl(Self, Int) -> Self` 等（`<<`、`>>`） | `Shl`（`shl`）等 |
| `Hash` | `hash(Self) -> Int` | `Hash`（编译出的 impl 定义 `hash_combine`） |
| `ToJson` | `to_json(Self) -> Json` | `ToJson`（`to_json`） |
| `Monad` | 见[高阶 trait 与 monad](monad.md) | 无 |

`Json` 是 MoonBit 的 `Json` 类型，在 MoonBit++ 中不透明：由 MoonBit 代码（导入的 `@json` 函数、
`derive(ToJson)`）产生和使用，`json.stringify()` 得到文本。`@json` 的 `FromJson` 和 `@debug` 的
`Debug` 是导入的包中的 trait（导入这两个包后可用），见下面的 derive。

`Hash` 的值在解释器和编译后的程序中不同（编译后用的是 MoonBit 的哈希）。

`println` 需要 `Show`。除 `Monad` 外，这些 trait 就是 MoonBit 自己的 trait：编译后，`#mbt`
类型的实例是真正的 MoonBit impl（例如 `impl Eq for Shape with equal(a0, a1)`），MoonBit 代码
可以直接打印、比较、排序这些值；带这些约束的 `#mbt fn`（`fn[T : Show + Eq]`）编译成带同样
约束的 MoonBit 函数。其他类型的实例只在 MoonBit++ 内部使用（MoonBit 已经有 `Int`、`String`
等类型的实例）。

## derive

在 enum 或 struct 后写 `derive(Show, Eq, Compare)`，检查器会生成对应的实例：

```moonbit
enum Tree[T] {
  Leaf
  Node(Tree[T], T, Tree[T])
} derive(Show, Eq, Compare)

struct Point {
  x : Int
  y : Int
} derive(Show, Eq)

fn main {
  let t : Tree[Int] = Node(Leaf, 1, Leaf)
  println(t)                      // Node(Leaf, 1, Leaf)
  println(t == t)                 // true
  println(Leaf.compare(t))        // -1
  let p : Point = { x: 1, y: 2 }
  println(p)                      // {x: 1, y: 2}
}
```

- `Show`：构造子写成 `C(x, y)`，struct 写成 `{x: 1, y: 2}`，字段用各自的 `to_string`。
- `Eq`：构造子相同且字段都相等。
- `Compare`：先按构造子的声明顺序，再从左到右比较字段。`Compare` 需要 `Eq`，所以写
  `derive(Eq, Compare)`。
- `Hash`：构造子的位置与各字段的哈希。
- `ToJson`、`FromJson`、`Debug`：由 MoonBit 自己 derive，所以类型必须是 `#mbt`；生成的
  MoonBit 声明带有 `derive(ToJson, @json.FromJson, Debug)`，MoonBit++ 的实例调用这些 MoonBit
  方法（因此只在编译后的程序中运行）。`FromJson` 需要导入 `moonbitlang/core/json`，`Debug`
  的实例需要导入 `moonbitlang/core/debug`（不导入时只在 MoonBit 一侧 derive）。格式与 MoonBit
  相同，例如 `Rgb(1, 2, 3)` 是 `["Rgb",1,2,3]`，struct 是对象。
- 类型参数会加上同一个约束：`enum Tree[T] derive(Eq)` 生成 `impl[T : Eq] Eq for Tree[T]`。
- 只支持只有类型参数的类型：带索引的类型、构造子带返回类型（GADT）的 enum、带显式参数的
  struct 都不支持。
- 某个字段的类型没有所需实例时，错误报告在 `derive` 所在的行。

完整示例见 [examples/derive.mbtpp](https://github.com/GreckF/mbtpp/blob/main/examples/derive.mbtpp)。
