# Dependent Matching and Refinement

When you match on a variable, the constructor's indices are unified with the indices in the
variable's type, and the result refines the whole context and the goal type (Agda style):

```moonbit
enum Vec2[T] : Nat -> Type {
  VNil : Vec2[T](0)
  VCons[n : Nat](T, Vec2[T](n)) : Vec2[T](S(n))
}

fn[T, n : Nat] Vec2::zip_with(self : Vec2[T](n), other : Vec2[T](n), f : (T, T) -> T) -> Vec2[T](n) {
  match (self, other) {
    (VNil, VNil) => VNil
    (VCons(x, xs), VCons(y, ys)) => VCons(f(x, y), xs.zip_with(ys, f))
  }
}

fn main {
  let v : Vec2[Int](2) = VCons(1, VCons(2, VNil))
  match v.zip_with(v, (a, b) => a + b) {
    VCons(x, _) => println(x)
  }
}
```

- When `self` matches `VNil`, unification yields `n = 0`. So `other : Vec2[T](0)` can only be `VNil`,
  and combinations like `(VNil, VCons(…))` need not be written.
- In each arm the goal type `Vec2[T](n)` is refined too: the `VNil` arm returns `Vec2[T](0)`, and the
  `VCons` arm returns `Vec2[T](S(n'))`.
- Matching on implicit parameters refines as well, e.g. `match g { Empty => …; Extend(_, _) => … }`,
  where `g` is an implicit parameter of the function.

## Matching on the result of a function call

When the scrutinee is not a variable (e.g. a function call), the index relationships in its result
type are still used to refine the goal type:

```text
match progress(t1) {
  PrStep(_, u1, st1) => PrStep(_, _, StApp1(t1, u1, t2, st1))
  PrDone(_, VLam(b)) => PrStep(_, _, StApp(b, t2))
}
```

See `examples/stlc.mbtpp` in the repository for the full example.

## Eliminating Prop

When matching on data in `Prop`, the result must also be in `Prop`, unless the type is a
subsingleton (such as propositional equality `===`, which has at most one proof).
