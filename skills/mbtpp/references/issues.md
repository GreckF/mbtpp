# 报告 MoonBit++ 的问题

问题提交到 https://github.com/GreckF/mbtpp/issues 。好的报告是**一个最小的、能直接运行的复现**，
加上实际与期望的结果。

## 1. 先确认是不是 bug

- **对照文档**：查对应章节（`book/src/lang/…`）和“已知限制”（`book/src/limitations.md`）。写在
  限制里的行为不是 bug；如果你认为这条限制应该去掉，可以报“改进建议”。
- **按设计的行为**（不要报 bug）：
  - 没有终止检查、可以证明假命题；
  - 解释器不运行导入的 MoonBit 函数；
  - 检查器一次只报一个错误；
  - `pub`、`priv` 没有可见性含义。
- **看完整的报错**：包括 `hint:` 行。很多“证明过不了”是缺 `#unfold`、文件检查顺序，或需要归纳。
- **用最新版本复现**：先运行 `moonpp version`，再和 https://github.com/GreckF/mbtpp/releases 上的
  最新版本比较。
- **搜索已有的 issue**：同一个问题不要重复报。

## 2. 判断问题出在哪个阶段

| 阶段 | 命令 | 典型症状 |
| --- | --- | --- |
| 解析 | `moonpp check` | `parse error`、语法应当合法却报错 |
| 类型检查 | `moonpp check` | 合法程序被拒绝、错误的程序被接受、报错信息误导、检查卡住或超时、崩溃 |
| 导入 | `moonpp check --verbose` | `.mbti` 中的项被跳过（`not imported:`）、导入的类型或函数用不了 |
| 解释器 | `moonpp run` | 运行结果错误、`runtime error`、和编译后的结果不同 |
| 编译 | `moonpp build` | moonpp 报编译错误，或生成的 MoonBit 代码 `moon build` 不通过 |
| 编译后运行 | `moonpp run --compiled` | 编译后结果错误、和解释器结果不同 |
| 工具 | `moonpp add/install/new/fix/ide`、VS Code 插件 | 命令失败、项目文件处理错误 |

一个很有用的对比：同一个程序分别用 `moonpp run` 和 `moonpp run --compiled` 运行。结果不同，几乎一定
是解释器或编译器的 bug，要说明哪一边是对的。

## 3. 缩小复现

- **删到最小**：删掉与问题无关的定义、分支、参数，直到再删就不出错为止；目标是一个文件、几十行
  以内。
- **尽量去掉依赖**：可能的话不依赖 mooncakes 上的包。导入问题无法去掉依赖时，给出：
  - 模块和版本（如 `moonbitlang/async@0.22.7`）；
  - `moon.pkg` 的 `import` 块；
  - `.mbti` 中相关的几行（在 `.mooncakes/<模块>/…/pkg.generated.mbti` 中）。
- **整个项目的问题**：需要多个文件（检查顺序、跨文件引用）时，给出目录结构和每个文件的内容。
- **没有限时的复现**：检查超时或卡住的问题，说明等了多久，有没有用 `#timelimit`。
- **确认最小复现仍然出错**，并贴它的输出，不是原来大程序的输出。
- **不贴私有代码和密钥**：只贴需要的部分。

## 4. issue 的内容

标题：`[阶段] 一句话描述`，例如 `[import] async function types with a parenthesised argument are skipped`、
`[checker] with-abstraction misses occurrences produced by later unfolding`。

正文模板：

````markdown
### 环境
- moonpp 版本：（moonpp version 的输出）
- moon 版本：（moon version 的输出，涉及编译、依赖时）
- Node.js 版本、操作系统：
- 编译目标：（涉及编译后运行时，如 --target js）

### 复现
```moonbit
// 最小的 .mbtpp 程序
```
（需要时附上 moon.pkg / moon.mod / 相关的 .mbti 片段）

命令：
```bash
moonpp check repro.mbtpp
```

### 实际结果
```text
完整输出，包括 hint: 行；崩溃时附上栈信息
```

### 期望结果
期望的输出或行为，以及依据（文档章节、MoonBit 的行为，或为什么程序应当合法/不合法）。

### 补充
- 解释器与编译后运行的结果是否一致
- 已经试过的绕过办法
- 与之相关的已有 issue
````

## 5. 不同类型问题的要点

- **合法程序被拒绝**：说明为什么它应当通过；能的话给出一个改写后能通过的版本，这能帮助定位。
- **错误程序被接受（可靠性问题）**：最严重的一类。给出利用它得到的错误结论，比如证明了 `0 === 1`。
  这类问题要排除“没有终止检查”和 `Type : Type` 这两个已知原因，比如证明里没有用到不终止的递归。
- **报错信息误导**：贴出报错，说明真正的原因，以及你期望的说法。
- **性能问题**：给出耗时和机器情况，说明计算的规模（例如“`sum_to(1000)` 检查用了 40 秒”）。
- **编译问题**：附上生成的 `.mbt` 中出错的片段（在 `mbtpp_out/<包>/` 或 `_mbtpp_build/` 中），以及
  `moon` 的报错。
- **崩溃**：例如 `RangeError: Maximum call stack size exceeded`，或 MoonBit 运行时的 panic。贴出完整
  输出和触发它的最小程序。

## 6. 提交

- 一个 issue 只报一个问题；相关的问题互相链接。
- 用 `gh` 提交：

  ```bash
  gh issue create --repo GreckF/mbtpp --title "[checker] …" --body-file issue.md
  ```

  提交之前，**先把标题和正文给用户看，得到同意再提交**：issue 是公开的。
- 自己修好了：在 issue 中说明，或者提交 PR，并附上回归测试（`src/*_test.mbt`，见仓库的
  `AGENTS.md`）。
