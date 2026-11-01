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

## Errors as values of the logic

During type checking, a call that raises an error computes to the value `raise e`. It can be written in
types, compared and caught by `try`, so you can prove when a function raises and when it does not:

```moonbit
suberror Empty

fn head(xs : List[Int]) -> Int raise Empty {
  match xs {
    Nil => raise Empty
    Cons(x, _) => x
  }
}

fn const0(x : Int) -> Int { 0 }

lemma head_nil() -> head(Nil) === raise Empty { Refl }

lemma head_ok(x : Int, xs : List[Int]) ->
  (try { head(Cons(x, xs)); true } catch { _ => false }) === true { Refl }

// as at run time, the error of the argument comes first
lemma strict() -> const0(head(Nil)) === raise Empty { Refl }

enum Void {}

// an error is not a value: this equation cannot hold
lemma not_zero(p : head(Nil) === 0) -> Void { match p {} }

fn main {
  println(try { const0(head(Nil)) } catch { Empty => -1 })
}
```

The rules follow call-by-value evaluation at run time:

- A `match` on `raise e`, passing it as an explicit argument to a function or a constructor, and
  `let x = raise e` are all `raise e`. A function body does not run before the call, so `(x) => raise e`
  is a value. Implicit arguments are erased at run time and do not propagate errors.
- A function is only unfolded when its arguments are known not to raise. In `const0(head(xs))`, `xs`
  is a variable, so whether `head(xs)` raises is unknown: the call is not unfolded, and
  `const0(head(xs)) === 0` cannot be proved by `Refl`. Variables always stand for values, so
  `const0(x) === 0` can.
- `raise e` differs from every constructor and literal; `raise e1` equals `raise e2` exactly when `e1`
  equals `e2`.
- Raising calls and `raise e` can only be written in types. A proof (a pure term) still cannot call a
  raising function, so the pure part cannot build an error, and errors do not make the logic
  inconsistent.
- The implicit arguments of a lemma stand for values, and unification does not solve them with terms
  that may raise. Those of constructors, of types, and of `Id::sym`, `Id::trans`, `Id::cong` and
  `Id::subst` can be such terms, since these do not rely on their arguments being values.
- A function that returns a proof (a type in `Prop`) cannot declare `raise`: proofs are erased at run
  time, and the error would be lost with them.
- The argument of `raise` is the whole expression: `raise Empty === x` is `raise (Empty === x)`; write
  `(raise Empty) === x`.
