# 命题与证明

命题是 `Prop` 中的类型，证明是它们的值。类型检查器在检查证明时会计算（规范化）表达式，所以
很多等式可以直接由计算得出。

- [命题相等](equality.md)：`===`、`Refl` 与 Prelude 中的等式引理。
- [lemma](lemma.md)：声明定理。
- [策略](tactics.md)：用 `proof { … }` 一步步构造证明。

自定义的命题是宇宙为 `Prop` 的 enum：

```moonbit
enum And[A : Prop, B : Prop] : Prop {
  Conj(A, B)
}

lemma and_comm[A : Prop, B : Prop](p : And[A, B]) -> And[B, A] {
  match p {
    Conj(a, b) => Conj(b, a)
  }
}
```

> 没有终止检查和严格正性检查：递归函数和递归证明都直接接受，因此可以“证明”假命题。
>
> 命题是证明无关的：同一命题的两个证明相等，证明只能消去到命题，或者在命题是子单例（至多一个
> 构造子、字段都是证明，如 `===`）时消去到任意类型。所以没有值依赖于证明，编译时所有证明都被
> 擦除（见[编译到 MoonBit](../interop/compile.md)）。用假证明做的转换（`Id::subst`）在编译后的
> 程序中不会因无限递归而停住，而会在类型不符处报运行时错误。
