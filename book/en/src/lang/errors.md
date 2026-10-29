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

Like functions with mutable state, functions that use `raise` and `try` are run during type
checking, and stay folded when the run cannot finish (see [Mutable State and Loops](mutation.md)).

## `catch` without `try`, and `noraise`

```moonbit
suberror Oops {
  Oops(Int)
}

fn risky(n : Int) -> Int raise Oops {
  if n < 0 {
    raise Oops(n)
  } else {
    n * 2
  }
}

fn safe(n : Int) -> Int {
  risky(n) catch {
    Oops(k) => k
  }
}

fn describe(n : Int) -> String {
  try risky(n) catch {
    Oops(k) if k < -5 => "very bad"
    _ => "bad"
  } noraise {
    v => "ok \{v}"
  }
}

fn main {
  println(safe(-3))
  println(describe(4))
  println(describe(-9))
}
```

- `e catch { … }` is the same as `try e catch { … }`; `catch` must be on the same line as `e`.
- `noraise { pattern => … }` handles the result when no error was raised. Errors raised in the
  `catch` and `noraise` arms are not caught by the same `try`.
- `catch` arms can use or-patterns, `as` and guards.
