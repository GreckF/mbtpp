# MoonBit++ 受控展开提案

参考：Gratzer, Sterling, Angiuli, Coquand, Birkedal, *Controlling Unfolding in Type Theory*
（arXiv:2210.05420）。Agda 2.6.4 的 `opaque`/`unfolding` 是同一机制的实现。

## 0. 总体

| 项目 | 决定 |
| --- | --- |
| 默认 | 定义**透明**（与现在相同）；与论文相反，论文默认不透明 |
| 不透明 | `#opaque`：类型检查时不展开（也不执行），除非在展开范围内 |
| 封闭 | `#opaque(sealed)`：除自己的定义体外，任何地方都不能展开（论文的 `abstract`） |
| 声明层展开 | `#unfold(f, g)`：在这个声明的定义体中可以展开 `f`、`g` |
| 表达式层展开 | `unfold(f, g) { e }`：在 `e` 中可以展开 `f`、`g` |
| 策略 | `unfold f, g`：证明的其余部分中可以展开 `f`、`g` |
| 传递性 | 展开 `g` 时，`g` 依赖的展开一起生效；依赖展开的透明定义只在依赖可以展开时展开 |
| 运行时 | 不受影响：解释器、编译器、擦除都与展开无关 |

## 1. 动机

论文的动机是模块化（证明不依赖定义的细节）、可读性（目标不被展开成大项）和性能。在
MoonBit++ 中：

- **可判定性**不是问题：`Type : Type`、没有终止检查，检查本来就不可判定。论文第 6 节的
  正规化证明对我们没有意义，我们不需要扩展类型。
- **模块化**：`+` 改成对第二个参数递归，所有依赖计算的证明都会失效。`#opaque` 把依赖实现的
  证明集中到少数加了 `#unfold` 的基础引理上，其余证明只使用这些引理。
- **性能与检查时限**：除了展开大定义，检查器还会执行使用可变状态的函数（`sum_to(1000)`）。
  不透明的函数既不展开也不执行。
- **抽象边界**：隐藏表示，例如 `Map` 的实现、用证明字段保证不变量的结构体。

可读性方面，检查器已经只在展开后能继续计算时才展开（卡住的调用保持折叠），类似 Kovács 的
glued evaluation，所以这不是主要动机。

### 为什么默认透明

手册和示例大量依赖自动计算：`2 + 2 === 4`、`plus_zero_left` 用 `Refl` 证明，类型层的
`NAry(3)`，依赖匹配中索引的计算，检查时执行的 `sum_to(10) === 55`。“类型检查时会计算”是这门
语言面向 MoonBit 用户的卖点。所以采用 Agda 的选择：默认透明，不透明是用户的选择。

## 2. 语法与例子

```moonbit
#opaque
fn plus(m : Nat, n : Nat) -> Nat {
  match m {
    Z => n
    S(k) => S(plus(k, n))
  }
}

// 只有这两条引理依赖 plus 的定义
#unfold(plus)
lemma plus_z(n : Nat) -> plus(Z, n) === n { Refl }

#unfold(plus)
lemma plus_s(m : Nat, n : Nat) -> plus(S(m), n) === S(plus(m, n)) { Refl }

// 其余证明只用引理
lemma plus_zero(n : Nat) -> plus(n, Z) === n {
  match n {
    Z => plus_z(Z)
    S(k) => Id::trans(plus_s(k, Z), Id::cong(S, plus_zero(k)))
  }
}

// 表达式层
lemma two() -> plus(1, 1) === 2 {
  unfold(plus) { Refl }
}

// 策略
lemma two_t : plus(1, 1) === 2 = proof {
  unfold plus
  rfl
}
```

- `#opaque` 和 `#unfold` 可以写在 `fn` 和 `lemma` 上（包括方法），可以和 `#mbt`、`#timelimit`
  一起写。
- `#unfold` 的名字是全局函数；`#opaque(sealed)` 的函数不能出现在其中（报错）。
- 一个不透明函数在自己的定义体中是透明的（递归调用可以展开）。

## 3. 语义

每个全局函数 `f` 有：模式（透明 / 不透明 / 封闭）与依赖集合 `deps(f)`（`#unfold` 的名字，以及
定义体中 `unfold` 块和 `unfold` 策略用到的名字）。

**展开范围**：检查一个声明的定义体时，可展开集合 `S` 是 `{f} ∪ deps(f)` 的传递闭包（闭包沿
`deps` 扩展：展开 `g` 时 `g` 依赖的定义也展开，论文 2.2 节）。`unfold(h) { e }` 在检查 `e`
期间把 `h` 及其闭包加入 `S`。检查签名时 `S` 为空。

**能否展开** `can_unfold(n)`：

1. `n ∈ S`：可以；
2. 否则，`n` 不透明或封闭：不可以；
3. 否则（透明），当且仅当 `deps(n)` 中的定义都能展开（论文的 abbreviation：依赖展开的透明
   定义随依赖一起展开）。

`can_unfold` 在所有展开与检查时执行的地方检查：`force`/`unfold`、转换检查的 `unfold_any`、
执行可变状态函数的 `exec_call` 以及执行中的调用。不能展开的调用保持折叠，像变量一样参与
合一（比较头部与参数）。

**辅助定义**：定义体中产生的全局辅助定义（递归局部函数、默认参数、效应的翻译版本）继承
所在声明的展开集合作为依赖。

### 与论文的差异

- 不精化到扩展类型，而是像 Agda 一样在展开处检查。
- 表达式层的 `unfold(f) { e }` 不提升为新的全局常量（论文 2.5 节），而是：检查 `e` 时可以展开
  `f`，并把 `f` 加入所在声明的依赖。所以 `unfold` 块的效果相当于声明层的 `#unfold`（论文中
  `⊕-left-unit` 与 `⊕-left-unit′` 的区别不保留）；在类型中的 `unfold` 块只影响类型本身的检查。
  检查器从不重新检查已经精化的项，所以这只可能让展开后的比较失败（不完备），不会接受类型错误
  的项；而结果更简单：目标中不会出现 `unfold` 留下的常量。
- 不精化到核心演算，也就没有正规化定理；这与 MoonBit++ 其他部分一致。

## 4. 与现有特性的交互

- **Prelude 与 trait**：Prelude 的函数、trait 方法与实例保持透明（`2 + 2 === 4` 仍然成立）。
- **错误作为值**：参数中的 `raise e` 照常传播（`f(raise e) === raise e` 与 `f` 的定义无关）。
  不透明函数抛出的错误只有展开时才可见。
- **效应**：被完整处理、实例化为纯的调用照常展开；不透明的效应多态函数不展开。
- **检查时执行**：不透明函数在展开范围外不执行，可以用来避免超时。
- **`#mbt`、编译**：不受影响。
- **错误提示**：检查失败时，如果这期间有不透明的定义没有展开，提示
  `hint: f is opaque here; if its definition is needed, add #unfold(f) to the declaration or use unfold(f) { … }`。

## 5. 实现

1. 解析：属性 `#opaque`、`#opaque(sealed)`、`#unfold(f, …)`（`DUnfoldAttr` 包装，像
   `#timelimit` 一样在检查前剥离并记录）；表达式 `unfold(f, …) { e }`（`unfold` 不是关键字：
   后面紧跟 `(` 和 `{` 块时才是展开块）；策略 `unfold f, …`。
2. 检查器：模式与依赖表；展开范围栈（声明定义体、签名、`unfold` 块、策略）；`can_unfold`
   及其在 `unfold`、`unfold_any`、`exec` 中的检查；辅助定义继承依赖；错误提示。
3. 测试、手册一章（“受控展开”，放在“命题与证明”之下）、示例。
