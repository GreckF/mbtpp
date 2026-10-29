# #mbt 函数

函数也可以标 `#mbt`：它会被编译为同名的公开 MoonBit 函数，MoonBit 代码可以直接调用。

```moonbit
#mbt
enum Tree[T] {
  Leaf
  Node(Tree[T], T, Tree[T])
}

#mbt
fn[T] insert(t : Tree[T], x : T, lt~ : (T, T) -> Bool) -> Tree[T] {
  match t {
    Leaf => Node(Leaf, x, Leaf)
    Node(l, y, r) =>
      if lt(x, y) {
        Node(insert(l, x, lt~), y, r)
      } else {
        Node(l, y, insert(r, x, lt~))
      }
  }
}

#mbt
fn[T] Tree::depth(self : Tree[T]) -> Int {
  match self {
    Leaf => 0
    Node(l, _, r) => {
      let a = l.depth()
      let b = r.depth()
      1 + (if a > b { a } else { b })
    }
  }
}

fn main {
  let mut t : Tree[Int] = Leaf
  for i = 0; i < 6; i = i + 1 {
    t = insert(t, i * 7 % 10, lt=(a, b) => a < b)
  }
  println(t.depth())
}
```

编译结果：

```text
pub fn[T0] insert(t : Tree[T0], x : T0, lt~ : (T0, T0) -> Bool raise) -> Tree[T0]
pub fn[T0] Tree::depth(self : Tree[T0]) -> Int32
```

（`moon fmt` 把 MoonBit 的 `Int` 写作 `Int32`。）

## 签名（类型检查时验证）

- 隐式参数只能是类型参数 `[T]`；约束只能是类型参数上的 `#mbt` trait，被约束的类型参数要出现在
  参数或结果中。
- 参数和结果是 MoonBit 类型。
- 支持 `x~`、`x?` 参数，不支持默认值。
- 方法只能属于本程序生成的 `#mbt` 类型。
- `main` 不能标 `#mbt`。
- `#mbt("名字")` 指定 MoonBit 中的函数名。

## 函数体（编译时验证）

函数体必须在原生片段中，否则编译报错，并指出第一个不能原生翻译的表达式，例如：

```text
#mbt fn f cannot be compiled to MoonBit: its body is not in the native fragment:
in `println(x)`, println has no native signature (a type without a MoonBit type,
or a bound that is not #mbt)
```

## raise

没有声明 `raise` 的函数在 MoonBit 中也不 `raise`，内部的运行时失败（如不完整的匹配）变成
`abort`。声明了 `raise E` 的函数在 MoonBit 中是 `raise`。
