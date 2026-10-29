# Pattern Matching

`match` is written the same way as in MoonBit:

```moonbit
fn describe(n : Int, xs : List[Int]) -> String {
  match (n, xs) {
    (0, _) => "zero"
    (_, Nil) => "empty"
    (_, Cons(x, Cons(_, _))) => "at least two, starting with \{x}"
    _ => "other"
  }
}

fn main {
  println(describe(1, Cons(7, Cons(8, Nil))))
}
```

- **Patterns**: variables, the wildcard `_`, constructors (possibly nested), literals, tuples.
- Arms are tried in order and may overlap; the first matching arm wins.
- **Implicit parameters of constructors** can be bound or ignored in patterns: `If[t](c, a, b)`, `IZ[_, a] => a`.
- **`let` patterns**: `let (a, b) = pair`.

## Or-patterns, `as`, and guards

```moonbit
enum Shape {
  Circle(Int)
  Rect(Int, Int)
  Square(Int)
}

fn kind(s : Shape) -> String {
  match s {
    Rect(_, _) | Square(_) => "polygon"
    Circle(r) if r > 10 => "big circle"
    Circle(_) => "circle"
  }
}

fn widest(s : Shape) -> Shape {
  match s {
    Rect(w, _) | Square(w) as big if w > 100 => big
    other => other
  }
}

fn main {
  println(kind(Circle(11)))
  println(widest(Square(200)) is Square(_))
}
```

- **Or-patterns** `p | q` can be nested (`Some(1 | 2)`); all alternatives must bind the same
  variables. The checker expands them into separate arms, each matched dependently on its own.
- **`p as x`**: `x` is the whole matched value. `as` binds loosest: in `A | B as x`, `x` is the
  value matched by `A | B`.
- **Guards** `p if cond => …`: when the condition is false, the following arms are tried. The
  condition can use the variables bound by the pattern. Guarded arms do not count for coverage.

## `is` and `guard`

```moonbit
fn get(o : Option[Int]) -> Int {
  if o is Some(x) && x > 5 {
    x
  } else {
    0
  }
}

fn length(xs : List[Int]) -> Int {
  let mut cur = xs
  let mut n = 0
  while cur is Cons(_, rest) {
    n = n + 1
    cur = rest
  }
  n
}

fn head_or(xs : List[Int], d : Int) -> Int {
  guard xs is Cons(h, _) else { return d }
  h
}

fn main {
  println(get(Some(9)))
  println(length(Cons(1, Cons(2, Nil))))
  println(head_or(Nil, 42))
}
```

- **`e is p`** is a `Bool`. In the condition of an `if`, `while` or `guard`, the variables bound
  by `p` are visible in the rest of the `&&` chain and in the code run when the condition holds.
- **`guard cond else { … }`**: when the condition fails, the `else` block runs; it usually
  `return`s, `break`s or calls `abort(…)`. The following statements can use the variables bound
  by `cond`. Without `else`, a failed condition aborts the program.
- With `is` in a condition, the `else` branch is expanded once at each `is` that can fail, so its
  code is duplicated.

Pattern matching in MoonBit++ is dependent:

- [Dependent Matching and Refinement](dependent-match.md): matching a constructor refines the indices in types.
- [Coverage Checking and Impossible Branches](coverage.md): missing arms are errors, and arms that are impossible by their types can be omitted.
- [The return Clause](return-clause.md): give the motive of a match explicitly (Rocq style).
