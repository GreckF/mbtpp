# async functions

MoonBit++ supports MoonBit's `async` functions:

```moonbit
async fn twice(f : async (Int) -> Int, x : Int) -> Int {
  f(f(x))
}

async fn inc(x : Int) -> Int noraise {
  x + 1
}

async fn main {
  let g = async fn(x : Int) -> Int { inc(x) * 2 }
  println(twice(g, 1))
  println(twice(x => inc(x), 5))
}
```

- **Syntax**: top-level and local functions are written `async fn name(…)`, anonymous functions
  `async fn(…) { … }`, and function types `async (A) -> B`.
- **Errors**: as in MoonBit, an async function may raise any error by default (like `raise
  Error`). `raise E` restricts the error type, and `noraise` says it does not raise.
- **Calls**: an async function can only be called from an async function. A lambda (including
  `x => …`) checked against an async function type is async, like the second argument of `twice`
  above. A synchronous function can pass an async function around as a value, but cannot call it.
- **`async fn main`**: the entry point can be async.
- **Interpreter**: `moonpp run` runs async functions synchronously, one after another, without
  concurrency. Imported MoonBit async functions, like other imported functions, can only be called
  once compiled.

## Using moonbitlang/async

Add the dependency with `moonpp add moonbitlang/async` and import it in the package's `moon.pkg`
to use its task groups, timers and IO:

```moonbit
// requires moonbitlang/async
async fn tick(name : String, n : Int, delay : Int) -> Unit {
  for i = 0; i < n; i = i + 1 {
    @async.sleep(delay)
    println(name + " " + i.to_string())
  }
}

async fn main {
  @async.with_task_group(fn(g) {
    g.spawn_bg(fn() { tick("a", 3, 30) })
    g.spawn_bg(fn() { tick("b", 2, 45) })
  })
  println("done")
}
```

With `moonpp run --compiled`, the two tasks interleave:

```text
a 0
b 0
a 1
b 1
a 2
done
```

`async` is a keyword, but it can still be a package alias: `@async.sleep`.

## Compilation

- Async functions are only compiled to native MoonBit code, because functions in the uniform
  representation are synchronous. Their signature and body must be in the native fragment;
  otherwise compilation fails and names the first term that is not, with the same rules as
  [`#mbt` functions](../interop/mbt-functions.md).
- Async functions can also only be used by native code. If code in the uniform representation
  refers to an async function, for example a synchronous function outside the native fragment that
  returns an async lambda, compilation fails.
- `async fn main` compiles to MoonBit's `async fn main`, and `#mbt async fn` is exported as `pub
  async fn`.
- `moonbitlang/async` supports the native, JS and wasm targets, but not wasm-gc.
