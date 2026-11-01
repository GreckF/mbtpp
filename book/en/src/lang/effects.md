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

- `effect E[T] { Op(A) -> R }` declares an effect; its operations are in `{ … }`. `perform Op(x)` has
  the type `R`, the type of the argument of `resume`; write `resume()` when `R` is `Unit`.
- The effects a function may perform follow its result type after `!`, joined with `+`, as in
  `-> T!E1 + E2`. This list is the function's **effect row**. A function with effects is called in a
  `try` that handles them, or in a function whose effect row contains them too.
- The arms of a `try` may handle errors and operations together; only operation arms have `resume`.
- After `resume`, the operations the `try` body performs later are handled by the same `try`: in the
  example, all three `Yield`s go to the same arm (such handlers are called "deep").
- Handlers are found by lexical scope: an operation performed in a lambda is handled by the `try`
  around the place where the lambda is created, not where it is called. So a lambda that performs an
  effect is created inside its handler, or in a function whose effect row contains the effect.

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
  returns the result of the `try`; it can be called any number of times. In the example each
  `Choose` resumes twice, the `try` body runs to the end 4 times, and the first `println` prints the
  results of the four choices, `Cons(2, Cons(1, Cons(1, Cons(0, Nil))))`; the second `try` does not
  resume and prints `-1`.
- Each resumption continues with the values the `let mut` variables had when the operation was
  performed: both resumptions of the second `Choose` above start from the same `n`, independently.
  Variables outside the `try`, arrays and `mut` fields are shared: what one resumption changes, the
  next one sees.
- Code using `ctl` operations is translated into code returning "computations" and compiled with the
  [uniform representation](../interop/compile.md#uniform-representation), slower than direct code;
  code with tail-resumptive operations only is not affected.

## Effect polymorphism

A function taking a callback should often have the callback's effects: it performs `Yield` when the
callback does, and is pure when the callback is. **Effect variables** express this:

```moonbit
fn[T, e] each(xs : List[T], f : (T) -> Unit!e) -> Unit!e {
  match xs {
    Nil => ()
    Cons(x, rest) => { f(x); each(rest, f) }
  }
}
```

- A lowercase name in an effect row (`e` here) is an effect variable, written in `fn[…]` like type
  parameters. Calls infer it from the arguments: `each(xs, x => perform Yield(x))` has the effect
  `Yield[T]`, and `each(xs, g)` (`g` pure) has none.
- Effect variables **can be left out**. When a parameter of function type is only called, or passed
  on directly as an argument to another function, the checker adds the missing `!e`, and the inferred
  effect variable shows in the function's type. `each` above has the same type without `e`, and
  functions of the Prelude such as `List::map` are effect polymorphic for this reason.
- When the parameter is stored, returned, or captured by a returned closure (it **escapes**), no
  effect variable is added, and leaving it out means the callback must be pure. For example,
  composing two functions:

  ```moonbit
  // f and g are captured by the returned closure: write e for effects
  fn[A, B, C, e] compose(f : (A) -> B!e, g : (B) -> C!e) -> (A) -> C!e {
    x => g(f(x))
  }
  ```

  Without `!e`, `compose` takes pure functions only, and a lambda performing an effect is an error.
- `!pure` asks for purity explicitly, and turns off the inference: `fn[T] apply(f : (T) -> T!pure,
  x : T) -> T` takes pure callbacks only.

## Errors and async are effects too

`raise E` and `async` are other ways of writing effect rows: `-> T raise E` is `-> T!Raise[E]`, and
the result type of an `async fn` has the effect `Async`. Effect variables therefore cover them too:
functions of the Prelude such as `List::map` raise when their callback raises, and are async when it
is async:

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

They keep their own translation when compiled: errors still compile to MoonBit errors, and async to
native MoonBit async. When an effect polymorphic function is given an async callback, the compiler
generates a native async version of it.

## Computing during type checking

Effects fully handled inside a function do not appear in its type: the function is pure, and the
checker computes it like any other function (see [Type-Level Computation](type-level.md)), even when
the handler updates a `let mut`:

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

`sum` updates a `let mut`, so, like other functions with mutable state, it is executed during
checking, and gives a result only when the arguments are concrete values (see
[Mutable State and Loops](mutation.md#interaction-with-type-checking)). When the handler uses no
`let mut`, handling only passes the arms in as functions: the call unfolds even when the arguments
are variables, so general facts can be proved about it:

```moonbit
effect Ask {
  Ask() -> Int
}

fn add_asked(x : Int) -> Int!Ask {
  x + perform Ask()
}

fn add_one(x : Int) -> Int {
  try { add_asked(x) } catch { Ask() => resume(1) }
}

// x is a variable, and the call still unfolds
lemma add_one_x(x : Int) -> add_one(x) === x + 1 { Refl }
```

## Limitations

- The arm of a tail-resumptive operation cannot perform `ctl` operations.
- A `try` cannot handle errors and `ctl` operations together; a `try … catch` (catching errors) and
  `defer` cannot enclose code that performs `ctl` operations.
- Functions returning propositions (such as `lemma`s) have no effects.
- Async functions cannot declare other effects.
- Effects cannot be used across packages.
