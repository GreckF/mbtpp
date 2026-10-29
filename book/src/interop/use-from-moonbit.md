# 在 MoonBit 中使用编译结果

`#mbt` 的函数、类型和 trait 编译后是公开的，所以 MoonBit 代码可以使用它们。

例如编译[#mbt 函数](mbt-functions.md)中的程序后，在生成项目的 `main/` 目录中加一个 MoonBit
测试文件 `export_wbtest.mbt`：

```text
test "exported functions" {
  let t = insert(Tree::Leaf, 3, lt=(a, b) => a < b)
  inspect(t.depth(), content="1")
}
```

然后在生成的项目中运行 `moon test`。

也可以让别的 MoonBit 项目通过工作区（`moon.work`）引用生成的项目。

目前生成的总是 main 包（带 `main` 函数），还不能生成单独的库包。
