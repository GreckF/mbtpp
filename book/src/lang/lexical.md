# 词法

- **注释**：`// …` 到行尾。没有块注释。
- **标识符**：字母、数字、`_`，不以数字开头。约定上类型、构造子、trait 以大写开头，其余小写。
- **语句分隔**：换行或 `;`。

## 字面量

| 字面量 | 例子 | 类型 |
| --- | --- | --- |
| 整数 | `0`、`42`、`1_000`、`-1`、`0xFF`、`0o17`、`0b1010` | `Int`；期望类型是 `Nat` 时展开为 `S(…S(Z))` |
| 浮点 | `1.5`、`2.0` | `Double` |
| 字符 | `'a'`、`'\n'` | `Char` |
| 字符串 | `"hello"` | `String` |
| 布尔 | `true`、`false` | `Bool` |
| 单位 | `()` | `Unit` |
| 数组 | `[1, 2, 3]` | `Array[Int]` |
| 元组 | `(1, "a")` | `(Int, String)` |

转义：`\n \t \r \\ \" \' \0`。

多行字符串：连续的 `#|` 行组成一个字符串，行之间是换行；`#|` 行原样保留，`$|` 行支持转义和插值。

```moonbit
fn main {
  let name = "MoonBit++"
  let text =
    #|first line, kept as is: \n
    $|hello, \{name}!
  println(text)
}
```

字符串插值 `"\{e}"` 把 `e` 的 `Show` 结果插入字符串：

```moonbit
fn main {
  let n = 3
  let xs = [1, 2, 3]
  println("n = \{n}, xs = \{xs}, next = \{n + 1}")
}
```

## 关键字

```text
fn let mut if else match enum struct trait impl for in with while return break
continue raise try catch true false Type Prop forall lemma proof monad as suberror
derive pub priv noraise loop is guard async defer
```

`pub`、`priv`、`derive(...)` 可以写，但被忽略：一个包是一个作用域，没有可见性。
