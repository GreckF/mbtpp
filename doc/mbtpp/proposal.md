# MoonBit++ 语法规范（第一阶段，已确认）

## 0. 总体

| 项目 | 决定 |
| --- | --- |
| 宇宙 | `Type : Type`；`Prop : Type`，Prop 非直谓且证明无关 |
| 终止 / 严格正性 | 不检查 |
| 函数 | uncurried：`(A, B) -> C` 与 `(A) -> (B) -> C` 是不同类型，不允许部分应用 |
| 参数 | `[...]` 隐式，`(...)` 显式；一组里隐式在前。**没有 `{}`** |
| `[x]` | 类型由使用推断，推断不出时默认为 `Type` |
| 模式匹配 | 依赖模式匹配（基于合一）＋ Rocq 风格 `as … in … return …` |
| 第一阶段范围 | 依赖核心、struct、方法、lemma、可变状态与循环、trait＋`monad {}`、`raise`/`try`、最小策略集 |
| 不做 | 可恢复的代数效应、`simp`/`omega`/`auto` |
| 模块 | MoonBit 式包；第一阶段只支持单个包＋内置 Prelude |
| 后端 | 类型检查器＋树遍历解释器 |

## 1. 表达式

与 MoonBit 一致：`let`、`let mut`、赋值、`if`/`else`、`match`、块、`f(a, b)`、
`x.m(args)`、`e |> f(a)`、`fn(x) { }`、`x => e`、`(x, y) => e`、`(e : T)`、`_`、
`while`、`for i = 0; i < n; i = i + 1 { }`、`for x in xs { }`、`return`、`break`、
`continue`、`raise`、`try { } catch { }`、字符串插值 `"\{x}"`。

三种等号：`=` 定义，`==` 布尔相等，`===` 命题相等（在 Prop 中）。

数字字面量在期望类型为 `Nat` 时展开为 `S(…S(Z))`，否则为 `Int`。

## 2. 类型与应用

```moonbit
(Int, Int) -> Int
Int -> Int
(n : Nat, v : Vector[Int](n)) -> Int
[T](x : T) -> T                  // 一组：隐式在前，显式在后
[T] -> Type                      // 只有隐式参数的一组
(n : Nat) -> [T](T) -> Vector[T](n)   // 两组，调用为 f(n)(x)
forall x : A, P(x)               // (x : A) -> P(x)
```

应用：`f[a, b](x, y)`，`[]` 按位置填写隐式参数（可以只写前缀，可以写 `_`），
`()` 必须恰好填满显式参数。类型也是函数，所以 `Array[Int]`、`Exp[Int]`、
`Vector[T](n)` 都是普通应用。

对于构造子，`[]` 只填写构造子自己的隐式参数，数据类型的参数总是由推断得到。

## 3. enum

```moonbit
enum Nat {
  Z
  S(Nat)
}

enum Exp : [T] -> Type {
  IntLit(Int) : Exp[Int]
  BoolLit(Bool) : Exp[Bool]
  Add(Exp[Int], Exp[Int]) : Exp[Int]
  If[T](Exp[Bool], Exp[T], Exp[T]) : Exp[T]
}

enum Vector[T] : Nat -> Type {
  Nil : Vector[T](0)
  Cons[n : Nat](T, Vector[T](n)) : Vector[T](S(n))
}

enum Id[T](x : T) : (y : T) -> Prop {
  Refl : Id[T](x)(x)
}
// a === b  是  Id[_](a)(b)
```

- `enum 名字[参数](参数) : 索引类型 -> 宇宙`。参数组和每个索引组都是独立的参数组，
  所以 `Id` 的完整写法是 `Id[T](x)(y)`。命题相等叫 `Id`，`Eq` 留给布尔相等的 trait（与 MoonBit 一致）。
- 构造子写作 `C[自己的隐式](显式) : 返回类型`；没有索引时可以省略返回类型。
- 构造子参数可以命名并被后面的参数引用：`MkSigma[A](fst : A, snd : P(fst))`。
- 重名构造子按期望类型消歧，或写成 `Vector::Cons`。

## 4. struct

```moonbit
struct Vec[T, n : Nat] {
  to_array : Array[T]
  length_to_array : to_array.size() === n
}

fn[T] Vec::from_array(xs : Array[T]) -> Vec[T, xs.size()] {
  { to_array: xs, length_to_array: Refl }
}
```

后面的字段可以依赖前面的字段。`Array::length()` 返回 `Int`，`Array::size()` 返回 `Nat`。

## 5. 函数与模式匹配

```moonbit
fn[T] Exp::eval(self : Exp[T]) -> T {
  match self {
    IntLit(n) => n
    BoolLit(b) => b
    Add(l, r) => l.eval() + r.eval()
    If[_](c, t, f) => if c.eval() { t.eval() } else { f.eval() }
  }
}

fn[T, n] Vector::head(self : Vector[T](S(n))) -> T {   // n 推断为 Nat
  match self {
    Nil                // 不可能的分支：只写模式
    Cons(hd, _) => hd
  }
}
```

- 隐式参数只写在 `fn` 之后：`fn[T] f(...)`（不支持 `fn f[T](...)`）。
- 方法：`fn Type::m(self : …)`，调用 `x.m(…)` 或 `Type::m(x, …)`。
- 外部原语：`fn f(x : Int) -> Int = "%prim_name"`。
- 不可能的分支可以省略，或者只写模式（不写 `=>`）；后者会检查它确实不可能。
- `let Pat = e` 是不可反驳绑定，同样做覆盖检查。

### 带标签参数（与 MoonBit 相同）

```moonbit
fn f(x : Int, a~ : Int, b~ : Int = x, c? : Int) -> Int { ... }

f(1, a=2)            // b 取默认值 x，c 为 None
f(b=5, a~, 1)        // a~ 即 a=a；带标签参数顺序任意
f(1, a=2, c=3)       // c? 参数传值时自动包成 Some(3)
f(1, a=2, c?=opt)    // c?= 直接传 Option；c? 即 c?=c
```

- `x~ : T` 必须传；`x~ : T = e` 有默认值，默认值可以引用前面的参数，每次调用时重新求值；
  `x? : T` 在函数体内的类型是 `T?`，即 `Option[T]`，不传时为 `None`。
- 只有顶层函数（包括方法）可以有带标签参数，lambda 和局部 `fn` 不行。
- 标签不属于函数类型：作为值使用时，函数类型只按声明顺序列出位置参数。
- `T?` 是 `Option[T]` 的简写。

### return 子句

```moonbit
match v as w in Vector[_](m) return P(m, w) {
  Nil => …
  Cons(h, t) => …
}
```

没有 `return` 时，被匹配的是变量则自动细化整个上下文与目标类型（Agda 风格）；
有 `return` 时按 Rocq 的语义，不细化上下文。

匹配 Prop 中的数据时，结果也必须在 Prop 中，除非该类型是子单例（如 `===`）。

## 6. lemma 与策略

```moonbit
lemma plus_zero : forall n : Nat, plus(n, 0) === n = proof { … }
lemma plus_zero2(n : Nat) -> plus(n, 0) === n { … }
```

策略：`intros x y`、`exact e`、`rfl`、`destruct x`、`rewrite h`（`rewrite <- h` 反向）、
`apply f`、`assume h : P`。

## 7. trait 与 monad

```moonbit
trait Show {
  to_string(Self) -> String
}

impl Show for Int with to_string(self) { … }
impl[T : Show] Show for Array[T] with to_string(self) { … }

trait Monad(Self : [T] -> Type) {
  fn[T] pure(T) -> Self[T]
  fn[T, U] bind(Self[T], T -> Self[U]) -> Self[U]
}

fn[M : Monad, T, U, V] lift2(f : (T, U) -> V, m : M[T], n : M[U]) -> M[V] {
  monad { Monad::pure(f(<- m, <- n)) }
}
```

`Self` 的种类按统一规则写成 `[T] -> Type`（这样才能写 `Self[T]`，并与 `Array`、
`Option` 的种类一致）。`[M : Monad]` 表示 `M` 加上一个由实例搜索填充的 `Monad` 实例。
运算符 `+ - * / % == < <= > >=` 解析为方法 `op_add` 等，先找 `H::op_add`，再找 trait。

## 8. 可变状态与异常

使用了 `let mut`、赋值、循环、`raise`、`try` 的函数在类型检查时不展开。

```moonbit
suberror DivError { DivError(String) }

fn div(a : Int, b : Int) -> Int raise DivError {
  if b == 0 { raise DivError("div by zero") }
  a / b
}

fn main {
  try div(1, 0) catch {
    DivError(msg) => println(msg)
  }
}
```

## 9. 导入 MoonBit 包

与 MoonBit 一样，依赖写在源文件旁边的 `moon.pkg.json` 里，代码中用 `@pkg.name` 引用：

```json
{ "import": [ "moonbitlang/core/math", { "path": "moonbitlang/core/strconv", "alias": "conv" } ] }
```

```moonbit
fn distance(x : Double, y : Double) -> Double { @math.hypot(x, y) }
fn parse_hex(s : String) -> Int raise { @conv.parse_int(s, base=16) }
```

- 接口从包的 `.mbti` 文件读取：`moonbitlang/core/*` 在 `$MOON_HOME/lib/core`（默认
  `~/.moon/lib/core`），其他包在源文件所在目录或上级目录的 `.mooncakes/` 中。
- 导入的函数只有类型、没有定义：类型检查时它们是不透明常量，不会展开；
  解释器运行到导入的函数时会报错（导入目前只用于类型检查）。
- 名字：包里的函数、类型、构造子分别为 `@pkg.f`、`@pkg.T`、`@pkg.T::C`（构造子也可以写
  `@pkg.C`，或按期望类型直接写 `C`），方法照常用 `x.m()` 调用。`#as_free_fn` 的方法也可以写成
  `@pkg.m`。`impl @pkg.Tr for T`、`trait A : @pkg.Tr` 可以使用导入的 trait。
- 导入的 `pub(all)` enum/struct 与 `pub(open)` trait 自动带 `#mbt("@pkg.T")`（见第 10 节），
  只要它们满足 `#mbt` 的条件；`pub` 的 enum/struct 是只读的（不能构造，可以匹配），`pub` 的
  trait 不能实现。
- 不支持的项会被跳过（`--verbose` 列出）：trait 对象 `&T`、自动填充的 `loc~`、泛型 `impl`，
  以及 `Show`/`Eq`/`Compare` 之外的 `impl`。`#deprecated` 的项不导入。
- 接口中出现但未定义的类型（如 `Int64`、`Map`）成为不透明类型；未知的 trait 约束
  （如 `Hash`）成为不透明 trait，任何类型都视为满足。`StringView`、`ArrayView[T]` 视为
  `String`、`Array[T]`。
- 为此新增了 `Double` 字面量与运算，以及多个 trait 约束 `[T : Eq + Show]`。

## 10. `#mbt`：平凡地翻译到 MoonBit 的类型与 trait

```moonbit
#mbt
enum Tree[T] { Leaf; Node(Tree[T], T, Tree[T]) }   // 编译为同名的 MoonBit enum

#mbt
struct Point { x : Int; y : Int }                  // 编译为同名的 MoonBit struct

#mbt("Option")
enum Option[T] { None; Some(T) }                   // 就是 MoonBit 已有的 Option（prelude 中）

#mbt
trait Size { size(Self) -> Int; zero() -> Self }  // 编译为 MoonBit trait

impl[T : Size] Size for Tree[T] with size(self) { ... }   // 编译为 MoonBit impl
fn[T : Size] total(t : Tree[T]) -> Int { t.size() }      // 编译为 fn[T0 : Size]
```

条件（类型检查时验证，违反直接报错）：

- 类型：只有类型参数，没有索引、不是命题、不是 suberror；构造子没有隐式字段；字段类型是
  “MoonBit 类型”：`Int`、`Double`、`Bool`、`Char`、`String`、`Unit`、类型参数、`#mbt` 类型，
  以及它们之间的（不依赖的）函数类型。由编译器生成的类型（`#mbt` 不带名字）名字和构造子
  须以大写字母开头，且不能与 `Value`、`Option` 等已有名字冲突。
- trait：`Self : Type`；父 trait 也是 `#mbt`；方法不是泛型的，参数与结果是 MoonBit 类型
  （`Self` 可以出现）。
- `#mbt` trait 的 `impl`：只有类型参数和 `#mbt` 约束；`Self` 是 MoonBit 类型（不能只是类型
  参数）；遵守 MoonBit 的孤儿规则——已有的 trait（`#mbt("name")`、导入的）只能为本程序生成的
  类型实现；只读（`pub`）的 trait 不能实现。
- 只读类型（导入的 `pub` enum/struct）不能构造。

函数也可以标 `#mbt`，它会被编译为同名的公开 MoonBit 函数，MoonBit 代码可以直接调用：

```moonbit
#mbt
fn[T] insert(t : Tree[T], x : T, lt~ : (T, T) -> Bool) -> Tree[T] { ... }
// pub fn[T0] insert(t : Tree[T0], x : T0, lt~ : (T0, T0) -> Bool raise) -> Tree[T0]

#mbt
fn[T] Tree::depth(self : Tree[T]) -> Int { ... }   // pub fn[T0] Tree::depth(...)
```

- 签名（类型检查时验证）：隐式参数只能是类型参数 `[T]`，约束只能是类型参数上的 `#mbt`
  trait；显式参数和结果是 MoonBit 类型；支持 `x~`、`x?` 参数，不支持默认值；方法只能属于本
  程序生成的 `#mbt` 类型；`main` 不能标 `#mbt`。`#mbt("name")` 指定 MoonBit 中的名字。
- 函数体（编译时验证）：必须在原生片段中，否则编译报错，并指出第一个不能原生翻译的表达式
  （例如调用了 `println`，它带非 `#mbt` 的 `Show` 约束）。
- `raise`：没有声明 `raise` 的函数在 MoonBit 中也不 `raise`，内部的运行时失败变成 `abort`；
  声明了 `raise E` 的函数在 MoonBit 中是 `raise`（错误是编译后的 MoonBit++ 错误值）。
- 生成的 `#mbt` 类型是 `pub(all)`，trait 是 `pub(open)`；可翻译的 `#mbt` trait 实例全部生成
  `impl`。

`#mbt` 不改变类型检查和解释执行的语义，只影响编译（见第 11 节）。

## 11. MoonBit++ → MoonBit 编译器

见之前的讨论：可行，但做法是混合的。能用 MoonBit 类型表达的部分生成原生代码，
其余部分（GADT 细化、类型层计算、HKT trait）退化为统一的值表示。核心语言为此保留
以下信息：参数分组、Prop 和类型参数的可擦除性、纯与不纯函数的标记。
