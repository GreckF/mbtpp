# Algebraic Effects

An effect is a set of operations that functions **perform** and that a `try` **handles**. A handler
can give a result back to where the operation was performed with `resume`, which lets the code go on.

```moonbit
effect Yield[T] {
  Yield(T) -> Unit
}

fn[T] iter_array(xs : Array[T]) -> Unit!Yield[T] {
  for x in xs {
    perform Yield(x)
  }
}

fn main {
  try {
    iter_array([1, 2, 3])
  } catch {
    Yield(x) => {
      println(x)
      resume()
    }
  }
}
```

- `effect E[T] { Op(A) -> R }` declares an effect. `perform Op(x)` has the type `R`, the type of the
  argument of `resume`; write `resume()` when `R` is `Unit`.
- The effects of a function follow its result type: `-> T!E1 + E2 raise Err`. A function with effects
  is called in a `try` that handles them, or in a function that declares them too.
- The arms of a `try` may handle errors and operations together; only operation arms have `resume`.
- Handlers are deep: after `resume`, the next operations are handled by the same `try`.
- Handlers are lexical: a lambda captures the handlers in scope when it is created, so a lambda that
  performs an effect is created inside its handler, or in a function that declares the effect.

## Two kinds of operations

An operation is **tail-resumptive** by default: every path of its arms ends with `resume(…)`. Such an
operation compiles to a plain function call, with no overhead. To resume elsewhere, several times, or
not at all, declare the operation with `ctl`:

```moonbit
effect Choose {
  ctl Choose() -> Bool
}

fn count_trues() -> Int!Choose {
  let mut n = 0
  if perform Choose() { n = n + 1 }
  if perform Choose() { n = n + 1 }
  n
}

fn main {
  // resume twice: all paths
  println(try { Cons(count_trues(), Nil) } catch {
    Choose() => resume(true).append(resume(false))
  })
  // do not resume: abort
  println(try { count_trues() } catch { Choose() => -1 })
}
```

- In a `ctl` arm, `resume(v)` runs the rest of the `try` body (still handled by this handler) and
  returns the result of the `try`; it can be called any number of times.
- Each resumption continues with the values the `let mut` variables had when the operation was
  performed (the result above is `[2, 1, 1, 0]`); variables outside the `try`, arrays and `mut`
  fields are shared.
- Code with `ctl` effects is translated into code returning "computations" and compiled with the
  uniform representation, slower than direct code; code with tail-resumptive operations only is not
  affected.

## Effect polymorphism

```moonbit
fn[T, e] each(xs : List[T], f : (T) -> Unit!e) -> Unit!e {
  match xs {
    Nil => ()
    Cons(x, rest) => { f(x); each(rest, f) }
  }
}
```

- A lowercase name in a row is an effect variable, among the implicit parameters. Calls infer it from
  the arguments: `each(xs, x => perform Yield(x))` has the effect `Yield[T]`, and `each(xs, g)` (`g`
  pure) has none.
- **It can be left out**: when a parameter of function type is only called, or passed on directly as
  an argument (not stored, returned, or captured by a returned closure), the checker adds `!e` and
  shows it in the function's type. Functions of the Prelude such as `List::map` are thus effect
  polymorphic. When the parameter escapes (as in `compose`), leaving it out means pure; write `!e`
  for effects.
- `!pure` asks for a pure function explicitly, and turns off the inference.

## Errors and async are effects too

`raise E` and `async` are ways of writing effect rows: `-> T raise E` is `-> T!Raise[E]`, and the
result type of an `async fn` has the effect `Async`. Effect variables therefore cover them too, and
functions of the Prelude such as `List::map` raise, or are async, when their callback is:

```moonbit
suberror TooBig {
  TooBig(Int)
}

fn check_small(x : Int) -> Int!Raise[TooBig] {
  if x > 2 { raise TooBig(x) } else { x }
}

fn main {
  let r = try {
    Cons(1, Cons(5, Nil)).map(x => check_small(x))
  } catch {
    TooBig(n) => { println("too big: \{n}"); Nil }
  }
  println(r)
}
```

They keep their own translation: errors still compile to MoonBit errors, and async to native MoonBit
async. An effect polymorphic function given an async callback gets a native async version.

## Computing during type checking

A fully handled computation is pure, and the checker computes it, even when the handler updates a
`let mut`:

```moonbit
effect Emit {
  Emit(Int) -> Unit
}

fn emit_all(xs : List[Int]) -> Unit!Emit {
  match xs {
    Nil => ()
    Cons(x, rest) => { perform Emit(x); emit_all(rest) }
  }
}

fn sum(xs : List[Int]) -> Int {
  let mut s = 0
  try { emit_all(xs) } catch { Emit(x) => { s = s + x; resume() } }
  s
}

lemma sum3() -> sum(Cons(1, Cons(2, Cons(3, Nil)))) === 6 { Refl }

fn main {
  println(sum(Cons(4, Cons(5, Nil))))
}
```

A handler without state only passes closures: it unfolds even when the arguments are variables, and
can be reasoned about by induction.

## Limitations

- The arm of a tail-resumptive operation cannot perform `ctl` operations.
- A `try` cannot handle errors and `ctl` operations together; a `try … catch` (of errors) and `defer`
  cannot enclose code that performs `ctl` operations.
- Proofs (functions returning a type in `Prop`) have no effects.
- Effects do not combine with `async`, and are not shared between packages.
