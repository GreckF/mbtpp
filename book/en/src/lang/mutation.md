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

Functions that use `let mut`, assignment, loops, `raise`, or `try` are **not unfolded** during type
checking: they can be called and run normally, but they take no part in type-level computation,
and equations about them cannot be proved with `Refl`.
