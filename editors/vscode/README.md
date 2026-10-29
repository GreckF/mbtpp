# MoonBit++ for VS Code

Support for MoonBit++ (`.mbtpp`) files:

- **Highlighting**: keywords, types and constructors, `fn`/`lemma` names,
  `Type::method`, `===`, `#mbt`, string interpolation, and tactics inside
  `proof { ... }` blocks.
- **Diagnostics** while typing: the type error of the package (one at a
  time, as the checker stops at the first), and hints for `pub`
  declarations that could be `#mbt`, with a quick fix that adds it.
- **Hover**: the type of a variable, function, constructor or type.
- **Go to definition** for the globals of the package.
- **Info view** (the ⊢ button in the editor title, or Ctrl+Shift+Enter):
  inside a `proof { ... }` block, the goals after the tactic at the cursor
  (hypotheses and ⊢ goal), or the goals before a tactic that failed; outside,
  the type of the name at the cursor.
- **Commands** (also the ▶ button): MoonBit++: Run, Run Compiled, Check,
  Build MoonBit Project, Add #mbt Where Possible.

## Requirements

The `moonpp` command (see the [installation](https://greckf.github.io/mbtpp/book/moonpp/install.html)).
If it is not on the `PATH`, set `mbtpp.moonppPath`, e.g. to
`node C:/path/to/mbtpp/bin/moonpp.js`. The extension runs `moonpp ide` on
the package of the file (its directory if it has a `moon.pkg`, else the file
alone), passing unsaved buffers.

## Settings

| Setting | Default | |
| --- | --- | --- |
| `mbtpp.moonppPath` | `moonpp` | the moonpp command |
| `mbtpp.checkOnType` | `true` | check while typing (else on open and save) |
| `mbtpp.checkDelay` | `300` | milliseconds after an edit before checking |
| `mbtpp.mbtHints` | `true` | show the `#mbt` hints |

## Install

Download `mbtpp-vscode.vsix` from the
[releases](https://github.com/GreckF/mbtpp/releases) and run "Extensions:
Install from VSIX...", or `code --install-extension mbtpp-vscode.vsix`.
From a checkout, `npx @vscode/vsce package` in this folder builds the
`.vsix`; or run it from source with
`code --extensionDevelopmentPath=editors/vscode`.
