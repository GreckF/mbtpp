# Mutable State and Loops

```moonbit
fn sum_to(n : Int) -> Int {
  let mut acc = 0
  for i = 1; i <= n; i = i + 1 {
    acc = acc + i
  }
  acc
}

fn find_first(xs : Array[Int], p : (Int) -> Bool) -> Int {
  for x in xs {
    if p(x) {
      return x
    }
  }
  -1
}

fn main {
  println(sum_to(100))
  println(find_first([1, 5, 8, 11], x => x % 2 == 0))
  let mut i = 0
  while true {
    i += 1
    if i > 5 {
      break
    }
  }
  println("i = \{i}")
  let arr = Array::make(3, 0)
  arr[1] = 42
  for k in 0..<3 {
    print(arr[k])
    print(" ")
  }
  println("")
}
```

- **Mutable variables**: `let mut x = e`, assignment `x = e`, and `+=`, `-=`, `*=`, `/=`.
- **Loops**: `while c { … }`; C-style `for i = 0; i < n; i = i + 1 { … }`; `for x in xs { … }`
  iterates over an array; `for k in a..<b` and `for k in a..=b` iterate over a range.
- **`break`** and **`continue`** apply to the innermost loop; **`return`** returns from the current
  function, and inside a lambda it returns only from the lambda.
- **Arrays** are mutable: `xs[i] = v`, `xs.push(x)`.

## Interaction with type checking

Functions that use `let mut`, assignment, loops, `raise`, or `try` are **run** during type checking,
as the interpreter would run them: if the run finishes, the call is replaced by its result; if it
cannot finish, the whole call stays folded, like a constant.

```moonbit
fn sum_to(n : Int) -> Int {
  let mut i = 0
  let mut acc = 0
  while i < n {
    i = i + 1
    acc = acc + i
  }
  acc
}

fn inc(x : Int) -> Int {
  let mut y = x
  y = y + 1
  y
}

lemma s10 : sum_to(10) === 55 = Refl
lemma inc_x[x : Int] : inc(x) === x + 1 = Refl

fn main {
  let v : Array[Int] = Array::make(sum_to(3), 0)
  println(v.length())
}
```

- **The run finishes** when every decision can be made: for example with concrete arguments, or,
  like `inc(x)`, when no decision is needed. Errors reach their `try` as usual, and output such as
  `println` is skipped (it does not change the result).
- **The call stays folded** when a decision depends on an unknown value (`if x < 0` in `abs(x)`,
  where `x` is a variable); when an error escapes the function; when the function uses an array
  (arrays are mutable), an imported MoonBit function or an async function; or when a lambda
  captures a `let mut` variable. The result could then depend on more than the arguments.
- So general properties over variable arguments, such as "for all `n`, `sum_to(n) * 2 == n * (n +
  1)`", still cannot be proved this way.
- A loop that does not terminate keeps the checker running until the
  [time limit](type-level.md#time-limits) of the definition.
