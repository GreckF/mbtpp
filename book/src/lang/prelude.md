# Prelude

每个程序都自动加载 Prelude（`moonpp --no-prelude` 可以关闭）。

| 名字 | 说明 |
| --- | --- |
| `Int`、`Double`、`Bool`、`Char`、`String`、`Unit`、`Array[T]`、`Error` | 内置类型 |
| `Nat`（`Z`、`S`） | 自然数，整数字面量在 `Nat` 处展开；`n.to_int()`、`int_to_nat(i)`、`+`、`*`、`==` |
| `Id[T](x)(y)`、`===`、`Refl` | 命题相等；`Id::sym`、`Id::trans`、`Id::cong`、`Id::subst` |
| `Option[T]`（`None`、`Some`）、`T?` | 可选值 |
| `Result[T, E]`（`Ok`、`Err`） | 结果 |
| `List[T]`（`Nil`、`Cons`） | 链表：`append`、`reverse`、`length`、`map`、`flat_map` |
| `(a, b)`、`(a, b, c)` | 元组（`Tuple2`、`Tuple3`） |
| `Failure`、`fail(msg)` | 通用错误 |
| `Show`、`Eq`、`Compare`、`Add`、`Sub`、`Mul`、`Div`、`Mod`、`Neg`、`Default`、`Monad` | trait（见 [trait](traits.md)） |
| `println`、`print`、`print_string` | 输出（`println` 和 `print` 需要 `Show`） |
| `abort(msg)`、`panic()` | 终止程序 |
| `not(b)` | 布尔取反 |

内置类型的方法：

| 类型 | 方法 |
| --- | --- |
| `Int` | 算术与比较运算符、`compare`、`to_string`、`to_double`、`unsafe_to_char` |
| `Double` | 算术与比较运算符、`compare`、`to_string`、`to_int` |
| `String` | `+`、`==`、`compare`、`length`、`s[i]`、`substring(start, end)`、`to_string` |
| `Char` | `==`、`compare`、`to_int`、`to_string` |
| `Bool` | `==`、`not`、`to_string` |
| `Array[T]` | `Array::make(n, x)`、`Array::new()`、`length`、`size`（`Nat`）、`xs[i]`、`xs[i] = v`、`push` |
