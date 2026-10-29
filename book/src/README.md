# MoonBit++ 手册

<p align="center"><img src="images/mascot.jpg" alt="MoonBit++ 吉祥物：穿白大褂、戴护目镜、捧腹大笑的紫红色兔子" width="320"></p>

MoonBit++ 是一门依赖类型语言，语法取自 MoonBit：同样的 `fn`、`enum`、`struct`、`trait`、
`match`、`let mut`、`for`、`raise`，加上依赖类型、索引类型、依赖模式匹配、命题与证明。

它包括：

- **类型检查器**：依赖类型、合一、依赖模式匹配与覆盖检查、实例搜索、简单的策略。
- **解释器**：直接运行类型检查后的程序。
- **编译器**：把程序翻译成 MoonBit，能用 MoonBit 类型表达的部分生成原生代码。
- **`moonpp`**：类似 `moon` 的命令行工具，管理项目、依赖与构建。

> 这是一个纯 vibe coding 的娱乐项目，请不要认真看待。

本手册分三部分：

- **语言**：从词法到证明、trait、副作用，每个特性一章。
- **moonpp**：安装、项目结构、命令、依赖、构建产物。
- **与 MoonBit 交互**：导入 MoonBit 包、编译到 MoonBit、`#mbt` 声明、在 MoonBit 中使用编译结果。

带 `fn main` 的示例右上角有 ▶ 按钮，可以在 [Playground](https://greckf.github.io/mbtpp/) 中打开
运行。源码与示例在 [GitHub](https://github.com/GreckF/mbtpp)。
