# Lexical Structure

- **Comments**: `// …` to the end of the line. There are no block comments.
- **Identifiers**: letters, digits, and `_`, not starting with a digit. By convention, types, constructors, and traits start with an uppercase letter; everything else is lowercase.
- **Statement separators**: newline or `;`.

## Literals

| Literal | Examples | Type |
| --- | --- | --- |
| Integer | `0`, `42`, `1_000`, `-1`, `0xFF`, `0o17`, `0b1010` | `Int`; expands to `S(…S(Z))` when the expected type is `Nat` |
| Floating point | `1.5`, `2.0` | `Double` |
| Other integers | `1L`, `1U`, `1UL`, `0xFFU` | `Int64`, `UInt`, `UInt64` |
| Single-precision float | `1.5F` | `Float` |
| Byte | `b'a'`, `b'\x01'` | `Byte` |
| Map | `{ "a": 1, "b": 2 }` | `Map[String, Int]`; `{}` is the empty map where a `Map` is expected |
| Character | `'a'`, `'\n'` | `Char` |
| String | `"hello"` | `String` |
| Boolean | `true`, `false` | `Bool` |
| Unit | `()` | `Unit` |
| Array | `[1, 2, 3]` | `Array[Int]` |
| Tuple | `(1, "a")` | `(Int, String)` |

Escapes: `\n \t \r \\ \" \' \0`.

Multiline strings: consecutive `#|` lines form one string, with newlines between the lines; `#|`
lines are kept as they are, and `$|` lines allow escapes and interpolation.

```moonbit
fn main {
  let name = "MoonBit++"
  let text =
    #|first line, kept as is: \n
    $|hello, \{name}!
  println(text)
}
```

String interpolation `"\{e}"` inserts the `Show` result of `e` into the string:

```moonbit
fn main {
  let n = 3
  let xs = [1, 2, 3]
  println("n = \{n}, xs = \{xs}, next = \{n + 1}")
}
```

## Keywords

```text
fn let mut if else match enum struct trait impl for in with while return break
continue raise try catch true false Type Prop forall lemma proof monad as suberror
derive pub priv noraise loop is guard async defer
```

`pub`, `priv`, and `derive(...)` are accepted but ignored: a package is a single scope with no visibility control.
