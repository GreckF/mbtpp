# async 函数

MoonBit++ 支持 MoonBit 的 `async` 函数：

```moonbit
async fn twice(f : async (Int) -> Int, x : Int) -> Int {
  f(f(x))
}

async fn inc(x : Int) -> Int noraise {
  x + 1
}

async fn main {
  let g = async fn(x : Int) -> Int { inc(x) * 2 }
  println(twice(g, 1))
  println(twice(x => inc(x), 5))
}
```

- **写法**：顶层和局部函数写 `async fn name(…)`，匿名函数写 `async fn(…) { … }`，函数类型写
  `async (A) -> B`。
- **错误**：与 MoonBit 相同，async 函数默认可以抛出任何错误（相当于 `raise Error`）。`raise E`
  限定错误类型，`noraise` 表示不抛出。
- **调用**：async 函数只能在 async 函数中调用。期望类型是 async 函数类型时，匿名函数（包括
  `x => …`）就是 async 的，例如上面传给 `twice` 的第二个参数。同步函数可以把 async 函数当作值
  传递，但不能调用它。
- **`async fn main`**：程序入口可以是 async 的。
- **解释器**：`moonpp run` 按顺序同步执行 async 函数，没有并发。导入的 MoonBit async 函数和其他
  导入函数一样，只能在编译后调用。

## 使用 moonbitlang/async

用 `moonpp add moonbitlang/async` 添加依赖，并在包的 `moon.pkg` 中导入后，就可以使用它的任务组、
定时器和 IO：

```moonbit
// requires moonbitlang/async
async fn tick(name : String, n : Int, delay : Int) -> Unit {
  for i = 0; i < n; i = i + 1 {
    @async.sleep(delay)
    println(name + " " + i.to_string())
  }
}

async fn main {
  @async.with_task_group(fn(g) {
    g.spawn_bg(fn() { tick("a", 3, 30) })
    g.spawn_bg(fn() { tick("b", 2, 45) })
  })
  println("done")
}
```

`moonpp run --compiled` 的输出中，两个任务交替运行：

```text
a 0
b 0
a 1
b 1
a 2
done
```

`async` 是关键字，但仍然可以作为包的别名：`@async.sleep`。

## 编译

- async 函数只编译成原生 MoonBit 代码，因为统一表示中的函数是同步的。它的签名和函数体必须在原生
  片段中，否则编译报错并指出第一个不在原生片段中的项，规则与 [`#mbt` 函数](../interop/mbt-functions.md)
  相同。
- async 函数也只能被原生代码使用。如果统一表示的代码引用了 async 函数，例如一个不在原生片段中的
  同步函数返回了 async 匿名函数，编译会报错。
- `async fn main` 编译成 MoonBit 的 `async fn main`；`#mbt async fn` 导出为 `pub async fn`。
- `moonbitlang/async` 支持 native、JS 和 wasm 目标，不支持 wasm-gc。
