# 类型对应与不导入的项

## 类型对应

| MoonBit | MoonBit++ |
| --- | --- |
| `Int32`（即 `Int`）、`Double`、`Bool`、`Char`、`String`、`Unit` | 同名内置类型（`Int32` 即 `Int`） |
| `Array[T]`、`T?`、`Result[T, E]` | 同名类型 |
| `StringView`、`ArrayView[T]` | `String`、`Array[T]` |
| `pub(all) enum`、`pub(all) struct` | 同样的 enum、struct，自动 `#mbt`；可以构造和匹配 |
| `pub enum`、`pub struct`（只读） | 同上，但不能构造，只能匹配和传递 |
| `pub(open) trait` | trait，自动 `#mbt`；可以为本程序的类型实现 |
| `pub trait` | trait，不能实现 |
| `type T`（抽象类型），以及未定义的类型（`Int64`、`Map` 等） | 不透明类型 |
| 未知的 trait 约束（`Hash` 等） | 不透明 trait，任何类型都满足 |
| `(A) -> B raise E`、`x~ : T`、`x? : T` | 相同 |

只读类型：

```text
fn f() -> @h.Handle { H(1) }
// error: cannot construct a value of the MoonBit type @h.Handle outside its package (it is not pub(all))
```

`#mbt` 见 [#mbt 类型与 trait](mbt-types.md)。

## 不导入的项

下面的项会被跳过，`moonpp check --verbose` 会列出它们：

- `async` 函数，以及参数中的 `async` 函数类型；
- trait 对象 `&T`；
- 自动填充的参数 `loc~ : SourceLoc`；
- 泛型 `impl`，以及 `Show`、`Eq`、`Compare` 之外的 `impl`；
- `#deprecated` 的项；
- `using` 重新导出。
