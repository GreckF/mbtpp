# #mbt 类型与 trait

在 enum、struct、trait 前加 `#mbt`，声明它们直接对应 MoonBit 的类型和 trait。编译后的原生
代码直接使用这些 MoonBit 类型，MoonBit 函数可以不经转换地接收它们。

```moonbit
#mbt
enum Tree[T] {
  Leaf
  Node(Tree[T], T, Tree[T])
}

#mbt
struct Pt {
  x : Int
  y : Int
}

#mbt
trait Size {
  size(Self) -> Int
}

impl Size for Int with size(self) { self }
impl Size for Pt with size(self) { self.x + self.y }
impl[T : Size] Size for Tree[T] with size(self) {
  match self {
    Leaf => 0
    Node(l, x, r) => l.size() + x.size() + r.size()
  }
}

fn main {
  let t : Tree[Pt] = Node(Leaf, { x: 1, y: 2 }, Leaf)
  println(t.size())
}
```

编译结果包括 `pub(all) enum Tree[T0]`、`pub(all) struct Pt`、`pub(open) trait Size`、
`impl[T0 : Size] Size for Tree[T0]`。

`#mbt` 不改变类型检查和解释执行，只影响编译。条件在类型检查时验证，不满足时报错。

## #mbt 类型

- 只有类型参数，没有索引；不是命题，不是 `suberror`；构造子没有隐式字段。
- 字段类型是 MoonBit 类型：`Int`、`Double`、`Bool`、`Char`、`String`、`Unit`、类型参数、`#mbt`
  类型，以及它们之间的函数类型。暂不支持数组。
- 生成的类型名和构造子须以大写字母开头，不能与 `Value`、`Option` 等已有名字冲突。

## #mbt("名字")

对应已有的 MoonBit 类型或 trait，不生成声明。Prelude 中的 `Option`、`Result` 就是
`#mbt("Option")`、`#mbt("Result")`。从 `.mbti` 导入的 `pub(all)` 类型和 `pub(open)` trait 自动带
`#mbt("@pkg.T")`（满足条件时）。

## #mbt trait

- `Self : Type`；父 trait 也是 `#mbt`。
- 方法不是泛型的，参数和结果是 MoonBit 类型（可以出现 `Self`）。
- 生成的 MoonBit trait 中方法都标 `raise`（编译后的代码用错误实现控制流）。
- 原生代码中，约束 `[T : Size]` 成为 MoonBit 的 `fn[T0 : Size]`，方法调用成为 `Size::size(x)`。

## #mbt trait 的实例

- 只有类型参数和 `#mbt` 约束；`Self` 是 MoonBit 类型（不能只是一个类型参数）。
- 遵守 MoonBit 的孤儿规则：已有的 trait（`#mbt("…")`、导入的）只能为本程序生成的类型实现。
- 只读（`pub`）的 trait 不能实现。
- 方法在原生片段中的实例生成 MoonBit `impl`。
