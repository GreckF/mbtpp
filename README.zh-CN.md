# MoonBit++

[English](README.md) | 中文

> **声明：这是一个纯 vibe coding 的娱乐项目，请不要认真看待。**
> 代码未经严格审查。

一门使用 MoonBit 语法的小型依赖类型语言：包括类型检查器和树遍历解释器，用 MoonBit 编写。

语言标准大致来自：
[写给一般月兔用户的MoonBit++入门](https://zhuanlan.zhihu.com/p/2067605478985749711)（知乎，作者：用户名可以重复吗）

## Playground

在线试用：<https://greckf.github.io/mbtpp/>（手册：<https://greckf.github.io/mbtpp/book/>）。
编辑时即时类型检查，可以用解释器运行，也可以查看编译器生成的 MoonBit 代码。页面在
[docs/](docs) 中，用 `node scripts/build-web.mjs` 重新构建。

## VS Code

[editors/vscode](editors/vscode) 是 VS Code 插件（每个 Release 都附有 `.vsix`）：语法高亮、
编辑时报错、悬停显示类型、跳转到定义、`#mbt` 快速修复、显示策略证明目标的 info view，以及
运行、检查、构建命令。它通过 `moonpp ide` 工作。

从最新的 Release 安装（或更新）：

```powershell
# Windows PowerShell
$f="$env:TEMP\mbtpp-vscode.vsix"; iwr https://github.com/GreckF/mbtpp/releases/latest/download/mbtpp-vscode.vsix -OutFile $f; code --install-extension $f --force
```

```sh
# macOS、Linux、Git Bash
curl -fsSLo /tmp/mbtpp-vscode.vsix https://github.com/GreckF/mbtpp/releases/latest/download/mbtpp-vscode.vsix && code --install-extension /tmp/mbtpp-vscode.vsix --force
```

## moonpp

`moonpp` 是构建工具，仿照 `moon` 设计。它需要 Node.js；编译和依赖管理还需要使用
`moon.mod` / `moon.pkg` 的 MoonBit 工具链（2026-10 或更新）。安装发布版（各版本见
[Releases](https://github.com/GreckF/mbtpp/releases)）：

```sh
npm install -g https://github.com/GreckF/mbtpp/releases/download/v0.1.1/moonpp-0.1.1.tgz
```

或者在仓库中先构建一次：

```sh
moon build --target js --release
```

再全局安装命令：

```sh
npm install -g .
```

（这样安装的是指向本仓库的链接，以后重新运行 `moon build --target js --release` 即可更新；
`npm uninstall -g moonpp` 卸载。）也可以直接调用 `bin/moonpp` 或 `bin\moonpp.cmd`。

```sh
moonpp new hello && cd hello   # 创建项目
moonpp run                     # 运行 main 包
moonpp check                   # 类型检查所有包（并列出可以标 #mbt 的 pub 声明）
moonpp fix                     # 给这些声明加上 #mbt
moonpp add moonbitlang/x       # 添加依赖（运行 `moon add`，生成缺失的 .mbti）
moonpp install                 # 安装依赖（运行 `moon install`）
moonpp run examples/vector.mbtpp   # 也可以是单个文件
moonpp build                   # 编译成 MoonBit 项目（mbtpp_out/<pkg>）并 `moon build`
moonpp build -o out            # ……改为生成到 out/
moonpp run --compiled          # 编译到 MoonBit 并用 `moon run` 运行
```

项目是一个 MoonBit 模块（`moon.mod`）；包是一个包含 `.mbtpp` 文件的目录。包用到的 MoonBit
包列在其 `moon.pkg` 的 `import` 块中，以 `@pkg.name` 引用；解释器只对它们做类型检查（运行到
对它们的调用会报错停止），编译后的程序才会真正调用它们（见
[examples/import](examples/import)）。仍然可以读取旧的 `moon.mod.json` / `moon.pkg.json`
项目，`moon fmt` 会迁移它们。

`moonpp build` 生成一个完整的 MoonBit 项目：自己的 `moon.mod`（MoonBit++ 项目的名字、版本
和依赖）、`moon.work`（以绝对路径列出工作区中的本地模块），以及包 `<pkg>`，其中每个
`.mbtpp` 文件对应一个 `.mbt` 文件（另有 `mbtpp_prelude.mbt`、`mbtpp_imports.mbt` 和
`mbtpp_runtime.mbt`），所以在那里不用 moonpp 也能 `moon run <pkg>`。

编译器把 MoonBit++ 翻译成 MoonBit：处理 MoonBit 能表达的类型（数字、字符串、带类型参数的
数据类型、函数）的函数会变成普通的 MoonBit 代码，例如 `Vector[T](n)` 变成
`enum E_Vector[T0] { Nil; Cons(T0, E_Vector[T0]) }`；其余部分（运行时计算的依赖类型等）使用
统一的值表示。标了 `#mbt` 的类型和 trait 直接对应：`#mbt enum Tree[T]` 变成 MoonBit 的
`enum Tree[T0]`，`#mbt trait` 变成带真正 `impl` 和约束的 MoonBit trait；导入的 `pub(all)`
类型和 `pub(open)` trait 自动是 `#mbt`，因此可以调用处理它们的 MoonBit 函数。`#mbt fn`
编译成同名的公开 MoonBit 函数，MoonBit 代码可以调用（见
[examples/mbt_types.mbtpp](examples/mbt_types.mbtpp)）。

`moon test` 运行 `examples/` 中的示例和 `src/*_test.mbt` 中的测试。

手册（语言、moonpp、与 MoonBit 交互）的中文版在 <https://greckf.github.io/mbtpp/book/>，
英文版在 <https://greckf.github.io/mbtpp/book/en/>；源文件在 [book/src](book/src) 和
[book/en/src](book/en/src)（[mdBook](https://github.com/rust-lang/mdBook)：
`node scripts/build-book.mjs` 生成 `docs/book` 和 `docs/book/en`，
`node scripts/check-book.mjs` 检查其中的示例）。设计说明见
[doc/mbtpp/proposal.md](doc/mbtpp/proposal.md)，实现说明见
[doc/mbtpp/implementation.md](doc/mbtpp/implementation.md)。
