# Editor

`editors/vscode` in the repository is a VS Code extension, and every release includes a packaged
`mbtpp-vscode.vsix`. Download and install the latest version (run it again to update; reload the
VS Code window after installing):

```powershell
# Windows PowerShell
$f="$env:TEMP\mbtpp-vscode.vsix"; iwr https://github.com/GreckF/mbtpp/releases/latest/download/mbtpp-vscode.vsix -OutFile $f; code --install-extension $f --force
```

```bash
# macOS, Linux, Git Bash
curl -fsSLo /tmp/mbtpp-vscode.vsix https://github.com/GreckF/mbtpp/releases/latest/download/mbtpp-vscode.vsix && code --install-extension /tmp/mbtpp-vscode.vsix --force
```

You can also download it manually and run `code --install-extension mbtpp-vscode.vsix`, or run
"Extensions: Install from VSIX..." in VS Code. The extension calls the `moonpp` command to do the
checking, so [install moonpp](install.md) first; if it is not on `PATH`, set the
`mbtpp.moonppPath` setting to something like `node C:/path/to/mbtpp/bin/moonpp.js`.

## Features

- **Syntax highlighting**: including tactics inside `proof { ... }`.
- **Diagnostics**: while you edit (after a 300 ms pause by default), the package containing the
  file is checked, unsaved content included. The checker stops at the first error, so one error is
  shown at a time. `pub` declarations that can be marked `#mbt` are shown as hints; the quick fix
  (light bulb) "Add #mbt" inserts the annotation, and "Add #mbt everywhere possible" runs
  `moonpp fix`.
- **Hover**: types of variables, functions, methods, fields, constructors (including those in
  patterns), and types.
- **Go to definition** (Ctrl+click, F12): global definitions in the package.
- **Symbols**: the outline and Ctrl+Shift+O list the declarations in the file (constructors,
  fields, and methods appear under their type); Ctrl+T searches the declarations of all `.mbtpp`
  files in the workspace.
- **Info view** (the button in the editor title bar, or Ctrl+Shift+Enter): when the cursor is
  inside `proof { ... }`, shows the goals after the tactic at the cursor runs (hypotheses and
  `⊢ goal`); before the first tactic it shows the initial goal; when a tactic fails it shows the
  goals before that tactic and the error. Elsewhere it shows the type of the name at the cursor.
- **Commands**: MoonBit++: Run (▶ in the title bar), Run Compiled, Check, Build MoonBit Project,
  and Add #mbt Where Possible run the corresponding `moonpp` command in a terminal.

For example, with the cursor on the second tactic below:

```text
lemma plus_comm : forall n m : Nat, n + m === m + n = proof {
  intros n m
  destruct n
  ...
```

the Info view shows the two goals after `destruct n`:

```text
Goal 1 of 2
n : Nat
m : Nat
⊢ (0 + m) === (m + 0)

Goal 2 of 2
n : Nat
m : Nat
n_0 : Nat
⊢ (S(n_0) + m) === (m + S(n_0))
```

## How it works

The extension runs `moonpp ide <file> --overlay <json>`: this checks the package containing the
file (the whole directory if it has a `moon.pkg`, otherwise just that file), and `--overlay`
supplies the contents of unsaved files. The output is a JSON object: errors and hints
(`diagnostics`), the names used along with their types and definition locations (`names`), the
declarations in the package (`symbols`), and the goals of each tactic block at its start and after
each tactic (`proofs`). Other editors can use this command to provide the same features.

## Settings

| Setting | Default | Description |
| --- | --- | --- |
| `mbtpp.moonppPath` | `moonpp` | The moonpp command |
| `mbtpp.checkOnType` | `true` | Check while editing (otherwise only on open and save) |
| `mbtpp.checkDelay` | `300` | Milliseconds to wait after an edit before checking |
| `mbtpp.mbtHints` | `true` | Show `#mbt` hints |
