# MoonBit++

> **声明：这是一个纯 vibe coding 的娱乐项目，请不要认真看待。**
> 代码未经严格审查。

A small dependently typed language with MoonBit syntax: a type checker and a
tree-walking interpreter, written in MoonBit.

语言标准大致来自：
[写给一般月兔用户的MoonBit++入门](https://zhuanlan.zhihu.com/p/2067605478985749711)（知乎，作者：用户名可以重复吗）

## Playground

Try it online: <https://greckf.github.io/mbtpp/> (manual: <https://greckf.github.io/mbtpp/book/>) — type checking while you
edit, running with the interpreter, and the MoonBit code the compiler
generates. The page lives in [docs/](docs); rebuild it with
`node scripts/build-web.mjs`.

## VS Code

[editors/vscode](editors/vscode) is a VS Code extension (a `.vsix` is
attached to each release): highlighting, errors while typing, hover types, go
to definition, `#mbt` quick fixes, an info view with the goals of tactic
proofs, and run/check/build commands. It uses `moonpp ide`.

## moonpp

`moonpp` is the build tool, modelled on `moon`. It needs Node.js, and a
MoonBit toolchain that uses `moon.mod` / `moon.pkg` (2026-10 or later) for
compiling and dependencies. Install a release (see
[Releases](https://github.com/GreckF/mbtpp/releases) for the versions):

```sh
npm install -g https://github.com/GreckF/mbtpp/releases/download/v0.1.0/moonpp-0.1.0.tgz
```

or, from a checkout, build it once with

```sh
moon build --target js --release
```

and install the command globally with

```sh
npm install -g .
```

(it links to this checkout, so later `moon build --target js --release` runs update it;
`npm uninstall -g moonpp` removes it). You can also call `bin/moonpp` or
`bin\moonpp.cmd` directly.

```sh
moonpp new hello && cd hello   # create a project
moonpp run                     # run the main package
moonpp check                   # type check all packages (and list `pub` declarations that could be #mbt)
moonpp fix                     # add #mbt to those declarations
moonpp add moonbitlang/x       # add a dependency (runs `moon add`, generates missing .mbti)
moonpp install                 # install dependencies (runs `moon install`)
moonpp run examples/vector.mbtpp   # a single file also works
moonpp build                   # compile to a MoonBit project (mbtpp_out/<pkg>) and `moon build` it
moonpp build -o out            # ... generated in out/ instead
moonpp run --compiled          # compile to MoonBit and run it with `moon run`
```

A project is a MoonBit module (`moon.mod`); a package is a directory of
`.mbtpp` files. The MoonBit packages a package uses are listed in the
`import` block of its `moon.pkg` and referred to as `@pkg.name`; they are
only type checked by the interpreter (running a call to them stops with an
error), and really called by the compiled program (see
[examples/import](examples/import)). Projects with the old `moon.mod.json` /
`moon.pkg.json` are still read; `moon fmt` migrates them.

`moonpp build` generates a complete MoonBit project: its own `moon.mod`
(the name, version and dependencies of the MoonBit++ project), a `moon.work`
(listing local modules of the workspace by absolute path) and the package
`<pkg>` with one `.mbt` file per `.mbtpp` file (plus `mbtpp_prelude.mbt`,
`mbtpp_imports.mbt` and `mbtpp_runtime.mbt`), so `moon run <pkg>` works there
without moonpp.

The compiler translates MoonBit++ to MoonBit: functions over types MoonBit
can express (numbers, strings, datatypes with type parameters, functions)
become ordinary MoonBit code, e.g. `Vector[T](n)` becomes
`enum E_Vector[T0] { Nil; Cons(T0, E_Vector[T0]) }`; the rest (dependent
types computed at run time, ...) uses a uniform value representation.
Types and traits marked `#mbt` translate trivially: `#mbt enum Tree[T]`
becomes the MoonBit `enum Tree[T0]`, a `#mbt trait` a MoonBit trait with
real `impl`s and bounds; imported `pub(all)` types and `pub(open)` traits
are `#mbt` automatically, so MoonBit functions over them can be called.
A `#mbt fn` is compiled to a public MoonBit function of the same name that
MoonBit code can call (see
[examples/mbt_types.mbtpp](examples/mbt_types.mbtpp)).

`moon test` runs the examples in `examples/` and the tests in `src/*_test.mbt`.

The manual (language, moonpp, MoonBit interop) is online at
<https://greckf.github.io/mbtpp/book/>; its source is in [book/src](book/src)
(an [mdBook](https://github.com/rust-lang/mdBook): `mdbook build book` writes
`docs/book`, `node scripts/check-book.mjs` checks its examples). The design
notes are in [doc/mbtpp/proposal.md](doc/mbtpp/proposal.md), the
implementation in [doc/mbtpp/implementation.md](doc/mbtpp/implementation.md).
