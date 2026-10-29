# MoonBit++ 使用手册

MoonBit++ 是一门依赖类型语言，语法取自 MoonBit：同样的 `fn`、`enum`、`struct`、`trait`、
`match`、`let mut`、`for`、`raise`，加上依赖类型、索引类型、依赖模式匹配、命题与证明。它带有类型
检查器、解释器，以及编译到 MoonBit 的编译器；配套的命令行工具 `moonpp` 负责项目管理、依赖和构建。

> 这是一个纯 vibe coding 的娱乐项目，请不要认真看待。类型检查器不做终止检查，证明可以靠无限
> 递归“证”出任何命题，不适合任何正式用途。

本手册分三部分：

- [第一部分：语言](#第一部分语言)：词法、表达式、类型、数据类型、模式匹配、证明、trait、副作用、
  Prelude。
- [第二部分：moonpp](#第二部分moonpp)：安装、项目结构、命令、依赖、构建。
- [第三部分：与 MoonBit 交互](#第三部分与-moonbit-交互)：导入 MoonBit 包、编译到 MoonBit、
  `#mbt` 类型 / trait / 函数、在 MoonBit 中使用编译结果。

在线试用：<https://greckf.github.io/mbtpp/>（类型检查、解释执行、查看编译出的 MoonBit 代码）。

## 快速开始

```bash
moonpp new hello
cd hello
moonpp run                # 用解释器运行 src/main
moonpp check              # 类型检查
moonpp run --compiled     # 编译到 MoonBit 再运行
moonpp build              # 编译到 MoonBit 项目 mbtpp_out/main
```

一个最小的程序：

```moonbit
enum Vector[T] : Nat -> Type {
  Nil : Vector[T](0)
  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
}

// 只接受非空向量：不需要 Nil 的分支
fn[T, n : Nat] Vector::head(self : Vector[T](S(n))) -> T {
  match self {
    Cons(x, _) => x
  }
}

fn main {
  let v : Vector[String](2) = Cons("Hello", Cons("MoonBit++", Nil))
  println(v.head())
}
```

---

# 第一部分：语言

## 1. 词法

- **注释**：`// …` 到行尾。没有块注释。
- **标识符**：字母、数字、`_`，不以数字开头。约定上类型、构造子、trait 以大写开头，其余小写。
- **字面量**：
  - 整数 `0`、`42`、`1_000`；负数写作 `-1`。期望类型是 `Nat` 时，整数字面量展开为
    `S(…S(Z))`，否则是 `Int`。
  - 浮点 `1.5`、`2.0` 是 `Double`。
  - 字符 `'a'`、`'\n'`；字符串 `"…"`。转义：`\n \t \r \\ \" \' \0`。
  - 字符串插值：`"x = \{x}"`，被插入的值需要 `Show`。
  - `true`、`false`、`()`。
- **语句分隔**：换行或 `;`。
- **关键字**：`fn let mut if else match enum struct trait impl for in with while return break
  continue raise try catch true false Type Prop forall lemma proof monad as suberror derive
  pub priv noraise loop`。`pub`、`priv`、`derive(...)` 可以写，但被忽略（单包，没有可见性）。

## 2. 表达式与语句

与 MoonBit 一致的部分：

```moonbit
fn demo(xs : Array[Int]) -> Int {
  let a = 1                       // 不可变绑定
  let mut total = a               // 可变绑定
  total = total + 2               // 赋值
  for i = 0; i < xs.length(); i = i + 1 {
    total = total + xs[i]
  }
  for x in xs {
    total = total + x
  }
  for k in 0..<3 {                // 也有 ..=
    total = total + k
  }
  while total > 100 {
    total = total - 100
  }
  let f = (x : Int) => x * 2      // lambda；也可写 x => e、(x, y) => e
  let g = fn(x : Int) { x + 1 }   // 匿名函数
  let s = if total > 10 { "big" } else { "small" }
  println(s)
  total += 1                      // 也有 -= *= /=
  total |> f |> g                 // 管道：e |> f 即 f(e)，e |> h(a) 即 h(e, a)
}

fn main {
  println(demo([1, 2, 3]))
}
```

- **块**：`{ s1; s2; e }` 的值是最后一个表达式。
- **调用**：`f(a, b)`、方法 `x.m(a)`（即 `T::m(x, a)`，`T` 是 `x` 的类型头部）、
  `Type::m(x, a)`。
- **运算符**：`+ - * / %`、`== != < <= > >=`、一元 `-`、`!`、`&&`、`||`。算术和比较运算符
  解析为方法：`a + b` 先找 `T::op_add`，再找 trait 方法；`a == b` 找 `op_equal`，`a < b` 找
  `op_lt`（或 `compare`）。所以给自己的类型写 `fn T::op_add(self : T, other : T) -> T` 就能用 `+`。
- **三种等号**：`=` 定义，`==` 布尔相等（`Bool`），`===` 命题相等（`Prop`，见第 7 节）。
- **类型注解**：`(e : T)`。**洞**：`_`，由合一推断。
- **数组**：`[1, 2, 3]`、`xs[i]`、`xs[i] = v`、`Array::make(n, x)`、`xs.length()`（`Int`）、
  `xs.size()`（`Nat`，可以出现在类型里）、`xs.push(x)`。
- **局部函数**：块内可以写 `fn name(x : T) -> R { … }`，但不能递归。
- **`return`、`break`、`continue`** 的含义与 MoonBit 相同；lambda 里的 `return` 只返回 lambda。

## 3. 函数

```moonbit
fn add(x : Int, y : Int) -> Int {
  x + y
}

fn[T] twice(f : (T) -> T, x : T) -> T {   // [T]：隐式参数
  f(f(x))
}

fn answer() -> Int { 42 }                 // 无参数函数

fn main {
  println(add(1, 2))
  println(twice(x => x + 1, 0))
  println(answer())
}
```

- **不柯里化**：`(Int, Int) -> Int` 是一个接受两个参数的函数，与 `(Int) -> (Int) -> Int`
  不同；不允许部分应用。
- **隐式参数**写在 `fn` 后面：`fn[T, n : Nat] f(…)`。`[T]` 即 `[T : Type]`；不写类型的隐式参数
  的类型由使用推断，推断不出时默认为 `Type`。调用时可以用 `f[Int](…)` 显式给出（按位置，可以
  只给前缀，可以写 `_`）。
- 无参数的函数内部表示为接受一个 `Unit` 参数。
- **方法**：`fn Type::m(self : Type, …)`。
- **外部原语**：`fn f(x : Int) -> Int = "%prim_name"`（只用于 Prelude）。

### 带标签参数（与 MoonBit 相同）

```moonbit
fn greet(name~ : String, greeting~ : String = "Hello", title? : String) -> String {
  match title {
    Some(t) => greeting + ", " + t + " " + name
    None => greeting + ", " + name
  }
}

fn main {
  println(greet(name="Alice"))
  println(greet(greeting="Hi", name="Bob", title="Dr."))
  let name = "Carol"
  println(greet(name~))            // name~ 即 name=name
  let t : String? = None
  println(greet(name~, title?=t))  // title?= 直接传 Option
}
```

- `x~ : T` 必须传；`x~ : T = e` 有默认值（可以引用前面的参数，每次调用时求值）；`x? : T` 在函数
  体内的类型是 `T?`（即 `Option[T]`），不传时为 `None`。
- 带标签参数可以按任意顺序传。只有顶层函数（包括方法）能有带标签参数。
- 作为值使用时，函数类型只按声明顺序列出参数，不含标签。

## 4. 类型

- **宇宙**：`Type : Type`；`Prop : Type`。`Prop` 中的类型是命题，它们的值是证明，证明无关
  （任意两个证明视为相等）。
- **函数类型**：

```moonbit
fn types_demo() -> Int {
  let f : (Int, Int) -> Int = (a, b) => a + b       // 两个参数
  let g : (Int) -> (Int) -> Int = a => b => a + b   // 返回函数的函数
  f(1, 2) + g(1)(2)
}
```

  依赖函数类型给参数起名：`(n : Nat, v : Vector[Int](n)) -> Int`；`forall x : A, P(x)` 是
  `(x : A) -> P(x)` 的写法；带隐式参数的一组写成 `[T](x : T) -> T`；只有隐式参数的一组写成
  `[T] -> Type`。
- **应用**：类型也是函数，`Array[Int]`、`Vector[T](n)`、`Id[T](x)(y)` 都是普通应用。
- **简写**：`T?` 即 `Option[T]`；`(A, B)` 是二元组类型。
- **类型可以计算**：返回 `Type` 的函数就是类型层的函数。

```moonbit
fn NAry(n : Nat) -> Type {
  match n {
    Z => Int
    S(k) => (Int) -> NAry(k)
  }
}

fn sum_n(n : Nat, acc : Int) -> NAry(n) {
  match n as m return NAry(m) {
    Z => acc
    S(k) => x => sum_n(k, acc + x)
  }
}

fn main {
  println(sum_n(3, 0)(1)(2)(3))   // 6
}
```

## 5. 数据类型

### enum

```moonbit
enum Shape {
  Circle(Double)
  Rect(Double, Double)
}

// 参数写在名字后，索引写在冒号后
enum Exp : [T] -> Type {
  IntLit(Int) : Exp[Int]
  BoolLit(Bool) : Exp[Bool]
  Add(Exp[Int], Exp[Int]) : Exp[Int]
  If[T](Exp[Bool], Exp[T], Exp[T]) : Exp[T]
}

enum Fin : (Nat) -> Type {
  FZ[n : Nat] : Fin(S(n))
  FS[n : Nat](Fin(n)) : Fin(S(n))
}

// 构造子的参数可以命名，后面的参数可以引用它
enum Sigma[A](P : (A) -> Type) {
  MkSigma(fst : A, snd : P(fst))
}
```

- 形式：`enum 名字[隐式参数](显式参数) : 索引 -> 宇宙 { 构造子 }`。参数在所有构造子中固定，
  索引可以随构造子变化。宇宙是 `Type` 或 `Prop`。
- 构造子：`C[自己的隐式参数](字段) : 返回类型`。没有索引时可以省略返回类型。
- 使用时数据类型的参数总是推断的；`[]` 只给构造子自己的隐式参数，例如 `FZ[n]`。
- 重名构造子按期望类型区分，也可以写全名 `Vector::Cons`。

### struct

```moonbit
struct Point {
  x : Int
  y : Int
}

// 后面的字段可以依赖前面的字段
struct Vec[T, n : Nat] {
  to_array : Array[T]
  length_to_array : to_array.size() === n
}

fn[T] Vec::from_array(xs : Array[T]) -> Vec[T, xs.size()] {
  { to_array: xs, length_to_array: Refl }
}

fn main {
  let p : Point = { x: 1, y: 2 }
  println(p.x + p.y)
  println(Vec::from_array([1, 2, 3]).to_array)
}
```

- 构造：`{ x: 1, y: 2 }`（类型由期望类型决定）；访问字段：`p.x`。
- 不支持结构体模式（`{ x: a, y: b } => …`）；用字段访问。

### suberror

```moonbit
suberror DivError {
  DivError(String)
}
```

错误类型，配合 `raise` 使用（第 9 节）。

## 6. 模式匹配

```moonbit
enum Vec2[T] : Nat -> Type {
  VNil : Vec2[T](0)
  VCons[n : Nat](T, Vec2[T](n)) : Vec2[T](S(n))
}

fn[T, n : Nat] Vec2::zip_with(self : Vec2[T](n), other : Vec2[T](n), f : (T, T) -> T) -> Vec2[T](n) {
  match (self, other) {
    (VNil, VNil) => VNil
    (VCons(x, xs), VCons(y, ys)) => VCons(f(x, y), xs.zip_with(ys, f))
  }
}

fn[T, n : Nat] Vec2::last(self : Vec2[T](S(n))) -> T {
  match self {
    VCons(x, VNil) => x
    VCons(_, VCons(y, ys)) => VCons(y, ys).last()
  }
}

fn main {
  let v : Vec2[Int](2) = VCons(1, VCons(2, VNil))
  println(v.zip_with(v, (a, b) => a + b).last())
}
```

- **依赖匹配**：匹配一个变量时，构造子的索引与变量类型的索引做合一，结果细化整个上下文和
  目标类型（Agda 风格）。上例中匹配 `self` 得到 `VNil` 后 `n = 0`，于是 `other` 也只能是 `VNil`，
  不必写其余分支。
- **覆盖检查**：缺少的分支会被报告（“match is not exhaustive; missing case(s): …”）。
  合一失败的分支是不可能的，可以省略；也可以只写模式不写 `=>`，此时检查它确实不可能：

```moonbit
enum V3[T] : Nat -> Type {
  N3 : V3[T](0)
  C3[n : Nat](T, V3[T](n)) : V3[T](S(n))
}

fn[T, n : Nat] V3::head(self : V3[T](S(n))) -> T {
  match self {
    N3
    C3(x, _) => x
  }
}
```

- **嵌套模式、元组模式、字面量模式、通配符 `_`**，与 MoonBit 相同；分支按顺序匹配，可以重叠。
- **构造子的隐式参数**可以在模式中绑定：`If[t](c, a, b)`、`IZ[_, a] => a`。
- **匹配函数调用的结果**也会细化：`match progress(t1) { PrDone(_, VLam(b)) => … }` 会把 `t1`
  的索引关系用于目标类型（见 `examples/stlc.mbtpp`）。
- **`let` 模式**：`let (a, b) = pair`，同样做覆盖检查。
- **return 子句**（Rocq 风格）：`match e as x in D[_](i) return P(i, x) { … }` 显式给出动机，
  此时不细化上下文。上一节的 `sum_n` 就是一例。
- **Prop 的消去**：匹配 `Prop` 中的数据时，结果也必须在 `Prop` 中，除非该类型是子单例
  （如 `===`）。

## 7. 证明

命题相等 `a === b` 是 Prelude 中的 `Id[_](a)(b)`，唯一的构造子是 `Refl`。类型检查时会计算（规范化）
表达式，所以 `plus(0, n) === n` 可以直接用 `Refl` 证明，`plus(n, 0) === n` 则需要归纳：

```moonbit
lemma plus_zero(n : Nat) -> n + 0 === n {
  match n {
    Z => Refl
    S(k) => Id::cong(S, plus_zero(k))
  }
}

lemma plus_succ(n : Nat, m : Nat) -> n + S(m) === S(n + m) {
  match n {
    Z => Refl
    S(k) => Id::cong(S, plus_succ(k, m))
  }
}

// 策略证明
lemma plus_comm : forall n m : Nat, n + m === m + n = proof {
  intros n m
  destruct n
  rewrite plus_zero(m)
  rfl
  rewrite plus_succ(m, n_0)
  rewrite plus_comm(n_0, m)
  rfl
}
```

- `lemma` 与 `fn` 相同，只是结果通常在 `Prop` 中。两种写法：`lemma 名字[隐式](参数) -> 命题 { 证明 }`
  和 `lemma 名字[隐式] : 命题 = 证明表达式`。
- Prelude 中的等式引理：`Id::sym(p)`、`Id::trans(p, q)`、`Id::cong(f, p)`、
  `Id::subst(p, motive, px)`（沿 `p` 改写 `motive(x)` 为 `motive(y)`，motive 可以返回 `Type`）。
- **策略**（`proof { … }`，每行一条）：

| 策略 | 作用 |
| --- | --- |
| `intros x y` | 引入假设（`intro`、`_` 也可以） |
| `exact e` | 用表达式 `e` 完成当前目标 |
| `rfl` | 用 `Refl` 完成目标（两边规范化后相同） |
| `destruct x` | 对 `x` 分情况，每个构造子一个新目标；字段命名为 `x_0`、`x_1`… |
| `rewrite e` / `rewrite <- e` | 用等式 `e` 从左到右 / 从右到左改写目标 |
| `apply f` | 用函数 `f` 把目标归约为它的参数 |
| `assume h : P` | 先证明 `P`（排在后面的目标），把它作为假设 `h` 使用 |

- 策略只是生成证明项的另一种方式：结果与手写的项相同。
- **不做终止检查、正性检查**：递归函数和递归证明都直接接受。证明不会在编译时擦除。

更复杂的例子见 `examples/proofs.mbtpp`（向量拼接的结合律、`reverse` 的性质）和
`examples/stlc.mbtpp`（简单类型 λ 演算的代换、progress 与 canonicity，以及从 canonicity 证明
中提取求值器）。

## 8. trait 与 monad

```moonbit
trait Shape2 {
  area(Self) -> Int
  name(Self) -> String
}

trait Solid : Shape2 {                       // 父 trait
  volume(Self, Int) -> Int
}

struct Square {
  side : Int
}

impl Shape2 for Square with area(self) { self.side * self.side }
impl Shape2 for Square with name(self) { "square" }
impl Solid for Square with volume(self, depth) { self.area() * depth }

fn[S : Shape2] describe(s : S) -> String {
  "\{s.name()} with area \{s.area()}"
}

fn[S : Solid] describe_solid(s : S) -> String {
  describe(s) + ", volume \{s.volume(2)}"   // 父 trait 的方法可用
}

fn main {
  let sq : Square = { side: 2 }
  println(describe_solid(sq))
}
```

- `impl Tr for T with m(params) { … }`：每个方法一条 `impl`。泛型实例：
  `impl[T : Show] Show for Array[T] with to_string(self) { … }`。
- 约束：`[T : Tr]`、多个约束 `[T : Eq + Show]`。实例由实例搜索自动填充（局部约束、父 trait、
  全局实例）。
- 方法调用：`x.m()` 或 `Tr::m(x)`。
- **高阶 trait**：`Self` 可以是类型构造子：

```moonbit
fn[M : Monad, T, U, V] lift2(f : (T, U) -> V, m : M[T], n : M[U]) -> M[V] {
  monad {
    let t <- m
    let u <- n
    Monad::pure(f(t, u))
  }
}

fn main {
  println(lift2((a, b) => a + b, Some(1), Some(2)))   // Some(3)
}
```

  Prelude 中 `trait Monad(Self : [T] -> Type) { fn[T] pure(T) -> Self[T]; fn[T, U] bind(…) }`，
  `Option` 和 `List` 有实例。
- **`monad { … }` 块**：`let x <- m` 绑定；表达式中的 `<- m` 就地绑定，如
  `Monad::pure(f(<- m, <- n))`。

## 9. 可变状态、循环与异常

```moonbit
suberror DivError2 {
  DivError2(String)
}

fn div(a : Int, b : Int) -> Int raise DivError2 {
  if b == 0 {
    raise DivError2("division by zero")
  }
  a / b
}

fn main {
  let r = try div(10, 0) catch {
    DivError2(msg) => {
      println("caught: " + msg)
      0
    }
  }
  println(r)
  println(try? div(10, 2))      // Ok(5)
}
```

- 函数类型 `-> T raise E`；`raise e` 抛出；`try e catch { 模式 => … }` 捕获；`try? e` 得到
  `Result[T, Error]`。`raise` 不写类型时为 `Error`。
- 使用了 `let mut`、赋值、循环、`raise`、`try` 的函数在类型检查时不展开（它们不参与类型层的
  计算）。

## 10. Prelude 一览

| 名字 | 说明 |
| --- | --- |
| `Int`、`Double`、`Bool`、`Char`、`String`、`Unit`、`Array[T]`、`Error` | 内置类型 |
| `Nat`（`Z`、`S`） | 自然数，整数字面量在 `Nat` 处展开；`n.to_int()`、`int_to_nat(i)`、`+`、`*`、`==` |
| `Id[T](x)(y)`、`===`、`Refl` | 命题相等；`Id::sym`、`Id::trans`、`Id::cong`、`Id::subst` |
| `Option[T]`（`None`、`Some`）、`T?` | 可选值 |
| `Result[T, E]`（`Ok`、`Err`） | 结果 |
| `List[T]`（`Nil`、`Cons`） | 链表；`append`、`reverse`、`length`、`map`、`flat_map` 等 |
| `Tuple2`、`Tuple3`、`(a, b)` | 元组 |
| `Failure`、`fail(msg)` | 通用错误 |
| `Show`、`Eq`、`Compare : Eq`、`Add`、`Monad` | trait（`Show::to_string` 等） |
| `println`、`print`、`print_string`、`abort`、`panic`、`not` | 输出与终止 |
| `Int`/`Double`/`String`/`Char`/`Bool` 的方法 | `op_add`、`compare`、`to_string`、`length`、`substring`、`to_double` 等 |

---

# 第二部分：moonpp

## 11. 安装

需要 Node.js 和 MoonBit 工具链（`moon`，2026-10 之后使用 `moon.mod` / `moon.pkg` 的版本）。在
本仓库中：

```bash
moon build --target js --release
npm install -g .
```

`npm install -g .` 安装的是指向本仓库的链接，以后重新 `moon build --target js --release` 即可更新。
也可以直接调用 `bin/moonpp`（Windows 上 `bin\moonpp.cmd`）。

## 12. 项目结构

MoonBit++ 项目就是一个 MoonBit 模块，包是放 `.mbtpp` 文件的目录：

```
hello/
  moon.mod                 模块：名字、版本、依赖、source 目录
  src/
    main/
      moon.pkg             包：导入的 MoonBit 包、是否是 main 包
      main.mbtpp           一个包可以有多个 .mbtpp 文件
  mbtpp_out/               moonpp build 的输出（第 15 节）
```

`moon.mod`：

```
name = "username/hello"

version = "0.1.0"

import {
  "moonbitlang/x@0.5.6",
}

source = "src"
```

`src/main/moon.pkg`：

```
import {
  "moonbitlang/x/encoding/percent",
  "moonbitlang/core/string" @str,
}

options(
  "is-main": true,
)
```

- `import` 块列出导入的 MoonBit 包，`@别名` 可选（默认是路径的最后一段）。
- main 包用 `options("is-main": true)` 标记（新版 `moon fmt` 会改写成
  `pkgtype(kind: "executable")`，两种都认）。
- 一个包的所有 `.mbtpp` 文件共享一个作用域，声明顺序无关；报错定位到具体文件。
- 旧格式（`moon.mod.json`、`moon.pkg.json`）也能读取。但新版 `moon` 不再接受 `moon.mod.json`，
  需要依赖管理或编译时，在项目根目录运行 `moon fmt` 迁移。

## 13. 命令

| 命令 | 作用 |
| --- | --- |
| `moonpp new <名字>` | 创建项目 |
| `moonpp check [路径]` | 类型检查整个项目（或一个包目录、一个文件） |
| `moonpp run [路径]` | 用解释器运行 main 包（或指定的包、文件） |
| `moonpp run --compiled [路径]` | 编译到 MoonBit 并用 `moon run` 运行 |
| `moonpp build [路径] [-o 目录]` | 编译成 MoonBit 项目并 `moon build` |
| `moonpp add <user/module[@版本]>` | 添加依赖（`moon add`），并为缺少接口的包生成 `.mbti` |
| `moonpp remove <module>` | 删除依赖（`moon remove`） |
| `moonpp install` | 安装依赖（`moon install`）并生成接口 |
| `moonpp interfaces` | 只为已下载的依赖生成缺失的接口（`moon info`） |
| `moonpp tree` | 依赖树（`moon tree`） |
| `moonpp version` | 版本 |

选项：

| 选项 | 作用 |
| --- | --- |
| `--verbose` | 列出导入时被跳过的接口项 |
| `--no-prelude` | 不加载 Prelude |
| `--compiled` | `run` 时运行编译结果而不是解释执行 |
| `-o`、`--output <目录>` | `build`、`run --compiled` 时生成项目的位置 |

路径可以是单个 `.mbtpp` 文件：`moonpp run examples/vector.mbtpp`。单个文件旁边如果有
`moon.pkg`，其中的导入同样生效。

## 14. 依赖

- **mooncakes.io 上的模块**：`moonpp add moonbitlang/x@0.5.6`，然后在包的 `moon.pkg` 中导入其中
  的包（`"moonbitlang/x/encoding/percent"`）。接口从项目的 `.mooncakes/` 读取。
- **MoonBit 标准库**：`moonbitlang/core/*` 不需要添加，接口从 MoonBit 安装目录
  （`~/.moon/lib/core`）读取。
- **本地模块**：用 MoonBit 的工作区。在项目根目录写 `moon.work`，并在 `moon.mod` 中声明依赖：

```
members = [
  ".",
  "../geo",
]
```

```
name = "username/app"

version = "0.1.0"

import {
  "u/geo@0.1.0",
}

source = "src"
```

  本地模块需要有 `.mbti` 接口（在该模块中运行 `moon info` 生成）。

## 15. 构建产物

`moonpp build` 生成一个完整的 MoonBit 项目，不依赖 moonpp 也能构建运行：

```
mbtpp_out/main/            （单个文件时是 文件所在目录/_mbtpp_build/<文件名>/）
  moon.mod                 原项目的名字、版本和依赖
  moon.work                工作区：自身，加上本地模块（绝对路径）
  README.md
  .gitignore
  main/
    moon.pkg               导入的 MoonBit 包，main 包
    main.mbt               生成的程序
    runtime.mbt            运行时支持（值表示、模式匹配、原语）
```

```bash
cd mbtpp_out/main
moon run main
```

输出目录可以用 `-o` 改变。每次构建会覆盖其中的文件。

---

# 第三部分：与 MoonBit 交互

## 16. 导入 MoonBit 包

在 `moon.pkg` 中导入后，用 `@包.名字` 引用：

```moonbit
fn distance(x : Double, y : Double) -> Double {
  @math.hypot(x, y)
}

fn parse_hex(s : String) -> Int raise {
  @str.parse_int(s, base=16)
}
```

（配合 `import { "moonbitlang/core/math", "moonbitlang/core/string" @str }`，见
`examples/import`。）

- **工作方式**：moonpp 读取包的 `.mbti` 接口文件，把其中的项翻译成 MoonBit++ 声明。函数成为
  外部常量：类型检查时只有类型，不会展开。
- **解释器不能运行导入的函数**：运行到它们时报错 “cannot run the imported MoonBit function …”。
  需要真正调用时，用编译后的程序（`moonpp run --compiled`）。
- **名字**：函数 `@pkg.f`；类型 `@pkg.T`；构造子 `@pkg.T::C` 或 `@pkg.C`（按期望类型也可以只写
  `C`）；方法照常 `x.m()`；`#as_free_fn` 的方法也可以写 `@pkg.m`；trait `@pkg.Tr`，可以用于约束、
  `impl @pkg.Tr for T`、`trait A : @pkg.Tr`。
- **类型对应**：

| MoonBit | MoonBit++ |
| --- | --- |
| `Int32`（`Int`）、`Double`、`Bool`、`Char`、`String`、`Unit` | 同名内置类型（`Int32` 即 `Int`） |
| `Array[T]`、`T?`、`Result[T, E]` | 同名类型 |
| `StringView`、`ArrayView[T]` | `String`、`Array[T]` |
| `pub(all) enum` / `pub(all) struct` | 同样的 enum / struct，自动 `#mbt`（第 18 节），可以构造和匹配 |
| `pub enum` / `pub struct`（只读） | 同上，但不能构造，只能匹配和传递 |
| `pub(open) trait` | trait，自动 `#mbt`，可以为本程序的类型实现 |
| `pub trait` | trait，不能实现 |
| `type T`（抽象类型）、未定义的类型（`Int64`、`Map` 等） | 不透明类型 |
| 未知的 trait 约束（`Hash` 等） | 不透明 trait，任何类型都满足 |
| `(A) -> B raise E`、`x~ : T`、`x? : T` | 相同 |

- **不导入的项**（`--verbose` 列出）：`async` 函数与 `async` 函数类型、trait 对象 `&T`、
  自动填充的 `loc~ : SourceLoc`、泛型 `impl`、`Show`/`Eq`/`Compare` 之外的 `impl`、`#deprecated` 的
  项、`using` 重新导出。

## 17. 编译到 MoonBit

编译器把类型检查后的核心项翻译成 MoonBit。两种翻译混合使用：

- **原生翻译**：参数和结果都是“原生类型”、函数体也在一阶片段中的函数，翻译成普通的（可以是
  泛型的）MoonBit 函数 `f_t`。原生类型是 `Int`、`Double`、`Bool`、`Char`、`String`、`Unit`、类型参数、
  函数类型，以及参数都是类型、字段都是原生类型的数据类型。索引和被擦除的字段消失：
  `Vector[T](n)` 成为 `enum E_Vector[T0] { Nil; Cons(T0, E_Vector[T0]) }`。
- **统一表示**：其余部分（类型层计算、GADT 细化、高阶 trait 等）使用运行时的统一值表示
  `Value`（`VInt`、`VCon(名字, 字段)`、`VFun` …），由 `runtime.mbt` 支持。两种代码之间在边界上
  转换。
- **擦除**：类型参数总是擦除；其他隐式参数和构造子的隐式字段，只用于类型时擦除。证明不擦除。
- 生成的代码经过 `moon fmt`。

一个典型的 `fib` 编译后约快 40 倍（解释器 7.85 s，编译后 0.18 s）。

### 调用 MoonBit 函数

编译后的程序真正调用导入的函数：

- **从原生代码调用**：直接调用，不做转换。
- **从统一表示调用**：按签名转换参数和结果。支持标量、类型参数、`Array`、`Option`、`#mbt`
  数据类型（逐构造子转换）、函数（回调）、不透明类型（装箱），以及带标签参数、可选参数和
  `raise`。
- 签名不支持的外部函数如果被调用，是**编译错误**，并说明原因。
- 只读类型的值不能从 `Value` 重建：只能在原生代码中传递。在统一表示中把它们交给 MoonBit
  函数会报编译错误，提示改为在原生片段中调用。

## 18. `#mbt`：平凡地翻译到 MoonBit 的声明

在 enum、struct、trait、fn 前加 `#mbt`，声明它们直接对应 MoonBit 的类型、trait 和函数。条件在
类型检查时验证，不满足时报错。`#mbt` 不改变类型检查和解释执行，只影响编译。

```moonbit
#mbt
enum Tree[T] {
  Leaf
  Node(Tree[T], T, Tree[T])
}

#mbt
struct Pt {
  x : Int
  y : Int
}

#mbt
trait Size {
  size(Self) -> Int
}

impl Size for Int with size(self) { self }
impl Size for Pt with size(self) { self.x + self.y }
impl[T : Size] Size for Tree[T] with size(self) {
  match self {
    Leaf => 0
    Node(l, x, r) => l.size() + x.size() + r.size()
  }
}

#mbt
fn[T : Size] total(t : Tree[T]) -> Int {
  t.size()
}

#mbt
fn[T] Tree::depth(self : Tree[T]) -> Int {
  match self {
    Leaf => 0
    Node(l, _, r) => {
      let a = l.depth()
      let b = r.depth()
      1 + (if a > b { a } else { b })
    }
  }
}

fn main {
  let t : Tree[Int] = Node(Leaf, 3, Node(Leaf, 4, Leaf))
  println(total(t))
  println(t.depth())
}
```

编译结果：`pub(all) enum Tree[T0]`、`pub(all) struct Pt`、`pub(open) trait Size`、
`impl[T0 : Size] Size for Tree[T0]`、`pub fn[T0 : Size] total(t : Tree[T0]) -> Int32`、
`pub fn[T0] Tree::depth(self : Tree[T0]) -> Int32`（`moon fmt` 把 MoonBit 的 `Int` 写作 `Int32`）。

- **`#mbt` 类型**：只有类型参数，没有索引；不是命题、不是 suberror；构造子没有隐式字段；
  字段类型是 MoonBit 类型（`Int`、`Double`、`Bool`、`Char`、`String`、`Unit`、类型参数、`#mbt` 类型、
  它们之间的函数类型；暂不支持数组）。生成的类型名和构造子须以大写字母开头，不能与 `Value`、
  `Option` 等已有名字冲突。
- **`#mbt("名字")`**：对应已有的 MoonBit 类型 / trait，不生成声明。Prelude 中的 `Option`、
  `Result` 就是 `#mbt("Option")`、`#mbt("Result")`。
- **`#mbt` trait**：`Self : Type`；父 trait 也是 `#mbt`；方法不是泛型的，类型是 MoonBit 类型。
  生成的 trait 方法都标 `raise`。
- **`#mbt` trait 的实例**：只有类型参数和 `#mbt` 约束；遵守 MoonBit 的孤儿规则（已有的 trait
  只能为本程序生成的类型实现）。方法在原生片段中的实例生成 MoonBit `impl`。
- **`#mbt` 函数**：编译为同名的 `pub fn`。隐式参数只能是 `[T]`；约束只能是类型参数上的 `#mbt`
  trait，被约束的类型参数要出现在参数或结果中；参数和结果是 MoonBit 类型；支持 `x~`、`x?`，不支持
  默认值；方法只能属于本程序生成的 `#mbt` 类型；`main` 不能标 `#mbt`。函数体必须在原生片段中，
  否则编译报错并指出第一个不能原生翻译的表达式（例如调用了 `println`，它带非 `#mbt` 的 `Show`
  约束）。没有声明 `raise` 的函数在 MoonBit 中也不 `raise`，内部的运行时失败变成 `abort`。
- 从 `.mbti` 导入的 `pub(all)` 类型和 `pub(open)` trait 自动带 `#mbt("@pkg.T")`（满足条件时）。

## 19. 在 MoonBit 中使用编译结果

`#mbt` 函数和类型是公开的，所以生成的包可以被 MoonBit 代码使用。例如在生成项目的 `main/`
中加一个测试文件：

```
test "exported functions" {
  let t = Tree::Node(Tree::Leaf, 3, Tree::Leaf)
  inspect(total(t), content="3")
  inspect(t.depth(), content="1")
}
```

也可以让别的 MoonBit 项目通过工作区引用生成的项目。目前生成的总是 main 包（带 `main` 函数），
还不能生成单独的库包。

## 20. 已知限制

- **语言**：没有终止检查（按设计）；没有可恢复的代数效应和 `simp`/`omega`/`auto` 策略；局部
  `fn` 不能递归；结构体没有可变字段；trait 没有默认方法。
- **导入**：解释器不能运行导入的函数；不支持 MoonBit 的 `async`（`async fn`、`async` 函数类型）。
- **编译器**：数组在原生代码中不是原生类型，含数组的签名走统一表示（也不能是 `#mbt`）；
  统一表示与原生代码之间按值转换，频繁跨边界传递大型数据会慢；证明不擦除。
- **工具**：生成的项目总是 main 包。
