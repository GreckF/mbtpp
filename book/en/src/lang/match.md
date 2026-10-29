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

Pattern matching in MoonBit++ is dependent:

- [Dependent Matching and Refinement](dependent-match.md): matching a constructor refines the indices in types.
- [Coverage Checking and Impossible Branches](coverage.md): missing arms are errors, and arms that are impossible by their types can be omitted.
- [The return Clause](return-clause.md): give the motive of a match explicitly (Rocq style).
