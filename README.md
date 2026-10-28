# MoonBit++

> **声明：这是一个纯 vibe coding 的娱乐项目，请不要认真看待。**
> 代码未经严格审查，类型检查器不保证可靠（没有终止检查，证明可以靠无限递归"证"出任何命题），
> 不适合用于任何正式用途。

A small dependently typed language with MoonBit syntax: a type checker and a
tree-walking interpreter, written in MoonBit.

语言标准大致来自：
[写给一般月兔用户的MoonBit++入门](https://zhuanlan.zhihu.com/p/2067605478985749711)（知乎，作者：用户名可以重复吗）

## moonpp

`moonpp` is the build tool, modelled on `moon`. It needs Node.js: build it
once with

```sh
moon build --target js
```

and put `bin/` on your `PATH` (or call `bin/moonpp`, `bin\moonpp.cmd` on
Windows).

```sh
moonpp new hello && cd hello   # create a project
moonpp run                     # run the main package
moonpp check                   # type check all packages
moonpp add moonbitlang/x       # add a dependency (runs `moon add`, generates missing .mbti)
moonpp install                 # install dependencies (runs `moon install`)
moonpp run examples/vector.mbtpp   # a single file also works
```

A project is a MoonBit module (`moon.mod.json`); a package is a directory of
`.mbtpp` files. The MoonBit packages a package uses are listed in the `import`
field of its `moon.pkg.json` and referred to as `@pkg.name`; they are only
type checked, so running a call to them stops with an error (see
[examples/import](examples/import)).

`moon test` runs the examples in `examples/` and the tests in `src/*_test.mbt`.

The language is described in [doc/mbtpp/proposal.md](doc/mbtpp/proposal.md),
the implementation in [doc/mbtpp/implementation.md](doc/mbtpp/implementation.md).
