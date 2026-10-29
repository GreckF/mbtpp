# Lexical Structure

- **Comments**: `// …` to the end of the line. There are no block comments.
- **Identifiers**: letters, digits, and `_`, not starting with a digit. By convention, types, constructors, and traits start with an uppercase letter; everything else is lowercase.
- **Statement separators**: newline or `;`.

## Literals

| Literal | Examples | Type |
| --- | --- | --- |
| Integer | `0`, `42`, `1_000`, `-1` | `Int`; expands to `S(…S(Z))` when the expected type is `Nat` |
| Floating point | `1.5`, `2.0` | `Double` |
| Character | `'a'`, `'\n'` | `Char` |
| String | `"hello"` | `String` |
| Boolean | `true`, `false` | `Bool` |
| Unit | `()` | `Unit` |
| Array | `[1, 2, 3]` | `Array[Int]` |
| Tuple | `(1, "a")` | `(Int, String)` |

Escapes: `\n \t \r \\ \" \' \0`.

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
derive pub priv noraise loop
```

`pub`, `priv`, and `derive(...)` are accepted but ignored: a package is a single scope with no visibility control.
