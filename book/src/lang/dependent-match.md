# 依赖匹配与细化

匹配一个变量时，构造子的索引与变量类型中的索引做合一，结果细化整个上下文和目标类型
（Agda 风格）：

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

fn main {
  let v : Vec2[Int](2) = VCons(1, VCons(2, VNil))
  match v.zip_with(v, (a, b) => a + b) {
    VCons(x, _) => println(x)
  }
}
```

- 匹配 `self` 得到 `VNil` 时，合一得出 `n = 0`。于是 `other : Vec2[T](0)` 只能是 `VNil`，
  `(VNil, VCons(…))` 这样的组合不需要写。
- 每个分支中，目标类型 `Vec2[T](n)` 也被细化：`VNil` 分支返回 `Vec2[T](0)`，`VCons` 分支返回
  `Vec2[T](S(n'))`。
- 匹配隐式参数也会细化。例如在 `fn[T, n : Nat] first_or(v : Vector[T](n), d : T)` 中
  `match n { … }`：`S(_)` 分支中 `v : Vector[T](S(_))`，所以再匹配 `v` 时只需要 `Cons` 分支。

## 匹配函数调用的结果

被匹配的不是变量（例如函数调用）时，结果类型中的索引关系同样用于细化目标类型。下面的片段取自
简单类型 λ 演算的类型安全证明：`progress(t1)` 的类型是 `Progress(t1)`，结果说明项 `t1` 能再走一步
（`PrStep`）或已经是值（`PrDone`）。在 `PrDone(_, VLam(b))` 分支中，构造子的索引与 `t1` 合一，
检查器得知 `t1` 就是 `Lam(b)`，所以 `StApp(b, t2)` 可以作为 `App(t1, t2)` 的一步：

```text
match progress(t1) {
  PrStep(_, u1, st1) => PrStep(_, _, StApp1(t1, u1, t2, st1))
  PrDone(_, VLam(b)) => PrStep(_, _, StApp(b, t2))
}
```

完整的例子见仓库中的 `examples/stlc.mbtpp`。

## 匹配目标中的表达式

在证明中（目标是命题时），被匹配的表达式如果出现在目标里，会先被抽象成一个新的变量，再对这个
变量做依赖匹配，所以每个分支中目标里的这个表达式被替换为分支的模式（Agda 的 `with`）。表达式
可以出现在目标所提到的函数的定义中，检查器会展开几层去找：

```moonbit
fn insert(x : Int, xs : List[Int]) -> List[Int] {
  match xs {
    Nil => Cons(x, Nil)
    Cons(y, rest) => if x <= y { Cons(x, xs) } else { Cons(y, insert(x, rest)) }
  }
}

fn length(xs : List[Int]) -> Nat {
  match xs {
    Nil => Z
    Cons(_, r) => S(length(r))
  }
}

lemma insert_length(x : Int, xs : List[Int]) -> length(insert(x, xs)) === S(length(xs)) {
  match xs {
    Nil => Refl
    Cons(y, rest) =>
      // 目标中 insert 的定义里有 `x <= y`：true 分支中它是 true
      match x <= y {
        true => Refl
        false => Id::cong(S, insert_length(x, rest))
      }
  }
}
```

- 只在目标是命题时这样做；普通函数中的 `match` 不受影响。
- 字面量模式（`true`、`0`、`"a"`）也会细化被匹配的变量：分支中这个变量就是那个字面量。

## Prop 的消去

匹配 `Prop` 中的数据（证明）时，结果也必须在 `Prop` 中，因为证明在编译时被擦除，运行时无法根据它
选择分支。例外是**子单例**：至多一个构造子、字段都是证明的命题，例如命题相等 `===`。匹配它不需要
在运行时做选择，所以结果可以是任意类型（见[命题与证明](proofs.md)）。
