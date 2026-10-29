# Build Output

`moonpp build` generates a complete MoonBit project that can be built and run without moonpp:

```text
mbtpp_out/main/
  moon.mod          name, version and dependencies of the original project
  moon.work         workspace: itself, plus local modules (absolute paths)
  README.md
  .gitignore
  main/
    moon.pkg            imported MoonBit packages; main package
    main.mbt            compiled from src/main/main.mbtpp
    shapes.mbt          compiled from src/main/shapes.mbtpp (one .mbt per .mbtpp)
    mbtpp_prelude.mbt   Prelude definitions in use
    mbtpp_imports.mbt   glue code for calling imported MoonBit packages (when needed)
    mbtpp_runtime.mbt   runtime support (value representation, pattern matching, primitives)
```

Source files and generated files correspond one to one: the definitions in `x.mbtpp` (functions,
data types, traits, instances) are compiled to `x.mbt`; a file with no runtime code (for example,
one with only lemmas) still produces an `x.mbt` containing only a comment header. The three file
names starting with `mbtpp_` are used by moonpp, so source files cannot have those names.

```bash
cd mbtpp_out/main
moon run main
```

- The default location is the project's `mbtpp_out/<package name>`; for a single file it is
  `<file's directory>/_mbtpp_build/<file name>`; `-o <dir>` specifies another location.
- Each build overwrites the files there and deletes `.mbt` files that were generated before but are
  no longer generated (only files carrying the moonpp generated-file marker are deleted).
- The generated project has its own `moon.work`, so a workspace in a parent directory does not
  affect it.
- The generated code is formatted with `moon fmt`.

To see what the generated code looks like, see [Compiling to MoonBit](../interop/compile.md).
