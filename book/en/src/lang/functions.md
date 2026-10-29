# Functions

```moonbit
fn add(x : Int, y : Int) -> Int {
  x + y
}

fn[T] twice(f : (T) -> T, x : T) -> T {   // [T]: implicit parameter
  f(f(x))
}

fn answer() -> Int { 42 }                 // function with no parameters

fn main {
  println(add(1, 2))
  println(twice(x => x + 1, 0))
  println(twice[Int](x => x * 2, 1))      // pass the implicit parameter explicitly
  println(answer())
}
```

## No currying

A function takes a group of parameters: `(Int, Int) -> Int` takes two parameters and is a different type from
`(Int) -> (Int) -> Int`, which returns a function. Partial application is not allowed.

A function with no parameters (`fn answer()`) is represented internally as taking a single `Unit` parameter.

## Implicit parameters

Implicit parameters go in `[...]` after `fn`:

```moonbit
fn[T] count(xs : Array[T], extra : Nat) -> Nat {
  plus(xs.size(), extra)
}

fn main {
  println(count([1, 2], 3).to_int())
}
```

- `[T]` means `[T : Type]`. For an implicit parameter without a type, the type is inferred from its uses, defaulting to `Type` if it cannot be inferred.
- At call sites they are usually inferred by unification. You can also give them positionally with `f[a, b](x)`: you may give only a prefix, and you may write `_`.
- Implicit parameters can only be written after `fn`; `fn f[T](...)` is not supported.

## Other forms

- **Methods**: `fn Type::m(self : Type, …)`; see [Methods and operators](methods.md).
- **Labelled arguments**: `x~ : T`, `x? : T`; see [Labelled arguments](labelled.md).
- **lemma**: a function whose result is a proposition; see [lemma](lemma.md).
- **External primitives**: `fn f(x : Int) -> Int = "%prim_name"`, used only in the Prelude.
- **`main`**: `fn main { … }`, the program entry point.
