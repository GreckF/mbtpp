# Compiling to MoonBit

The compiler translates the type-checked program into MoonBit. `moonpp build` and `moonpp run --compiled` use it;
"Compile to MoonBit" in the [Playground](https://greckf.github.io/mbtpp/) shows the result directly.

Two translations are mixed:

## Native translation

A function whose parameters and result are native types, and whose body is in the first-order fragment, is translated into an ordinary (possibly generic) MoonBit
function. The native types are:

- `Int`, `Double`, `Bool`, `Char`, `String`, `Unit`;
- type parameters and function types;
- data types whose parameters are all types and whose fields are all native types.

Indices and erased fields disappear, for example:

```text
enum Vector[T] : Nat -> Type { Nil : …; Cons[n : Nat](T, Vector[T](n)) : … }
// compiles to
enum E_Vector[T0] { Nil; Cons(T0, E_Vector[T0]) }
```

`#mbt` types use their own names instead of `E_…` (see [#mbt Types and Traits](mbt-types.md)).

## Uniform representation

Everything else (type-level computation, GADT refinement, non-`#mbt` traits, etc.) uses the uniform representation `Value`. It is
an extensible enum (MoonBit's `extenum`) in the runtime, with fixed variants `VInt`, `VFun`, and so on; each generated file uses
`extenum Value += { … }` to add the constructors of its own data types. Indices and erased fields do not appear, and fields are
`Value`. For example, the GADT in `basic.mbtpp`:

```text
enum Exp : [T] -> Type {
  IntLit(Int) : Exp[Int]
  Add(Exp[Int], Exp[Int]) : Exp[Int]
  If[T](Exp[Bool], Exp[T], Exp[T]) : Exp[T]
  …
}
```

compiles in `basic.mbt` to

```text
extenum Value += {
  K_Exp_IntLit(Value)
  K_Exp_Add(Value, Value)
  K_Exp_If(Value, Value, Value)
  …
}
```

The `match` in `eval` is native:

```text
fn f19_exp_eval(self : Value) -> Value raise {
  match self {
    K_Exp_IntLit(n) => n
    K_Exp_Add(lhs, rhs) => VInt(as_int(f19_exp_eval(lhs)) + as_int(f19_exp_eval(rhs)))
    …
  }
}
```

The result type of `eval` varies with the index (the `IntLit` branch returns `Int`, the `BoolLit` branch returns `Bool`), which MoonBit's
type system cannot express, so its result is still `Value`. Runtime support (`apply`, primitives, the dynamic pattern matcher) lives in
the generated `mbtpp_runtime.mbt`; it gets constructor names and fields (for display and equality) from decoders that each file
registers in `fn init`. The two kinds of code convert values at their boundary.

Because `Value` can be extended from other files and other packages, this representation also suits separate compilation of multiple MoonBit++ packages in the future.

## Erasure

- Type parameters are always erased.
- Other implicit parameters and implicit constructor fields are erased when they are used only in types.
- Proofs are always erased: parameters and fields whose type is a proposition (implicit or not),
  `let`s of proofs and calls of lemmas produce no code, and lemmas themselves are not generated; a
  match on a proof runs its first arm (a match on a proof of an empty proposition becomes an
  `abort`). So a `#mbt fn` can have proof parameters, like
  `fn get(xs : Array[Int], i : Int, p : i < n)`, and the exported MoonBit function does not have
  them.

## Performance

A `fib` program runs about 40 times faster when compiled (7.85 s interpreted, 0.18 s compiled). Before constructors became native
variants of `Value`, data in the uniform representation was `VCon(constructor name, field array)` and matching compared strings; with native variants,
evaluating an `Exp` tree with 2^18 leaves 20 times dropped from 2.65 s to 1.26 s.
