# 构建产物

`moonpp build` 生成一个完整的 MoonBit 项目，不依赖 moonpp 也能构建运行：

```text
mbtpp_out/main/
  moon.mod          原项目的名字、版本和依赖
  moon.work         工作区：自身，加上本地模块（绝对路径）
  README.md
  .gitignore
  main/
    moon.pkg        导入的 MoonBit 包；main 包
    main.mbt        生成的程序
    runtime.mbt     运行时支持（值表示、模式匹配、原语）
```

```bash
cd mbtpp_out/main
moon run main
```

- 默认位置是项目的 `mbtpp_out/<包名>`；单个文件是 `<文件所在目录>/_mbtpp_build/<文件名>`；
  `-o <目录>` 指定其他位置。
- 每次构建会覆盖其中的文件。
- 生成的项目自带 `moon.work`，所以上层目录中的工作区不会影响它。
- 生成的代码经过 `moon fmt` 格式化。

生成的代码是什么样的，见[编译到 MoonBit](../interop/compile.md)。
