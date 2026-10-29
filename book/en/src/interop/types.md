# Type Mapping and Skipped Items

## Type mapping

| MoonBit | MoonBit++ |
| --- | --- |
| `Int32` (i.e. `Int`), `Double`, `Bool`, `Char`, `String`, `Unit` | The built-in types of the same name (`Int32` is `Int`) |
| `Array[T]`, `T?`, `Result[T, E]` | The types of the same name |
| `StringView`, `ArrayView[T]` | `String`, `Array[T]` |
| `pub(all) enum`, `pub(all) struct` | The same enum or struct, automatically `#mbt`; can be constructed and matched |
| `pub enum`, `pub struct` (read-only) | As above, but cannot be constructed, only matched and passed around |
| `pub(open) trait` | A trait, automatically `#mbt`; can be implemented for this program's types |
| `pub trait` | A trait that cannot be implemented |
| `type T` (abstract types), and undefined types (`Int64`, `Map`, etc.) | Opaque types |
| Unknown trait bounds (`Hash`, etc.) | Opaque traits, satisfied by every type |
| `(A) -> B raise E`, `x~ : T`, `x? : T` | The same |

Read-only types:

```text
fn f() -> @h.Handle { H(1) }
// error: cannot construct a value of the MoonBit type @h.Handle outside its package (it is not pub(all))
```

For `#mbt`, see [#mbt Types and Traits](mbt-types.md).

## Skipped items

The following items are skipped; `moonpp check --verbose` lists them:

- `async` functions, and `async` function types in parameters;
- trait objects `&T`;
- auto-filled parameters `loc~ : SourceLoc`;
- generic `impl`s, and `impl`s other than `Show`, `Eq`, and `Compare`;
- `#deprecated` items;
- `using` re-exports.
