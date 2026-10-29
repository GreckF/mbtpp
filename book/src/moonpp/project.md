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
- 一个包的所有 `.mbtpp` 文件共享一个作用域；报错定位到具体文件。

## 检查顺序

一个包的文件按文件名的字典序依次检查。名字可以互相引用（定义在后面的函数也能调用），但类型
检查时的**计算**只能用已经检查过的函数体：如果 `facts.mbtpp` 中的证明要计算 `shapes.mbtpp` 中
定义的函数，`shapes.mbtpp` 必须先检查。这时用 `"mbtpp-order"` 指定顺序：

```text
options(
  "is-main": true,
  "mbtpp-order": [ "shapes.mbtpp" ],
)
```

列出的文件先检查（按列出的顺序），其余文件仍按字典序在后面。旧格式的 `moon.pkg.json` 中写
`"mbtpp-order": [ "shapes.mbtpp" ]`。`moon` 会忽略这个选项，`moon fmt` 会保留它。

如果一个错误可能是检查顺序造成的，`moonpp` 会给出提示：

```text
src/main/facts.mbtpp:1:47: error: type mismatch
  expected: Shape::area(Rect(3, 3)) === 9
  actual:   ?94 === ?94
hint: Shape::area is defined in src/main/shapes.mbtpp, which is checked after
src/main/facts.mbtpp, so its definition could not be used here; the error may
come from that. … list it in the package's moon.pkg: options("mbtpp-order": [ "shapes.mbtpp", ... ])
```

## 旧格式

旧的 `moon.mod.json`、`moon.pkg.json` 也能读取。但新版 `moon` 不再接受 `moon.mod.json`，所以
需要依赖管理或编译时，在项目根目录运行 `moon fmt` 迁移；`moonpp` 遇到这种情况会给出提示。
