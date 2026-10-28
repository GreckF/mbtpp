# MoonBit++ for VS Code

Syntax highlighting for `.mbtpp` files: keywords, types and constructors,
`fn`/`lemma` names, `Type::method`, `===`, string interpolation, and tactics
inside `proof { ... }` blocks.

## Install

Copy (or link) this folder into the VS Code extensions directory and reload
the window:

```bash
cp -r editors/vscode ~/.vscode/extensions/greckf.mbtpp-0.1.0
```

On Windows the directory is `%USERPROFILE%\.vscode\extensions`. Alternatively,
package it with `npx @vscode/vsce package` and install the `.vsix` with
"Extensions: Install from VSIX...".
