# Prelude

The Prelude is loaded automatically into every program (`moonpp --no-prelude` turns it off).

| Name | Description |
| --- | --- |
| `Int`, `Double`, `Bool`, `Char`, `String`, `Unit`, `Array[T]`, `Error` | Built-in types |
| `Nat` (`Z`, `S`) | Natural numbers; integer literals expand at type `Nat`; `n.to_int()`, `int_to_nat(i)`, `+`, `*`, `==` |
| `Id[T](x)(y)`, `===`, `Refl` | Propositional equality; `Id::sym`, `Id::trans`, `Id::cong`, `Id::subst` |
| `Option[T]` (`None`, `Some`), `T?` | Optional values |
| `Result[T, E]` (`Ok`, `Err`) | Results |
| `List[T]` (`Nil`, `Cons`) | Linked lists: `append`, `reverse`, `length`, `map`, `flat_map` |
| `(a, b)`, `(a, b, c)` | Tuples (`Tuple2`, `Tuple3`) |
| `Failure`, `fail(msg)` | General-purpose error |
| `Show`, `Eq`, `Compare`, `Add`, `Sub`, `Mul`, `Div`, `Mod`, `Neg`, `Default`, `Monad` | Traits (see [Traits](traits.md)) |
| `println`, `print`, `print_string` | Output (`println` and `print` require `Show`) |
| `abort(msg)`, `panic()` | Terminate the program |
| `not(b)` | Boolean negation |

Methods on built-in types:

| Type | Methods |
| --- | --- |
| `Int` | Arithmetic and comparison operators, `compare`, `to_string`, `to_double`, `unsafe_to_char` |
| `Double` | Arithmetic and comparison operators, `compare`, `to_string`, `to_int` |
| `String` | `+`, `==`, `compare`, `length`, `s[i]`, `substring(start, end)`, `to_string` |
| `Char` | `==`, `compare`, `to_int`, `to_string` |
| `Bool` | `==`, `not`, `to_string` |
| `Array[T]` | `Array::make(n, x)`, `Array::new()`, `length`, `size` (`Nat`), `xs[i]`, `xs[i] = v`, `push` |
