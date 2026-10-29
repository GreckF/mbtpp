# Traits

```moonbit
trait Shape {
  area(Self) -> Int
  name(Self) -> String
}

trait Solid : Shape {                          // supertrait
  volume(Self, Int) -> Int
}

struct Square {
  side : Int
}

impl Shape for Square with area(self) { self.side * self.side }
impl Shape for Square with name(self) { "square" }
impl Solid for Square with volume(self, depth) { self.area() * depth }

fn[S : Shape] describe(s : S) -> String {
  "\{s.name()} with area \{s.area()}"
}

fn[S : Solid] describe_solid(s : S) -> String {
  describe(s) + ", volume \{s.volume(2)}"     // supertrait methods are available
}

fn main {
  let sq : Square = { side: 2 }
  println(describe_solid(sq))
}
```

- **Declaration**: `trait Name : Super1 + Super2 { method(param types) -> result }`. The first
  parameter of a method is usually `Self`. Generic methods are written `fn[T] m(…)`.
- **Implementation**: `impl Tr for T with m(params) { … }`, one per method. Generic instances:
  `impl[T : Show] Show for Array[T] with to_string(self) { … }`.
- **Bounds**: `fn[T : Tr]`; multiple bounds are written `[T : Eq + Show]`.
- **Calls**: `x.m()` or `Tr::m(x)`.

### Bounds and implicit parameters

`[T : Add]` and `[n : Nat]` are written the same way; they are told apart by the name to the right
of the colon:

- If the right side is a trait (or several traits joined by `+`), this is a **bound**: `T` is a
  type (its kind is determined by the trait's `Self`: `Type` for `Add`, `[T] -> Type` for
  `Monad`), and each trait adds an instance parameter that the checker fills in automatically.
  Read it as "a type `T` that implements `Add`".
- If the right side is a type, this is an ordinary **implicit parameter**: `n` is a value of type
  `Nat`, as in `fn[T, n : Nat] Vector::head(…)`.

Traits and types share one namespace and cannot have the same name, so there is no ambiguity. Note:

- This rule applies only inside `[...]`. An explicit parameter `(x : Add)` is checked as a type and
  is an error: there are no MoonBit trait objects `&Add`.
- Local names take precedence: if an enclosing parameter has the same name as a trait, the right
  side of the colon refers to that parameter.
- Multiple bounds must have the same kind (the kind of `T` is taken from the first trait);
  `[M : Monad + Show]` is an error.
- **Instance search**: the instances for bounds are filled in by the checker. It first looks at
  local bounds (and their supertraits), then at global instances (including generic instances).

Traits in the Prelude: `Show` (`to_string`), `Eq` (`op_equal`), `Compare : Eq` (`compare`),
`Add` (`op_add`), `Monad` (see [Higher-Kinded Traits and Monads](monad.md)). `println` requires
`Show`.
