# MoonBit++

> **声明：这是一个纯 vibe coding 的娱乐项目，请不要认真看待。**
> 代码未经严格审查，类型检查器不保证可靠（没有终止检查，证明可以靠无限递归"证"出任何命题），
> 不适合用于任何正式用途。

A small dependently typed language with MoonBit syntax: a type checker and a
tree-walking interpreter, written in MoonBit.

语言标准大致来自：
[写给一般月兔用户的MoonBit++入门](https://zhuanlan.zhihu.com/p/2067605478985749711)（知乎，作者：用户名可以重复吗）

```sh
moon build --target wasm-gc
moonrun _build/wasm-gc/release/build/app/app.wasm -- examples/vector.mbtpp        # check and run
moonrun _build/wasm-gc/release/build/app/app.wasm -- check examples/vector.mbtpp  # only check
```

`moon test` runs the examples in `examples/` and the rejection tests in
`rejects_test.mbt`.

The language is described in [doc/mbtpp/proposal.md](doc/mbtpp/proposal.md),
the implementation in [doc/mbtpp/implementation.md](doc/mbtpp/implementation.md).
