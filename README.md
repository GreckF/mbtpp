# MoonBit++

A small dependently typed language with MoonBit syntax: a type checker and a
tree-walking interpreter, written in MoonBit.

```sh
moon build --target wasm-gc
moonrun _build/wasm-gc/release/build/app/app.wasm -- examples/vector.mbtpp        # check and run
moonrun _build/wasm-gc/release/build/app/app.wasm -- check examples/vector.mbtpp  # only check
```

`moon test` runs the examples in `examples/` and the rejection tests in
`rejects_test.mbt`.

The language is described in [doc/mbtpp/proposal.md](doc/mbtpp/proposal.md),
the implementation in [doc/mbtpp/implementation.md](doc/mbtpp/implementation.md).
