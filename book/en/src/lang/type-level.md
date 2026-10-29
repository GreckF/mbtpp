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

Only pure functions are unfolded during type checking: functions that use mutable state, loops, or exceptions are not unfolded (see
[Mutable state and loops](mutation.md)).
