# 命令

| 命令 | 作用 |
| --- | --- |
| `moonpp new <名字>` | 创建项目 |
| `moonpp check [路径]` | 类型检查整个项目、一个包目录或一个文件 |
| `moonpp run [路径]` | 用解释器运行 main 包（或指定的包、文件） |
| `moonpp run --compiled [路径]` | 编译到 MoonBit 并用 `moon run` 运行 |
| `moonpp build [路径] [-o 目录]` | 编译成 MoonBit 项目并 `moon build` |
| `moonpp add <user/module[@版本]>` | 添加依赖（`moon add`），并为缺少接口的包生成 `.mbti` |
| `moonpp remove <module>` | 删除依赖（`moon remove`） |
| `moonpp install` | 安装依赖（`moon install`）并生成接口 |
| `moonpp interfaces` | 只为已下载的依赖生成缺失的接口（`moon info`） |
| `moonpp tree` | 依赖树（`moon tree`） |
| `moonpp version` | 版本 |

## 选项

| 选项 | 作用 |
| --- | --- |
| `--verbose` | 列出导入时被跳过的接口项 |
| `--no-prelude` | 不加载 Prelude |
| `--compiled` | `run` 时运行编译结果而不是解释执行 |
| `-o`、`--output <目录>` | `build`、`run --compiled` 时生成项目的位置 |

## 单个文件

路径可以是一个 `.mbtpp` 文件：

```bash
moonpp run examples/vector.mbtpp
moonpp run --compiled examples/vector.mbtpp
```

文件旁边如果有 `moon.pkg`，其中的导入同样生效。编译单个文件时，生成的项目在文件所在目录的
`_mbtpp_build/<文件名>/`。
