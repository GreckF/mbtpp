# Known Limitations

## Language

- No termination checking or strict positivity checking (by design): you can "prove" false propositions.
- No automation tactics such as `simp`, `omega`, or `auto`. For the limits of algebraic effects, see [Algebraic Effects](lang/effects.md#limitations).
- Recursive local functions cannot use the `let mut` variables around them.
- A `match` with array patterns is not checked for coverage and does not refine types.
- `Map` is implemented in MoonBit++ by the Prelude (in insertion order, with linear lookups); it is
  not MoonBit's `Map`, so imported functions taking or returning a MoonBit `Map` cannot be called.
- There are no `BigInt` literals (`1N`), `Int16` or `UInt16`; `Float` only has its operators,
  comparisons and conversions.
- When functions with mutable state are run during type checking, calls that use arrays, imported functions or lambdas capturing `let mut` variables are not run (see [Mutable State and Loops](lang/mutation.md)).
- Time limits are measured in wall-clock time, so a file may time out on a slower machine (see [Time limits](lang/type-level.md#time-limits)).

## Imports

- The interpreter cannot run imported MoonBit functions; they can only be called after compilation.
- The interpreter runs async functions synchronously, without concurrency; async functions are only compiled to native code (see [async Functions](lang/async.md)).
- Imported functions returning a trait object `&Tr` cannot be compiled yet; for the other items that are not imported, see [Type mapping and items not imported](interop/types.md).

## Compiler

- `Hash` values differ between the interpreter and the compiled program (which uses MoonBit's hashes).
- Values are converted by value between the uniform representation and native code, so frequently passing large data across the boundary is slow.

## Tooling

- The generated project is always a main package; library packages cannot be generated.
- Requires a recent `moon` (one that uses `moon.mod` / `moon.pkg`).
