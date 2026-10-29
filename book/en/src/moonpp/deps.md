# Dependencies

## Modules on mooncakes.io

```bash
moonpp add moonbitlang/x@0.5.6
```

Then import packages from the module in your package's `moon.pkg`:

```text
import {
  "moonbitlang/x/encoding/percent",
}
```

`moonpp add` calls `moon add` to download the module, and runs `moon info` to generate interfaces
for packages that lack a `.mbti` interface. Interfaces are read from the project's `.mooncakes/`.

## Standard library

`moonbitlang/core/*` does not need to be added; its interfaces are read from the MoonBit
installation directory (`~/.moon/lib/core`).

## Local modules

Use a MoonBit workspace: write a `moon.work` in the project root and declare the dependency in
`moon.mod`.

`moon.work`:

```text
members = [
  ".",
  "../geo",
]
```

`moon.mod`:

```text
name = "username/app"

version = "0.1.0"

import {
  "u/geo@0.1.0",
}

source = "src"
```

Local modules need `.mbti` interfaces; run `moon info` in that module to generate them.

For how to use MoonBit packages once they are imported, see
[Importing MoonBit Packages](../interop/import.md).
