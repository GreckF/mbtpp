# 项目结构

MoonBit++ 项目就是一个 MoonBit 模块，包是放 `.mbtpp` 文件的目录：

```text
hello/
  moon.mod                 模块：名字、版本、依赖、source 目录
  src/
    main/
      moon.pkg             包：导入的 MoonBit 包、是否是 main 包
      main.mbtpp           一个包可以有多个 .mbtpp 文件
  mbtpp_out/               moonpp build 的输出
```

## moon.mod

```text
name = "username/hello"

version = "0.1.0"

import {
  "moonbitlang/x@0.5.6",
}

source = "src"
```

`import` 块是模块的依赖，由 `moonpp add` 维护。

## moon.pkg

```text
import {
  "moonbitlang/x/encoding/percent",
  "moonbitlang/core/string" @str,
}

options(
  "is-main": true,
)
```

- `import` 块列出包导入的 MoonBit 包，`@别名` 可选，默认是路径的最后一段。
- main 包用 `options("is-main": true)` 标记。新版 `moon fmt` 会改写成
  `pkgtype(kind: "executable")`，两种写法都认。
- 一个包的所有 `.mbtpp` 文件共享一个作用域，声明顺序无关；报错定位到具体文件。

## 旧格式

旧的 `moon.mod.json`、`moon.pkg.json` 也能读取。但新版 `moon` 不再接受 `moon.mod.json`，所以
需要依赖管理或编译时，在项目根目录运行 `moon fmt` 迁移；`moonpp` 遇到这种情况会给出提示。
