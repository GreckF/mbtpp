# Known Limitations

## Language

- No termination checking or strict positivity checking (by design): you can "prove" false propositions.
- No resumable algebraic effects, and no automation tactics such as `simp`, `omega`, or `auto`.
- Local functions cannot be recursive.
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
