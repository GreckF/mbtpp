# 模式匹配

`match` 的写法与 MoonBit 相同：

```moonbit
fn describe(n : Int, xs : List[Int]) -> String {
  match (n, xs) {
    (0, _) => "zero"
    (_, Nil) => "empty"
    (_, Cons(x, Cons(_, _))) => "at least two, starting with \{x}"
    _ => "other"
  }
}

fn main {
  println(describe(1, Cons(7, Cons(8, Nil))))
}
```

- **模式**：变量、通配符 `_`、构造子（可以嵌套）、字面量、元组。
- 分支按顺序匹配，可以重叠，第一个匹配的分支生效。
- **构造子的隐式参数**可以在模式中绑定或忽略：`If[t](c, a, b)`、`IZ[_, a] => a`。
- **`let` 模式**：`let (a, b) = pair`。

## 或模式、`as` 与守卫

```moonbit
enum Shape {
  Circle(Int)
  Rect(Int, Int)
  Square(Int)
}

fn kind(s : Shape) -> String {
  match s {
    Rect(_, _) | Square(_) => "polygon"
    Circle(r) if r > 10 => "big circle"
    Circle(_) => "circle"
  }
}

fn widest(s : Shape) -> Shape {
  match s {
    Rect(w, _) | Square(w) as big if w > 100 => big
    other => other
  }
}

fn main {
  println(kind(Circle(11)))
  println(widest(Square(200)) is Square(_))
}
```

- **或模式** `p | q`：可以嵌套（`Some(1 | 2)`），各个选项必须绑定相同的变量。检查器把它展开成多个
  分支，每个分支各自做依赖匹配。
- **`p as x`**：`x` 是整个被匹配的值。`as` 结合得最松，`A | B as x` 中的 `x` 是 `A | B` 匹配到的值。
- **守卫** `p if cond => …`：条件为假时继续尝试后面的分支，条件中可以使用模式绑定的变量。带守卫的
  分支不计入覆盖检查。

## 数组与区间模式

```moonbit
fn describe(xs : Array[Int]) -> String {
  match xs {
    [] => "empty"
    [x] => "one: \{x}"
    [a, .. rest, z] if a == z => "same ends around \{rest.length()}"
    [a, ..] => "starts with \{a}"
  }
}

fn kind(c : Char) -> String {
  match c {
    'a'..='z' => "lower"
    '0'..='9' => "digit"
    _ => "other"
  }
}

fn main {
  println(describe([3, 1, 2, 3]))
  println(kind('q'))
}
```

- **数组模式**：`[p, q]` 匹配恰好两个元素，`[p, .., z]` 至少两个；`..rest` 把中间的元素绑定为一个
  新数组。也可以用于 `String`（元素是 `Char`）。
- **区间模式**：`lo..=hi`、`lo..<hi`，边界是字面量，`_` 表示不限，例如 `_..<60`。
- 区间模式转成守卫，匹配仍是依赖匹配。含数组模式的 `match` 按顺序逐个分支测试：不做覆盖检查（没有
  分支适用时程序中止），也不细化类型。守卫中使用 `is` 的 `match` 也是这样，此时 `is` 绑定的变量在
  分支中可见。

## `is` 与 `guard`

```moonbit
fn get(o : Option[Int]) -> Int {
  if o is Some(x) && x > 5 {
    x
  } else {
    0
  }
}

fn length(xs : List[Int]) -> Int {
  let mut cur = xs
  let mut n = 0
  while cur is Cons(_, rest) {
    n = n + 1
    cur = rest
  }
  n
}

fn head_or(xs : List[Int], d : Int) -> Int {
  guard xs is Cons(h, _) else { return d }
  h
}

fn main {
  println(get(Some(9)))
  println(length(Cons(1, Cons(2, Nil))))
  println(head_or(Nil, 42))
}
```

- **`e is p`** 的值是 `Bool`。在 `if`、`while`、`guard` 的条件中，`p` 绑定的变量在 `&&` 链的后续
  部分和条件成立时执行的代码中可见。
- **`guard cond else { … }`**：条件不成立时执行 `else` 块，块中通常是 `return`、`break` 或
  `abort(…)`。之后的语句可以使用 `cond` 绑定的变量。省略 `else` 时，条件不成立会中止程序。
- 条件中有 `is` 时，`else` 分支在每个 `is` 失败的地方各展开一次，代码会重复。

MoonBit++ 的模式匹配是依赖的：

- [依赖匹配与细化](dependent-match.md)：匹配一个构造子时，类型中的索引随之细化。
- [覆盖检查与不可能分支](coverage.md)：缺少的分支会报错，类型上不可能的分支可以省略。
- [return 子句](return-clause.md)：显式给出匹配的动机（Rocq 风格）。
