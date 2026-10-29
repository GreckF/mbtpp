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
| `&Tr` (trait objects) | `&Tr`, see [Trait Objects](../lang/trait-objects.md); functions returning `&Tr` cannot be compiled yet |

Read-only types:

```text
fn f() -> @h.Handle { H(1) }
// error: cannot construct a value of the MoonBit type @h.Handle outside its package (it is not pub(all))
```

For `#mbt`, see [#mbt Types and Traits](mbt-types.md).

## impl

The `impl`s of an interface (generic ones too, such as
`impl[K : Show, V : Show] Show for HashMap[K, V]`) are imported as instances when their trait is
one of the Prelude traits that are MoonBit's (`Show`, `Eq`, `Compare`, `Hash`, `ToJson`, `Default`,
the operator traits, ...; see [Traits](../lang/traits.md)) or a trait of an imported package (such
as `@json.FromJson` or `@debug.Debug`). The
methods of the instance call the MoonBit trait method (e.g. `Show::to_string(x)`), and MoonBit
finds the impl. For example:

```text
let a = @bigint.BigInt::from_int(1000)
println(a * a + a)                                        // Mul, Add, Show
let m : @hashmap.HashMap[String, Int] = Default::default() // impl[K, V] Default for HashMap[K, V]
println(m == m)                                           // impl[K : Hash + Eq, V : Eq] Eq ...
```

Generic functions with bounds (`fn[T : Add + Mul]`) work with these types too.

## Auto-filled parameters

`loc~ : SourceLoc` and `args_loc~ : ArgsLoc` are not parameters in MoonBit++: calls leave them out
and MoonBit fills them in in the compiled program. The location is the one in the generated
`.mbt` file.

## Re-exports

The types and functions of `pub using @q {type T as U}` can be used under the package's own name
(`@p.U`):

- when `@q` is `@builtin` or is imported too, `@p.U` is `@q.T` (the same type);
- otherwise `@p.U` is an opaque type.

The traits of `@builtin` (`pub using @builtin {trait Show}`) are the Prelude's; other trait
re-exports are not imported.

`async` functions are imported as MoonBit++ async functions, and so are `async` function types in
parameters (see [async Functions](../lang/async.md)); the `nocancel` mark is ignored.

## Skipped items

The following items are skipped; `moonpp check --verbose` lists them:

- `impl`s of traits that are neither Prelude traits nor imported traits (e.g. `@debug.Debug`
  when `moonbitlang/core/debug` is not imported);
- `#deprecated` items;
- trait re-exports (except those of `@builtin`), and re-exported functions whose package is not
  imported.
