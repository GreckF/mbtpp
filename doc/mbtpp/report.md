# MoonBit++ 实现报告

本文总结这一轮工作完成的功能、实现方式、验证方法和已知局限。仓库在
`GreckF/mbtpp`（`main` 分支）；旧的 shitt 实现完整保存在同级目录
`kitty-hawk-old` 中（含全部分支、remote 与 stash）。

> 声明：这是 vibe coding 的娱乐项目。类型检查器**没有终止检查**，用无限递归可以“证明”任何命题，
> 请不要把它当作可信的证明工具。

---

## 1. 总览

| 组成 | 位置 | 说明 |
| --- | --- | --- |
| 解析器 | `src/parser` | MoonBit 风格的词法/语法分析；`.mbti` 接口文件的翻译 |
| 类型检查器 | `src/tt` | NbE、合一、依赖模式匹配、覆盖检查、trait、策略、导入 |
| 解释器 | `src/interp` | 在精化后的核心项上直接求值 |
| 编译器 | `src/codegen` | MoonBit++ → MoonBit（统一表示 + 原生类型翻译） |
| 构建工具 | `src/moonpp`、`bin/` | `moonpp new/check/run/build/add/install/...` |
| 编辑器支持 | `editors/vscode` | VS Code 语法高亮 |
| 文档 | `doc/mbtpp/` | 语言规范（`proposal.md`）、实现说明（`implementation.md`）、本报告 |

测试：`moon test` 共 **56 个测试全部通过**，另外 10 个示例程序在“解释执行”和“编译为 MoonBit 后执行”两种方式下输出完全一致。

---

## 2. 语言

语法尽量与 MoonBit 一致，规范见 `doc/mbtpp/proposal.md`。要点：

- **依值类型**：`Type : Type`（type in type），另有非直谓、证明无关的 `Prop`。
- **uncurried 函数**：`(A, B) -> C` 与 `(A) -> (B) -> C` 是不同的类型，调用必须给出整组参数；`[...]` 为隐式参数，`(...)` 为显式参数，同一组内隐式在前。`[T]` 是 `[T : Type]` 的简写，未标注的隐式参数类型由使用推断。
- **归纳类型**：带参数与索引的 `enum`（GADT），例如
  `enum Vector[T] : Nat -> Type { Nil : Vector[T](0); Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n)) }`；
  依赖字段的 `struct`；`suberror`。
- **命题相等**：`a === b` 是 `Id[_](a)(b)` 的语法糖（`Eq` 留给布尔相等的 trait，与 MoonBit 一致）。
- **依赖模式匹配**：自动细化上下文，或使用 Rocq 风格的 `match e as x in T return R { ... }`；不可能的分支可省略或只写模式。
- **方法与运算符**：`fn T::m(self ...)`、`x.m()`、`a + b` → `op_add` 等。
- **trait**：含高阶 `trait Monad(Self : [T] -> Type)`、父 trait、`impl ... with`、多重约束 `[T : Eq + Show]`。
- **`monad { }`**：`let x <- m` 与嵌套的 `<- m`。
- **命令式特性**：`let mut`、赋值、`while`、`for`、`for .. in`、`break`/`continue`/`return`；`raise`、`try ... catch`、`try?`。
- **带标签参数**（与 MoonBit 相同）：`x~ : T`、`x~ : T = 默认值`、`x? : T`；调用时 `x=e`、`x~`、`x?=e`、`x?`；`T?` 是 `Option[T]` 的简写。
- **策略**：`proof { intros; exact; rfl; destruct; rewrite; apply; assume }`，策略生成普通的证明项。
- **导入 MoonBit 包**：在 `moon.pkg.json` 中声明，以 `@pkg.name` 使用。
- **`Double`** 字面量与运算。

**未实现**：可恢复的代数效应（`effect`/`perform`/`resume`）、`simp`/`omega`/`auto`、局部递归函数、可变字段、trait 默认方法。

---

## 3. 类型检查器（`src/tt`）

- **NbE**：de Bruijn 索引（项）与层级（值）；全局函数在值中保持折叠（`VGlobal`），按需展开，展开卡在 `match` 上时保持折叠，使报错信息可读，也避免对递归实例的无限展开。
- **合一**：模式合一；高阶参数的一阶近似（`M[T] = Option[Int]`）；非模式参数的“剪枝”作为最后手段；定义性证明无关。
- **依赖模式匹配**：上下文中的变量分为“绑定”和“定义”；细化即把绑定变量变成定义变量，并整体重算上下文以保持值在代换下的稳定（例如 `n := plus(m, 0)` 之后又得到 `m := 0`，`n` 会被重新规约为 `0`）。
- **覆盖检查**：按构造子分裂；能识别空类型（如 `Fin(0)`）使情形不可能。曾发现并修复一个可靠性 bug：内建类型（`Int` 等）没有构造子，被误判为空类型。
- **Prop 消去限制**：除子单例（如 `===`）外，匹配证明只能得到命题。
- **实例搜索**：局部实例、父 trait 投影、全局实例（含带约束的实例）。
- **按需精化声明**：签名按需求值，函数体按源码顺序紧跟签名精化，后面的签名可以计算前面的函数。

---

## 4. 解释器（`src/interp`）

树遍历求值核心项；支持可变状态、循环、`return`、异常。导入的 MoonBit 函数在解释器中不能运行（会报错并说明原因），只用于类型检查。

---

## 5. 导入 MoonBit 包（`.mbti`）

- `moon.pkg.json` 的 `import` 字段声明依赖；`moonbitlang/core/*` 的接口从 MoonBit 安装目录读取，其他包从项目的 `.mooncakes` 读取（会读取依赖模块的 `source` 字段）。
- `.mbti` 按顶层项拆分，每项用 MoonBit++ 解析器解析并翻译成声明，函数是 extern（`@mbt:<包>.<名>`），类型检查时不展开。
- 命名：`@pkg.f`、`@pkg.T`、`@pkg.T::C`（也可写 `@pkg.C`），方法照常 `x.m()`，`#as_free_fn` 的方法也可写 `@pkg.m`；`impl @pkg.Tr for T` 实现导入的 trait。
- `pub(all)` enum/struct 与 `pub(open)` trait 自动成为 `#mbt("@pkg.T")`（满足条件时，见 7.4）；`pub` 的 enum/struct 只读（不能构造），`pub` trait 不能实现。
- 宽松处理：失败的项被跳过（`--verbose` 列出），不会影响用户代码；未知类型成为不透明类型，未知 trait 约束成为任何类型都满足的不透明 trait；`StringView`/`ArrayView[T]` 视为 `String`/`Array[T]`。
- 实测：65 个 core 包逐个导入全部成功；约 1600 个函数中只跳过 36 个（trait 对象 `&T`、自动填充的 `loc~`）。跳过的项主要是泛型 `impl` 以及 Show/Eq/Compare 之外的 `impl`。

---

## 6. 构建工具 `moonpp`

编译成 JS 后由 Node.js 运行（`bin/moonpp`、`bin/moonpp.cmd`），以便调用 `moon`；程序运行在大栈的 worker 线程中（10 万层递归可正常运行，wasm 版本 2000 层即栈溢出）。

| 命令 | 功能 |
| --- | --- |
| `moonpp new <name>` | 创建项目：`moon.mod.json`、`src/main/{moon.pkg.json, main.mbtpp}` 等 |
| `moonpp check [路径]` | 类型检查整个项目、一个包目录或一个文件；一个包可由多个文件组成，报错定位到具体文件 |
| `moonpp run [路径]` | 解释执行主包（或指定的包/文件） |
| `moonpp build [路径]` | 编译为 MoonBit 并 `moon build` |
| `moonpp run --compiled [路径]` | 编译为 MoonBit 并 `moon run` |
| `moonpp add <模块>` / `install` | 调用 `moon add` / `moon install`，再为缺少 `.mbti` 的依赖运行 `moon info` 生成接口 |
| `moonpp remove`、`tree` | 转交给 `moon` |
| `moonpp interfaces` | 只为已下载的依赖生成缺失的接口 |

项目本身就是一个 moon 模块，因此依赖管理完全复用 `moon`。

---

## 7. 编译器：MoonBit++ → MoonBit（`src/codegen`）

### 7.1 结构

1. **统一表示**（`codegen.mbt`、`runtime.mbt`）：所有值用 `enum Value`（`VInt`、`VCon(构造子名, 参数)`、`VFun`……）表示，可以翻译语言的全部特性（GADT、类型层计算、trait、异常、循环）。
   - n 元函数成为 MoonBit 函数，饱和调用是直接调用，作为值使用时才构造闭包；
   - `match` 翻译为 MoonBit 原生 `match`；`if`、构造子、基本运算内联；
   - 只输出从 `main` 可达的定义；变量沿用源码名字；未使用的模式绑定被删除；输出经过 `moon fmt`。
2. **擦除分析**（`erase.mbt`）：对整个程序求最大不动点。类型参数总是擦除；其他隐式参数与隐式构造子字段（例如 `Cons[n]` 中的长度）只要在运行时没有被用到就擦除。若用户真的在运行时使用了它（`Cons[m](_, _) => S(m)`），分析会保留它。
3. **原生类型翻译**（`typed.mbt`）：参数与结果都是“原生类型”的函数，只要函数体落在可翻译的片段中，就生成普通的 MoonBit 函数 `f_t`；哪些函数能翻译由不动点决定。每个这样的函数另有一个 `Value` 包装，统一代码照常调用它。
   - 原生类型：`Int`/`Double`/`Bool`/`Char`/`String`/`Unit`、类型参数、参数为类型的数据类型（索引与被擦除的字段消失）、函数类型；
   - 片段：算术与比较、`if`、对原生 enum 与字面量的 `match`、`let`/`let mut`/赋值/循环/`return`、对其他函数的调用、作为参数的 lambda、调用函数类型的变量；
   - 类型化代码直接调用导入的 MoonBit 函数，不经过 `Value`。
4. **外部函数**（`ffi.mbt`）：统一代码调用导入函数时，按签名生成转换代码：标量、类型变量、`Array`、`Option`、回调、不透明外部类型（装在生成的 `Foreign` enum 中）、带标签/可选参数、错误。

### 7.2 翻译结果示例

`examples/vector.mbtpp` 中的向量与函数：

```moonbit
enum E_Vector[T0] {
  Nil
  Cons(T0, E_Vector[T0])
}

fn[T0] f18_vector_append_t(self_252 : E_Vector[T0], ys_253 : E_Vector[T0]) -> E_Vector[T0] raise {
  match self_252 {
    E_Vector::Nil => ys_253
    E_Vector::Cons(x_256, xs_257) => E_Vector::Cons(x_256, f18_vector_append_t(xs_257, ys_253))
    _ => rt_fail("no match")
  }
}

fn[T0, T1] f21_vector_map_t(self_297 : E_Vector[T0], f_298 : (T0) -> T1 raise) -> E_Vector[T1] raise {
  match self_297 {
    E_Vector::Nil => E_Vector::Nil
    E_Vector::Cons(x_301, xs_302) => E_Vector::Cons(f_298(x_301), f21_vector_map_t(xs_302, f_298))
    _ => rt_fail("no match")
  }
}
```

长度索引 `n`、`m` 以及 `n + m` 的计算完全消失。调用 MoonBit 库函数的代码（`examples/import`）：

```moonbit
fn f18_distance_t(x_186 : Double, y_187 : Double) -> Double raise {
  @math.hypot(x_186, y_187)
}

fn f19_parse_hex_t(s_183 : String) -> Int raise {
  @conv.parse_int(s_183[:], base=16) catch {
    err => raise CRaise(foreign_error(err))
  }
}
```

类型依赖于值的函数（如 `NAry(n)` 返回类型由 `n` 计算）、使用 trait 字典的函数保持统一表示，但同样正确运行。

### 7.3 性能

| 程序 | 解释执行 | 编译后（含 `moon run` 启动） |
| --- | --- | --- |
| `fib(30)` + 一个 `Nat` 递归 | 7.85 s | 0.18 s |
| `fib(35)` | — | 0.34 s |

### 7.4 `#mbt` 类型与 trait

`#mbt` 标注的 enum/struct/trait 平凡地翻译到 MoonBit（条件见语言规范第 10 节，类型检查时验证）：

- **类型**：原生翻译直接使用 MoonBit 类型。`#mbt enum Tree[T]` 生成同名的 `enum Tree[T0]`（而不是 `E_Tree`），`#mbt struct Point` 生成 `struct Point`，用 `Point::{ x: .., y: .. }` 构造、`{ x: p, .. }` 匹配；`#mbt("Option")` 与导入的 `@pkg.T` 不生成声明，直接用已有类型。prelude 的 `Option`、`Result` 是 `#mbt("Option")`、`#mbt("Result")`。
- **trait**：生成 MoonBit trait（方法都标 `raise`，因为编译后的代码用异常实现控制流）；原生函数的约束 `[T : Size]` 成为 `fn[T0 : Size]`，实例参数消失；方法调用成为 `(Size::size(x) : Int)`。
- **impl**：方法体在原生片段中的实例生成 MoonBit `impl`，按需输出（原生代码在具体类型上需要它时）。一个调用所需的实例如果不能成为 impl，这个调用退回统一表示（实例作为值传递）。
- **统一表示**：`#mbt` 类型的值在统一代码中仍是 `VCon`，在边界逐构造子转换。带约束的函数同时生成原生版本和统一版本（统一版本接收实例值）。
- **外部调用**：参数、结果为 `#mbt` 类型（包括导入的 `pub(all)` 类型）的 MoonBit 函数可以从统一代码调用（逐构造子转换），从原生代码调用则不转换。带 `#mbt` trait 约束的 MoonBit 泛型函数可以从原生代码调用。
- **只读类型**：导入的 `pub` 类型不能在包外构造，所以不能从 `Value` 转回：原生代码直接传递这些值；统一代码只能检查它们（匹配）。需要把统一代码中的只读值传给 MoonBit 的调用会在编译时报错，并说明原因。
- **编译期报错**：签名不受支持的外部函数如果被调用，现在是编译错误（以前是生成一个运行时报错的存根）。
- **`#mbt` 函数**：编译为同名的 `pub fn`（方法为 `pub fn T::m`，带标签参数保持 `x~`/`x?`），调用原生翻译 `f_t`；签名在类型检查时验证，函数体不在原生片段时编译报错，错误指出第一个不能原生翻译的表达式及原因（例如“in `println(x)`, println has no native signature”）。没有声明 `raise` 的函数生成不 `raise` 的签名，内部失败变为 `abort`。生成的 `#mbt` 类型为 `pub(all)`、trait 为 `pub(open)`，可翻译的实例全部生成 `impl`，所以 MoonBit 代码可以直接使用这些函数（已用一个白盒测试调用 `insert(.., lt=..)`、`total`、`t.depth()` 验证）。

例子 `examples/mbt_types.mbtpp`，以及一个带 `pub(all) enum Shape`、`pub(all) struct Point`、`pub enum Handle`、`pub(open) trait HasArea` 的本地依赖包的项目，编译后与解释执行（或预期结果）一致；生成代码中可以看到 `enum Tree[T0]`、`trait Size`、`impl[T0 : Size] Size for Tree[T0]`、`@shapes.Shape::Circle(...)`、`impl @shapes.HasArea for Square`。

### 7.5 验证

- 11 个示例（基本、向量、依赖结构、单子、异常/循环、依赖类型、证明、STLC 的代换与进展性、带标签参数、trait、`#mbt`）编译后与解释执行输出逐字一致；
- 导入示例在编译后真正调用了 `@math.hypot`（输出 5）与 `@conv.parse_int(…, base=16)`（输出 255）；
- 项目模式下使用 `.mooncakes` 中的依赖（`@stack.Stack`）编译运行成功；
- `src/codegen_test.mbt` 对生成代码的关键签名做快照测试（原生/统一、擦除、泛型、闭包）。

---

## 8. 已知局限

- **可靠性**：没有终止检查（按设计），无限递归可以“证明”任何命题；编译时证明不擦除，发散的证明会在运行时发散。
- **语言**：未实现可恢复的代数效应和 `simp`/`omega`/`auto`；局部 `fn` 不能递归；没有可变字段和 trait 默认方法；`fn f()` 内部表示为接受一个 `Unit` 参数。
- **导入**：解释器不能执行导入的函数；trait 对象 `&T`、`loc~` 自动填充参数、泛型 `impl` 以及 Show/Eq/Compare 之外的 `impl` 不导入。
- **编译器**：
  - 数组在类型化代码中不是原生类型（与统一代码之间转换会复制，破坏共享修改的语义，所以没有做）；因此含 `Array` 字段的类型不能是 `#mbt`（导入时这样的类型不自动标注），以数组传递约束类型的 MoonBit 泛型函数（如 `fn[T : Tr] f(Array[T])`）也不能调用；
  - `#mbt` 类型在统一代码中按值转换（复制）；MoonBit 函数修改传入的 `mut` 字段时，MoonBit++ 一侧看不到（MoonBit++ 本身没有可变字段）；
  - 被约束的类型参数必须出现在函数的参数或结果中（MoonBit 不能显式给出类型参数），否则函数走统一表示；
  - 导入包中 `impl @pkg.Tr for @pkg.T` 这类实例不导入，MoonBit++ 只知道自己写的实例；
  - 统一代码与类型化代码之间按值转换，频繁跨边界传递大型数据结构可能较慢；
  - 编译输出中被擦除的字段不再出现在 `show_value` 的错误信息里（与解释器的显示略有不同）。
- **工具**：`moon add`/`moon install` 本身在本机环境下无法连接 mooncakes.io，未能端到端实测；之后的接口生成与导入已用离线副本验证。

---

## 9. 常用命令

```bash
moon build --target js          # 构建 moonpp（之后使用 bin/moonpp）
moon test                        # 56 个测试
bin/moonpp new hello && cd hello && ../bin/moonpp run
bin/moonpp run examples/vector.mbtpp
bin/moonpp run --compiled examples/vector.mbtpp
```
