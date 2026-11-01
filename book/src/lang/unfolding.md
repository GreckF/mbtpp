# 受控展开

类型检查时，函数默认会被展开（计算），所以 `2 + 2 === 4` 可以直接用 `Refl` 证明。但证明依赖函数的
具体定义也有代价：改动定义（比如让加法对第二个参数递归）会让依赖它的证明全部失效；展开或执行大的
定义也会拖慢检查，甚至超过[检查时限](type-level.md#检查时限)。

`#opaque` 让一个函数在类型检查时不展开，只有在明确要求的地方才展开：

```moonbit
#opaque
fn add(m : Nat, n : Nat) -> Nat {
  match m {
    Z => n
    S(k) => S(add(k, n))
  }
}

// 只有这两条引理依赖 add 的定义
#unfold(add)
lemma add_z(n : Nat) -> add(Z, n) === n { Refl }

#unfold(add)
lemma add_s(m : Nat, n : Nat) -> add(S(m), n) === S(add(m, n)) { Refl }

// 其余的证明只用上面的引理
lemma add_n_z(n : Nat) -> add(n, Z) === n {
  match n {
    Z => add_z(Z)
    S(k) => Id::trans(add_s(k, Z), Id::cong(S, add_n_z(k)))
  }
}

fn main {
  println(add(3, 4).to_int())
}
```

`add` 仍然是普通的函数，运行和编译都不受影响；只是在类型检查时，`add(Z, n)` 不会被计算成 `n`，
而像一个未知函数的调用一样保持原样。改动 `add` 的定义时，只需要重新证明 `add_z` 和 `add_s`。

## 展开的三种写法

| 写法 | 范围 |
| --- | --- |
| `#unfold(f, g)` 写在声明前 | 这个声明的定义体 |
| `unfold(f, g) { e }` | 表达式 `e`，可以出现在类型中 |
| `proof { unfold f, g … }` 中的策略 | 证明的其余部分 |

```moonbit
#opaque
fn add(m : Nat, n : Nat) -> Nat {
  match m {
    Z => n
    S(k) => S(add(k, n))
  }
}

lemma two_plus_two() -> add(2, 2) === 4 {
  unfold(add) { Refl }
}

lemma two_plus_two_t : add(2, 2) === 4 = proof {
  unfold add
  rfl
}
```

- `#unfold` 只作用于定义体，不作用于声明的类型；类型中需要展开时，在类型里写 `unfold(f) { … }`。
- 在一个声明中用到 `unfold` 块或 `unfold` 策略，相当于这个声明 `#unfold` 了这些函数（见下面的
  传递性）。
- 一个不透明函数在自己的定义体中可以展开，例如递归调用。
- 不能展开时出错，检查器会提示：

  ```text
  t.mbtpp:8:35: error: type mismatch
    expected: add(1, 1) === 2
    ...
  hint: add is opaque here; if the definition is needed, add #unfold(add) to the declaration, or use unfold(add) { … }
  ```

## 传递性

展开一个函数时，它所展开的函数也一起展开。下面的 `app` 的类型用到 `add`，定义体只有在 `add`
可以计算时才合乎类型，所以它 `#unfold(add)`；展开 `app` 的证明因此也能计算 `add`：

```moonbit
#opaque
fn add(m : Nat, n : Nat) -> Nat {
  match m {
    Z => n
    S(k) => S(add(k, n))
  }
}

enum Vec[T] : Nat -> Type {
  VNil : Vec[T](0)
  VCons[n : Nat](T, Vec[T](n)) : Vec[T](S(n))
}

#opaque
#unfold(add)
fn[T, m : Nat, n : Nat] app(u : Vec[T](m), v : Vec[T](n)) -> Vec[T](add(m, n)) {
  match u {
    VNil => v
    VCons(x, r) => VCons(x, app(r, v))
  }
}

// app(VNil, v) 的类型是 Vec[T](add(0, n))，v 的类型是 Vec[T](n)：
// 写等式需要在类型中展开 add；证明展开 app，也就展开了 add
#unfold(app)
lemma app_nil[T, n : Nat](v : Vec[T](n)) -> app(VNil, v) === unfold(add) { v } {
  Refl
}
```

没有 `#opaque` 但写了 `#unfold(f)` 的函数，只在 `f` 可以展开的地方展开：它的定义依赖 `f` 的
计算，在 `f` 不展开的地方展开它没有意义。

## 不执行

使用可变状态的函数在类型检查时会被执行（见[可变状态与循环](mutation.md#与类型检查的关系)）。
不透明的函数在展开范围之外也不执行，这可以用来避免检查时不必要的计算：

```moonbit
#opaque
fn sum_to(n : Int) -> Int {
  let mut acc = 0
  for i = 1; i <= n; i = i + 1 {
    acc = acc + i
  }
  acc
}

#unfold(sum_to)
lemma sum_10() -> sum_to(10) === 55 { Refl }
```

## `#opaque(sealed)`

`#opaque(sealed)` 的函数在任何地方都不能展开（只有它自己的定义体可以），`#unfold`、`unfold` 中
写它会报错。用它可以确保其他代码只通过公开的引理使用这个函数。

## 说明

- `#opaque`、`#unfold` 可以写在 `fn` 和 `lemma` 上（包括方法），可以与 `#mbt`、`#timelimit`
  一起写。没有标注的函数（包括 Prelude 的函数和 trait 的实例）照常展开。
- 不透明只影响类型检查：解释器、编译器和擦除都不受影响。
- 参数中的错误照常传播：`f(raise e)` 是 `raise e`，与 `f` 是否展开无关（见
  [错误作为逻辑中的值](errors.md#错误作为逻辑中的值)）。
- 这一机制来自 Gratzer 等人的 *Controlling Unfolding in Type Theory*；与论文不同，MoonBit++ 的
  函数默认是透明的。设计说明见仓库中的 `doc/mbtpp/unfolding.md`。
