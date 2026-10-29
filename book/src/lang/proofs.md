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

> 没有终止检查和严格正性检查：递归函数和递归证明都直接接受，因此可以“证明”假命题。证明在
> 编译时也不擦除。
