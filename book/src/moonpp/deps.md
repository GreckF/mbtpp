# 依赖

## mooncakes.io 上的模块

```bash
moonpp add moonbitlang/x@0.5.6
```

然后在包的 `moon.pkg` 中导入模块中的包：

```text
import {
  "moonbitlang/x/encoding/percent",
}
```

`moonpp add` 调用 `moon add` 下载模块，并为缺少 `.mbti` 接口的包运行 `moon info` 生成接口。
接口从项目的 `.mooncakes/` 读取。

## 标准库

`moonbitlang/core/*` 不需要添加，接口从 MoonBit 安装目录（`~/.moon/lib/core`）读取。

## 本地模块

用 MoonBit 的工作区：在项目根目录写 `moon.work`，并在 `moon.mod` 中声明依赖。

`moon.work`：

```text
members = [
  ".",
  "../geo",
]
```

`moon.mod`：

```text
name = "username/app"

version = "0.1.0"

import {
  "u/geo@0.1.0",
}

source = "src"
```

本地模块需要有 `.mbti` 接口，在该模块中运行 `moon info` 生成。

导入之后怎样使用 MoonBit 包，见[导入 MoonBit 包](../interop/import.md)。
