# enum and Indexed Types

## Plain enums

```moonbit
enum Shape {
  Circle(Double)
  Rect(Double, Double)
}

fn Shape::area(self : Shape) -> Double {
  match self {
    Circle(r) => 3.14 * r * r
    Rect(w, h) => w * h
  }
}

fn main {
  println(Rect(2.0, 3.0).area())
}
```

## Parameters and indices

```text
enum Name[implicit params](explicit params) : indices -> universe { constructors }
```

- **Parameters** come after the name and are fixed across all constructors.
- **Indices** come after the colon and may vary between constructors. The universe is `Type` or `Prop`.
- **Constructors**: `C[own implicit params](fields) : return type`. The return type can be omitted when there are no indices.

```moonbit
enum Vector[T] : Nat -> Type {
  Nil : Vector[T](0)
  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
}

// Indices written in []: a GADT
enum Exp : [T] -> Type {
  IntLit(Int) : Exp[Int]
  BoolLit(Bool) : Exp[Bool]
  Add(Exp[Int], Exp[Int]) : Exp[Int]
  If[T](Exp[Bool], Exp[T], Exp[T]) : Exp[T]
}

fn[T] Exp::eval(self : Exp[T]) -> T {
  match self {
    IntLit(n) => n
    BoolLit(b) => b
    Add(l, r) => l.eval() + r.eval()
    If(c, t, f) => if c.eval() { t.eval() } else { f.eval() }
  }
}

fn main {
  let e = If(BoolLit(true), Add(IntLit(1), IntLit(2)), IntLit(0))
  println(e.eval())
}
```

The result type of `Exp::eval` varies by constructor: when `IntLit(n)` matches, `T` is refined to `Int`.

## Named fields

Constructor fields can be named, and the types of later fields can refer to them:

```moonbit
enum Sigma[A](P : (A) -> Type) {
  MkSigma(fst : A, snd : P(fst))
}
```

## Using constructors

- The data type's parameters are always inferred; `[...]` supplies only the constructor's own implicit parameters, e.g. `Cons[n](x, xs)`.
- Constructors with the same name are disambiguated by the expected type, or you can write the full name `Vector::Cons`.
- An enum whose universe is `Prop` is a proposition, e.g. `Id` in the Prelude (see [Propositional Equality](equality.md)).

## Labelled fields

```moonbit
enum Shape {
  Rect(width~ : Int, height~ : Int)
  Circle(Int, label~ : String)
}

fn area(s : Shape) -> Int {
  match s {
    Rect(width~, height~) => width * height
    Circle(r, ..) => 3 * r * r
  }
}

fn main {
  println(area(Rect(height=2, width=5)))
}
```

Constructor fields can have labels: `C(x=e)` builds, and `C(x~)` or `C(x=p)` matches; `..` lets
the other fields match anything.
