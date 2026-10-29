# Expressions and Statements

Expressions and statements are the same as in MoonBit:

```moonbit
fn demo(xs : Array[Int]) -> Int {
  let a = 1                       // immutable binding
  let mut total = a               // mutable binding
  total = total + 2               // assignment
  for x in xs {
    total = total + x
  }
  let f = (x : Int) => x * 2      // lambda; also x => e, (x, y) => e
  let g = fn(x : Int) { x + 1 }   // anonymous function
  let s = if total > 10 { "big" } else { "small" }
  println(s)
  total |> f |> g                 // pipe
}

fn main {
  println(demo([1, 2, 3]))
}
```

- **Blocks**: the value of `{ s1; s2; e }` is the last expression.
- **`let`**: `let x = e`, `let x : T = e`; pattern bindings `let (a, b) = pair` (coverage checked).
- **`if`**: `if c { a } else { b }` is an expression; without `else` its value is `()`.
- **Lambdas**: `x => e`, `(x, y) => e`, `(x : Int) => e`, `fn(x : Int) { … }`.
- **Pipes**: `e |> f` means `f(e)`, and `e |> f(a)` means `f(e, a)`.
- **Type annotations**: `(e : T)`.
- **Holes**: `_` is inferred by unification and can appear in both expressions and types, e.g. `Cons(_, xs)`, `f[_, Int](x)`.
- **Local functions**: a block can contain `fn name(x : T) -> R { … }`; it can be recursive. A
  recursive local function cannot use the `let mut` variables around it.
- **Cascades**: `xs..push(1)..push(2)` calls the methods of `xs` in turn; its value is `xs`.
- **Arrays**: `xs[i]` reads an element and `xs[i] = v` assigns one.

There are three kinds of equals sign: `=` defines, `==` is boolean equality (result `Bool`), and `===` is propositional equality (result `Prop`; see
[Propositional equality](equality.md)).

For loops, `return`, `break`, and `continue`, see [Mutable state and loops](mutation.md); for `raise` and `try`, see
[Error handling](errors.md).
