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

MoonBit++ 的模式匹配是依赖的：

- [依赖匹配与细化](dependent-match.md)：匹配一个构造子时，类型中的索引随之细化。
- [覆盖检查与不可能分支](coverage.md)：缺少的分支会报错，类型上不可能的分支可以省略。
- [return 子句](return-clause.md)：显式给出匹配的动机（Rocq 风格）。
