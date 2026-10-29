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

## impl

接口中的 `impl`（包括泛型的，如 `impl[K : Show, V : Show] Show for HashMap[K, V]`）导入为
实例，条件是 trait 是 Prelude 中对应 MoonBit 的 trait（`Show`、`Eq`、`Compare`、`Hash`、
`ToJson`、`Default`、运算符 trait 等，见 [trait](../lang/traits.md)），或是导入的包中的 trait
（如 `@json.FromJson`、`@debug.Debug`）。
实例的方法调用 MoonBit 的 trait 方法（如 `Show::to_string(x)`），由 MoonBit 找到对应的
impl。例如：

```text
let a = @bigint.BigInt::from_int(1000)
println(a * a + a)                                        // Mul、Add、Show
let m : @hashmap.HashMap[String, Int] = Default::default() // impl[K, V] Default for HashMap[K, V]
println(m == m)                                           // impl[K : Hash + Eq, V : Eq] Eq ...
```

带约束的泛型函数（`fn[T : Add + Mul]`）也可以用于这些类型。

## 自动填充的参数

`loc~ : SourceLoc`、`args_loc~ : ArgsLoc` 不是 MoonBit++ 中的参数：调用时不写，编译后由
MoonBit 填入。填入的位置是生成的 `.mbt` 中的位置。

## 重新导出

`pub using @q {type T as U}` 中的类型和函数可以通过本包的名字使用（`@p.U`）：

- `@q` 是 `@builtin` 或也被导入时，`@p.U` 就是 `@q.T`（同一个类型）；
- 否则 `@p.U` 是一个不透明类型。

`@builtin` 的 trait（`pub using @builtin {trait Show}`）就是 Prelude 中的 trait；其他 trait 的
重新导出不导入。

## 不导入的项

下面的项会被跳过，`moonpp check --verbose` 会列出它们：

- `async` 函数，以及参数中的 `async` 函数类型；
- trait 对象 `&T`；
- trait 既不是 Prelude trait、也不是导入的 trait 的 `impl`（例如没有导入 `moonbitlang/core/debug`
  时的 `@debug.Debug`）；
- `#deprecated` 的项；
- trait 的重新导出（`@builtin` 的除外），以及来源包未导入的函数的重新导出。
