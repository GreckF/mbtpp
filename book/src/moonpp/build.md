# 构建产物

`moonpp build` 生成一个完整的 MoonBit 项目，不依赖 moonpp 也能构建运行：

```text
mbtpp_out/main/
  moon.mod          原项目的名字、版本和依赖
  moon.work         工作区：自身，加上本地模块（绝对路径）
  README.md
  .gitignore
  main/
    moon.pkg            导入的 MoonBit 包；main 包
    main.mbt            src/main/main.mbtpp 编译的结果
    shapes.mbt          src/main/shapes.mbtpp 编译的结果（每个 .mbtpp 一个 .mbt）
    mbtpp_prelude.mbt   用到的 Prelude 定义
    mbtpp_imports.mbt   调用导入的 MoonBit 包的胶水代码（需要时）
    mbtpp_runtime.mbt   运行时支持（值表示、模式匹配、原语）
```

源文件与生成文件一一对应：`x.mbtpp` 中的定义（函数、数据类型、trait、实例）编译到 `x.mbt`；
没有运行时代码的文件（例如只有 lemma）也会生成一个只有注释头的 `x.mbt`。三个 `mbtpp_` 开头的
文件名由 moonpp 使用，源文件不能叫这些名字。

```bash
cd mbtpp_out/main
moon run main
```

- 默认位置是项目的 `mbtpp_out/<包名>`；单个文件是 `<文件所在目录>/_mbtpp_build/<文件名>`；
  `-o <目录>` 指定其他位置。
- 每次构建会覆盖其中的文件，并删除以前生成、现在不再生成的 `.mbt` 文件（只删除带 moonpp 生成
  标记的文件）。
- 生成的项目自带 `moon.work`，所以上层目录中的工作区不会影响它。
- 生成的代码经过 `moon fmt` 格式化。

生成的代码是什么样的，见[编译到 MoonBit](../interop/compile.md)。
