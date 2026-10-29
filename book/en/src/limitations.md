# Known Limitations

## Language

- No termination checking or strict positivity checking (by design): you can "prove" false propositions.
- No resumable algebraic effects, and no automation tactics such as `simp`, `omega`, or `auto`.
- Recursive local functions cannot use the `let mut` variables around them.
- A `match` with array patterns is not checked for coverage and does not refine types.
- When functions with mutable state are run during type checking, calls that use arrays, imported functions or lambdas capturing `let mut` variables are not run (see [Mutable State and Loops](lang/mutation.md)).
- Time limits are measured in wall-clock time, so a file may time out on a slower machine (see [Time limits](lang/type-level.md#time-limits)).
- Structs have no mutable fields, and there are no struct patterns.
- Traits have no default methods.

## Imports

- The interpreter cannot run imported MoonBit functions; they can only be called after compilation.
- The interpreter runs async functions synchronously, without concurrency; async functions are only compiled to native code (see [async Functions](lang/async.md)).
- Generic `impl`s, trait objects, and similar items in imported packages are not imported (see [Type mapping and items not imported](interop/types.md)).

## Compiler

- Arrays are not native types in native code: signatures containing arrays use the uniform representation and cannot be `#mbt`.
- Values are converted by value between the uniform representation and native code, so frequently passing large data across the boundary is slow.

## Tooling

- The generated project is always a main package; library packages cannot be generated.
- Requires a recent `moon` (one that uses `moon.mod` / `moon.pkg`).
