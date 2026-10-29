# Project Structure

A MoonBit++ project is simply a MoonBit module, and a package is a directory containing `.mbtpp`
files:

```text
hello/
  moon.mod                 module: name, version, dependencies, source directory
  src/
    main/
      moon.pkg             package: imported MoonBit packages, whether it is a main package
      main.mbtpp           a package can have several .mbtpp files
  mbtpp_out/               output of moonpp build
```

## moon.mod

```text
name = "username/hello"

version = "0.1.0"

import {
  "moonbitlang/x@0.5.6",
}

source = "src"
```

The `import` block lists the module's dependencies and is maintained by `moonpp add`.

## moon.pkg

```text
import {
  "moonbitlang/x/encoding/percent",
  "moonbitlang/core/string" @str,
}

options(
  "is-main": true,
)
```

- The `import` block lists the MoonBit packages the package imports. `@alias` is optional and
  defaults to the last segment of the path.
- The main package is marked with `options("is-main": true)`. Newer versions of `moon fmt` rewrite
  this as `pkgtype(kind: "executable")`; both forms are accepted.
- All `.mbtpp` files of a package share one scope; errors point to the specific file.

## Check order

The files of a package are checked one after another in lexicographic order of file name. Names can
refer to each other (a function can call one defined later), but **computation** during type
checking can only use function bodies that have already been checked: if a proof in `facts.mbtpp`
needs to compute a function defined in `shapes.mbtpp`, `shapes.mbtpp` must be checked first. Use
`"mbtpp-order"` to specify the order:

```text
options(
  "is-main": true,
  "mbtpp-order": [ "shapes.mbtpp" ],
)
```

The listed files are checked first (in the listed order), and the remaining files follow in
lexicographic order. In the old `moon.pkg.json` format, write
`"mbtpp-order": [ "shapes.mbtpp" ]`. `moon` ignores this option, and `moon fmt` preserves it.

If an error may have been caused by the check order, `moonpp` gives a hint:

```text
src/main/facts.mbtpp:1:47: error: type mismatch
  expected: Shape::area(Rect(3, 3)) === 9
  actual:   ?94 === ?94
hint: Shape::area is defined in src/main/shapes.mbtpp, which is checked after
src/main/facts.mbtpp, so its definition could not be used here; the error may
come from that. … list it in the package's moon.pkg: options("mbtpp-order": [ "shapes.mbtpp", ... ])
```

## Old format

The old `moon.mod.json` and `moon.pkg.json` files can still be read. However, newer versions of
`moon` no longer accept `moon.mod.json`, so when you need dependency management or compilation, run
`moon fmt` in the project root to migrate; `moonpp` gives a hint when this happens.
