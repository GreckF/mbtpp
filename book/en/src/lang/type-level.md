# Type-Level Computation

Types are values, so you can compute types with ordinary functions, and the type checker normalizes (evaluates) them:

```moonbit
// The type of functions that take n Int arguments and return Int
fn NAry(n : Nat) -> Type {
  match n {
    Z => Int
    S(k) => (Int) -> NAry(k)
  }
}

fn sum_n(n : Nat, acc : Int) -> NAry(n) {
  match n as m return NAry(m) {
    Z => acc
    S(k) => x => sum_n(k, acc + x)
  }
}

fn main {
  println(sum_n(3, 0)(1)(2)(3))   // 6
}
```

The type of `sum_n(3, 0)`, `NAry(3)`, is computed during type checking to `(Int) -> (Int) -> (Int) -> Int`.
Here a [return clause](return-clause.md) gives the motive of the match.

During type checking, pure functions are unfolded, and functions that use mutable state, loops, or
exceptions are run, staying folded when the run cannot finish (see
[Mutable state and loops](mutation.md)).

## Time limits

There is no termination checking, so a computation during type checking may never end. The checking
of each definition is therefore limited in time, 30 seconds by default; beyond that, the definition
fails, with the function being evaluated at that moment:

```text
t.mbtpp:3:1: error: checking f took more than 30 s (while evaluating T); a definition that does
not terminate? Raise the limit with #timelimit(seconds) or #timelimit(none)
```

`#timelimit` before a definition changes its limit:

```moonbit
fn sum_to(n : Int) -> Int {
  let mut acc = 0
  for i = 1; i <= n; i = i + 1 {
    acc = acc + i
  }
  acc
}

#timelimit(120)
lemma big : sum_to(1000) === 500500 = Refl

#timelimit(none)
lemma bigger : sum_to(2000) === 2001000 = Refl
```

- The unit is seconds; `#timelimit(none)` means no limit. It can be combined with `#mbt`.
- The limit applies to each definition, not to the whole check. The signature and the body are
  timed separately. Other definitions checked on the way (for example functions it uses that are
  written later) have their own limits, and their time does not count for this one.
- The limit only covers type checking, not running the program with `moonpp run`.
- The playground also stops a whole check or run after 60 seconds, and the VS Code extension stops a
  check after 120 seconds by default (setting `mbtpp.checkTimeout`).
