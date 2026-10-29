# The MoonBit++ Manual

<p align="center"><img src="images/mascot.jpg" alt="MoonBit++ mascot: a magenta rabbit in a white lab coat and goggles, laughing hard" width="320"></p>

MoonBit++ is a dependently typed language with MoonBit syntax: the same `fn`, `enum`, `struct`, `trait`,
`match`, `let mut`, `for`, and `raise`, plus dependent types, indexed types, dependent pattern matching, propositions, and proofs.

It includes:

- **A type checker**: dependent types, unification, dependent pattern matching with coverage checking, instance search, and simple tactics.
- **An interpreter**: runs type-checked programs directly.
- **A compiler**: translates programs to MoonBit, generating native code for the parts expressible in MoonBit types.
- **`moonpp`**: a `moon`-like command-line tool for managing projects, dependencies, and builds.

> This is a purely vibe-coded fun project. Please don't take it seriously.

This manual has three parts:

- **Language**: one chapter per feature, from lexical structure to proofs, traits, and effects.
- **moonpp**: installation, project layout, commands, dependencies, and build output.
- **Interop with MoonBit**: importing MoonBit packages, compiling to MoonBit, `#mbt` declarations, and using compiled output from MoonBit.

Examples with `fn main` have a ▶ button in the top-right corner that opens them in the [Playground](https://greckf.github.io/mbtpp/)
to run. Source code and examples are on [GitHub](https://github.com/GreckF/mbtpp).
