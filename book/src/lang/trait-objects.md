# trait 对象

`&Tr` 是“某个实现了 `Tr` 的类型的值”，和 MoonBit 的 trait 对象一样：

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

- **打包**：在需要 `&Tr` 的地方（类型标注、参数、数组元素），一个类型有 `Tr` 实例的值会自动
  打包。
- **调用**：`x.m(...)` 调用打包的实例的方法；`&Tr` 本身也有 `Tr` 的实例（以及父 trait 的
  实例），所以 `&Show` 可以用于 `println`、带 `Show` 约束的函数。
- **对象安全**：和 MoonBit 一样，`Self` 必须是类型，每个方法（包括父 trait 的）只在第一个
  参数中出现 `Self`，且不是泛型方法。`&Eq` 不行（`op_equal(Self, Self)`），`&Monad` 也不行。
- **表示**：`&Tr` 是依赖 struct `{ ty : Type; inst : Tr(ty); val : ty }`，在第一次使用时生成。

## 与 MoonBit 交互

导入的函数的 `&Tr` 参数（例如 `moonbitlang/core/prelude` 的 `inspect(&Show, content?)`），只要
`Tr` 是 MoonBit 的 trait（Prelude 中对应 MoonBit 的 trait，或导入的 trait），就可以传入
MoonBit++ 的 `&Tr`：编译后它被包装成一个 MoonBit 值，其 impl 调用 MoonBit++ 的实例。
例如自己实现 `Show` 的类型可以交给 MoonBit 的 `inspect` 比较。

导入的函数返回 `&Tr` 时还不能编译。
