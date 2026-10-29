# Using Compiled Code from MoonBit

`#mbt` functions, types, and traits are public after compilation, so MoonBit code can use them.

For example, after compiling the program in [#mbt Functions](mbt-functions.md), add a MoonBit
test file `export_wbtest.mbt` to the `main/` directory of the generated project:

```text
test "exported functions" {
  let t = insert(Tree::Leaf, 3, lt=(a, b) => a < b)
  inspect(t.depth(), content="1")
}
```

Then run `moon test` in the generated project.

Other MoonBit projects can also reference the generated project through a workspace (`moon.work`).

Currently the output is always a main package (with a `main` function); standalone library packages cannot be generated yet.
