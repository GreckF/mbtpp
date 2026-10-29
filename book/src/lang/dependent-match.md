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
- 匹配隐式参数也会细化，例如 `match g { Empty => …; Extend(_, _) => … }`，其中 `g` 是函数的
  隐式参数。

## 匹配函数调用的结果

被匹配的不是变量（例如函数调用）时，结果类型中的索引关系同样用于细化目标类型：

```text
match progress(t1) {
  PrStep(_, u1, st1) => PrStep(_, _, StApp1(t1, u1, t2, st1))
  PrDone(_, VLam(b)) => PrStep(_, _, StApp(b, t2))
}
```

完整的例子见仓库中的 `examples/stlc.mbtpp`。

## Prop 的消去

匹配 `Prop` 中的数据时，结果也必须在 `Prop` 中，除非这个类型是子单例（如命题相等 `===`，
它最多只有一个证明）。
