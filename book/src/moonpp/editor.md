# 编辑器

仓库的 `editors/vscode` 是 VS Code 插件，每个 Release 都附有打包好的 `mbtpp-vscode.vsix`：

```bash
code --install-extension mbtpp-vscode.vsix
```

也可以在 VS Code 中运行 “Extensions: Install from VSIX...”。插件调用 `moonpp` 命令完成检查，
所以要先[安装 moonpp](install.md)；如果它不在 `PATH` 上，把设置 `mbtpp.moonppPath` 设为例如
`node C:/path/to/mbtpp/bin/moonpp.js`。

## 功能

- **语法高亮**：包括 `proof { ... }` 中的策略。
- **诊断**：编辑时（默认停顿 300 毫秒后）检查文件所在的包，未保存的内容也算在内。检查器遇到
  第一个错误就停止，所以一次显示一个错误。可以标 `#mbt` 的 `pub` 声明显示为提示，快速修复
  （灯泡）“Add #mbt” 会插入标注，“Add #mbt everywhere possible” 运行 `moonpp fix`。
- **悬停**：变量、函数、构造子、类型的类型。
- **跳转到定义**：包中的全局定义。
- **Info view**（编辑器标题栏的按钮，或 Ctrl+Shift+Enter）：光标在 `proof { ... }` 中时，显示
  光标处策略执行后的目标（假设和 `⊢ 目标`）；在第一个策略之前显示初始目标；策略失败时显示
  执行它之前的目标和错误。光标在其他地方时显示光标处名字的类型。
- **命令**：MoonBit++: Run（标题栏的 ▶）、Run Compiled、Check、Build MoonBit Project、
  Add #mbt Where Possible，在终端中运行对应的 `moonpp` 命令。

例如，光标在下面第二个策略上时：

```text
lemma plus_comm : forall n m : Nat, n + m === m + n = proof {
  intros n m
  destruct n
  ...
```

Info view 显示 `destruct n` 之后的两个目标：

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

## 工作方式

插件运行 `moonpp ide <文件> --overlay <json>`：检查文件所在的包（目录中有 `moon.pkg` 时是
整个目录，否则只是这个文件），`--overlay` 给出未保存文件的内容。输出是一个 JSON：错误和
提示（`diagnostics`）、用到的名字及其类型和定义位置（`names`）、每个策略块在开始和每个策略
之后的目标（`proofs`）。其他编辑器也可以用这个命令实现同样的功能。

## 设置

| 设置 | 默认值 | 作用 |
| --- | --- | --- |
| `mbtpp.moonppPath` | `moonpp` | moonpp 命令 |
| `mbtpp.checkOnType` | `true` | 编辑时检查（否则只在打开和保存时） |
| `mbtpp.checkDelay` | `300` | 编辑后等待多少毫秒再检查 |
| `mbtpp.mbtHints` | `true` | 显示 `#mbt` 提示 |
