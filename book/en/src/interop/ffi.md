# Calling MoonBit Functions

Compiled programs really call imported MoonBit functions:

- **From native code**: called directly, with no conversion.
- **From the uniform representation**: arguments and results are converted according to the signature.

Supported signatures:

| Type | Conversion |
| --- | --- |
| `Int`, `Double`, `Bool`, `Char`, `String`, `Unit` | Scalar |
| Type parameters | None (the value itself) |
| `Array[T]`, `T?` | Element by element |
| `#mbt` data types (including imported `pub(all)` types) | Constructor by constructor |
| Function types | Callback: arguments and results are converted when MoonBit calls it |
| Opaque types | Boxed |
| Labeled arguments, optional arguments, `raise` | Supported |
| Generic functions with `#mbt` trait bounds | Callable from native code |

- Calling an external function whose signature is unsupported is a **compile error** that explains why.
- Values of **read-only types** (`pub` rather than `pub(all)`) cannot be rebuilt from the uniform representation; they can only be passed around in native code.
  Passing them to a MoonBit function from the uniform representation is a compile error, suggesting that you make the call in the native fragment instead.
