# Error Handling

```moonbit
suberror DivError {
  DivError(String)
}

fn div(a : Int, b : Int) -> Int raise DivError {
  if b == 0 {
    raise DivError("division by zero")
  }
  a / b
}

fn main {
  let r = try div(10, 0) catch {
    DivError(msg) => {
      println("caught: " + msg)
      0
    }
  }
  println(r)
  println(try? div(10, 2))      // Ok(5)
}
```

- **Error types**: `suberror Name { C(…) }`, or the single-constructor shorthand
  `suberror Name(String)`.
- **Declaration**: function type `-> T raise E`; `raise` without a type means `Error` (any error).
- **Raising**: `raise e`.
- **Catching**: `try e catch { pattern => … }`. Arms match on the error's constructor; errors that
  match no arm keep propagating outward.
- **`try? e`**: produces a `Result[T, Error]` instead of raising.
- `fail(msg)` in the Prelude raises `Failure(msg)`.

Like mutable state, `raise` and `try` keep a function from being unfolded during type checking (see
[Mutable State and Loops](mutation.md)).
