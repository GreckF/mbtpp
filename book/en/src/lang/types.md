# Types

## Universes

- `Type : Type`: types are values, and the type of a type is `Type` (which makes the system inconsistent; see the disclaimer in the [introduction](../README.md)).
- `Prop : Type`: the universe of propositions. Values of types in `Prop` are proofs; proofs are irrelevant, so any two proofs of the same type are considered equal.
  See [Propositions and proofs](proofs.md).

## Function types

| Syntax | Meaning |
| --- | --- |
| `(Int, Int) -> Int` | A function taking two parameters |
| `(Int) -> (Int) -> Int` | A function returning a function |
| `(n : Nat, v : Vector[Int](n)) -> Int` | Dependent function type: later types may refer to earlier parameters |
| `forall x : A, P(x)` | Means `(x : A) -> P(x)`; `forall x y : A, …` binds several |
| `[T](x : T) -> T` | One parameter group, implicit first, explicit after |
| `[T] -> Type` | A group with only implicit parameters |
| `(A) -> B raise E` | A function that may raise error `E` |

```moonbit
fn types_demo() -> Int {
  let f : (Int, Int) -> Int = (a, b) => a + b       // two parameters
  let g : (Int) -> (Int) -> Int = a => b => a + b   // function returning a function
  f(1, 2) + g(1)(2)
}

fn main {
  println(types_demo())
}
```

## Application and shorthands

- Types are functions too: `Array[Int]`, `Vector[T](n)`, and `Id[T](x)(y)` are all ordinary applications, where `[...]` gives implicit
  arguments and `(...)` gives explicit ones.
- `T?` means `Option[T]`; `(A, B)` is a pair type.
- A function returning `Type` is a type-level function; see [Type-level computation](type-level.md).

## Constants and type aliases

- `const N : Int = 3` and `const N = 3` define constants (like `let`).
- `typealias Int as Score` and `typealias Pair[A] = (A, A)` define type aliases.
