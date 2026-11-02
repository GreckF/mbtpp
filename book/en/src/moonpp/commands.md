# Commands

| Command | Description |
| --- | --- |
| `moonpp new <name>` | Create a project |
| `moonpp check [path]` | Type-check the whole project, a package directory, or a file; also points out `pub` declarations that can be marked `#mbt` |
| `moonpp fix [path]` | Add `#mbt` to those `pub` declarations |
| `moonpp ide <file> [--overlay <json>]` | Check the package containing the file for an editor and output JSON (see [Editor](editor.md)) |
| `moonpp run [path]` | Run the main package (or the given package or file) with the interpreter |
| `moonpp run --compiled [path] [-- args…]` | Compile to MoonBit and run with `moon run`; the arguments after `--` go to the program |
| `moonpp test [path]` | Run the `test "name" { … }` blocks with the interpreter; they can use `assert_eq`, `assert_true`, etc. |
| `moonpp build [path] [-o dir]` | Compile to a MoonBit project and run `moon build` |
| `moonpp add <user/module[@version]>` | Add a dependency (`moon add`) and generate `.mbti` files for packages that lack an interface |
| `moonpp remove <module>` | Remove a dependency (`moon remove`) |
| `moonpp install` | Install dependencies (`moon install`) and generate interfaces |
| `moonpp interfaces` | Only generate missing interfaces for downloaded dependencies (`moon info`) |
| `moonpp tree` | Show the dependency tree (`moon tree`) |
| `moonpp version` | Show the version |

## Options

| Option | Description |
| --- | --- |
| `--verbose` | List interface items skipped during import; with `build` and `run --compiled`, also the functions without a native version, and why |
| `--no-prelude` | Do not load the Prelude |
| `--compiled` | With `run`, run the compiled output instead of interpreting |
| `-o`, `--output <dir>` | Where `build` and `run --compiled` generate the project |
| `-- args…` | Command line arguments for the program with `run --compiled` (read with `@sys.get_cli_args()`, say) |

## Single files

The path can be a single `.mbtpp` file:

```bash
moonpp run examples/vector.mbtpp
moonpp run --compiled examples/vector.mbtpp
```

If there is a `moon.pkg` next to the file, its imports apply as well. When a single file is
compiled, the generated project goes in `_mbtpp_build/<file name>/` in the file's directory.
