# Importing MoonBit Packages

After importing a package in the package's `moon.pkg`, refer to its items with `@pkg.name`:

```text
import {
  "moonbitlang/core/math",
  "moonbitlang/core/string" @str,
}
```

```text
fn distance(x : Double, y : Double) -> Double {
  @math.hypot(x, y)
}

fn parse_hex(s : String) -> Int raise {
  @str.parse_int(s, base=16)
}

fn main {
  println(distance(3.0, 4.0))
  println(try? parse_hex("ff"))
}
```

(See `examples/import` in the repository for the full example.)

## How it works

`moonpp` reads the package's `.mbti` interface file and translates its items into MoonBit++ declarations:

- Functions become external constants: during type checking they have only a type and are never unfolded.
- Types and traits become the corresponding MoonBit++ declarations (see [Type Mapping and Skipped Items](types.md)).

**The interpreter cannot run imported functions**; reaching one reports
"cannot run the imported MoonBit function … in the interpreter". To actually call them, run the compiled
program: `moonpp run --compiled` (see [Calling MoonBit Functions](ffi.md)).

## Names

| Item | Syntax |
| --- | --- |
| Function | `@pkg.f` |
| Type | `@pkg.T` |
| Constructor | `@pkg.T::C` or `@pkg.C`; with a known expected type, just `C` |
| Method | `x.m()`; methods marked `#as_free_fn` can also be written `@pkg.m` |
| Trait | `@pkg.Tr`: in bounds, `impl @pkg.Tr for T`, and `trait A : @pkg.Tr` |

Labeled arguments, optional arguments, and `raise` work the same as in MoonBit.
