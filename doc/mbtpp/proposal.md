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

## 9. MoonBit++ → MoonBit 编译器

见之前的讨论：可行，但做法是混合的。能用 MoonBit 类型表达的部分生成原生代码，
其余部分（GADT 细化、类型层计算、HKT trait）退化为统一的值表示。核心语言为此保留
以下信息：参数分组、Prop 和类型参数的可擦除性、纯与不纯函数的标记。
