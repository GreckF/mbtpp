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
- **Instance search**: the instances for bounds are filled in by the checker. It first looks at
  local bounds (and their supertraits), then at global instances (including generic instances).

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

## Traits in the Prelude

| Trait | Methods | MoonBit trait and method |
| --- | --- | --- |
| `Show` | `to_string(Self) -> String` | `Show` (`to_string`) |
| `Eq` | `op_equal(Self, Self) -> Bool` (`==`) | `Eq` (`equal`) |
| `Compare : Eq` | `compare(Self, Self) -> Int` | `Compare` (`compare`) |
| `Add`, `Sub`, `Mul`, `Div`, `Mod` | `op_add` etc. (`+ - * / %`) | `Add` (`add`) etc. |
| `Neg` | `op_neg(Self) -> Self` (unary `-`) | `Neg` (`neg`) |
| `Default` | `default() -> Self`, called as `Default::default()` | `Default` (`default`) |
| `Monad` | see [Higher-Kinded Traits and Monads](monad.md) | none |

`println` requires `Show`. Except for `Monad`, these traits are MoonBit's own traits: in the
compiled program, the instances for `#mbt` types are real MoonBit impls (e.g.
`impl Eq for Shape with equal(a0, a1)`), so MoonBit code can print, compare and sort these
values; a `#mbt fn` with these bounds (`fn[T : Show + Eq]`) compiles to a MoonBit function with
the same bounds. Instances for other types are only used inside MoonBit++ (MoonBit already has
the instances for `Int`, `String`, etc.).

## derive

Write `derive(Show, Eq, Compare)` after an enum or a struct and the checker generates the
instances:

```moonbit
enum Tree[T] {
  Leaf
  Node(Tree[T], T, Tree[T])
} derive(Show, Eq, Compare)

struct Point {
  x : Int
  y : Int
} derive(Show, Eq)

fn main {
  let t : Tree[Int] = Node(Leaf, 1, Leaf)
  println(t)                      // Node(Leaf, 1, Leaf)
  println(t == t)                 // true
  println(Leaf.compare(t))        // -1
  let p : Point = { x: 1, y: 2 }
  println(p)                      // {x: 1, y: 2}
}
```

- `Show`: constructors as `C(x, y)`, structs as `{x: 1, y: 2}`, fields with their own
  `to_string`.
- `Eq`: the same constructor with equal fields.
- `Compare`: by constructor, in declaration order, then by fields from left to right. `Compare`
  needs `Eq`, so write `derive(Eq, Compare)`.
- Type parameters get the same bound: `enum Tree[T] derive(Eq)` generates
  `impl[T : Eq] Eq for Tree[T]`.
- Only types with type parameters alone are supported: indexed types, enums whose constructors
  have a return type (GADTs) and structs with explicit parameters are not. Other traits (such as
  `Hash`) cannot be derived.
- If the type of a field has no instance of the trait, the error is reported on the line of the
  `derive`.

See [examples/derive.mbtpp](https://github.com/GreckF/mbtpp/blob/main/examples/derive.mbtpp) for
a complete example.
